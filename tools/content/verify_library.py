#!/usr/bin/env python3
"""فحص سلامة قاعدة مكتبة. هذا هو المرجع الذي سيُنفَّذ ما يقابله داخل التطبيق (المرحلة 4)."""
import sqlite3, sys

REQUIRED_META = {
    "quran": ["source", "license", "license_notice", "ayah_count", "surah_count"],
    "bukhari": ["source", "license", "numbering", "hadith_count"],
    "muslim": ["source", "license", "numbering", "hadith_count"],
}


def verify(path):
    problems = []
    try:
        db = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        if db.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
            return ["فشل integrity_check"]
        meta = dict(db.execute("SELECT key, value FROM meta"))
    except sqlite3.Error as e:
        return [f"تعذّر فتح القاعدة: {e}"]
    lib = meta.get("library")
    if lib not in REQUIRED_META:
        return [f"مكتبة غير معروفة: {lib!r}"]
    for k in REQUIRED_META[lib]:
        if not meta.get(k):
            problems.append(f"حقل meta مفقود: {k}")
    if lib == "quran":
        n = db.execute("SELECT COUNT(*) FROM ayahs").fetchone()[0]
        s = db.execute("SELECT COUNT(*) FROM surahs").fetchone()[0]
        if s != 114: problems.append(f"عدد السور {s}")
        if n != int(meta.get("ayah_count", -1)) or n != 6236: problems.append(f"عدد الآيات {n}")
        if db.execute("SELECT COUNT(*) FROM ayahs WHERE text=''").fetchone()[0]:
            problems.append("آيات فارغة")
        bad = db.execute("""SELECT s.id FROM surahs s LEFT JOIN ayahs a ON a.surah=s.id
                            GROUP BY s.id HAVING COUNT(a.id)<>s.ayah_count""").fetchall()
        if bad: problems.append(f"سور ناقصة: {[b[0] for b in bad]}")
    else:
        n = db.execute("SELECT COUNT(*) FROM hadiths").fetchone()[0]
        if n != int(meta.get("hadith_count", -1)) or n == 0: problems.append(f"عدد الأحاديث {n}")
        orphan = db.execute("SELECT COUNT(*) FROM hadiths h LEFT JOIN books b ON b.id=h.book_id WHERE b.id IS NULL").fetchone()[0]
        if orphan: problems.append(f"أحاديث بلا كتاب: {orphan}")
        empty = db.execute("SELECT COUNT(*) FROM hadiths WHERE text=''").fetchone()[0]
        if empty and not meta.get("empty_text_numbers"): problems.append(f"نصوص فارغة غير موثقة: {empty}")
    return problems


if __name__ == "__main__":
    p = verify(sys.argv[1])
    print("سليمة" if not p else "مشكلات: " + "; ".join(p))
    sys.exit(0 if not p else 3)
