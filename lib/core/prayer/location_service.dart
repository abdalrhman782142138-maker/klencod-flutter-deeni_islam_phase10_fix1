import 'package:flutter/services.dart';

class LocationResult {
  const LocationResult(this.lat, this.lon, this.accuracyMeters);

  final double lat;
  final double lon;
  final double accuracyMeters;
}

enum LocationFailureKind { denied, unavailable, timeout, other }

class LocationFailure implements Exception {
  const LocationFailure(this.kind, this.message);

  final LocationFailureKind kind;
  final String message;

  @override
  String toString() => message;
}

/// موقع الهاتف التقريبي (ACCESS_COARSE_LOCATION فقط). لا يُطلب إلا عند ضغط المستخدم على «استخدام موقع الهاتف».
/// الموقع يُستخدم محلياً لحساب المواقيت ولا يُرسل لأي خادم.
class LocationService {
  LocationService._();

  static const MethodChannel _channel = MethodChannel('com.deeniislam.app/location');

  static Future<LocationResult> request() async {
    try {
      final Map<dynamic, dynamic>? m =
          await _channel.invokeMapMethod<dynamic, dynamic>('getLocation');
      if (m == null) {
        throw const LocationFailure(LocationFailureKind.other, 'لم يصل رد من النظام.');
      }
      final num lat = m['lat'] as num;
      final num lon = m['lon'] as num;
      final num acc = (m['accuracy'] as num?) ?? 0;
      return LocationResult(lat.toDouble(), lon.toDouble(), acc.toDouble());
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'permission_denied':
          throw const LocationFailure(
              LocationFailureKind.denied, 'لم تمنح إذن الموقع. يمكنك اختيار مدينة أو إدخال الإحداثيات يدوياً.');
        case 'unavailable':
          throw const LocationFailure(
              LocationFailureKind.unavailable, 'خدمة الموقع متوقفة على هاتفك. فعّلها أو اختر مدينة يدوياً.');
        case 'timeout':
          throw const LocationFailure(
              LocationFailureKind.timeout, 'تعذّر تحديد الموقع في الوقت المناسب. جرّب مرة أخرى أو اختر مدينة.');
        default:
          throw const LocationFailure(LocationFailureKind.other, 'تعذّر تحديد الموقع.');
      }
    } on MissingPluginException {
      throw const LocationFailure(LocationFailureKind.other, 'تحديد الموقع غير متاح على هذا الجهاز.');
    }
  }
}
