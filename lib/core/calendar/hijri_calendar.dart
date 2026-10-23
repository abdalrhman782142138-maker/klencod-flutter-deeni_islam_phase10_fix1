import 'dart:math' as math;

/// التقويم الهجري الجدولي (حسابي). نقل حرفي من tools/hijri/hijri_ref.py.
/// ليس رصداً للهلال ولا جدول أم القرى الرسمي، وقد يختلف عنهما يوماً أو يومين.
/// العصر الفلكي (الخميس ١٥ يوليو ٦٢٢ جوليان): الأقرب لأم القرى في العينة المنشورة.

const int kHijriEpochJdn = 1948439;
const int kHijriEpochCivilJdn = 1948440;
const int kMaxHijriOffset = 3;

const List<String> kHijriMonthsAr = <String>[
  'محرم',
  'صفر',
  'ربيع الأول',
  'ربيع الآخر',
  'جمادى الأولى',
  'جمادى الآخرة',
  'رجب',
  'شعبان',
  'رمضان',
  'شوال',
  'ذو القعدة',
  'ذو الحجة',
];

class YearMonthDay {
  const YearMonthDay(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  @override
  bool operator ==(Object other) {
    return other is YearMonthDay &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => year * 10000 + month * 100 + day;
}

int gregorianToJdn(int y, int m, int d) {
  final int a = (14 - m) ~/ 12;
  final int yy = y + 4800 - a;
  final int mm = m + 12 * a - 3;
  return d + (153 * mm + 2) ~/ 5 + 365 * yy + yy ~/ 4 - yy ~/ 100 + yy ~/ 400 - 32045;
}

YearMonthDay jdnToGregorian(int jdn) {
  final int a = jdn + 32044;
  final int b = (4 * a + 3) ~/ 146097;
  final int c = a - (146097 * b) ~/ 4;
  final int d = (4 * c + 3) ~/ 1461;
  final int e = c - (1461 * d) ~/ 4;
  final int m = (5 * e + 2) ~/ 153;
  final int day = e - (153 * m + 2) ~/ 5 + 1;
  final int month = m + 3 - 12 * (m ~/ 10);
  final int year = 100 * b + d - 4800 + m ~/ 10;
  return YearMonthDay(year, month, day);
}

bool isHijriLeap(int year) => (14 + 11 * year) % 30 < 11;

int hijriMonthLength(int year, int month) {
  if (month % 2 == 1) return 30;
  if (month == 12 && isHijriLeap(year)) return 30;
  return 29;
}

int islamicToJdn(int y, int m, int d, [int epoch = kHijriEpochJdn]) {
  return d + (29.5 * (m - 1)).ceil() + (y - 1) * 354 + (3 + 11 * y) ~/ 30 + epoch - 1;
}

/// يعيد null للأيام قبل بداية التقويم الهجري.
YearMonthDay? jdnToIslamic(int jdn, [int epoch = kHijriEpochJdn]) {
  if (jdn < epoch) return null;
  final int y = (30 * (jdn - epoch) + 10646) ~/ 10631;
  final int m = math.min(12, ((jdn - (29 + islamicToJdn(y, 1, 1, epoch))) / 29.5).ceil() + 1);
  final int d = jdn - islamicToJdn(y, m, 1, epoch) + 1;
  return YearMonthDay(y, m, d);
}

/// التاريخ الهجري ليوم ميلادي مع تصحيح يدوي بالأيام (موجب = تقديم).
YearMonthDay? hijriFromGregorian(int y, int m, int d, [int offsetDays = 0]) {
  return jdnToIslamic(gregorianToJdn(y, m, d) + offsetDays);
}

YearMonthDay gregorianFromHijri(int y, int m, int d, [int offsetDays = 0]) {
  return jdnToGregorian(islamicToJdn(y, m, d) - offsetDays);
}
