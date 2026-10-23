import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/arabic_format.dart';
import 'hijri_calendar.dart';

/// تصحيح يدوي للتاريخ الهجري (أيام)، محفوظ محلياً.
class CalendarSettings extends ChangeNotifier {
  CalendarSettings._();

  static final CalendarSettings instance = CalendarSettings._();

  int _offset = 0;

  int get hijriOffset => _offset;

  Future<void> load() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      _offset = (p.getInt('hijri_offset') ?? 0).clamp(-kMaxHijriOffset, kMaxHijriOffset).toInt();
    } catch (_) {}
  }

  Future<void> setHijriOffset(int v) async {
    final int nv = v.clamp(-kMaxHijriOffset, kMaxHijriOffset).toInt();
    if (nv == _offset) return;
    _offset = nv;
    notifyListeners();
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setInt('hijri_offset', nv);
    } catch (_) {}
  }

  YearMonthDay? hijriOf(DateTime g) => hijriFromGregorian(g.year, g.month, g.day, _offset);

  static String formatHijri(YearMonthDay h) {
    return '${ArabicFormat.digits(h.day)} ${kHijriMonthsAr[h.month - 1]} ${ArabicFormat.digits(h.year)} هـ';
  }

  /// «٩ جمادى الأولى ١٤٤٨ هـ» أو null.
  String? hijriText(DateTime g) {
    final YearMonthDay? h = hijriOf(g);
    return h == null ? null : formatHijri(h);
  }
}
