"""اختبارات منطق الأدوات فقط. البيانات هنا اختبارية صناعية (FIXTURES)
تُولَّد داخل الاختبار ولا تُشحن مع التطبيق ولا تمثل أي محتوى ديني حقيقي."""
import base64, gzip, json, os, sqlite3, sys, tempfile, unittest
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import arnorm, build_quran_db as bq, build_hadith_db as bh, make_manifest as mm, verify_library as vl
from expected_counts import SURAH_AYAH_COUNTS

NOTICE = "# FIXTURE-NOTICE: اختبار فقط"


def write_quran_fixture(d, drop=None, wrong_meta=False):
    lines = [NOTICE]
    for s, n in enumerate(SURAH_AYAH_COUNTS, 1):
        for a in range(1, n + 1):
            if drop != (s, a):
                lines.append(f"{s}|{a}|نصٌّ اختباري {s} {a}")
    t = os.path.join(d, "t.txt"); open(t, "w", encoding="utf-8").write("\n".join(lines))
    suras = "".join(f'<sura index="{i}" ayas="{n + (1 if wrong_meta and i == 2 else 0)}" name="س{i}" tname="t" ename="e" type="Meccan" order="{i}"/>'
                    for i, n in enumerate(SURAH_AYAH_COUNTS, 1))
    m = os.path.join(d, "m.xml"); open(m, "w", encoding="utf-8").write(f"<quran>{suras}</quran>")
    return t, m


def write_hadith_fixture(d, empty=False, dup=False):
    hs = [{"hadithnumber": i, "arabicnumber": i, "text": "" if (empty and i == 3) else f"حديثٌ اختباري {i}",
           "reference": {"book": 1 if i <= 3 else 2, "hadith": i}} for i in range(1, 7)]
    if dup: hs[4]["hadithnumber"] = 1
    p = os.path.join(d, "e.json")
    json.dump({"metadata": {"name": "x", "sections": {"1": "كتاب أ", "2": "كتاب ب"}}, "hadiths": hs},
              open(p, "w", encoding="utf-8"), ensure_ascii=False)
    return p


