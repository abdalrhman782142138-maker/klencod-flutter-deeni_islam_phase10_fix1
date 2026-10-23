import 'package:flutter/material.dart';

import '../../core/content/content_config.dart';
import '../../core/content/library_manager.dart';
import '../../core/content/manifest.dart';
import '../../core/models/library_status.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/arabic_format.dart';

typedef ContinueCallback = void Function(BuildContext context);

/// شاشة الترحيب وتنزيل المكتبات الثلاث: القرآن وصحيح البخاري وصحيح مسلم.
class WelcomeDownloadPage extends StatefulWidget {
  const WelcomeDownloadPage({Key? key, this.firstRun = false, this.onContinue})
      : super(key: key);

  final bool firstRun;

  /// عند الاستدعاء من شاشة البداية: ما يُفعل عند المتابعة (الانتقال للرئيسية).
  final ContinueCallback? onContinue;

  @override
  State<WelcomeDownloadPage> createState() => _WelcomeDownloadPageState();
}

class _WelcomeDownloadPageState extends State<WelcomeDownloadPage> {
  final LibraryManager _m = LibraryManager.instance;

  @override
  void initState() {
    super.initState();
    // بعد أول إطار، كي لا يُبلَّغ المستمعون أثناء البناء.
    WidgetsBinding.instance.addPostFrameCallback((_) => _m.loadManifest());
  }

