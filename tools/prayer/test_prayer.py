"""اختبارات مرجع حساب المواقيت. المراجع الخارجية هنا أحداث فلكية معروفة (اعتدالات/انقلابات 2026
وقيم معادلة الزمن التقليدية)، وحساب ثانٍ مستقل بصيغ Astronomical Almanac، ومعايير فيزيائية."""
import math, os, sys, unittest, datetime as dt
sys.path.insert(0, os.path.dirname(__file__))
import prayer_ref as pr
from zoneinfo import ZoneInfo

D2R = pr.D2R


def solar_longitude_deg(jd):
    """خط طول الشمس الظاهري من نفس الصيغ (للبحث عن لحظات الاعتدال)."""
    t = (jd - 2451545.0) / 36525.0
    l0 = (280.46646 + t * (36000.76983 + t * 0.0003032)) % 360.0
    m = (357.52911 + t * (35999.05029 - 0.0001537 * t)) * D2R
    c = ((1.914602 - t * 0.004817) * math.sin(m) + 0.019993 * math.sin(2 * m) + 0.000289 * math.sin(3 * m))
    om = 125.04 - 1934.136 * t
    return (l0 + c - 0.00569 - 0.00478 * math.sin(om * D2R)) % 360.0


def jd_of(y, mo, d, h, mi):
    return pr.julian_day(y, mo, d, h + mi / 60.0)


def almanac_dec_eqt(jd):
    """حساب ثانٍ مستقل (Astronomical Almanac، دقة منخفضة)."""
    n = jd - 2451545.0
    L = (280.460 + 0.9856474 * n) % 360.0
    g = ((357.528 + 0.9856003 * n) % 360.0) * D2R
    lam = (L + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g)) * D2R
    eps = (23.439 - 0.0000004 * n) * D2R
    dec = math.asin(math.sin(eps) * math.sin(lam)) / D2R
    ra = math.atan2(math.cos(eps) * math.sin(lam), math.cos(lam)) / D2R % 360.0
    d = (L - ra + 180.0) % 360.0 - 180.0
    return dec, d * 4.0


class Astronomy(unittest.TestCase):
    def test_equinoxes_and_solstices_2026(self):
        # لحظات معروفة (UTC): اعتدال مارس 14:46 ، انقلاب يونيو 08:24 ، اعتدال سبتمبر 00:05 ، انقلاب ديسمبر 20:50
        cases = [((2026, 3, 20, 14, 46), 0.0), ((2026, 6, 21, 8, 24), 90.0),
                 ((2026, 9, 23, 0, 5), 180.0), ((2026, 12, 21, 20, 50), 270.0)]
        for (y, mo, d, h, mi), target in cases:
            lon = solar_longitude_deg(jd_of(y, mo, d, h, mi))
            diff = (lon - target + 180) % 360 - 180
            # الشمس تتحرك ~0.04°/ساعة؛ نقبل ±0.06° (≈ ±1.5 ساعة) لأن اللحظات من الذاكرة بدقة دقائق
            self.assertLess(abs(diff), 0.06, f"{y}-{mo}-{d}: {lon}")

    def test_declination_extremes(self):
        dec, _ = pr.sun_position(jd_of(2026, 6, 21, 8, 24))
        self.assertAlmostEqual(dec, 23.44, delta=0.02)
        dec, _ = pr.sun_position(jd_of(2026, 12, 21, 20, 50))
        self.assertAlmostEqual(dec, -23.44, delta=0.02)
        dec, _ = pr.sun_position(jd_of(2026, 3, 20, 14, 46))
        self.assertAlmostEqual(dec, 0.0, delta=0.03)

    def test_equation_of_time_traditional_values(self):
        # قيم التحليل التقليدي (analemma) عند الظهيرة UT
        table = [((2026, 2, 11), -14.2), ((2026, 5, 14), 3.7), ((2026, 7, 26), -6.5), ((2026, 11, 3), 16.4)]
        for (y, mo, d), want in table:
            _, eqt = pr.sun_position(jd_of(y, mo, d, 12, 0))
            self.assertAlmostEqual(eqt, want, delta=0.35, msg=f"{y}-{mo}-{d}")

    def test_matches_independent_almanac_formulas_all_year(self):
        worst_dec = worst_eqt = 0.0
        for day in range(0, 365, 3):
            jd = pr.julian_day(2026, 1, 1, 12.0) + day
            d1, e1 = pr.sun_position(jd)
            d2, e2 = almanac_dec_eqt(jd)
            worst_dec = max(worst_dec, abs(d1 - d2)); worst_eqt = max(worst_eqt, abs(e1 - e2))
        self.assertLess(worst_dec, 0.03, worst_dec)   # درجة
        self.assertLess(worst_eqt, 0.25, worst_eqt)   # دقيقة

    def test_days_from_civil(self):
        self.assertEqual(pr.days_from_civil(1970, 1, 1), 0)
        self.assertEqual(pr.days_from_civil(2026, 10, 18), (dt.date(2026, 10, 18) - dt.date(1970, 1, 1)).days)
        self.assertEqual(pr.days_from_civil(2000, 2, 29), (dt.date(2000, 2, 29) - dt.date(1970, 1, 1)).days)

    def test_julian_day_j2000(self):
        self.assertAlmostEqual(pr.julian_day(2000, 1, 1, 12.0), 2451545.0, places=6)


