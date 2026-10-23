"""يولّد قيماً ذهبية من المرجع Python لاختبار نسخة Dart (test/prayer_golden_test.dart)."""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import prayer_ref as pr

CASES = [
    # (الاسم، السنة، الشهر، اليوم، خط العرض، خط الطول، الطريقة، حنفي، إزاحة المنطقة بالدقائق)
    ("makkah_uq", 2026, 10, 18, 21.4225, 39.8262, "umm_al_qura", False, 180),
    ("cairo_egypt", 2026, 7, 1, 30.0444, 31.2357, "egypt", False, 180),
    ("cairo_mwl_hanafi", 2026, 10, 18, 30.0444, 31.2357, "mwl", True, 180),
    ("london_isna_dst", 2026, 3, 30, 51.5074, -0.1278, "isna", False, 60),
    ("jakarta_karachi", 2026, 1, 15, -6.2088, 106.8456, "karachi", False, 420),
    ("sydney_mwl", 2026, 12, 21, -33.8688, 151.2093, "mwl", False, 660),
    ("newyork_isna", 2026, 6, 21, 40.7128, -74.0060, "isna", False, -240),
    ("apia_mwl_dateline", 2026, 10, 18, -13.83, -171.76, "mwl", False, 840),
    ("oslo_highlat", 2026, 6, 21, 59.9139, 10.7522, "mwl", False, 120),
    ("tromso_polar", 2026, 6, 21, 69.6492, 18.9553, "mwl", False, 120),
]
out = []
for name, y, m, d, lat, lon, meth, han, tz in CASES:
    r = pr.calculate(y, m, d, lat, lon, meth, han, tz_offset_minutes=tz)
    out.append({"name": name, "y": y, "m": m, "d": d, "lat": lat, "lon": lon, "method": meth,
                "hanafi": han, "tz": tz, "result": None if r is None else r})
print(json.dumps(out, ensure_ascii=False, indent=1))