class Tests(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()

    def test_normalize(self):
        self.assertEqual(arnorm.normalize_ar("بِسْمِ ٱللَّهِ"), "بسم الله")
        self.assertEqual(arnorm.normalize_ar("مُوسَىٰ"), "موسي")
        self.assertEqual(arnorm.normalize_ar("أَإِيمَانٌ ١٢"), "اايمان 12")
        self.assertEqual(arnorm.normalize_ar("ـــ"), "")

    def test_oracle(self):
        self.assertEqual(sum(SURAH_AYAH_COUNTS), 6236)

    def test_quran_ok_and_verify(self):
        t, m = write_quran_fixture(self.d); out = os.path.join(self.d, "q.db")
        r = bq.build(t, m, out, "fixture")
        self.assertEqual(r["ayah_count"], "6236")
        self.assertEqual(r["fts"], "none")  # افتراضياً بلا FTS5
        out_fts = os.path.join(self.d, "qf.db")
        self.assertEqual(bq.build(t, m, out_fts, "fixture", fts_enabled=True)["fts"], "fts5")
        self.assertEqual(vl.verify(out), [])
        db = sqlite3.connect(out_fts)
        self.assertEqual(db.execute("select text from ayahs where surah=1 and ayah=1").fetchone()[0], "نصٌّ اختباري 1 1")  # النص غير معدّل
        self.assertEqual(db.execute("select count(*) from ayahs_fts where ayahs_fts match 'اختباري'").fetchone()[0], 6236)

    def test_quran_missing_ayah_fails(self):
        t, m = write_quran_fixture(self.d, drop=(2, 100))
        with self.assertRaises(bq.BuildError): bq.build(t, m, os.path.join(self.d, "q.db"), "f")

    def test_quran_meta_conflict_fails(self):
        t, m = write_quran_fixture(self.d, wrong_meta=True)
        with self.assertRaises(bq.BuildError): bq.build(t, m, os.path.join(self.d, "q.db"), "f")

    def test_quran_missing_notice_fails(self):
        t, m = write_quran_fixture(self.d)
        open(t, "w", encoding="utf-8").write("\n".join(l for l in open(t, encoding="utf-8").read().split("\n") if not l.startswith("#")))
        with self.assertRaises(bq.BuildError): bq.build(t, m, os.path.join(self.d, "q.db"), "f")

    def _args(self, e, out, **kw):
        import argparse
        base = dict(edition=e, library="bukhari", title="ت", out=out, source="s", source_version="v",
                    license="L", license_url="u", numbering="n", expected_last=None, expected_count=None, allow_empty=0)
        base.update(kw); return argparse.Namespace(**base)

    def test_hadith_ok(self):
        e = write_hadith_fixture(self.d); out = os.path.join(self.d, "h.db")
        r = bh.build(self._args(e, out, expected_last=6, expected_count=6))
        self.assertEqual(r["hadith_count"], "6"); self.assertEqual(vl.verify(out), [])

    def test_hadith_failures(self):
        out = os.path.join(self.d, "h.db")
        with self.assertRaises(bh.BuildError): bh.build(self._args(write_hadith_fixture(self.d, empty=True), out))
        with self.assertRaises(bh.BuildError): bh.build(self._args(write_hadith_fixture(self.d, dup=True), out))
        with self.assertRaises(bh.BuildError): bh.build(self._args(write_hadith_fixture(self.d), out, expected_last=7))
        bad = os.path.join(self.d, "bad.json"); json.dump({"x": 1}, open(bad, "w"))
        with self.assertRaises(bh.BuildError): bh.build(self._args(bad, out))

    def test_verify_detects_corruption(self):
        t, m = write_quran_fixture(self.d); out = os.path.join(self.d, "q.db"); bq.build(t, m, out, "f")
        db = sqlite3.connect(out); db.execute("DELETE FROM ayahs WHERE surah=3 AND ayah=5"); db.commit(); db.close()
        self.assertTrue(vl.verify(out))
        trunc = os.path.join(self.d, "trunc.db"); open(trunc, "wb").write(open(out, "rb").read()[:5000])
        self.assertTrue(vl.verify(trunc))

    def test_manifest_hash_gzip_signature(self):
        t, m = write_quran_fixture(self.d); q = os.path.join(self.d, "q.db"); bq.build(t, m, q, "f")
        from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
        from cryptography.hazmat.primitives import serialization
        k = Ed25519PrivateKey.generate(); kp = os.path.join(self.d, "k.pem")
        open(kp, "wb").write(k.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
        o1, o2 = os.path.join(self.d, "o1"), os.path.join(self.d, "o2")
        man = mm.build(1, "https://example.invalid/x", o1, [("quran", q)], kp)
        mm.build(1, "https://example.invalid/x", o2, [("quran", q)], kp)
        e = man["libraries"][0]
        self.assertEqual(mm.sha256_file(os.path.join(o1, "quran.db.gz")), e["sha256_compressed"])
        self.assertEqual(hashlib_sha(gzip.open(os.path.join(o1, "quran.db.gz")).read()), e["sha256"])
        self.assertEqual(e["sha256_compressed"], mm.sha256_file(os.path.join(o2, "quran.db.gz")))  # حتمي
        data = open(os.path.join(o1, "manifest.json"), "rb").read()
        sig = base64.b64decode(open(os.path.join(o1, "manifest.json.sig")).read())
        k.public_key().verify(sig, data)  # يرفع استثناء إن فشل
        from cryptography.exceptions import InvalidSignature
        with self.assertRaises(InvalidSignature): k.public_key().verify(sig, data + b" ")


def hashlib_sha(b):
    import hashlib; return hashlib.sha256(b).hexdigest()


if __name__ == "__main__":
    unittest.main(verbosity=2)
