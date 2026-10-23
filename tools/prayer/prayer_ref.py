"""مرجع حساب مواقيت الصلاة (Python). يُنقل حرفياً إلى lib/core/prayer/prayer_calculator.dart.

الخوارزمية: موضع الشمس بصيغ Meeus المختصرة (نفس صيغ NOAA)، ثم زاوية الساعة لكل ارتفاع للشمس،
مع تكرار لتحديث الميل عند وقت الحدث نفسه. كل الأزمنة تُعاد كلحظات UTC (بالثواني منذ epoch).
لا شبكة ولا مكتبات خارجية.
"""
import math

D2R = math.pi / 180.0
SUN_ALT = -0.833  # الشروق والغروب: انكسار 0.567° + نصف قطر القرص 0.266°


def julian_day(y, m, d, hour_ut=0.0):
    if m <= 2:
        y -= 1
        m += 12
    a = y // 100
    b = 2 - a + a // 4
    return (math.floor(365.25 * (y + 4716)) + math.floor(30.6001 * (m + 1)) + d + b - 1524.5
            + hour_ut / 24.0)


def days_from_civil(y, m, d):
    """عدد الأيام منذ 1970-01-01 (خوارزمية Howard Hinnant)."""
    y -= m <= 2
    era = (y if y >= 0 else y - 399) // 400
    yoe = y - era * 400
    doy = (153 * (m + (-3 if m > 2 else 9)) + 2) // 5 + d - 1
    doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468


def sun_position(jd):
    """يعيد (الميل بالدرجات، معادلة الزمن بالدقائق)."""
    t = (jd - 2451545.0) / 36525.0
    l0 = (280.46646 + t * (36000.76983 + t * 0.0003032)) % 360.0
    m = 357.52911 + t * (35999.05029 - 0.0001537 * t)
    e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
    mr = m * D2R
    c = ((1.914602 - t * (0.004817 + 0.000014 * t)) * math.sin(mr)
         + (0.019993 - 0.000101 * t) * math.sin(2 * mr)
         + 0.000289 * math.sin(3 * mr))
    true_long = l0 + c
    omega = 125.04 - 1934.136 * t
    lam = true_long - 0.00569 - 0.00478 * math.sin(omega * D2R)
    eps0 = 23.0 + (26.0 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60.0) / 60.0
    eps = eps0 + 0.00256 * math.cos(omega * D2R)
    decl = math.asin(math.sin(eps * D2R) * math.sin(lam * D2R)) / D2R
    y = math.tan(eps * D2R / 2.0) ** 2
    l0r = l0 * D2R
    eq = (y * math.sin(2 * l0r) - 2 * e * math.sin(mr)
          + 4 * e * y * math.sin(mr) * math.cos(2 * l0r)
          - 0.5 * y * y * math.sin(4 * l0r) - 1.25 * e * e * math.sin(2 * mr))
    return decl, 4.0 * eq / D2R


def transit_ut(jd0, lon):
    t = 12.0 - lon / 15.0
    for _ in range(3):
        _, eqt = sun_position(jd0 + t / 24.0)
        t = 12.0 - lon / 15.0 - eqt / 60.0
    return t


def hour_angle(alt_deg, lat, decl):
    """زاوية الساعة بالساعات، أو None إن لم تبلغ الشمس هذا الارتفاع."""
    c = ((math.sin(alt_deg * D2R) - math.sin(lat * D2R) * math.sin(decl * D2R))
         / (math.cos(lat * D2R) * math.cos(decl * D2R)))
    if c < -1.0 or c > 1.0:
        return None
    return math.acos(c) / D2R / 15.0


def asr_altitude(shadow_factor, lat, decl):
    return math.atan(1.0 / (shadow_factor + math.tan(abs(lat - decl) * D2R))) / D2R


def event_ut(jd0, lon, lat, alt_fn, after_noon):
    """ساعة UT للحدث (قد تتجاوز 0..24 عند خطوط الطول الطرفية)، أو None."""
    big_t = transit_ut(jd0, lon)
    t = big_t
    for _ in range(4):
        decl, _ = sun_position(jd0 + t / 24.0)
        h = hour_angle(alt_fn(decl), lat, decl)
        if h is None:
            return None
        t = big_t + h if after_noon else big_t - h
    return t


