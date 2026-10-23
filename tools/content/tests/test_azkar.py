"""اختبارات منطق مدقق الأذكار. البيانات صناعية (FIXTURES) ولا تُشحن ولا تمثل أذكاراً حقيقية."""
import copy, json, os, re, sys, tempfile, unittest
HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, ".."))
import build_azkar as ba

SRC = {"name": "fixture", "url": "https://example.invalid", "license": "L", "license_url": "https://example.invalid/l", "version": "1"}


def fixture():
    cats = []
    for cid in ba.REQUIRED_CATEGORIES:
        cats.append({"id": cid, "title_ar": f"تصنيف {cid}", "items": [
            {"id": "1", "text": f"نص اختباري أول {cid}", "count": 3, "reference": "مرجع اختباري", "notes": None},
            {"id": "2", "text": f"نص اختباري ثان {cid}", "count": None, "reference": None, "notes": None}]})
    return {"schema": 1, "source": dict(SRC), "categories": cats}


class T(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()

    def write(self, data):
        p = os.path.join(self.d, "in.json"); json.dump(data, open(p, "w", encoding="utf-8"), ensure_ascii=False); return p

    def test_ok(self):
        n, h = ba.build(self.write(fixture()), os.path.join(self.d, "o", "azkar.json"))
        self.assertEqual(n, 10); self.assertEqual(len(h), 64)

    def test_rejections(self):
        def bad(mut, msg):
            d = fixture(); mut(d)
            with self.assertRaises(ba.BuildError, msg=msg): ba.validate(d)
        bad(lambda d: d["categories"].pop(0), "تصنيف مطلوب مفقود")
        bad(lambda d: d["categories"][0]["items"][0].update(text="  "), "نص فارغ")
        bad(lambda d: d["categories"][0]["items"][0].update(count=0), "عدد صفر")
        bad(lambda d: d["categories"][0]["items"][0].update(count="3"), "عدد نصي")
        bad(lambda d: d["categories"][0]["items"][1].update(id="1"), "معرّف مكرر")
        bad(lambda d: d["categories"][0]["items"][1].update(text="نصٌّ اختباري أول morning"), "نص مكرر (بعد التطبيع)")
        bad(lambda d: d["source"].pop("license"), "ترخيص ناقص")
        bad(lambda d: d.update(schema=2), "schema")
        bad(lambda d: d["categories"][1].update(id=d["categories"][0]["id"]), "تصنيف مكرر")

    def test_dart_parser_keys_match_schema(self):
        src = open(os.path.join(HERE, "..", "..", "..", "lib", "core", "azkar", "azkar_repository.dart"), encoding="utf-8").read()
        keys = set(re.findall(r"\['(\w+)'\]", src))
        self.assertTrue({"schema", "categories", "title_ar", "items", "text", "count", "reference", "notes", "id"} <= keys, keys)
        d = fixture(); allowed = set(d) | set(d["categories"][0]) | set(d["categories"][0]["items"][0]) | set(d["source"])
        self.assertTrue(keys <= allowed, f"Dart يقرأ مفاتيح لا ينتجها المخطط: {keys - allowed}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
