import 'package:flutter/material.dart';

import 'app.dart';
import 'core/calendar/calendar_settings.dart';
import 'core/content/library_manager.dart';
import 'core/prayer/prayer_settings.dart';
import 'core/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  await PrayerSettings.instance.load();
  await CalendarSettings.instance.load();
  try {
    await LibraryManager.instance.init();
  } catch (_) {
    // الخطأ يظهر في شاشة المكتبات؛ لا يتوقف التطبيق.
  }
  runApp(const DeeniApp());
}