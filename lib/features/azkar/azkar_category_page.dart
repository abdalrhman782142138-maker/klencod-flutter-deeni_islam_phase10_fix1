import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/azkar/azkar_models.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/user_data/user_data_store.dart';
import '../../core/utils/arabic_format.dart';
import '../../core/utils/share_service.dart';
import '../common/font_size_sheet.dart';

const String kAzkarKind = 'azkar';

String azkarCitation(AzkarCategory c, Dhikr d) {
  final StringBuffer b = StringBuffer(d.text);
  if (d.count != null && d.count! > 1) {
    b.write('\n(يُقال ${ArabicFormat.digits(d.count!)} مرات)');
  }
  if (d.reference != null && d.reference!.trim().isNotEmpty) {
    b.write('\n[${d.reference}]');
  }
  return b.toString();
}

/// أذكار تصنيف واحد. لا مسبحة ولا عدّاد: يُعرض عدد التكرار نصاً فقط كما ورد في المصدر.
class AzkarCategoryPage extends StatefulWidget {
  const AzkarCategoryPage({Key? key, required this.category, this.focusId})
      : super(key: key);

  final AzkarCategory category;
  final String? focusId;

  @override
  State<AzkarCategoryPage> createState() => _AzkarCategoryPageState();
}

class _AzkarCategoryPageState extends State<AzkarCategoryPage> {
  final Map<String, GlobalKey> _keys = <String, GlobalKey>{};
  Set<String> _favs = <String>{};

  @override
  void initState() {
    super.initState();
    _loadFavs();
    final String? f = widget.focusId;
    if (f != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final BuildContext? c = _keys[f]?.currentContext;
        if (c != null) Scrollable.ensureVisible(c, alignment: 0.08);
      });
    }
  }

  Future<void> _loadFavs() async {
    final List<String> refs = await UserDataStore.instance.favorites(kAzkarKind);
    if (mounted) setState(() => _favs = refs.toSet());
  }

  String _ref(Dhikr d) => '${widget.category.id}:${d.id}';

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  Future<void> _onTap(Dhikr d) async {
    final bool fav = _favs.contains(_ref(d));
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext c) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(fav ? Icons.bookmark_remove_rounded : Icons.bookmark_add_rounded),
                title: Text(fav ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة'),
                onTap: () async {
                  Navigator.of(c).pop();
                  final bool now =
                      await UserDataStore.instance.toggleFavorite(kAzkarKind, _ref(d));
                  if (!mounted) return;
                  setState(() {
                    if (now) {
                      _favs.add(_ref(d));
                    } else {
                      _favs.remove(_ref(d));
                    }
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('نسخ'),
                onTap: () async {
                  Navigator.of(c).pop();
                  await Clipboard.setData(
                      ClipboardData(text: azkarCitation(widget.category, d)));
                  _toast('تم النسخ');
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('مشاركة'),
                onTap: () async {
                  Navigator.of(c).pop();
                  final bool ok =
                      await ShareService.shareText(azkarCitation(widget.category, d));
                  if (!ok) _toast('تعذّرت المشاركة؛ نُسخ النص إلى الحافظة');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AzkarCategory cat = widget.category;
    return Scaffold(
      appBar: AppBar(
        title: Text(cat.titleAr),
        actions: <Widget>[
          IconButton(
            tooltip: 'حجم الخط',
            onPressed: () => showFontSizeSheet(
              context,
              notifier: AppSettings.instance.hadithFontSize,
              onChanged: AppSettings.instance.setHadithFontSize,
              min: 16,
              max: 40,
            ),
            icon: const Icon(Icons.text_fields_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder<double>(
          valueListenable: AppSettings.instance.hadithFontSize,
          builder: (BuildContext context, double size, Widget? _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final Dhikr d in cat.items) _tile(context, d, size),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, Dhikr d, double size) {
    final Color muted = AppTheme.muted(context);
    final Color accent = AppTheme.accent(context);
    final bool fav = _favs.contains(_ref(d));
    final bool hasRef = d.reference != null && d.reference!.trim().isNotEmpty;
    return Container(
      key: _keys.putIfAbsent(d.id, () => GlobalKey()),
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: fav ? AppColors.gold.withAlpha(24) : AppTheme.surface(context),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _onTap(d),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (d.count != null || fav)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: <Widget>[
                      if (d.count != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: accent.withAlpha(140)),
                          ),
                          child: Text(
                            d.count == 1 ? 'مرة واحدة' : 'يُقال ${ArabicFormat.digits(d.count!)} مرات',
                            style: TextStyle(fontSize: 12.5, color: accent),
                          ),
                        ),
                      const Spacer(),
                      if (fav) Icon(Icons.bookmark_rounded, size: 20, color: accent),
                    ],
                  ),
                ),
              Text(d.text,
                  textAlign: TextAlign.justify,
                  style: TextStyle(fontSize: size, height: 1.9)),
              if (hasRef) ...<Widget>[
                const SizedBox(height: 8),
                Text(d.reference!, style: TextStyle(fontSize: 12.5, height: 1.6, color: muted)),
              ],
              if (d.notes != null && d.notes!.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(d.notes!, style: TextStyle(fontSize: 12.5, height: 1.6, color: muted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