METHODS = {
    # id: (الاسم، زاوية الفجر، زاوية العشاء، فاصل العشاء بالدقائق بعد المغرب)
    "mwl": ("رابطة العالم الإسلامي", 18.0, 17.0, None),
    "egypt": ("الهيئة المصرية العامة للمساحة", 19.5, 17.5, None),
    "karachi": ("جامعة العلوم الإسلامية - كراتشي", 18.0, 18.0, None),
    "umm_al_qura": ("أم القرى - مكة المكرمة", 18.5, None, 90),
    "isna": ("أمريكا الشمالية (ISNA)", 15.0, 15.0, None),
    "kuwait": ("الكويت", 18.0, 17.5, None),
    "qatar": ("قطر", 18.0, None, 90),
    "dubai": ("دبي", 18.2, 18.2, None),
    "singapore": ("سنغافورة", 20.0, 18.0, None),
    "turkey": ("تركيا (ديانت)", 18.0, 17.0, None),
}


def shift_civil(y, m, d, days):
    """يزيح تاريخاً ميلادياً بعدد أيام (للتعامل مع مناطق خارج يومها الشمسي)."""
    n = days_from_civil(y, m, d) + days
    z = n + 719468
    era = (z if z >= 0 else z - 146096) // 146097
    doe = z - era * 146097
    yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
    yy = yoe + era * 400
    doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
    mp = (5 * doy + 2) // 153
    dd = doy - (153 * mp + 2) // 5 + 1
    mm = mp + (3 if mp < 10 else -9)
    return (yy + (1 if mm <= 2 else 0), mm, dd)


def calculate(y, m, d, lat, lon, method="mwl", hanafi=False, tz_offset_minutes=None):
    """مواقيت يوم مدني (y,m,d) في الموقع المعطى.

    tz_offset_minutes: إزاحة المنطقة الزمنية وقت الظهر المحلي. تُستخدم لضمان أن يقع الظهر في اليوم
    المدني المطلوب حتى في مناطق تبتعد عن يومها الشمسي (مثل ساموا وكيريباتي). اختيارية.

    يعيد dict: fajr, sunrise, dhuhr, asr, maghrib, isha كثواني epoch (UTC، غير مقرّبة)،
    و approximated (bool: عُوِّض الفجر/العشاء بتقدير ليلي). أو None إن كانت الشمس لا تشرق/لا تغرب.
    """
    _, fajr_a, isha_a, isha_iv = METHODS[method]
    if tz_offset_minutes is not None:
        local_noon_h = transit_ut(julian_day(y, m, d), lon) + tz_offset_minutes / 60.0
        shift = -math.floor(local_noon_h / 24.0)
        if shift != 0:
            y, m, d = shift_civil(y, m, d, shift)
    jd0 = julian_day(y, m, d)
    base = days_from_civil(y, m, d) * 86400.0
    sunrise = event_ut(jd0, lon, lat, lambda _d: SUN_ALT, False)
    sunset = event_ut(jd0, lon, lat, lambda _d: SUN_ALT, True)
    if sunrise is None or sunset is None:
        return None
    dhuhr = transit_ut(jd0, lon)
    f = 2.0 if hanafi else 1.0
    asr = event_ut(jd0, lon, lat, lambda dc: asr_altitude(f, lat, dc), True)
    fajr = event_ut(jd0, lon, lat, lambda _d: -fajr_a, False)
    isha = (sunset + isha_iv / 60.0) if isha_iv is not None else event_ut(
        jd0, lon, lat, lambda _d: -isha_a, True)
    approx = False
    if fajr is None or isha is None or asr is None:
        # عروض عالية: سُبع الليل (الليل = من الغروب إلى شروق اليوم التالي)
        next_rise = event_ut(jd0 + 1.0, lon, lat, lambda _d: SUN_ALT, False)
        if next_rise is None:
            return None
        night = (next_rise + 24.0) - sunset
        if fajr is None:
            fajr = sunrise - night / 7.0
        if isha is None:
            isha = sunset + night / 7.0
        if asr is None:
            asr = dhuhr + (sunset - dhuhr) * 0.5
        approx = True
    out = {"fajr": fajr, "sunrise": sunrise, "dhuhr": dhuhr, "asr": asr, "maghrib": sunset,
           "isha": isha}
    res = {k: base + v * 3600.0 for k, v in out.items()}
    res["approximated"] = approx
    return res


def round_minute(epoch_seconds):
    return math.floor(epoch_seconds / 60.0 + 0.5) * 60
