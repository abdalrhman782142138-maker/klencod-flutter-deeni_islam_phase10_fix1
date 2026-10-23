import 'dart:math' as math;

/// حساب مواقيت الصلاة محلياً (بلا إنترنت). نقل حرفي من tools/prayer/prayer_ref.py
/// (المختبَر بحالات مرجعية). تحقق منه test/prayer_golden_test.dart بقيم ذهبية.
/// الأزمنة لحظات UTC. لا يستخدم سجلات Dart 3 ليبقى متوافقاً مع قيد SDK الحالي.

const double _d2r = math.pi / 180.0;
const double kSunAltitude = -0.833; // انكسار 0.567° + نصف قطر القرص 0.266°

enum PrayerKind { fajr, sunrise, dhuhr, asr, maghrib, isha }

class PrayerMethod {
  const PrayerMethod({
    required this.id,
    required this.nameAr,
    required this.fajrAngle,
    this.ishaAngle,
    this.ishaIntervalMinutes,
    this.noteAr = '',
  });

  final String id;
  final String nameAr;
  final double fajrAngle;
  final double? ishaAngle;

  /// إن وُجد: العشاء = المغرب + هذا العدد من الدقائق (بدل الزاوية).
  final int? ishaIntervalMinutes;
  final String noteAr;
}

const List<PrayerMethod> kPrayerMethods = <PrayerMethod>[
  PrayerMethod(id: 'mwl', nameAr: 'رابطة العالم الإسلامي', fajrAngle: 18.0, ishaAngle: 17.0),
  PrayerMethod(
      id: 'egypt',
      nameAr: 'الهيئة المصرية العامة للمساحة',
      fajrAngle: 19.5,
      ishaAngle: 17.5),
  PrayerMethod(
      id: 'karachi',
      nameAr: 'جامعة العلوم الإسلامية - كراتشي',
      fajrAngle: 18.0,
      ishaAngle: 18.0),
  PrayerMethod(
      id: 'umm_al_qura',
      nameAr: 'أم القرى - مكة المكرمة',
      fajrAngle: 18.5,
      ishaIntervalMinutes: 90,
      noteAr: 'تعتمد الجهة الرسمية ١٢٠ دقيقة للعشاء في رمضان؛ لا يُطبَّق ذلك تلقائياً الآن (يمكنك تعديل العشاء يدوياً).'),
  PrayerMethod(id: 'isna', nameAr: 'أمريكا الشمالية (ISNA)', fajrAngle: 15.0, ishaAngle: 15.0),
  PrayerMethod(id: 'kuwait', nameAr: 'الكويت', fajrAngle: 18.0, ishaAngle: 17.5),
  PrayerMethod(id: 'qatar', nameAr: 'قطر', fajrAngle: 18.0, ishaIntervalMinutes: 90),
  PrayerMethod(id: 'dubai', nameAr: 'دبي', fajrAngle: 18.2, ishaAngle: 18.2),
  PrayerMethod(id: 'singapore', nameAr: 'سنغافورة', fajrAngle: 20.0, ishaAngle: 18.0),
  PrayerMethod(id: 'turkey', nameAr: 'تركيا (ديانت)', fajrAngle: 18.0, ishaAngle: 17.0),
];

PrayerMethod prayerMethodById(String id) {
  for (final PrayerMethod m in kPrayerMethods) {
    if (m.id == id) return m;
  }
  return kPrayerMethods.first;
}

double julianDay(int y, int m, int d, [double hourUt = 0.0]) {
  int yy = y;
  int mm = m;
  if (mm <= 2) {
    yy -= 1;
    mm += 12;
  }
  final int a = yy ~/ 100;
  final int b = 2 - a + a ~/ 4;
  return (365.25 * (yy + 4716)).floorToDouble() +
      (30.6001 * (mm + 1)).floorToDouble() +
      d +
      b -
      1524.5 +
      hourUt / 24.0;
}

/// عدد الأيام منذ 1970-01-01 (Howard Hinnant؛ للسنوات الموجبة).
int daysFromCivil(int y, int m, int d) {
  final int yy = y - (m <= 2 ? 1 : 0);
  final int era = (yy >= 0 ? yy : yy - 399) ~/ 400;
  final int yoe = yy - era * 400;
  final int doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) ~/ 5 + d - 1;
  final int doe = yoe * 365 + yoe ~/ 4 - yoe ~/ 100 + doy;
  return era * 146097 + doe - 719468;
}

class SunPosition {
  const SunPosition(this.declination, this.equationOfTimeMinutes);

  final double declination;
  final double equationOfTimeMinutes;
}

