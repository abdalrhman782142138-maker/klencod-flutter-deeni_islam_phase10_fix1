import 'dart:math' as math;

/// حساب اتجاه القبلة (نقل حرفي من tools/qibla/qibla_ref.py المختبَر بمراجع منشورة).
/// القبلة = السمت الابتدائي للدائرة العظمى إلى الكعبة، من الشمال الحقيقي.
const double kKaabaLat = 21.4225;
const double kKaabaLon = 39.8262;
const double kEarthRadiusKm = 6371.0088;
const double kAlignToleranceDeg = 3.0;
const double _d2r = math.pi / 180.0;

/// السمت إلى الكعبة بالدرجات [0,360)، أو null إن كان الموقع عند الكعبة (أقل من ~٥٠ م).
double? bearingToKaaba(double lat, double lon) {
  if (distanceToKaabaKm(lat, lon) < 0.05) return null;
  final double p1 = lat * _d2r;
  final double p2 = kKaabaLat * _d2r;
  final double dl = (kKaabaLon - lon) * _d2r;
  final double y = math.sin(dl) * math.cos(p2);
  final double x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  return (math.atan2(y, x) / _d2r + 360.0) % 360.0;
}

double distanceToKaabaKm(double lat, double lon) {
  final double p1 = lat * _d2r;
  final double p2 = kKaabaLat * _d2r;
  final double dp = p2 - p1;
  final double dl = (kKaabaLon - lon) * _d2r;
  final double s1 = math.sin(dp / 2);
  final double s2 = math.sin(dl / 2);
  final double a = s1 * s1 + math.cos(p1) * math.cos(p2) * s2 * s2;
  return 2 * kEarthRadiusKm * math.asin(math.min(1.0, math.sqrt(a)));
}

/// الدوران المطلوب من [heading] إلى [target] في (-180, 180]؛ موجب = يميناً.
double signedAngleDiff(double target, double heading) {
  final double d = (target - heading + 540.0) % 360.0 - 180.0;
  return d == -180.0 ? 180.0 : d;
}

/// الانحراف المغناطيسي شرقاً موجب: الحقيقي = المغناطيسي + الانحراف.
double trueHeading(double magnetic, double declination) {
  return (magnetic + declination + 360.0) % 360.0;
}

bool isAligned(double target, double heading, [double tolerance = kAlignToleranceDeg]) {
  return signedAngleDiff(target, heading).abs() <= tolerance;
}

/// مرشح تمرير منخفض للزوايا (متوسط أسّي لجيب وجيب التمام) فلا يقفز عند عبور الصفر.
class HeadingFilter {
  HeadingFilter({this.alpha = 0.2});

  final double alpha;
  double? _s;
  double? _c;

  double add(double deg) {
    final double s = math.sin(deg * _d2r);
    final double c = math.cos(deg * _d2r);
    if (_s == null || _c == null) {
      _s = s;
      _c = c;
    } else {
      _s = _s! + alpha * (s - _s!);
      _c = _c! + alpha * (c - _c!);
    }
    return (math.atan2(_s!, _c!) / _d2r + 360.0) % 360.0;
  }

  void reset() {
    _s = null;
    _c = null;
  }
}
