"""اختبار سكربت الجلب والبناء على خادم HTTP محلي بملفات اختبارية (FIXTURES؛ ليست محتوى ديني حقيقي)."""
import http.server, json, os, socketserver, sys, tempfile, threading, unittest
HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
import fetch_and_build as fb
from test_pipeline import write_quran_fixture, write_hadith_fixture


class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a): pass


class T(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = tempfile.mkdtemp()
        t, m = write_quran_fixture(cls.root)           # يكتب t.txt و m.xml
        # رأس يحاكي إشعار Tanzil
        txt = open(t, encoding="utf-8").read().replace("# FIXTURE-NOTICE: اختبار فقط",
              "# Tanzil Quran Text (Fixture)\n# License: Creative Commons Attribution 3.0")
        open(os.path.join(cls.root, "text.txt"), "w", encoding="utf-8").write(txt)
        os.rename(m, os.path.join(cls.root, "meta.xml"))
        for ed, lib in (("ara-bukhari", "b"), ("ara-muslim", "m")):
            e = write_hadith_fixture(cls.root)
            os.makedirs(os.path.join(cls.root, "hadith", "editions"), exist_ok=True)
            os.replace(e, os.path.join(cls.root, "hadith", "editions", f"{ed}.json"))
        json.dump({"ara-bukhari": {"metadata": {"last_hadithnumber": 6}}, "ara-muslim": {"metadata": {"last_hadithnumber": 6}}},
                  open(os.path.join(cls.root, "hadith", "info.json"), "w"))
        open(os.path.join(cls.root, "hadith", "LICENSE"), "w").write("FIXTURE LICENSE: free for any use.\nSecond line\n")
        handler = lambda *a, **k: Quiet(*a, directory=cls.root, **k)
        cls.srv = socketserver.TCPServer(("127.0.0.1", 0), handler)
        cls.port = cls.srv.server_address[1]
        threading.Thread(target=cls.srv.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown()

    def args(self, out, *extra):
        b = f"http://127.0.0.1:{self.port}"
        return ["--out", out, "--tanzil-text", f"{b}/text.txt", "--tanzil-meta", f"{b}/meta.xml",
                "--hadith-base", f"{b}/hadith", "--hadith-license", f"{b}/hadith/LICENSE", "--yes", *extra]

    def test_full_run(self):
        out = tempfile.mkdtemp()
        self.assertEqual(fb.main(self.args(out)), 0)
        for f in ("quran.db", "bukhari.db", "muslim.db", "report.txt"):
            self.assertTrue(os.path.exists(os.path.join(out, f)), f)
        rep = open(os.path.join(out, "report.txt"), encoding="utf-8").read()
        self.assertIn("6236 آية", rep); self.assertIn("sha256=", rep)
        self.assertIn("آخر رقم 6 (المرجع من info.json: 6)", rep)

    def test_header_without_notice_is_rejected(self):
        bad = tempfile.mkdtemp()
        open(os.path.join(bad, "text.txt"), "w", encoding="utf-8").write("1|1|نص بلا إشعار\n")
        open(os.path.join(bad, "meta.xml"), "w").write("<quran/>")
        h = http.server.SimpleHTTPRequestHandler
        srv = socketserver.TCPServer(("127.0.0.1", 0), lambda *a, **k: Quiet(*a, directory=bad, **k))
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        try:
            b = f"http://127.0.0.1:{srv.server_address[1]}"
            rc = fb.main(["--out", tempfile.mkdtemp(), "--skip-hadith", "--tanzil-text", f"{b}/text.txt", "--tanzil-meta", f"{b}/meta.xml"])
            self.assertEqual(rc, 2)
        finally:
            srv.shutdown()

    def test_manual_files_mode_and_corrupt_data_fails(self):
        out = tempfile.mkdtemp()
        rc = fb.main(["--out", out, "--skip-hadith", "--quran-text", os.path.join(self.root, "text.txt"),
                      "--quran-meta", os.path.join(self.root, "meta.xml")])
        self.assertEqual(rc, 0)
        # نص ناقص آية → فشل ولا قاعدة ناتجة
        lines = open(os.path.join(self.root, "text.txt"), encoding="utf-8").read().split("\n")
        broken = os.path.join(out, "broken.txt")
        open(broken, "w", encoding="utf-8").write("\n".join(l for l in lines if not l.startswith("2|100|")))
        out2 = tempfile.mkdtemp()
        rc = fb.main(["--out", out2, "--skip-hadith", "--quran-text", broken, "--quran-meta", os.path.join(self.root, "meta.xml")])
        self.assertEqual(rc, 2); self.assertFalse(os.path.exists(os.path.join(out2, "quran.db")))

    def test_unreachable_url_fails_cleanly(self):
        rc = fb.main(["--out", tempfile.mkdtemp(), "--skip-hadith", "--tanzil-text", "http://127.0.0.1:9/none", "--tanzil-meta", "http://127.0.0.1:9/none"])
        self.assertEqual(rc, 2)

    def test_find_last_number(self):
        self.assertEqual(fb.find_last_number({"x": {"ara-bukhari": {"last_hadithnumber": "7563"}}}, "ara-bukhari"), 7563)
        self.assertIsNone(fb.find_last_number({"y": 1}, "ara-bukhari"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
