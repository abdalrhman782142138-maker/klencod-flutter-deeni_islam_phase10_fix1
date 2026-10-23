"""فحص تطابق نقل Dart مع مرجع Python دون تشغيل Dart:
1) الثوابت العددية في كل دالة (معاملات Meeus وغيرها) متطابقة كمجموعة مرتبة.
2) جدول الطرق متطابق (الزوايا والفواصل).
3) بيانات المدن سليمة (نطاقات، تفرّد، وتُنتج مواقيت لكل طريقة).
البيانات هنا من ملفات المشروع نفسها."""
import math, os, re, sys, unittest
HERE = os.path.dirname(__file__)
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import prayer_ref as pr

PY = open(os.path.join(HERE, "prayer_ref.py"), encoding="utf-8").read()
DART = open(os.path.join(ROOT, "lib/core/prayer/prayer_calculator.dart"), encoding="utf-8").read()
CITIES = open(os.path.join(ROOT, "lib/core/prayer/cities.dart"), encoding="utf-8").read()
NUM = re.compile(r"(?<![\w.])\d+\.\d+(?:e-?\d+)?")   # الثوابت العشرية فقط (المعاملات الفلكية)


def py_body(name):
    m = re.search(rf"^def {name}\(.*?(?=^def |^[A-Z_]+ = |\Z)", PY, re.S | re.M)
    return m.group(0)


def dart_body(name):
    i = DART.index(name + "(")
    # من بداية التعريف حتى الدالة/الصنف التالي على مستوى الملف
    j = re.search(r"^\S", DART[i + 1:], re.M)
    start = DART.rfind("\n", 0, i) + 1
    k = re.search(r"\n}\n", DART[i:])
    return DART[start:i + k.end()]


def numbers(src, drop=()):
    src = re.sub(r"//.*|#.*", "", src)
    src = re.sub(r'""".*?"""', "", src, flags=re.S)
    vals = sorted(float(x) for x in NUM.findall(src))
    for d in drop:          # استثناءات موثّقة (قيم افتراضية تخص Dart فقط)
        vals.remove(d)
    return vals


class Port(unittest.TestCase):
    def test_sun_position_constants_identical(self):
        a = [x for x in numbers(py_body("sun_position"))]
        b = [x for x in numbers(dart_body("SunPosition sunPosition"))]
        self.assertEqual(a, b)

    def test_other_functions_constants(self):
        pairs = [("transit_ut", "double transitUt"), ("hour_angle", "double? hourAngle"),
                 ("asr_altitude", "double asrAltitude"), ("event_ut", "double? eventUt"),
                 ("julian_day", "double julianDay"), ("days_from_civil", "int daysFromCivil")]
        for py, dart in pairs:
            self.assertEqual(numbers(py_body(py)), numbers(dart_body(dart)), py)

    def test_calculate_constants(self):
        a = numbers(py_body("calculate"))
        # استثناءان موثّقان في Dart: 17.0 قيمة افتراضية لزاوية العشاء (لا تُستخدم فعلياً)،
        # و 3600.0 تتكرر ست مرات (لكل صلاة) بينما Python يضربها في حلقة واحدة.
        b = numbers(dart_body("RawPrayerTimes? calculateRaw"), drop=(17.0,) + (3600.0,) * 5)
        self.assertEqual(a, b)

    def test_methods_table(self):
        found = re.findall(
            r"PrayerMethod\(\s*id: '(\w+)',\s*nameAr: '([^']*)',\s*fajrAngle: ([\d.]+),"
            r"(?:\s*ishaAngle: ([\d.]+))?(?:,?\s*ishaIntervalMinutes: (\d+))?", DART)
        d = {i: (n, float(f), float(a) if a else None, int(iv) if iv else None) for i, n, f, a, iv in found}
        self.assertEqual(set(d), set(pr.METHODS))
        for k, (name, fa, ia, iv) in pr.METHODS.items():
            self.assertEqual(d[k][0], name, k)
            self.assertEqual(d[k][1:], (fa, ia, iv), k)

    def test_sun_altitude_constant(self):
        self.assertIn(f"kSunAltitude = {pr.SUN_ALT}", DART)

    def test_cities(self):
        rows = re.findall(r"City\('([^']+)', '([^']+)', (-?[\d.]+), (-?[\d.]+)\)", CITIES)
        self.assertGreaterEqual(len(rows), 45)
        names = [r[0] + "|" + r[1] for r in rows]
        self.assertEqual(len(names), len(set(names)))
        for name, country, lat, lon in rows:
            lat, lon = float(lat), float(lon)
            self.assertTrue(-90 <= lat <= 90 and -180 <= lon <= 180, name)
            for m in pr.METHODS:
                r = pr.calculate(2026, 10, 18, lat, lon, m)
                self.assertIsNotNone(r, (name, m))
                self.assertTrue(r["fajr"] < r["sunrise"] < r["dhuhr"] < r["asr"] < r["maghrib"] < r["isha"], (name, m))
        d = {r[0]: (float(r[2]), float(r[3])) for r in rows}
        # مكة والقاهرة نفس إحداثيات حالات المرجع المنشورة
        self.assertEqual(d["مكة المكرمة"], (21.4225, 39.8262))
        self.assertEqual(d["القاهرة"], (30.0444, 31.2357))


if __name__ == "__main__":
    unittest.main(verbosity=2)
