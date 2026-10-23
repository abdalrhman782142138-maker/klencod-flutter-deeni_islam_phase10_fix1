#!/usr/bin/env python3
"""يبني quran.db من ملفات Tanzil دون أي تعديل على النص.

الاستخدام:
  build_quran_db.py --text quran-uthmani.txt --meta quran-data.xml --out quran.db

المدخلات تُنزَّل يدوياً من tanzil.net (شروط Tanzil: نسخ حرفي، بلا تغيير للنص،
مع ذكر المصدر ورابط tanzil.net، وإبقاء الإشعار في الملفات المشتقة).
يفشل البناء عند أي نقص: لا يُنتَج ملف ناقص أبداً.
"""
import argparse, hashlib, os, sqlite3, sys
import xml.etree.ElementTree as ET
from arnorm import normalize_ar
from expected_counts import SURAH_AYAH_COUNTS, TOTAL_AYAT


class BuildError(Exception):
    pass


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def parse_text(path):
    notice, rows = [], []
    with open(path, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            line = line.rstrip("\r\n")
            if not line.strip():
                continue
            if line.startswith("#"):
                notice.append(line)
                continue
            parts = line.split("|", 2)
            if len(parts) != 3:
                raise BuildError(f"سطر غير صالح رقم {n}: {line[:60]!r}")
            try:
                s, a = int(parts[0]), int(parts[1])
            except ValueError:
                raise BuildError(f"رقم سورة/آية غير صالح في السطر {n}")
            if not parts[2].strip():
                raise BuildError(f"نص فارغ في {s}:{a}")
            rows.append((s, a, parts[2]))
    return rows, "\n".join(notice)


def validate_rows(rows):
    seen = {}
    for s, a, _ in rows:
        if not 1 <= s <= 114:
            raise BuildError(f"رقم سورة خارج النطاق: {s}")
        if (s, a) in seen:
            raise BuildError(f"آية مكررة {s}:{a}")
        seen[(s, a)] = 1
    for s in range(1, 115):
        want = SURAH_AYAH_COUNTS[s - 1]
        got = sorted(a for (ss, a) in seen if ss == s)
        if got != list(range(1, want + 1)):
            raise BuildError(f"سورة {s}: المتوقع {want} آية متتابعة، الموجود {len(got)}")
    if len(rows) != TOTAL_AYAT:
        raise BuildError(f"مجموع الآيات {len(rows)} بدل {TOTAL_AYAT}")


def parse_meta(path):
    root = ET.parse(path).getroot()
    suras = [e for e in root.iter() if e.tag.split("}")[-1] == "sura"]
    if len(suras) != 114:
        raise BuildError(f"ملف البيانات الوصفية يحوي {len(suras)} سورة بدل 114")
    out = {}
    for e in suras:
        i = int(e.attrib["index"])
        out[i] = dict(
            name_ar=e.attrib["name"], name_tr=e.attrib.get("tname", ""),
            name_en=e.attrib.get("ename", ""), type=e.attrib.get("type", ""),
            order=int(e.attrib.get("order", 0) or 0), ayas=int(e.attrib["ayas"]),
        )
    for i in range(1, 115):
        if i not in out:
            raise BuildError(f"سورة {i} غير موجودة في البيانات الوصفية")
        if out[i]["ayas"] != SURAH_AYAH_COUNTS[i - 1]:
            raise BuildError(f"تعارض عدد آيات سورة {i} بين المرجعين")
    return out


def build(text, meta, out, source_version, fts_enabled=False):
    rows, notice = parse_text(text)
    if not notice:
        raise BuildError("إشعار الترخيص غير موجود في ملف النص؛ لا يجوز اشتقاق ملف بدونه")
    validate_rows(rows)
    sm = parse_meta(meta)
    if os.path.exists(out):
        os.remove(out)
    db = sqlite3.connect(out)
    db.executescript("""
    PRAGMA journal_mode=OFF;
    CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
    CREATE TABLE surahs(id INTEGER PRIMARY KEY, name_ar TEXT NOT NULL, name_tr TEXT,
        name_en TEXT, type TEXT, revelation_order INTEGER, ayah_count INTEGER NOT NULL);
    CREATE TABLE ayahs(id INTEGER PRIMARY KEY, surah INTEGER NOT NULL, ayah INTEGER NOT NULL,
        text TEXT NOT NULL, search TEXT NOT NULL, UNIQUE(surah, ayah));
    """)
    for i, m in sm.items():
        db.execute("INSERT INTO surahs VALUES(?,?,?,?,?,?,?)",
                   (i, m["name_ar"], m["name_tr"], m["name_en"], m["type"], m["order"], m["ayas"]))
    for s, a, t in sorted(rows):
        db.execute("INSERT INTO ayahs(surah,ayah,text,search) VALUES(?,?,?,?)",
                   (s, a, t, normalize_ar(t)))
    fts = "none"
    try:
        if not fts_enabled:
            raise sqlite3.OperationalError("fts disabled")
        db.execute("CREATE VIRTUAL TABLE ayahs_fts USING fts5(search, content='ayahs', content_rowid='id')")
        db.execute("INSERT INTO ayahs_fts(rowid, search) SELECT id, search FROM ayahs")
        fts = "fts5"
    except sqlite3.OperationalError:
        pass
    meta_rows = {
        "schema_version": "1", "library": "quran", "source": "Tanzil.net",
        "source_url": "http://tanzil.net", "license": "CC BY 3.0",
        "license_notice": notice, "source_text_file": os.path.basename(text),
        "source_text_sha256": sha256_file(text), "source_meta_sha256": sha256_file(meta),
        "source_version": source_version, "surah_count": "114", "ayah_count": str(len(rows)),
        "search_normalization": "arnorm.py v1", "fts": fts,
    }
    db.executemany("INSERT INTO meta VALUES(?,?)", meta_rows.items())
    db.commit()
    db.execute("VACUUM")
    db.close()
    return meta_rows


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--text", required=True)
    ap.add_argument("--meta", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--source-version", default="unspecified")
    ap.add_argument("--fts", action="store_true", help="إنشاء جدول FTS5 (غير مطلوب؛ يتطلب SQLite بدعم FTS5)")
    a = ap.parse_args()
    try:
        r = build(a.text, a.meta, a.out, a.source_version, a.fts)
    except BuildError as e:
        if os.path.exists(a.out):
            os.remove(a.out)
        print("فشل البناء:", e, file=sys.stderr)
        sys.exit(2)
    print(f"تم: {a.out} · {r['surah_count']} سورة · {r['ayah_count']} آية · fts={r['fts']}")
