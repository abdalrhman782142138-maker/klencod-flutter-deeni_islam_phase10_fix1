"""تطابق نقل Dart مع المرجع Python دون تشغيل Dart: الثوابت والصيغ العددية وأسماء الأشهر."""
import os, re, sys, unittest
HERE = os.path.dirname(__file__)
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import hijri_ref as h

PY = open(os.path.join(HERE, "hijri_ref.py"), encoding="utf-8").read()
DART = open(os.path.join(ROOT, "lib/core/calendar/hijri_calendar.dart"), encoding="utf-8").read()
NUM = re.compile(r"(?<![\w.])\d+(?:\.\d+)?")


def nums(src, lang):
    # في Python الرمز // قسمة صحيحة وليس تعليقاً؛ لذلك تُزال تعليقات كل لغة بقاعدتها
    src = re.sub(r"#.*", "", src) if lang == "py" else re.sub(r"//.*", "", src)
    src = re.sub(r'""".*?"""', "", src, flags=re.S)
    src = re.sub(r"'[^']*'|\"[^\"]*\"", "", src)
    return sorted(float(x) for x in NUM.findall(src))


def py_fn(n): return re.search(rf"^def {n}\(.*?(?=^def |^[A-Z_]+ = |\Z)", PY, re.S | re.M).group(0)


def dart_fn(sig):
    i = DART.index(sig)
    arrow, brace = DART.find("=>", i), DART.find("{", i)
    if arrow != -1 and (brace == -1 or arrow < brace):          # دالة سهمية: حتى أول ";"
        return DART[i:DART.index(";", arrow) + 1]
    return DART[i:i + re.search(r"\n}\n", DART[i:]).end()]


class Port(unittest.TestCase):
    def test_constants(self):
        self.assertEqual(int(re.search(r"kHijriEpochJdn = (\d+);", DART).group(1)), h.EPOCH)
        self.assertEqual(int(re.search(r"kHijriEpochCivilJdn = (\d+);", DART).group(1)), h.EPOCH_CIVIL)
        self.assertEqual(int(re.search(r"kMaxHijriOffset = (\d+);", DART).group(1)), h.MAX_OFFSET_DAYS)

    def test_month_names(self):
        block = re.search(r"kHijriMonthsAr = <String>\[(.*?)\];", DART, re.S).group(1)
        self.assertEqual(tuple(re.findall(r"'([^']+)'", block)), h.MONTHS_AR)

    def test_formula_literals(self):
        pairs = [("gregorian_to_jdn", "int gregorianToJdn"), ("jdn_to_gregorian", "YearMonthDay jdnToGregorian"),
                 ("is_leap", "bool isHijriLeap"), ("month_length", "int hijriMonthLength"),
                 ("islamic_to_jdn", "int islamicToJdn"), ("jdn_to_islamic", "YearMonthDay? jdnToIslamic")]
        for py, dart in pairs:
            self.assertEqual(sorted(set(nums(py_fn(py), 'py'))), sorted(set(nums(dart_fn(dart), 'dart'))), py)

    def test_ui_uses_saturday_first_mapping(self):
        ui = open(os.path.join(ROOT, "lib/features/calendar/calendar_page.dart"), encoding="utf-8").read()
        self.assertIn("(days.first.weekday + 1) % 7", ui)      # السبت = 0 كما في الاختبار أدناه
        import datetime as dt
        sat = dt.date(2026, 10, 17)                             # سبت
        self.assertEqual((sat.isoweekday() + 1) % 7, 0)
        self.assertEqual((dt.date(2026, 10, 18).isoweekday() + 1) % 7, 1)   # أحد
        self.assertEqual((dt.date(2026, 10, 23).isoweekday() + 1) % 7, 6)   # جمعة


if __name__ == "__main__":
    unittest.main(verbosity=2)