def alt_of_sun(epoch, lat, lon):
    """ارتفاع الشمس الفعلي عند لحظة محددة (حساب مستقل لقياس زاوية كل صلاة)."""
    t = dt.datetime.fromtimestamp(epoch, dt.timezone.utc)
    jd = pr.julian_day(t.year, t.month, t.day, t.hour + t.minute / 60 + t.second / 3600)
    dec, eqt = almanac_dec_eqt(jd)           # ميل من الحساب الثاني المستقل
    utc_min = t.hour * 60 + t.minute + t.second / 60
    tst = (utc_min + eqt + 4 * lon) % 1440
    ha = (tst / 4 - 180) * D2R
    s = math.sin(lat * D2R) * math.sin(dec * D2R) + math.cos(lat * D2R) * math.cos(dec * D2R) * math.cos(ha)
    return math.asin(s) / D2R


class Physics(unittest.TestCase):
    CITIES = {"makkah": (21.4225, 39.8262), "cairo": (30.0444, 31.2357), "london": (51.5074, -0.1278),
              "jakarta": (-6.2088, 106.8456), "sydney": (-33.8688, 151.2093), "newyork": (40.7128, -74.0060)}

    def test_event_altitudes_match_targets_via_independent_sun(self):
        for name, (lat, lon) in self.CITIES.items():
            for (y, m, d) in [(2026, 3, 20), (2026, 6, 21), (2026, 10, 18), (2026, 12, 21)]:
                r = pr.calculate(y, m, d, lat, lon, "mwl")
                self.assertIsNotNone(r, name)
                if r["approximated"]:
                    continue   # الفجر/العشاء مقدَّران بسُبع الليل؛ لا زاوية مستهدفة
                for key, want in (("sunrise", -0.833), ("maghrib", -0.833), ("fajr", -18.0), ("isha", -17.0)):
                    got = alt_of_sun(r[key], lat, lon)
                    # النموذجان مستقلان؛ الفرق < 0.12° (≈ 30 ثانية زمنية)
                    self.assertAlmostEqual(got, want, delta=0.12, msg=f"{name} {y}-{m}-{d} {key}: {got}")

    def test_asr_altitude_and_madhab_order(self):
        for name, (lat, lon) in self.CITIES.items():
            r1 = pr.calculate(2026, 10, 18, lat, lon, "mwl", hanafi=False)
            r2 = pr.calculate(2026, 10, 18, lat, lon, "mwl", hanafi=True)
            self.assertGreater(r2["asr"], r1["asr"])
            dec, _ = almanac_dec_eqt(pr.julian_day(2026, 10, 18, 12))
            for r, f in ((r1, 1.0), (r2, 2.0)):
                want = pr.asr_altitude(f, lat, dec)
                self.assertAlmostEqual(alt_of_sun(r["asr"], lat, lon), want, delta=0.15, msg=name)

    def test_noon_is_midpoint_of_sunrise_sunset(self):
        for name, (lat, lon) in self.CITIES.items():
            r = pr.calculate(2026, 10, 18, lat, lon)
            self.assertAlmostEqual((r["sunrise"] + r["maghrib"]) / 2, r["dhuhr"], delta=45, msg=name)

    def test_order_and_umm_al_qura_interval(self):
        for name, (lat, lon) in self.CITIES.items():
            for m in pr.METHODS:
                r = pr.calculate(2026, 10, 18, lat, lon, m)
                self.assertTrue(r["fajr"] < r["sunrise"] < r["dhuhr"] < r["asr"] < r["maghrib"] < r["isha"], (name, m))
        r = pr.calculate(2026, 10, 18, 21.4225, 39.8262, "umm_al_qura")
        self.assertAlmostEqual(r["isha"] - r["maghrib"], 90 * 60, delta=1e-6)

    def test_equator_equinox_day_length(self):
        r = pr.calculate(2026, 3, 20, 0.0, 0.0)
        dur = (r["maghrib"] - r["sunrise"]) / 3600
        self.assertAlmostEqual(dur, 12.11, delta=0.06)      # 12h + ~6.6 دقيقة (انكسار + القرص)

    def test_high_latitude_fallback_and_polar(self):
        r = pr.calculate(2026, 6, 21, 59.9139, 10.7522)     # أوسلو: لا يبلغ الفجر/العشاء -18°
        self.assertIsNotNone(r); self.assertTrue(r["approximated"])
        self.assertTrue(r["fajr"] < r["sunrise"] and r["maghrib"] < r["isha"])
        self.assertIsNone(pr.calculate(2026, 6, 21, 69.6492, 18.9553))   # ترومسو: شمس منتصف الليل
        self.assertIsNone(pr.calculate(2026, 12, 21, 69.6492, 18.9553))  # ليل قطبي
        r = pr.calculate(2026, 10, 18, 21.4225, 39.8262)
        self.assertFalse(r["approximated"])

    def test_local_time_conversion_and_dst(self):
        # لندن: بدء التوقيت الصيفي 2026-03-29 ؛ الظهر ~12:00-13:00 محلياً قبل وبعد
        for (y, m, d), off in (((2026, 3, 28), 0), ((2026, 3, 30), 1)):
            r = pr.calculate(y, m, d, 51.5074, -0.1278)
            local = dt.datetime.fromtimestamp(r["dhuhr"], ZoneInfo("Europe/London"))
            self.assertEqual(local.utcoffset(), dt.timedelta(hours=off))
            self.assertTrue(12 + off - 0.5 <= local.hour + local.minute / 60 <= 12 + off + 0.5, local)

    def test_extreme_zones_land_on_correct_civil_day(self):
        # مناطق خارج يومها الشمسي: ساموا (+13/14) وكيريباتي (+14) وفيجي وهونولولو
        zones = (("Pacific/Apia", -13.83, -171.76), ("Pacific/Kiritimati", 1.87, -157.4),
                 ("Pacific/Fiji", -17.7, 178.0), ("Pacific/Honolulu", 21.3, -157.86),
                 ("Pacific/Tongatapu", -21.14, -175.2), ("Asia/Tokyo", 35.68, 139.69))
        for tz, lat, lon in zones:
            for day in (dt.date(2026, 3, 1), dt.date(2026, 10, 18), dt.date(2026, 12, 31)):
                noon = dt.datetime(day.year, day.month, day.day, 12, tzinfo=ZoneInfo(tz))
                off = int(noon.utcoffset().total_seconds() // 60)
                r = pr.calculate(day.year, day.month, day.day, lat, lon, tz_offset_minutes=off)
                local = dt.datetime.fromtimestamp(r["dhuhr"], ZoneInfo(tz))
                self.assertEqual(local.date(), day, (tz, day, local))
                self.assertTrue(11 <= local.hour <= 14, (tz, day, local))
                # بدون الإزاحة تتغير النتيجة فقط في المناطق الخارجة عن يومها الشمسي
        r0 = pr.calculate(2026, 10, 18, -13.83, -171.76)
        r1 = pr.calculate(2026, 10, 18, -13.83, -171.76, tz_offset_minutes=14 * 60)
        self.assertAlmostEqual(r1["dhuhr"] - r0["dhuhr"], -86400, delta=300)

    def test_shift_civil(self):
        for base in (dt.date(2026, 3, 1), dt.date(2024, 2, 28), dt.date(2026, 12, 31), dt.date(2026, 1, 1)):
            for k in (-2, -1, 0, 1, 2, 400):
                want = base + dt.timedelta(days=k)
                self.assertEqual(pr.shift_civil(base.year, base.month, base.day, k),
                                 (want.year, want.month, want.day))


class PublishedReferences(unittest.TestCase):
    """جداول منشورة من مصادر مستقلة (جُمعت يدوياً من نتائج بحث؛ المصدر في كل حالة).
    الفروق المقبولة ≤ دقيقة واحدة (اختلاف الإحداثيات والتقريب بين المصادر)."""
    KEYS = ("fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha")

    def _check(self, y, m, d, lat, lon, method, tz, ref, tol):
        r = pr.calculate(y, m, d, lat, lon, method, False, tz_offset_minutes=tz)
        for k, want in zip(self.KEYS, ref):
            got = dt.datetime.fromtimestamp(pr.round_minute(r[k]) + tz * 60, dt.timezone.utc)
            wh, wm = map(int, want.split(":"))
            diff = (got.hour * 60 + got.minute) - (wh * 60 + wm)
            self.assertLessEqual(abs(diff), tol, f"{y}-{m}-{d} {k}: got {got:%H:%M} want {want}")

    def test_makkah_umm_al_qura_2026_10_18(self):
        # makkahlive.net / athkarapp.com / timesprayer.com / sajda.com (UTC+3)
        self._check(2026, 10, 18, 21.4225, 39.8262, "umm_al_qura", 180,
                    ["05:01", "06:17", "12:06", "15:26", "17:54", "19:24"], 1)

    def test_cairo_egyptian_2026_07(self):
        # makkahlive.net جدول القاهرة (الهيئة المصرية، UTC+3 صيفاً)
        self._check(2026, 7, 1, 30.0444, 31.2357, "egypt", 180,
                    ["04:12", "05:57", "13:00", "16:35", "20:00", "21:33"], 1)
        self._check(2026, 7, 18, 30.0444, 31.2357, "egypt", 180,
                    ["04:23", "06:06", "13:02", "16:38", "19:57", "21:27"], 1)

    def test_cairo_mwl_2026_10_18(self):
        # truecalendar.com (MWL، UTC+3)
        self._check(2026, 10, 18, 30.0444, 31.2357, "mwl", 180,
                    ["05:38", "06:58", "12:40", "15:55", "18:22", "19:37"], 1)


class RoundTrip(unittest.TestCase):
    def test_rounding(self):
        self.assertEqual(pr.round_minute(89), 60)
        self.assertEqual(pr.round_minute(90), 120)
        self.assertEqual(pr.round_minute(29.9), 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
