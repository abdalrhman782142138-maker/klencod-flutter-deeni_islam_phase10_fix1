import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/content/library_manager.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/routes.dart';
import '../home/home_page.dart';
import '../library/welcome_download_page.dart';

/// شاشة البداية: خلفية بلون الأيقونة نفسه مع ظهور تدريجي للشعار.
class SplashPage extends StatefulWidget {
  const SplashPage({Key? key}) : super(key: key);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(_fade);
    _controller.forward();
    _timer = Timer(const Duration(milliseconds: 1800), _goHome);
  }

  void _goHome() {
    if (!mounted) return;
    final bool firstRun =
        !AppSettings.instance.welcomeSeen && !LibraryManager.instance.allReady;
    final Widget next = firstRun
        ? WelcomeDownloadPage(
            firstRun: true,
            onContinue: (BuildContext c) {
              AppSettings.instance.markWelcomeSeen();
              Navigator.of(c).pushReplacement(fadeRoute(const HomePage()));
            },
          )
        : const HomePage();
    Navigator.of(context).pushReplacement(fadeRoute(next));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double logoSize = width * 0.62 > 300 ? 300 : width * 0.62;
    return Scaffold(
      backgroundColor: AppColors.forest,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Image.asset(
              'assets/images/logo.png',
              width: logoSize,
              height: logoSize,
              semanticLabel: 'ديني الإسلام',
            ),
          ),
        ),
      ),
    );
  }
}
