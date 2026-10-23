import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_calculator.dart';

class Place {
  const Place({required this.name, required this.lat, required this.lon, required this.source});

  final String name;
  final double lat;
  final double lon;

  /// city | manual | gps
  final String source;

  String get sourceAr {
    switch (source) {
      case 'gps':
        return 'موقع الهاتف';
      case 'city':
        return 'مدينة مختارة';
      default:
        return 'إحداثيات يدوية';
    }
  }
}

/// إعدادات المواقيت المحفوظة محلياً. أي تغيير يزيد [version] فيُعاد الحساب.
class PrayerSettings extends ChangeNotifier {
  PrayerSettings._();

  static final PrayerSettings instance = PrayerSettings._();

  Place? _place;
  String _methodId = 'mwl';
  bool _hanafi = false;
  bool _autoTz = true;
  int _manualTzMinutes = 0;
  bool _use24h = false;
  final Map<PrayerKind, int> _adjust = <PrayerKind, int>{};
  int version = 0;

  Place? get place => _place;
  String get methodId => _methodId;
  PrayerMethod get method => prayerMethodById(_methodId);
  bool get hanafi => _hanafi;
  bool get autoTz => _autoTz;
  int get manualTzMinutes => _manualTzMinutes;
  bool get use24h => _use24h;
  Map<PrayerKind, int> get adjustments => Map<PrayerKind, int>.unmodifiable(_adjust);

  static const int maxAdjust = 30;

  Future<void> load() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      final String? name = p.getString('pt_place_name');
      final double? lat = p.getDouble('pt_place_lat');
      final double? lon = p.getDouble('pt_place_lon');
      if (name != null && lat != null && lon != null && _validCoords(lat, lon)) {
        _place = Place(name: name, lat: lat, lon: lon, source: p.getString('pt_place_src') ?? 'manual');
      }
      final String? m = p.getString('pt_method');
      if (m != null) _methodId = prayerMethodById(m).id;
      _hanafi = p.getBool('pt_hanafi') ?? false;
      _autoTz = p.getBool('pt_auto_tz') ?? true;
      _manualTzMinutes = (p.getInt('pt_tz_min') ?? 0).clamp(-720, 840).toInt();
      _use24h = p.getBool('pt_24h') ?? false;
      for (final PrayerKind k in PrayerKind.values) {
        final int v = (p.getInt('pt_adj_${k.name}') ?? 0).clamp(-maxAdjust, maxAdjust).toInt();
        if (v != 0) _adjust[k] = v;
      }
    } catch (_) {
      // قراءة فاشلة: تبقى القيم الافتراضية ولا يتوقف التطبيق.
    }
  }

  static bool _validCoords(double lat, double lon) {
    return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180;
  }

  static bool validCoordinates(double lat, double lon) => _validCoords(lat, lon);

  void _changed() {
    version++;
    notifyListeners();
  }

  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<void> setPlace(Place p) async {
    if (!_validCoords(p.lat, p.lon)) return;
    _place = p;
    _changed();
    final SharedPreferences? s = await _prefs();
    await s?.setString('pt_place_name', p.name);
    await s?.setDouble('pt_place_lat', p.lat);
    await s?.setDouble('pt_place_lon', p.lon);
    await s?.setString('pt_place_src', p.source);
  }

  Future<void> setMethod(String id) async {
    _methodId = prayerMethodById(id).id;
    _changed();
    await (await _prefs())?.setString('pt_method', _methodId);
  }

  Future<void> setHanafi(bool v) async {
    _hanafi = v;
    _changed();
    await (await _prefs())?.setBool('pt_hanafi', v);
  }

  Future<void> setAutoTz(bool v) async {
    _autoTz = v;
    _changed();
    await (await _prefs())?.setBool('pt_auto_tz', v);
  }

  Future<void> setManualTzMinutes(int minutes) async {
    _manualTzMinutes = minutes.clamp(-720, 840).toInt();
    _changed();
    await (await _prefs())?.setInt('pt_tz_min', _manualTzMinutes);
  }

  Future<void> setUse24h(bool v) async {
    _use24h = v;
    _changed();
    await (await _prefs())?.setBool('pt_24h', v);
  }

  Future<void> setAdjustment(PrayerKind k, int minutes) async {
    final int v = minutes.clamp(-maxAdjust, maxAdjust).toInt();
    if (v == 0) {
      _adjust.remove(k);
    } else {
      _adjust[k] = v;
    }
    _changed();
    await (await _prefs())?.setInt('pt_adj_${k.name}', v);
  }
}
