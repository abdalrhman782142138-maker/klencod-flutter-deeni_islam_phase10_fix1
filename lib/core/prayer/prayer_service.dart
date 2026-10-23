import 'prayer_calculator.dart';
import 'prayer_settings.dart';

class PrayerSnapshot {
  const PrayerSnapshot({
    required this.civilYear,
    required this.civilMonth,
    required this.civilDay,
    required this.today,
    required this.tomorrow,
    required this.problem,
  });

  final int civilYear;
  final int civilMonth;
  final int civilDay;
  final PrayerDay? today;
  final PrayerDay? tomorrow;

  /// سبب تعذّر الحساب (مثل شمس لا تغرب)، أو null.
  final String? problem;
}

/// يحسب مواقيت اليوم والغد بحسب الإعدادات الحالية ويخزّن النتيجة حتى يتغير التاريخ أو الإعدادات.
class PrayerService {
  PrayerService._();

  static final PrayerService instance = PrayerService._();

  PrayerSnapshot? _cached;
  String? _key;

  /// تاريخ اليوم المدني بحسب وضع المنطقة الزمنية.
  DateTime civilNow(DateTime nowUtc) {
    final PrayerSettings s = PrayerSettings.instance;
    if (s.autoTz) return nowUtc.toLocal();
    return nowUtc.add(Duration(minutes: s.manualTzMinutes));
  }

  /// إزاحة المنطقة وقت الظهر المحلي لليوم المدني (للتوقيت التلقائي تراعي التوقيت الصيفي).
  int tzOffsetFor(int y, int m, int d) {
    final PrayerSettings s = PrayerSettings.instance;
    if (!s.autoTz) return s.manualTzMinutes;
    return DateTime(y, m, d, 12).timeZoneOffset.inMinutes;
  }

  /// لحظة UTC → تاريخ/وقت بحقول محلية للعرض.
  DateTime toDisplay(DateTime utc) {
    final PrayerSettings s = PrayerSettings.instance;
    if (s.autoTz) return utc.toLocal();
    return utc.add(Duration(minutes: s.manualTzMinutes));
  }

  PrayerDay? computeDay(int y, int m, int d) {
    final PrayerSettings s = PrayerSettings.instance;
    final Place? p = s.place;
    if (p == null) return null;
    return computePrayerDay(
      y: y,
      m: m,
      d: d,
      lat: p.lat,
      lon: p.lon,
      method: s.method,
      hanafi: s.hanafi,
      tzOffsetMinutes: tzOffsetFor(y, m, d),
      adjustments: s.adjustments,
    );
  }

  /// مواقيت يوم مدني محدد (لتصفح الأيام).
  PrayerDay? dayFor(DateTime civilDate) => computeDay(civilDate.year, civilDate.month, civilDate.day);

  PrayerSnapshot? snapshot([DateTime? nowUtc]) {
    final PrayerSettings s = PrayerSettings.instance;
    if (s.place == null) return null;
    final DateTime civil = civilNow(nowUtc ?? DateTime.now().toUtc());
    final String key = '${s.version}|${civil.year}-${civil.month}-${civil.day}';
    if (key == _key && _cached != null) return _cached;
    final PrayerDay? today = computeDay(civil.year, civil.month, civil.day);
    final DateTime tm = DateTime.utc(civil.year, civil.month, civil.day).add(const Duration(days: 1));
    final PrayerDay? tomorrow = computeDay(tm.year, tm.month, tm.day);
    _cached = PrayerSnapshot(
      civilYear: civil.year,
      civilMonth: civil.month,
      civilDay: civil.day,
      today: today,
      tomorrow: tomorrow,
      problem: today == null
          ? 'لا يمكن حساب المواقيت في هذا الموقع في هذا التاريخ (الشمس لا تشرق أو لا تغرب).'
          : null,
    );
    _key = key;
    return _cached;
  }
}
