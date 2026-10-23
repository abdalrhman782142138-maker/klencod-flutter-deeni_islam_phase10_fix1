import 'package:flutter/material.dart';

import '../../../core/content/library_manager.dart';
import '../../../core/models/app_section.dart';
import '../../../core/models/library_status.dart';
import '../../../core/theme/app_theme.dart';

/// قسم المكتبات الثلاث مع الحالة الفعلية لكل مكتبة وشرح التنزيل الأول.
class LibrarySection extends StatelessWidget {
  const LibrarySection({
    Key? key,
    required this.onOpen,
    required this.onDownload,
  }) : super(key: key);

  final ValueChanged<AppSection> onOpen;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final LibraryManager manager = LibraryManager.instance;
    return AnimatedBuilder(
      animation: manager,
      builder: (BuildContext context, Widget? _) {
        final Color muted = AppTheme.muted(context);
        final Color accent = AppTheme.accent(context);
        final bool ready = manager.allReady;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!ready)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withAlpha(26),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.gold.withAlpha(90)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.cloud_download_outlined, color: accent, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'تنزيل المكتبات الأساسية',
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تحتاج المكتبات الثلاث إلى اتصال بالإنترنت مرة واحدة فقط. بعدها تُقرأ ويُبحث فيها دون إنترنت.',
                      style: TextStyle(fontSize: 13.5, height: 1.65, color: muted),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: onDownload,
                      child: Text(manager.anyPartial ? 'استئناف التنزيل' : 'بدء التنزيل'),
                    ),
                  ],
                ),
              ),
            for (final AppSection s in AppSection.libraries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LibraryRow(
                  section: s,
                  status: manager.statusOf(LibraryManager.idFor(s.id) ?? ''),
                  onTap: () => onOpen(s),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({
    Key? key,
    required this.section,
    required this.status,
    required this.onTap,
  }) : super(key: key);

  final AppSection section;
  final LibraryStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color muted = AppTheme.muted(context);
    final Color accent = AppTheme.accent(context);
    final bool ready = status == LibraryStatus.ready;
    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withAlpha(36),
                ),
                child: Icon(section.icon, color: accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      section.title,
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(section.subtitle, style: TextStyle(fontSize: 13, color: muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: (ready ? accent : muted).withAlpha(140)),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(fontSize: 12, color: ready ? accent : muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
