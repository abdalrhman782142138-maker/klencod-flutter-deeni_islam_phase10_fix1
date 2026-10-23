import 'package:deeni_islam/core/calendar/hijri_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

// قيم ذهبية من tools/hijri/hijri_ref.py (المختبَر يوماً بيوم لـ١٧٠٠ سنة ومقارَن بتواريخ أم القرى المنشورة).
class _G {
  const _G(this.y, this.m, this.d, this.h, this.hPlus1, this.hMinus2);

  final int y;
  final int m;
  final int d;
  final List<int>? h;
  final List<int>? hPlus1;
  final List<int>? hMinus2;
}

const List<_G> _golden = <_G>[
  _G(2026, 2, 18, <int>[1447, 9, 2], <int>[1447, 9, 3], <int>[1447, 8, 29]),
  _G(2026, 3, 20, <int>[1447, 10, 2], <int>[1447, 10, 3], <int>[1447, 9, 30]),
  _G(2026, 5, 27, <int>[1447, 12, 11], <int>[1447, 12, 12], <int>[1447, 12, 9]),
  _G(2026, 6, 16, <int>[1448, 1, 1], <int>[1448, 1, 2], <int>[1447, 12, 29]),
  _G(2026, 6, 25, <int>[1448, 1, 10], <int>[1448, 1, 11], <int>[1448, 1, 8]),
  _G(2026, 8, 25, <int>[1448, 3, 12], <int>[1448, 3, 13], <int>[1448, 3, 10]),
  _G(2026, 10, 19, <int>[1448, 5, 8], <int>[1448, 5, 9], <int>[1448, 5, 6]),
  _G(2026, 10, 20, <int>[1448, 5, 9], <int>[1448, 5, 10], <int>[1448, 5, 7]),
  _G(2027, 2, 8, <int>[1448, 9, 2], <int>[1448, 9, 3], <int>[1448, 8, 29]),
  _G(2027, 3, 9, <int>[1448, 10, 1], <int>[1448, 10, 2], <int>[1448, 9, 29]),
  _G(2027, 5, 16, <int>[1448, 12, 10], <int>[1448, 12, 11], <int>[1448, 12, 8]),
  _G(2025, 6, 26, <int>[1447, 1, 1], <int>[1447, 1, 2], <int>[1446, 12, 28]),
  _G(2000, 1, 1, <int>[1420, 9, 25], <int>[1420, 9, 26], <int>[1420, 9, 23]),
  _G(1979, 11, 21, <int>[1400, 1, 2], <int>[1400, 1, 3], <int>[1399, 12, 29]),
  _G(2030, 12, 31, <int>[1452, 9, 7], <int>[1452, 9, 8], <int>[1452, 9, 5]),
  _G(2100, 3, 1, <int>[1523, 12, 20], <int>[1523, 12, 21], <int>[1523, 12, 18]),
  _G(1900, 1, 1, <int>[1317, 8, 29], <int>[1317, 9, 1], <int>[1317, 8, 27]),
  _G(622, 7, 16, null, null, null),
];

List<int>? _t(YearMonthDay? v) => v == null ? null : <int>[v.year, v.month, v.day];

void main() {
  test('قيم ذهبية: ميلادي → هجري مع تصحيح', () {
    for (final _G g in _golden) {
      expect(_t(hijriFromGregorian(g.y, g.m, g.d)), g.h, reason: '${g.y}-${g.m}-${g.d}');
      expect(_t(hijriFromGregorian(g.y, g.m, g.d, 1)), g.hPlus1, reason: '+1 ${g.y}-${g.m}-${g.d}');
      expect(_t(hijriFromGregorian(g.y, g.m, g.d, -2)), g.hMinus2, reason: '-2 ${g.y}-${g.m}-${g.d}');
    }
  });

  test('الذهاب والعودة لكل يوم في ١٧٠٠ سنة هجرية', () {
    for (int jdn = kHijriEpochJdn; jdn < kHijriEpochJdn + 1700 * 355; jdn++) {
      final YearMonthDay h = jdnToIslamic(jdn)!;
      expect(islamicToJdn(h.year, h.month, h.day), jdn);
      expect(h.month >= 1 && h.month <= 12, true);
      expect(h.day >= 1 && h.day <= hijriMonthLength(h.year, h.month), true);
    }
  });

  test('ميلادي ↔ JDN', () {
    expect(gregorianToJdn(2000, 1, 1), 2451545);
    expect(gregorianToJdn(2026, 10, 11), 2461325);
    for (int jdn = 2300000; jdn < 2700000; jdn += 13) {
      final YearMonthDay g = jdnToGregorian(jdn);
      expect(gregorianToJdn(g.year, g.month, g.day), jdn);
    }
  });

  test('مطابقة أم القرى المنشورة: لا فرق يتجاوز يوماً و٧ من ١١ متطابقة', () {
    final List<List<List<int>>> uq = <List<List<int>>>[
      <List<int>>[<int>[2026, 2, 18], <int>[1447, 9, 1]],
      <List<int>>[<int>[2026, 3, 20], <int>[1447, 10, 1]],
      <List<int>>[<int>[2026, 5, 27], <int>[1447, 12, 10]],
      <List<int>>[<int>[2026, 6, 16], <int>[1448, 1, 1]],
      <List<int>>[<int>[2026, 6, 25], <int>[1448, 1, 10]],
      <List<int>>[<int>[2026, 8, 25], <int>[1448, 3, 12]],
      <List<int>>[<int>[2026, 10, 19], <int>[1448, 5, 8]],
      <List<int>>[<int>[2027, 2, 8], <int>[1448, 9, 1]],
      <List<int>>[<int>[2027, 3, 9], <int>[1448, 10, 1]],
      <List<int>>[<int>[2027, 5, 16], <int>[1448, 12, 10]],
      <List<int>>[<int>[2025, 6, 26], <int>[1447, 1, 1]],
    ];
    int exact = 0;
    for (final List<List<int>> p in uq) {
      final int diff = islamicToJdn(p[1][0], p[1][1], p[1][2]) - gregorianToJdn(p[0][0], p[0][1], p[0][2]);
      expect(diff.abs() <= 1, true);
      if (diff == 0) exact++;
    }
    expect(exact >= 7, true);
  });

  test('العصر المدني يطابق الجدولي في ويكيبيديا', () {
    final YearMonthDay h = jdnToIslamic(gregorianToJdn(2026, 10, 11), kHijriEpochCivilJdn)!;
    expect(<int>[h.year, h.month, h.day], <int>[1448, 4, 28]);
  });

  test('قبل بداية التقويم يعيد null', () {
    expect(jdnToIslamic(kHijriEpochJdn - 1), isNull);
  });
}