  void _continue() {
    if (widget.onContinue != null) {
      widget.onContinue!(context);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmCancel() async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) {
        return AlertDialog(
          title: const Text('إلغاء التنزيل؟'),
          content: const Text('سيُحذف ما نُزِّل جزئياً، وتبدأ من جديد عند التنزيل لاحقاً.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('متابعة التنزيل'),
            ),
            TextButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('إلغاء التنزيل'),
            ),
          ],
        );
      },
    );
    if (yes == true) {
      await _m.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _m,
      builder: (BuildContext context, Widget? _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.firstRun ? 'مرحباً بك' : 'المكتبات الأساسية'),
            automaticallyImplyLeading: !widget.firstRun,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: <Widget>[
                _intro(context),
                const SizedBox(height: 14),
                _sourceStatus(context),
                const SizedBox(height: 14),
                for (final String id in kLibraryIds) ...<Widget>[
                  _LibraryRow(id: id, manager: _m),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
                _totals(context),
                const SizedBox(height: 18),
                ..._actions(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _intro(BuildContext context) {
    final Color muted = AppTheme.muted(context);
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.wifi_rounded, color: AppTheme.accent(context), size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'الإنترنت مطلوب مرة واحدة فقط',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'لتنزيل القرآن الكريم وصحيح البخاري وصحيح مسلم إلى جهازك. بعد اكتمال التنزيل '
            'والتحقق من سلامة كل مكتبة تُقرأ ويُبحث فيها دون إنترنت، ولا يُعاد التنزيل عند كل تشغيل. '
            'لا يبدأ أي تنزيل إلا بعد أن تضغط «بدء التنزيل».',
            style: TextStyle(fontSize: 14, height: 1.7, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _sourceStatus(BuildContext context) {
    final Color muted = AppTheme.muted(context);
    final ManifestState st = _m.manifestState;
    if (_m.storageError != null) {
      return _note(context, Icons.error_outline_rounded, _m.storageError!, null);
    }
    if (st == ManifestState.loading || st == ManifestState.idle) {
      return Row(
        children: <Widget>[
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text('جارٍ جلب أحجام المكتبات…', style: TextStyle(fontSize: 13.5, color: muted)),
        ],
      );
    }
    if (st == ManifestState.failed) {
      return _note(
        context,
        Icons.cloud_off_rounded,
        _m.manifestMessage ?? 'تعذّر جلب قائمة المكتبات.',
        ContentConfig.isConfigured ? _m.loadManifest : null,
      );
    }
    if (_m.manifestMessage != null) {
      return _note(context, Icons.info_outline_rounded, _m.manifestMessage!, _m.loadManifest);
    }
    return const SizedBox.shrink();
  }

  Widget _note(BuildContext context, IconData icon, String text, VoidCallback? retry) {
    final Color muted = AppTheme.muted(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context)),
        color: AppTheme.surface(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13.5, height: 1.6, color: muted)),
          ),
          if (retry != null)
            TextButton(onPressed: retry, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }

  Widget _totals(BuildContext context) {
    final Color muted = AppTheme.muted(context);
    final int total = _m.overallTotal;
    if (total <= 0) return const SizedBox.shrink();
    final int done = _m.overallDone;
    final bool active = _m.busy || done > 0;
    final double fraction = total == 0 ? 0 : done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'الحجم الإجمالي للتنزيل: ${ArabicFormat.bytes(total)}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        if (active) ...<Widget>[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: fraction, minHeight: 8),
          ),
          const SizedBox(height: 6),
          Text(
            '${ArabicFormat.percent(fraction)} · نُزِّل ${ArabicFormat.bytes(done)} '
            'والمتبقي ${ArabicFormat.bytes(total - done)}',
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ],
      ],
    );
  }

  List<Widget> _actions(BuildContext context) {
    final Color muted = AppTheme.muted(context);
    if (_m.allReady) {
      return <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.check_circle_rounded, color: AppTheme.accent(context)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'اكتمل التنزيل وتم التحقق من المكتبات الثلاث. تعمل الآن دون إنترنت.',
                style: TextStyle(fontSize: 14.5, height: 1.6, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton(onPressed: _continue, child: const Text('المتابعة')),
      ];
    }
    if (_m.busy) {
      return <Widget>[
        OutlinedButton(
          onPressed: _m.pause,
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          child: const Text('إيقاف مؤقت'),
        ),
        TextButton(onPressed: _confirmCancel, child: const Text('إلغاء التنزيل')),
        const SizedBox(height: 4),
        Text(
          'أبقِ التطبيق مفتوحاً أثناء التنزيل. إن أُغلق يُستأنف لاحقاً من حيث توقف.',
          style: TextStyle(fontSize: 12.5, height: 1.6, color: muted),
        ),
      ];
    }
    final bool resume = _m.anyPartial;
    return <Widget>[
      FilledButton(
        onPressed: _m.canStart ? _m.start : null,
        child: Text(resume ? 'استئناف التنزيل' : 'بدء التنزيل'),
      ),
      if (_m.anyDamaged) ...<Widget>[
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _m.repairDamaged,
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          child: const Text('إصلاح المكتبات التالفة'),
        ),
      ],
      if (resume) ...<Widget>[
        TextButton(onPressed: _confirmCancel, child: const Text('حذف ما نُزِّل جزئياً')),
      ],
      TextButton(onPressed: _continue, child: const Text('المتابعة بدون المكتبات الآن')),
    ];
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({Key? key, required this.id, required this.manager}) : super(key: key);

  final String id;
  final LibraryManager manager;

  static const Map<String, String> _titles = <String, String>{
    'quran': 'القرآن الكريم',
    'bukhari': 'صحيح البخاري',
    'muslim': 'صحيح مسلم',
  };

  @override
  Widget build(BuildContext context) {
    final Color muted = AppTheme.muted(context);
    final LibraryProgress p = manager.progressOf(id);
    final LibraryEntry? entry = manager.manifest?.entry(id);
    final String size = entry == null ? 'الحجم: —' : 'الحجم: ${ArabicFormat.bytes(entry.sizeCompressed)}';
    final bool showBar = p.bytesTotal > 0 &&
        (p.status == LibraryStatus.downloading ||
            p.status == LibraryStatus.paused ||
            p.status == LibraryStatus.verifying);
    final bool problem =
        p.status == LibraryStatus.failed || p.status == LibraryStatus.damaged;
    final Color chip = p.status == LibraryStatus.ready
        ? AppTheme.accent(context)
        : (problem ? Theme.of(context).colorScheme.error : muted);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _titles[id] ?? id,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: chip.withAlpha(140)),
                ),
                child: Text(p.status.label, style: TextStyle(fontSize: 12, color: chip)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(size, style: TextStyle(fontSize: 13, color: muted)),
          if (showBar) ...<Widget>[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: p.status == LibraryStatus.verifying
                    ? null
                    : (p.bytesDone / p.bytesTotal).clamp(0.0, 1.0).toDouble(),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${ArabicFormat.bytes(p.bytesDone)} من ${ArabicFormat.bytes(p.bytesTotal)}',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
          if (p.message != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              p.message!,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: problem ? Theme.of(context).colorScheme.error : muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
