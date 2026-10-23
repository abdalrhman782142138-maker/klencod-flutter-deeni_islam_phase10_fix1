import 'prayer_calculator.dart';

String prayerNameAr(PrayerKind k) {
  switch (k) {
    case PrayerKind.fajr:
      return 'الفجر';
    case PrayerKind.sunrise:
      return 'الشروق';
    case PrayerKind.dhuhr:
      return 'الظهر';
    case PrayerKind.asr:
      return 'العصر';
    case PrayerKind.maghrib:
      return 'المغرب';
    case PrayerKind.isha:
      return 'العشاء';
  }
}
