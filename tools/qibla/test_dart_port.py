"""تطابق نقل Dart مع مرجع Python: الثوابت العددية والمنطق، دون تشغيل Dart."""
import os, re, sys, unittest
HERE = os.path.dirname(__file__)
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import qibla_ref as q

PY = open(os.path.join(HERE, "qibla_ref.py"), encoding="utf-8").read()
DART = open(os.path.join(ROOT, "lib/core/qibla/qibla_calculator.dart"), encoding="utf-8").read()
NUM = re.compile(r"(?<![\w.])\d+(?:\.\d+)?(?:e-?\d+)?")


def nums(src):
    src = re.sub(r"//.*|#.*", "", src)
    src = re.sub(r'""".*?"""', "", src, flags=re.S)
    return sorted(float(x) for x in NUM.findall(src))


def py_fn(name):
    return re.search(rf"^def {name}\(.*?(?=^def |\Z)", PY, re.S | re.M).group(0)


def dart_fn(sig):
    i = DART.index(sig)
    return DART[i:i + re.search(r"\n}\n", DART[i:]).end()]


class Port(unittest.TestCase):
    def test_constants(self):
        for name, val in (("kKaabaLat", q.KAABA_LAT), ("kKaabaLon", q.KAABA_LON),
                          ("kEarthRadiusKm", q.EARTH_RADIUS_KM), ("kAlignToleranceDeg", q.ALIGN_TOLERANCE_DEG)):
            m = re.search(rf"const double {name} = ([\d.]+);", DART)
            self.assertEqual(float(m.group(1)), val, name)

    def test_function_literals_match(self):
        pairs = [("bearing_to_kaaba", "double? bearingToKaaba"), ("distance_to_kaaba_km", "double distanceToKaabaKm"),
                 ("signed_diff", "double signedAngleDiff"), ("true_heading", "double trueHeading")]
        for py, dart in pairs:
            a, b = nums(py_fn(py)), nums(dart_fn(dart))
            # قد تختلف أعداد الأصفار/الواحدات الشكلية (ts مثل 0.5 مقابل / 2)؛ نقارن المجموعتين كمجموعات
            self.assertEqual(sorted(set(a)), sorted(set(b)), py)

    def test_filter_alpha_default(self):
        self.assertIn("HeadingFilter({this.alpha = 0.2})", DART)

    def test_kotlin_heading_logic_matches_documented_rule(self):
        k = open(os.path.join(ROOT, "android/app/src/main/kotlin/com/deeniislam/app/MainActivity.kt"), encoding="utf-8").read()
        self.assertIn("Math.abs(r[8]) >= 0.7f", k)
        self.assertIn("Math.atan2(r[1].toDouble(), r[4].toDouble())", k)        # محور Y عند الوضع الأفقي
        self.assertIn("Math.atan2(-r[2].toDouble(), -r[5].toDouble())", k)      # -Z عند الوضع القائم
        self.assertNotIn("ACCESS_FINE_LOCATION", k)


if __name__ == "__main__":
    unittest.main(verbosity=2)
