"""فحص تعاقدي بين كود Dart وأدوات Python (بدون مترجم Dart).

1) مفاتيح manifest.json التي ينتجها make_manifest تغطي كل ما يقرؤه manifest.dart.
2) جمل SQL في db_inspector.dart تعمل فعلاً على قواعد ينتجها البانيان (أسماء الجداول والأعمدة صحيحة).
البيانات صناعية (FIXTURES) ولا تُشحن."""
import json, os, re, sqlite3, sys, tempfile, unittest
HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
import build_quran_db as bq, build_hadith_db as bh, make_manifest as mm
from test_pipeline import write_quran_fixture, write_hadith_fixture
import argparse

DART = os.path.join(HERE, "..", "..", "..", "lib", "core", "content")


def dart_text(name):
    return open(os.path.join(DART, name), encoding="utf-8").read()


def sql_statements(src):
    lit = r"""(?:'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")"""
    out = []
    for m in re.finditer(lit + r"(?:\s*" + lit + r")*", src):
        parts = re.findall(lit, m.group(0))
        s = "".join(p[1:-1] for p in parts)
        if re.match(r"\s*(SELECT|PRAGMA)\b", s):
            out.append(s)
    return out


class Contract(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()
        t, m = write_quran_fixture(self.d)
        self.q = os.path.join(self.d, "quran.db"); bq.build(t, m, self.q, "f")
        e = write_hadith_fixture(self.d)
        self.h = os.path.join(self.d, "bukhari.db")
        bh.build(argparse.Namespace(edition=e, library="bukhari", title="ت", out=self.h, source="s",
                 source_version="v", license="L", license_url="u", numbering="n", expected_last=None,
                 expected_count=None, allow_empty=0))

    def test_manifest_keys(self):
        man = mm.build(1, "https://example.invalid/x", os.path.join(self.d, "o"),
                       [("quran", self.q), ("bukhari", self.h)])
        src = dart_text("manifest.dart")
        lib_keys = set(re.findall(r"_(?:str|posInt|hex)\(raw, '(\w+)'\)", src))
        root_keys = set(re.findall(r"root\['(\w+)'\]", src)) | set(re.findall(r"_posInt\(root, '(\w+)'\)", src))
        self.assertTrue(lib_keys and root_keys)
        for k in lib_keys:
            self.assertIn(k, man["libraries"][0], f"المفتاح {k} يقرؤه Dart ولا ينتجه Python")
        for k in root_keys:
            self.assertIn(k, man, f"مفتاح الجذر {k}")

    def test_inspector_sql_runs_on_real_schema(self):
        stmts = sql_statements(dart_text("db_inspector.dart"))
        self.assertGreaterEqual(len(stmts), 8)
        for path, tables in ((self.q, ("surahs", "ayahs")), (self.h, ("hadiths", "books"))):
            db = sqlite3.connect(path)
            ran = 0
            for s in stmts:
                is_quran = "surahs" in s or "ayahs" in s
                is_had = "hadiths" in s or "books" in s
                if (is_quran and path != self.q) or (is_had and path != self.h):
                    continue
                db.execute(s).fetchall(); ran += 1   # يرفع استثناء إن كان الاسم خطأ
            self.assertGreaterEqual(ran, 3)
            self.assertEqual(db.execute("PRAGMA integrity_check").fetchone()[0], "ok")

    def test_meta_keys_used_by_dart_exist(self):
        src = dart_text("db_inspector.dart")
        keys = set(re.findall(r"meta\['(\w+)'\]", src)) | {"source", "license"}
        qm = dict(sqlite3.connect(self.q).execute("SELECT key,value FROM meta"))
        hm = dict(sqlite3.connect(self.h).execute("SELECT key,value FROM meta"))
        for k in keys:
            if k == "ayah_count": self.assertIn(k, qm)
            elif k in ("hadith_count", "numbering", "empty_text_numbers"): self.assertIn(k, hm)
            else: self.assertTrue(k in qm and k in hm, k)

    def test_dart_normalizer_matches_python(self):
        """جداول arabic_normalizer.dart تطابق arnorm.py على كل رمز BMP."""
        import arnorm
        src = open(os.path.join(DART, "..", "utils", "arabic_normalizer.dart"), encoding="utf-8").read()
        ranges = [(int(a, 16), int(b, 16)) for a, b in
                  re.findall(r"<int>\[0x([0-9A-Fa-f]+), 0x([0-9A-Fa-f]+)\]", src)]
        cmap = {int(k, 16): v for k, v in re.findall(r"0x([0-9A-Fa-f]+): '(.)'", src)}
        self.assertTrue(ranges and cmap)
        def dart_sim(cp):
            if any(a <= cp <= b for a, b in ranges):
                return ""
            return cmap.get(cp, chr(cp))
        mism = []
        for cp in list(range(0x21, 0xD800)) + list(range(0xE000, 0x10000)):
            ch = chr(cp)
            if ch.isspace():
                continue
            if arnorm.normalize_ar(ch) != dart_sim(cp):
                mism.append(hex(cp))
        self.assertEqual(mism, [], f"فروق بين Dart وPython: {mism[:10]}")

    def test_repository_sql_runs_on_real_schema(self):
        src = open(os.path.join(DART, "..", "quran", "quran_repository.dart"), encoding="utf-8").read()
        stmts = sql_statements(src)
        self.assertGreaterEqual(len(stmts), 3)
        db = sqlite3.connect(self.q)
        for s_ in stmts:
            if s_.rstrip().endswith("WHERE"):   # بادئة البحث: تُجرَّب مع الجملة أدناه
                continue
            n = s_.count("?")
            db.execute(s_, [1] * n).fetchall()
        like = re.search(r'_likeClause = "(.*?)";', src).group(1).replace("\\\\", "\\")
        prefix = re.search(r"_searchPrefix =\s*'(.*?)';", src).group(1)
        q = f"{prefix}{like} AND {like} ORDER BY surah, ayah LIMIT ?"
        rows = db.execute(q, ["%اختباري%", "%1%", 5]).fetchall()
        self.assertEqual(len(rows), 5)
        # الهروب: % و _ حرفيان
        self.assertEqual(db.execute(f"{prefix}{like} LIMIT 5", ["%\\%%"]).fetchall(), [])

    def test_hadith_repository_sql_runs_on_real_schema(self):
        """يحلّ ثوابت static const في hadith_repository.dart (مع \\${...}) ويجرّب كل SELECT."""
        src = open(os.path.join(DART, "..", "hadith", "hadith_repository.dart"), encoding="utf-8").read()
        lit = r"""(?:'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")"""
        consts = {}
        for m in re.finditer(r"static const String (\w+)\s*=\s*((?:" + lit + r"\s*)+);", src):
            parts = re.findall(lit, m.group(2))
            val = "".join(p[1:-1] for p in parts)
            val = re.sub(r"\$\{(\w+)\}", lambda x: consts[x.group(1)], val)
            consts[m.group(1)] = val
        stmts = {k: v for k, v in consts.items() if re.match(r"\s*SELECT\b", v)}
        self.assertGreaterEqual(len(stmts), 6, list(stmts))
        db = sqlite3.connect(self.h)
        for name, q in stmts.items():
            if q.rstrip().endswith("WHERE"):
                continue
            params, idx = [], 0
            for mm_ in re.finditer(r"\?", q):
                before = q[:mm_.start()]
                params.append("1" if before.rstrip().endswith("number =") else 1)
            db.execute(q, params).fetchall()
        like = consts["_likeClause"].replace("\\\\", "\\")
        q = f"{consts['_cols']}{like} AND {like} ORDER BY ord LIMIT ?"
        rows = db.execute(q, ["%اختباري%", "%1%", 5]).fetchall()
        self.assertEqual(len(rows), 1)       # الحديث رقم 1 فقط يحوي «1»
        # أول دفعة من الكتاب 1 مرتبة، والدفعة السابقة معكوسة ثم تُقلب في Dart
        nxt = db.execute(consts["_nextSql"], [1, 0, 40]).fetchall()
        self.assertEqual([r[1] for r in nxt], [1, 2, 3])
        prv = db.execute(consts["_prevSql"], [1, 3, 40]).fetchall()
        self.assertEqual([r[1] for r in prv], [2, 1])
        self.assertEqual(db.execute(consts["_beforeSql"], [1, 1]).fetchall(), [])
        self.assertTrue(db.execute(consts["_beforeSql"], [1, 2]).fetchall())
        self.assertEqual(len(db.execute(consts["_byNumberSql"], ["4"]).fetchall()), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
