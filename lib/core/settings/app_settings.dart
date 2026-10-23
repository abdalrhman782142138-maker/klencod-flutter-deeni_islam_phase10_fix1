import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إعدادات التطبيق المحفوظة محلياً. في هذه المرحلة: الوضع الفاتح/الداكن فقط.
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const String _kThemeMode = 'theme_mode';
  static const String _kWelcomeSeen = 'welcome_seen';
  static const String _kQuranFont = 'quran_font_size';
  static const String _kHadithFont = 'hadith_font_size';

  ThemeMode _themeMode = ThemeMode.system;

  bool _welcomeSeen = false;

  /// حجم خط القراءة في القرآن (يُستمع إليه مباشرة دون إعادة بناء التطبيق كله).
  final ValueNotifier<double> quranFontSize = ValueNotifier<double>(28);

  /// حجم خط قراءة الحديث (البخاري ومسلم).
  final ValueNotifier<double> hadithFontSize = ValueNotifier<double>(22);

  ThemeMode get themeMode => _themeMode;

  /// هل عُرضت شاشة الترحيب (تنزيل المكتبات) من قبل؟
  bool get welcomeSeen => _welcomeSeen;

  Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _themeMode = _decode(prefs.getString(_kThemeMode));
      _welcomeSeen = prefs.getBool(_kWelcomeSeen) ?? false;
      quranFontSize.value = (prefs.getDouble(_kQuranFont) ?? 28.0).clamp(20.0, 44.0).toDouble();
      hadithFontSize.value = (prefs.getDouble(_kHadithFont) ?? 22.0).clamp(16.0, 40.0).toDouble();
    } catch (_) {
      // عند فشل القراءة يبقى الوضع تلقائياً ولا يتوقف التطبيق.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemeMode, _encode(mode));
    } catch (_) {
      // التغيير يبقى مطبقاً في الجلسة الحالية حتى لو تعذّر الحفظ.
    }
  }

  Future<void> setQuranFontSize(double v) async {
    final double nv = v.clamp(20.0, 44.0).toDouble();
    if (nv == quranFontSize.value) return;
    quranFontSize.value = nv;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kQuranFont, nv);
    } catch (_) {}
  }

  Future<void> setHadithFontSize(double v) async {
    final double nv = v.clamp(16.0, 40.0).toDouble();
    if (nv == hadithFontSize.value) return;
    hadithFontSize.value = nv;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kHadithFont, nv);
    } catch (_) {}
  }

  Future<void> markWelcomeSeen() async {
    if (_welcomeSeen) return;
    _welcomeSeen = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kWelcomeSeen, true);
    } catch (_) {}
  }

  static ThemeMode _decode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _encode(ThemeMode mode) => mode.name;
}
