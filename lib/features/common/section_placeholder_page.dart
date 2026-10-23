import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// صفحة صادقة لقسم لم يُنفَّذ بعد: تشرح حالته ولا تعرض محتوى وهمياً.
class SectionPlaceholderPage extends StatelessWidget {
  const SectionPlaceholderPage({
    Key? key,
    required this.title,
    required this.icon,
    required this.message,
  }) : super(key: key);

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final Color muted = AppTheme.muted(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withAlpha(36),
                  ),
                  child: Icon(icon, size: 34, color: AppTheme.accent(context)),
                ),
                const SizedBox(height: 20),
                Text(
                  'قيد الإنشاء',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.7, color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
