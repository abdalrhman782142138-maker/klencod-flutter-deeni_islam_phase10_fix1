import 'package:flutter/services.dart';

class CompassReading {
  const CompassReading(this.magneticHeading, this.accuracy);

  /// اتجاه أعلى الهاتف (أو اتجاه الكاميرا الخلفية إن كان قائماً) مغناطيسياً بالدرجات.
  final double magneticHeading;

  /// دقة الحساس (Android): 0 غير موثوقة، 1 منخفضة، 2 متوسطة، 3 عالية.
  final int accuracy;
}

/// بوصلة الهاتف عبر قناة أصلية (SensorManager). لا تحتاج أي إذن.
/// الانحراف المغناطيسي يُحسب محلياً (GeomagneticField) دون إنترنت.
class CompassService {
  CompassService._();

  static const MethodChannel _method = MethodChannel('com.deeniislam.app/compass');
  static const EventChannel _events = EventChannel('com.deeniislam.app/compass_events');

  static Future<bool> isAvailable() async {
    try {
      return (await _method.invokeMethod<bool>('isAvailable')) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// الانحراف المغناطيسي (شرقاً موجب) لموقع معين، أو null إن تعذّر.
  static Future<double?> declination(double lat, double lon) async {
    try {
      return await _method.invokeMethod<double>(
          'declination', <String, dynamic>{'lat': lat, 'lon': lon});
    } catch (_) {
      return null;
    }
  }

  static Stream<CompassReading> readings() {
    return _events.receiveBroadcastStream().map((dynamic ev) {
      final Map<dynamic, dynamic> m = ev as Map<dynamic, dynamic>;
      return CompassReading((m['magnetic'] as num).toDouble(), (m['accuracy'] as num).toInt());
    });
  }
}
