"""مرجع حساب اتجاه القبلة (Python). يُنقل حرفياً إلى lib/core/qibla/qibla_calculator.dart.

القبلة = السمت الابتدائي للدائرة العظمى من موقع المستخدم إلى الكعبة، بالدرجات مع عقارب الساعة من
الشمال **الحقيقي**. اتجاه الهاتف من المستشعرات مغناطيسي ويُصحَّح بالانحراف المغناطيسي.
"""
import math

KAABA_LAT = 21.4225
KAABA_LON = 39.8262
EARTH_RADIUS_KM = 6371.0088
D2R = math.pi / 180.0
ALIGN_TOLERANCE_DEG = 3.0


def bearing_to_kaaba(lat, lon):
    """السمت من (lat, lon) إلى الكعبة، أو None إن كان الموقع عند الكعبة (أقل من ~50 م)."""
    if distance_to_kaaba_km(lat, lon) < 0.05:
        return None
    p1 = lat * D2R
    p2 = KAABA_LAT * D2R
    dl = (KAABA_LON - lon) * D2R
    y = math.sin(dl) * math.cos(p2)
    x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl)
    return (math.atan2(y, x) / D2R + 360.0) % 360.0


def distance_to_kaaba_km(lat, lon):
    p1 = lat * D2R
    p2 = KAABA_LAT * D2R
    dp = p2 - p1
    dl = (KAABA_LON - lon) * D2R
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * EARTH_RADIUS_KM * math.asin(min(1.0, math.sqrt(a)))


def signed_diff(target, heading):
    """الدوران المطلوب (درجات) من اتجاه الهاتف إلى الهدف في (-180, 180]؛ موجب = يميناً."""
    d = (target - heading + 540.0) % 360.0 - 180.0
    return 180.0 if d == -180.0 else d


def true_heading(magnetic, declination):
    """الانحراف شرقاً موجب: الحقيقي = المغناطيسي + الانحراف."""
    return (magnetic + declination + 360.0) % 360.0


def is_aligned(target, heading, tolerance=ALIGN_TOLERANCE_DEG):
    return abs(signed_diff(target, heading)) <= tolerance


def smooth_angle(prev_sin_cos, new_deg, alpha=0.2):
    """مرشح تمرير منخفض على الزوايا (متوسط أسّي لجيب وجيب التمام). يعيد (حالة، زاوية)."""
    s, c = math.sin(new_deg * D2R), math.cos(new_deg * D2R)
    if prev_sin_cos is None:
        ps, pc = s, c
    else:
        ps = prev_sin_cos[0] + alpha * (s - prev_sin_cos[0])
        pc = prev_sin_cos[1] + alpha * (c - prev_sin_cos[1])
    return (ps, pc), (math.atan2(ps, pc) / D2R + 360.0) % 360.0
