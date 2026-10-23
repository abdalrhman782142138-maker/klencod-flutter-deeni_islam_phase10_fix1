"""اختبارات المرجع الهجري: مقارنة بتواريخ أم القرى المنشورة، وطريقة مستقلة (مشي دورة ٣٠ سنة)،
وخصائص التقويم. المراجع المنشورة: ummalquracalendar.org / makkahlive.net / makkahcompass.org /
islamtics.com / islamiccalc.com (عدة مصادر متفقة) وويكيبيديا للجدولي المدني."""
import datetime as dt, os, sys, unittest
sys.path.insert(0, os.path.dirname(__file__))
import hijri_ref as h

UQ = [((2026, 2, 18), (1447, 9, 1)), ((2026, 3, 20), (1447, 10, 1)), ((2026, 5, 27), (1447, 12, 10)),
      ((2026, 6, 16), (1448, 1, 1)), ((2026, 6, 25), (1448, 1, 10)), ((2026, 8, 25), (1448, 3, 12)),
      ((2026, 10, 19), (1448, 5, 8)), ((2027, 2, 8), (1448, 9, 1)), ((2027, 3, 9), (1448, 10, 1)),
      ((2027, 5, 16), (1448, 12, 10)), ((2025, 6, 26), (1447, 1, 1))]


def walk_start_of_year(year):
    """بداية السنة (JDN) بالمشي الصريح من 1 محرم 1: طول السنة 354/355 بحسب دورة الـ٣٠."""
    jdn = h.EPOCH
    for y in range(1, year):
        jdn += 355 if (y % 30) in h.LEAP_YEARS_IN_CYCLE else 354
    return jdn


class Gregorian(unittest.TestCase):
    def test_roundtrip_against_python_dates(self):
        for ordinal in range(dt.date(1583, 1, 1).toordinal(), dt.date(2600, 1, 1).toordinal(), 7):
            d = dt.date.fromordinal(ordinal)
            jdn = h.gregorian_to_jdn(d.year, d.month, d.day)
            self.assertEqual(jdn, ordinal + 1721425)          # JDN = ordinal + 1721425 (الاثنين 0001-01-01 غريغوري)
            self.assertEqual(h.jdn_to_gregorian(jdn), (d.year, d.month, d.day))

    def test_known_jdn(self):
        self.assertEqual(h.gregorian_to_jdn(2000, 1, 1), 2451545)
        self.assertEqual(h.gregorian_to_jdn(2026, 10, 11), 2461325)      # ويكيبيديا: Julian day 2461325


class Islamic(unittest.TestCase):
    def test_month_and_year_lengths(self):
        for y in range(1, 1700):
            lens = [h.month_length(y, m) for m in range(1, 13)]
            self.assertTrue(all(x in (29, 30) for x in lens))
            self.assertIn(sum(lens), (354, 355))
            self.assertEqual(sum(lens) == 355, (y % 30) in h.LEAP_YEARS_IN_CYCLE, y)
            self.assertEqual(h.is_leap(y), (y % 30) in h.LEAP_YEARS_IN_CYCLE, y)
        self.assertEqual(sum(355 if y in h.LEAP_YEARS_IN_CYCLE else 354 for y in range(1, 31)), 10631)

    def test_formula_matches_independent_walk(self):
        jdn = h.EPOCH
        for y in range(1, 1700):
            self.assertEqual(h.islamic_to_jdn(y, 1, 1), jdn, y)
            start = jdn
            for m in range(1, 13):
                self.assertEqual(h.islamic_to_jdn(y, m, 1), start, (y, m))
                start += h.month_length(y, m)
            jdn += 355 if h.is_leap(y) else 354
            self.assertEqual(start, jdn)

    def test_every_day_roundtrip_and_continuity(self):
        prev = None
        for jdn in range(h.EPOCH, h.EPOCH + 1700 * 355, 1):
            y, m, d = h.jdn_to_islamic(jdn)
            self.assertEqual(h.islamic_to_jdn(y, m, d), jdn)
            self.assertTrue(1 <= m <= 12 and 1 <= d <= h.month_length(y, m), (jdn, y, m, d))
            if prev is not None:
                py, pm, pd = prev
                if d == 1:
                    self.assertEqual(pd, h.month_length(py, pm))
                    self.assertTrue((y, m) == (py, pm + 1) or (m == 1 and y == py + 1 and pm == 12))
                else:
                    self.assertEqual((y, m, d), (py, pm, pd + 1))
            prev = (y, m, d)

    def test_before_epoch_rejected(self):
        with self.assertRaises(ValueError):
            h.jdn_to_islamic(h.EPOCH - 1)

    def test_agreement_with_umm_al_qura_published(self):
        diffs = []
        for g, hh in UQ:
            diffs.append(h.islamic_to_jdn(*hh) - h.gregorian_to_jdn(*g))
        self.assertTrue(all(abs(x) <= 1 for x in diffs), diffs)          # لا فرق يتجاوز يوماً
        exact = sum(1 for x in diffs if x == 0)
        self.assertGreaterEqual(exact, 7, diffs)                         # ٧ من ١١ متطابقة تماماً
        # تاريخ اليوم المنشور: 19 أكتوبر 2026 = 8 جمادى الأولى 1448 (أم القرى)
        self.assertEqual(h.hijri_from_gregorian(2026, 10, 20), (1448, 5, 9))

    def test_civil_variant_matches_wikipedia_tabular(self):
        # ويكيبيديا (Hijri era, tabular): 11 أكتوبر 2026 = 28 ربيع الآخر 1448 (العصر المدني)
        self.assertEqual(h.jdn_to_islamic(h.gregorian_to_jdn(2026, 10, 11), h.EPOCH_CIVIL), (1448, 4, 28))

    def test_offset(self):
        base = h.hijri_from_gregorian(2026, 10, 20)
        self.assertEqual(h.hijri_from_gregorian(2026, 10, 20, 1), h.hijri_from_gregorian(2026, 10, 21))
        self.assertEqual(h.hijri_from_gregorian(2026, 10, 20, -1), h.hijri_from_gregorian(2026, 10, 19))
        self.assertEqual(h.gregorian_from_hijri(*base), (2026, 10, 20))
        self.assertEqual(h.gregorian_from_hijri(*h.hijri_from_gregorian(2026, 10, 20, 2), offset_days=2), (2026, 10, 20))

    def test_month_names(self):
        self.assertEqual(len(h.MONTHS_AR), 12)
        self.assertEqual(h.MONTHS_AR[8], "رمضان")
        self.assertEqual(h.MONTHS_AR[11], "ذو الحجة")


if __name__ == "__main__":
    unittest.main(verbosity=2)