SunPosition sunPosition(double jd) {
  final double t = (jd - 2451545.0) / 36525.0;
  final double l0 = (280.46646 + t * (36000.76983 + t * 0.0003032)) % 360.0;
  final double m = 357.52911 + t * (35999.05029 - 0.0001537 * t);
  final double e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
  final double mr = m * _d2r;
  final double c = (1.914602 - t * (0.004817 + 0.000014 * t)) * math.sin(mr) +
      (0.019993 - 0.000101 * t) * math.sin(2 * mr) +
      0.000289 * math.sin(3 * mr);
  final double trueLong = l0 + c;
  final double omega = 125.04 - 1934.136 * t;
  final double lam = trueLong - 0.00569 - 0.00478 * math.sin(omega * _d2r);
  final double eps0 = 23.0 +
      (26.0 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60.0) / 60.0;
  final double eps = eps0 + 0.00256 * math.cos(omega * _d2r);
  final double decl = math.asin(math.sin(eps * _d2r) * math.sin(lam * _d2r)) / _d2r;
  final double tn = math.tan(eps * _d2r / 2.0);
  final double y = tn * tn;
  final double l0r = l0 * _d2r;
  final double eq = y * math.sin(2 * l0r) -
      2 * e * math.sin(mr) +
      4 * e * y * math.sin(mr) * math.cos(2 * l0r) -
      0.5 * y * y * math.sin(4 * l0r) -
      1.25 * e * e * math.sin(2 * mr);
  return SunPosition(decl, 4.0 * eq / _d2r);
}

double transitUt(double jd0, double lon) {
  double t = 12.0 - lon / 15.0;
  for (int i = 0; i < 3; i++) {
    final SunPosition s = sunPosition(jd0 + t / 24.0);
    t = 12.0 - lon / 15.0 - s.equationOfTimeMinutes / 60.0;
  }
  return t;
}

/// زاوية الساعة بالساعات، أو null إن لم تبلغ الشمس هذا الارتفاع.
double? hourAngle(double altDeg, double lat, double decl) {
  final double c = (math.sin(altDeg * _d2r) - math.sin(lat * _d2r) * math.sin(decl * _d2r)) /
      (math.cos(lat * _d2r) * math.cos(decl * _d2r));
  if (c < -1.0 || c > 1.0) return null;
  return math.acos(c) / _d2r / 15.0;
}

double asrAltitude(double shadowFactor, double lat, double decl) {
  return math.atan(1.0 / (shadowFactor + math.tan((lat - decl).abs() * _d2r))) / _d2r;
}

double? eventUt(
  double jd0,
  double lon,
  double lat,
  double Function(double decl) altFn,
  bool afterNoon,
) {
  final double bigT = transitUt(jd0, lon);
  double t = bigT;
  for (int i = 0; i < 4; i++) {
    final SunPosition s = sunPosition(jd0 + t / 24.0);
    final double? h = hourAngle(altFn(s.declination), lat, s.declination);
    if (h == null) return null;
    t = afterNoon ? bigT + h : bigT - h;
  }
  return t;
}

/// أزمنة خام (ثواني epoch، UTC، غير مقرّبة).
class RawPrayerTimes {
  const RawPrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.approximated,
  });

  final double fajr;
  final double sunrise;
  final double dhuhr;
  final double asr;
  final double maghrib;
  final double isha;

  /// true: الفجر أو العشاء (أو العصر) قُدِّر بسُبع الليل لأن الشمس لا تبلغ الزاوية في هذا الموقع/التاريخ.
  final bool approximated;

  double of(PrayerKind k) {
    switch (k) {
      case PrayerKind.fajr:
        return fajr;
      case PrayerKind.sunrise:
        return sunrise;
      case PrayerKind.dhuhr:
        return dhuhr;
      case PrayerKind.asr:
        return asr;
      case PrayerKind.maghrib:
        return maghrib;
      case PrayerKind.isha:
        return isha;
    }
  }
}

