import 'package:flutter/material.dart';

/// انتقال بتلاشٍ هادئ.
Route<void> fadeRoute(Widget page) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (BuildContext c, Animation<double> a, Animation<double> s) => page,
    transitionsBuilder:
        (BuildContext c, Animation<double> a, Animation<double> s, Widget child) {
      return FadeTransition(opacity: a, child: child);
    },
  );
}
