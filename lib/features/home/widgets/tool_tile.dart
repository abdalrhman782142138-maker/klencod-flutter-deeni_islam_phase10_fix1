import 'package:flutter/material.dart';

import '../../../core/models/app_section.dart';
import '../../../core/theme/app_theme.dart';

/// بطاقة قسم من الأدوات اليومية.
class ToolTile extends StatelessWidget {
  const ToolTile({Key? key, required this.section, required this.onTap})
      : super(key: key);

  final AppSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color muted = AppTheme.muted(context);
    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withAlpha(36),
                ),
                child: Icon(section.icon, size: 22, color: AppTheme.accent(context)),
              ),
              const SizedBox(height: 12),
              Text(
                section.title,
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                section.subtitle,
                style: TextStyle(fontSize: 12.5, height: 1.5, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