/// مواقيت يوم مدني (y,m,d). [tzOffsetMinutes] إزاحة المنطقة وقت الظهر المحلي (تضمن وقوع
/// الظهر في اليوم المدني المطلوب حتى في المناطق الخارجة عن يومها الشمسي). null = بلا تصحيح.
/// تعيد null إن كانت الشمس لا تشرق/لا تغرب (مناطق قطبية).
RawPrayerTimes? calculateRaw({
  required int y,
  required int m,
  required int d,
  required double lat,
  required double lon,
  required PrayerMethod method,
  bool hanafi = false,
  int? tzOffsetMinutes,
}) {
  int yy = y;
  int mm = m;
  int dd = d;
  if (tzOffsetMinutes != null) {
    final double localNoonH = transitUt(julianDay(yy, mm, dd), lon) + tzOffsetMinutes / 60.0;
    final int shift = -((localNoonH / 24.0).floor());
    if (shift != 0) {
      final DateTime sh = DateTime.utc(yy, mm, dd).add(Duration(days: shift));
      yy = sh.year;
      mm = sh.month;
      dd = sh.day;
    }
  }
  final double jd0 = julianDay(yy, mm, dd);
  final double base = daysFromCivil(yy, mm, dd) * 86400.0;

  final double? sunrise = eventUt(jd0, lon, lat, (double _) => kSunAltitude, false);
  final double? sunset = eventUt(jd0, lon, lat, (double _) => kSunAltitude, true);
  if (sunrise == null || sunset == null) return null;
  final double dhuhr = transitUt(jd0, lon);
  final double f = hanafi ? 2.0 : 1.0;
  double? asr = eventUt(jd0, lon, lat, (double dc) => asrAltitude(f, lat, dc), true);
  double? fajr = eventUt(jd0, lon, lat, (double _) => -method.fajrAngle, false);
  final int? interval = method.ishaIntervalMinutes;
  double? isha = interval != null
      ? sunset + interval / 60.0
      : eventUt(jd0, lon, lat, (double _) => -(method.ishaAngle ?? 17.0), true);

  bool approx = false;
  if (fajr == null || isha == null || asr == null) {
    final double? nextRise =
        eventUt(jd0 + 1.0, lon, lat, (double _) => kSunAltitude, false);
    if (nextRise == null) return null;
    final double night = (nextRise + 24.0) - sunset;
    fajr ??= sunrise - night / 7.0;
    isha ??= sunset + night / 7.0;
    asr ??= dhuhr + (sunset - dhuhr) * 0.5;
    approx = true;
  }
  return RawPrayerTimes(
    fajr: base + fajr! * 3600.0,
    sunrise: base + sunrise * 3600.0,
    dhuhr: base + dhuhr * 3600.0,
    asr: base + asr! * 3600.0,
    maghrib: base + sunset * 3600.0,
    isha: base + isha! * 3600.0,
    approximated: approx,
  );
}

int roundToMinute(double epochSeconds) {
  return (epochSeconds / 60.0 + 0.5).floor() * 60;
}

/// مواقيت يوم جاهزة للعرض: لحظات UTC مقرّبة للدقيقة مع التعديل اليدوي بالدقائق.
class PrayerDay {
  const PrayerDay({
    required this.year,
    required this.month,
    required this.day,
    required this.times,
    required this.approximated,
  });

  final int year;
  final int month;
  final int day;
  final Map<PrayerKind, DateTime> times;
  final bool approximated;
}

PrayerDay? computePrayerDay({
  required int y,
  required int m,
  required int d,
  required double lat,
  required double lon,
  required PrayerMethod method,
  bool hanafi = false,
  int? tzOffsetMinutes,
  Map<PrayerKind, int> adjustments = const <PrayerKind, int>{},
}) {
  final RawPrayerTimes? raw = calculateRaw(
    y: y,
    m: m,
    d: d,
    lat: lat,
    lon: lon,
    method: method,
    hanafi: hanafi,
    tzOffsetMinutes: tzOffsetMinutes,
  );
  if (raw == null) return null;
  final Map<PrayerKind, DateTime> out = <PrayerKind, DateTime>{};
  for (final PrayerKind k in PrayerKind.values) {
    final int secs = roundToMinute(raw.of(k)) + (adjustments[k] ?? 0) * 60;
    out[k] = DateTime.fromMillisecondsSinceEpoch(secs * 1000, isUtc: true);
  }
  return PrayerDay(year: y, month: m, day: d, times: out, approximated: raw.approximated);
}

/// الصلاة القادمة (الشروق ليس صلاة). تُمرَّر مواقيت اليوم ومواقيت الغد.
class NextPrayer {
  const NextPrayer(this.kind, this.time, this.isTomorrow);

  final PrayerKind kind;
  final DateTime time;
  final bool isTomorrow;
}

const List<PrayerKind> kPrayersOnly = <PrayerKind>[
  PrayerKind.fajr,
  PrayerKind.dhuhr,
  PrayerKind.asr,
  PrayerKind.maghrib,
  PrayerKind.isha,
];

NextPrayer? nextPrayer(PrayerDay today, PrayerDay? tomorrow, DateTime nowUtc) {
  for (final PrayerKind k in kPrayersOnly) {
    final DateTime t = today.times[k]!;
    if (t.isAfter(nowUtc)) return NextPrayer(k, t, false);
  }
  if (tomorrow != null) {
    return NextPrayer(PrayerKind.fajr, tomorrow.times[PrayerKind.fajr]!, true);
  }
  return null;
}
