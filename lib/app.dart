import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_page.dart';

class DeeniApp extends StatelessWidget {
  const DeeniApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = AppSettings.instance;
    return AnimatedBuilder(
      animation: settings,
      builder: (BuildContext context, Widget? _) {
        return MaterialApp(
          title: 'ديني الإسلام',
          debugShowCheckedModeBanner: false,
          // اللغة العربية تجعل الاتجاه من اليمين إلى اليسار في كل الصفحات.
          locale: const Locale('ar'),
          supportedLocales: const <Locale>[Locale('ar')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.themeMode,
          home: const SplashPage(),
        );
      },
    );
  }
}
