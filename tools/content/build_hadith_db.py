#!/usr/bin/env python3
"""يبني قاعدة بيانات لكتاب حديث من إصدار JSON بصيغة hadith-api.

الاستخدام:
  build_hadith_db.py --edition ara-bukhari.json --library bukhari --title "صحيح البخاري" \
     --expected-last N --license "..." --license-url URL --numbering "..." --out bukhari.db

لا يُخمَّن شيء: إذا اختلف شكل الملف عن المتوقع يتوقف البناء ويشرح السبب.
--expected-last: آخر رقم حديث مرجعي (من info.json في المصدر) للتحقق من الاكتمال.
"""
import argparse, hashlib, json, os, sqlite3, sys
from arnorm import normalize_ar


class BuildError(Exception):
    pass


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def load_edition(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict) or "hadiths" not in data or "metadata" not in data:
        keys = list(data)[:8] if isinstance(data, dict) else type(data).__name__
        raise BuildError(f"شكل الملف غير متوقع (المفاتيح: {keys}). أرسل لي عينة لأعدّل المحلّل.")
    return data


def extract(data, allow_empty):
    meta = data["metadata"]
    sections = meta.get("sections") or {}
    if not sections:
        raise BuildError("لا توجد أقسام (كتب) في metadata.sections")
    details = meta.get("section_details") or {}
    items, seen, empties = [], set(), []
    for ord_, h in enumerate(data["hadiths"], 1):
        for k in ("hadithnumber", "text"):
            if k not in h:
                raise BuildError(f"الحديث ترتيب {ord_} بلا الحقل {k}")
        num = str(h["hadithnumber"])
        if num in seen:
            raise BuildError(f"رقم حديث مكرر: {num}")
        seen.add(num)
        text = (h["text"] or "").strip()
        if not text:
            empties.append(num)
        ref = h.get("reference") or {}
        sec = ref.get("book")
        if sec is None:
            sec = _section_by_range(details, h["hadithnumber"])
        if sec is None or str(sec) not in sections:
            raise BuildError(f"تعذّر تحديد الكتاب للحديث {num}")
        items.append((ord_, num, int(sec), text))
    if len(empties) > allow_empty:
        raise BuildError(f"{len(empties)} حديثاً بنص فارغ (أمثلة: {empties[:5]}). المسموح {allow_empty}.")
    return sections, items, empties


def _section_by_range(details, n):
    for sid, d in details.items():
        lo, hi = d.get("hadithnumber_first"), d.get("hadithnumber_last")
        if lo is not None and hi is not None and lo <= n <= hi:
            return sid
    return None


def build(a):
    data = load_edition(a.edition)
    sections, items, empties = extract(data, a.allow_empty)
    if not items:
        raise BuildError("لا توجد أحاديث")
    last = max(float(n) for _, n, _, _ in items)
    if a.expected_last is not None and int(last) != a.expected_last:
        raise BuildError(f"آخر رقم {last} لا يطابق المرجع {a.expected_last}")
    if a.expected_count is not None and len(items) != a.expected_count:
        raise BuildError(f"عدد الأحاديث {len(items)} لا يطابق المرجع {a.expected_count}")
    if os.path.exists(a.out):
        os.remove(a.out)
    db = sqlite3.connect(a.out)
    db.executescript("""
    PRAGMA journal_mode=OFF;
    CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
    CREATE TABLE books(id INTEGER PRIMARY KEY, name_ar TEXT NOT NULL, hadith_count INTEGER NOT NULL);
    CREATE TABLE hadiths(id INTEGER PRIMARY KEY, ord INTEGER NOT NULL, number TEXT NOT NULL UNIQUE,
        book_id INTEGER NOT NULL REFERENCES books(id), text TEXT NOT NULL, search TEXT NOT NULL);
    CREATE INDEX hadiths_book ON hadiths(book_id, ord);
    """)
    counts = {}
    for _, _, sid, _ in items:
        counts[sid] = counts.get(sid, 0) + 1
    for sid, name in sections.items():
        if counts.get(int(sid)):
            db.execute("INSERT INTO books VALUES(?,?,?)", (int(sid), name, counts[int(sid)]))
    for ord_, num, sid, text in items:
        db.execute("INSERT INTO hadiths(ord,number,book_id,text,search) VALUES(?,?,?,?,?)",
                   (ord_, num, sid, text, normalize_ar(text)))
    fts = "none"
    try:
        if not getattr(a, "fts", False):
            raise sqlite3.OperationalError("fts disabled")
        db.execute("CREATE VIRTUAL TABLE hadiths_fts USING fts5(search, content='hadiths', content_rowid='id')")
        db.execute("INSERT INTO hadiths_fts(rowid, search) SELECT id, search FROM hadiths")
        fts = "fts5"
    except sqlite3.OperationalError:
        pass
    m = {
        "schema_version": "1", "library": a.library, "title_ar": a.title,
        "source": a.source, "source_edition_file": os.path.basename(a.edition),
        "source_sha256": sha256_file(a.edition), "source_version": a.source_version,
        "license": a.license, "license_url": a.license_url, "numbering": a.numbering,
        "hadith_count": str(len(items)), "last_number": str(int(last)),
        "book_count": str(len(counts)), "empty_text_numbers": ",".join(empties),
        "search_normalization": "arnorm.py v1", "fts": fts,
    }
    db.executemany("INSERT INTO meta VALUES(?,?)", m.items())
    db.commit(); db.execute("VACUUM"); db.close()
    return m


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--edition", required=True)
    p.add_argument("--library", required=True, choices=["bukhari", "muslim"])
    p.add_argument("--title", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--source", default="fawazahmed0/hadith-api")
    p.add_argument("--source-version", default="unspecified")
    p.add_argument("--license", required=True)
    p.add_argument("--license-url", required=True)
    p.add_argument("--numbering", required=True)
    p.add_argument("--expected-last", type=int)
    p.add_argument("--expected-count", type=int)
    p.add_argument("--allow-empty", type=int, default=0)
    p.add_argument("--fts", action="store_true")
    a = p.parse_args()
    try:
        r = build(a)
    except BuildError as e:
        if os.path.exists(a.out):
            os.remove(a.out)
        print("فشل البناء:", e, file=sys.stderr)
        sys.exit(2)
    print(f"تم: {a.out} · {r['hadith_count']} حديثاً · {r['book_count']} كتاباً · fts={r['fts']}")
