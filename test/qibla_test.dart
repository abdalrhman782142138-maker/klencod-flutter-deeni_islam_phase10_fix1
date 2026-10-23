import 'package:deeni_islam/core/qibla/qibla_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

// قيم ذهبية من tools/qibla/qibla_ref.py (المطابق لمراجع منشورة: نيويورك ٥٨٫٤٨°، لندن ١١٨٫٩٩°،
// جاكرتا ٢٩٥٫٢°، سيدني ٢٧٧٫٥°).
class _Pt {
  const _Pt(this.name, this.lat, this.lon, this.bearing, this.km);

  final String name;
  final double lat;
  final double lon;
  final double bearing;
  final double km;
}

const List<_Pt> _pts = <_Pt>[
  _Pt('New York', 40.7128, -74.006, 58.48170103788368, 10306.32062427432),
  _Pt('London', 51.5074, -0.1278, 118.98721949633443, 4793.781762338425),
  _Pt('Jakarta', -6.2088, 106.8456, 295.1517362622441, 7920.137774584169),
  _Pt('Sydney', -33.8688, 151.2093, 277.4995891209515, 13236.273761300226),
  _Pt('Tokyo', 35.6762, 139.6503, 292.9986801861639, 9471.862248741261),
  _Pt('Los Angeles', 34.0522, -118.2437, 23.857075959670624, 13424.336324286387),
  _Pt('Cairo', 30.0444, 31.2357, 136.13727662254735, 1287.2179939459118),
  _Pt('Istanbul', 41.0082, 28.9784, 151.62059029258205, 2405.069927251288),
  _Pt('Karachi', 24.8607, 67.0011, 267.7409955017553, 2800.051523931236),
  _Pt('Cape Town', -33.9249, 18.4241, 23.352542268995705, 6558.3145150715245),
  _Pt('Buenos Aires', -34.6037, -58.3816, 76.26774269650275, 12061.345752510759),
  _Pt('Madinah', 24.4672, 39.6112, 176.23707136526355, 339.2704517881478),
];

void main() {
  for (final _Pt p in _pts) {
    test('qibla: ${p.name}', () {
      expect(bearingToKaaba(p.lat, p.lon)!, closeTo(p.bearing, 1e-6));
      expect(distanceToKaabaKm(p.lat, p.lon), closeTo(p.km, 1e-6));
    });
  }

  test('منشور: نيويورك ولندن وجاكرتا وسيدني', () {
    expect(bearingToKaaba(40.7128, -74.0060)!, closeTo(58.48, 0.1));
    expect(bearingToKaaba(51.5074, -0.1278)!, closeTo(118.99, 0.1));
    expect(bearingToKaaba(-6.2088, 106.8456)!, closeTo(295.2, 0.15));
    expect(bearingToKaaba(-33.8688, 151.2093)!, closeTo(277.5, 0.1));
  });

  test('عند الكعبة لا يوجد اتجاه', () {
    expect(bearingToKaaba(kKaabaLat, kKaabaLon), isNull);
    expect(bearingToKaaba(21.43, 39.83), isNotNull);
  });

  test('الفرق الزاوي والمحاذاة وتصحيح الانحراف', () {
    expect(signedAngleDiff(10, 350), 20);
    expect(signedAngleDiff(350, 10), -20);
    expect(signedAngleDiff(0, 180), 180);
    expect(isAligned(119, 121.5), true);
    expect(isAligned(119, 123.5), false);
    expect(isAligned(1, 359), true);
    expect(trueHeading(350, 15), 5);
    expect(trueHeading(10, -15), 355);
  });

  test('المرشح لا يقفز عند عبور الصفر', () {
    final HeadingFilter f = HeadingFilter();
    double out = 0;
    for (final double d in <double>[359, 1, 359, 1, 359, 1, 359, 1, 359, 1]) {
      out = f.add(d);
    }
    expect(out > 350 || out < 10, true);
    final HeadingFilter g = HeadingFilter();
    for (int i = 0; i < 60; i++) {
      out = g.add(90);
    }
    expect(out, closeTo(90, 1e-3));
  });
}
