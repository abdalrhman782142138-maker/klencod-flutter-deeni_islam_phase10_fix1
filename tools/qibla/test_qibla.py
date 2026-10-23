"""اختبارات مرجع القبلة: مراجع منشورة، وحساب مستقل بالمتجهات، وخصائص هندسية."""
import math, os, sys, unittest
sys.path.insert(0, os.path.dirname(__file__))
import qibla_ref as q

D2R = q.D2R


def vec(lat, lon):
    la, lo = lat * D2R, lon * D2R
    return (math.cos(la) * math.cos(lo), math.cos(la) * math.sin(lo), math.sin(la))


def dot(a, b): return sum(x * y for x, y in zip(a, b))


def vector_bearing(lat, lon):
    """حساب مستقل: السمت بإسقاط متجه الهدف على المستوى المماس (شرق/شمال) عند نقطة البداية."""
    p = vec(lat, lon); t = vec(q.KAABA_LAT, q.KAABA_LON)
    la, lo = lat * D2R, lon * D2R
    east = (-math.sin(lo), math.cos(lo), 0.0)
    north = (-math.sin(la) * math.cos(lo), -math.sin(la) * math.sin(lo), math.cos(la))
    return (math.atan2(dot(t, east), dot(t, north)) / D2R + 360.0) % 360.0


class Published(unittest.TestCase):
    # (المدينة، خط العرض، خط الطول، السمت المنشور، السماحية)  المصادر: makkahlive.net / calcatools.com /
    # duaforall.com / iforgeapps.com / niyatapp.com / online-compass.com (نتائج بحث، عدة مصادر متفقة)
    CASES = [("New York", 40.7128, -74.0060, 58.48, 0.1), ("London", 51.5074, -0.1278, 118.99, 0.1),
             ("Jakarta", -6.2088, 106.8456, 295.2, 0.15), ("Sydney", -33.8688, 151.2093, 277.5, 0.1),
             ("Tokyo", 35.6762, 139.6503, 293.0, 0.5), ("Los Angeles", 34.0522, -118.2437, 24.0, 0.5),
             ("Cairo", 30.0444, 31.2357, 136.0, 0.5)]

    def test_bearings(self):
        for name, lat, lon, want, tol in self.CASES:
            got = q.bearing_to_kaaba(lat, lon)
            self.assertAlmostEqual(got, want, delta=tol, msg=f"{name}: {got}")

    def test_distance_new_york(self):
        self.assertAlmostEqual(q.distance_to_kaaba_km(40.7128, -74.0060), 10306, delta=40)


class Geometry(unittest.TestCase):
    def test_matches_independent_vector_method(self):
        worst = 0.0
        for lat in range(-80, 81, 10):
            for lon in range(-180, 181, 20):
                b = q.bearing_to_kaaba(lat, lon)
                if b is None:
                    continue
                d = abs(q.signed_diff(b, vector_bearing(lat, lon)))
                worst = max(worst, d)
        self.assertLess(worst, 1e-6, worst)

    def test_cardinal_cases(self):
        self.assertAlmostEqual(q.bearing_to_kaaba(60.0, q.KAABA_LON), 180.0, places=6)    # شمال مكة على المسار نفسه
        self.assertAlmostEqual(q.bearing_to_kaaba(-10.0, q.KAABA_LON), 0.0, places=6)     # جنوبها
        self.assertTrue(q.bearing_to_kaaba(q.KAABA_LAT, q.KAABA_LON + 20) > 180)          # شرقها: القبلة غرباً
        self.assertTrue(q.bearing_to_kaaba(q.KAABA_LAT, q.KAABA_LON - 20) < 180)          # غربها: القبلة شرقاً

    def test_at_kaaba_returns_none(self):
        self.assertIsNone(q.bearing_to_kaaba(q.KAABA_LAT, q.KAABA_LON))
        self.assertIsNone(q.bearing_to_kaaba(21.4227, 39.8264))
        self.assertIsNotNone(q.bearing_to_kaaba(21.43, 39.83))

    def test_range(self):
        for lat in range(-89, 90, 7):
            for lon in range(-180, 180, 11):
                b = q.bearing_to_kaaba(lat, lon)
                self.assertTrue(b is None or 0 <= b < 360)

    def test_signed_diff_and_alignment(self):
        self.assertEqual(q.signed_diff(10, 350), 20)
        self.assertEqual(q.signed_diff(350, 10), -20)
        self.assertEqual(q.signed_diff(0, 180), 180)
        self.assertEqual(q.signed_diff(180, 0), 180)
        self.assertEqual(q.signed_diff(90, 90), 0)
        self.assertTrue(q.is_aligned(119, 121.5)); self.assertFalse(q.is_aligned(119, 123.5))
        self.assertTrue(q.is_aligned(1, 359))            # عبور الصفر

    def test_true_heading(self):
        self.assertEqual(q.true_heading(350, 15), 5)        # نيويورك تقريباً: انحراف غربي سالب
        self.assertEqual(q.true_heading(10, -15), 355)
        self.assertEqual(q.true_heading(0, 0), 0)

    def test_smoothing_wraps_around_zero(self):
        st = None
        for deg in (359, 1, 359, 1, 359, 1, 359, 1, 359, 1):
            st, out = q.smooth_angle(st, deg)
        self.assertTrue(out > 350 or out < 10, out)      # لا يقفز إلى ~180 عند عبور الصفر
        st = None
        for _ in range(60):
            st, out = q.smooth_angle(st, 90)
        self.assertAlmostEqual(out, 90, places=3)


if __name__ == "__main__":
    unittest.main(verbosity=2)
