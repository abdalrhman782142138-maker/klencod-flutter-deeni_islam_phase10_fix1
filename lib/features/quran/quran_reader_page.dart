import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/quran/quran_models.dart';
import '../../core/quran/quran_repository.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/user_data/user_data_store.dart';
import '../../core/utils/arabic_format.dart';
import '../../core/utils/arabic_normalizer.dart';
import '../../core/utils/share_service.dart';

/// قارئ سورة: كل آيات السورة في عرض واحد قابل للتمرير، مع حفظ آخر موضع تلقائياً.
class QuranReaderPage extends StatefulWidget {
  const QuranReaderPage({Key? key, required this.surah, this.targetAyah})
      : super(key: key);

  final Surah surah;
  final int? targetAyah;

  @override
  State<QuranReaderPage> createState() => _QuranReaderPageState();
}

class _QuranReaderPageState extends State<QuranReaderPage> {
  static const String _kind = 'quran';

  final ScrollController _scroll = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  final Map<int, GlobalKey> _keys = <int, GlobalKey>{};

  List<Ayah>? _ayahs;
  String? _error;
  String? _bismillahHeader;
  Set<int> _favs = <int>{};
  int _current = 1;
  int? _highlight;
  Timer? _saveTimer;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _highlightTimer?.cancel();
    _computeCurrent();
    UserDataStore.instance.setLastPosition(_kind, '${widget.surah.id}:$_current');
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final QuranRepository repo = QuranRepository.instance;
      final List<Ayah> ayahs = await repo.ayahsOf(widget.surah.id);
      if (ayahs.isEmpty) {
        throw const QuranUnavailable('لا توجد آيات لهذه السورة في المكتبة.');
      }
      final String? bis = await repo.bismillahText();
      final List<String> favRefs =
          await UserDataStore.instance.favorites(_kind, prefix: '${widget.surah.id}:');
      final Set<int> favs = <int>{
        for (final String r in favRefs) int.tryParse(r.split(':').last) ?? -1,
      };
      // البسملة: تُعرض كترويسة فقط إن لم تكن جزءاً من نص الآية الأولى في المصدر.
      String? header;
      if (bis != null && widget.surah.id != 1 && widget.surah.id != 9) {
        final String nb = normalizeAr(bis);
        if (!normalizeAr(ayahs.first.text).startsWith(nb)) header = bis;
      }
      if (!mounted) return;
      setState(() {
        _ayahs = ayahs;
        _bismillahHeader = header;
        _favs = favs;
      });
      final int start = widget.targetAyah ?? 1;
      _current = start;
      UserDataStore.instance.setLastPosition(_kind, '${widget.surah.id}:$start');
      if (widget.targetAyah != null) {
        _jumpTo(widget.targetAyah!);
        _flash(widget.targetAyah!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is QuranUnavailable ? e.message : 'تعذّر فتح السورة.';
      });
    }
  }

  GlobalKey _keyFor(int n) => _keys.putIfAbsent(n, () => GlobalKey());

  void _jumpTo(int n) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? c = _keys[n]?.currentContext;
      if (c != null) {
        Scrollable.ensureVisible(c, alignment: 0.08);
      }
    });
  }

  void _flash(int n) {
    setState(() => _highlight = n);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _highlight = null);
    });
  }

  /// أول آية ما زال جزء منها ظاهراً أسفل أعلى منطقة القراءة.
  void _computeCurrent() {
    final RenderObject? vp = _viewportKey.currentContext?.findRenderObject();
    if (vp is! RenderBox || !vp.attached) return;
    final double vpTop = vp.localToGlobal(Offset.zero).dy;
    int? best;
    double bestTop = double.infinity;
    for (final MapEntry<int, GlobalKey> e in _keys.entries) {
      final RenderObject? ro = e.value.currentContext?.findRenderObject();
      if (ro is! RenderBox || !ro.attached) continue;
      final double top = ro.localToGlobal(Offset.zero).dy;
      if (top + ro.size.height > vpTop + 12 && top < bestTop) {
        bestTop = top;
        best = e.key;
      }
    }
    if (best != null) _current = best;
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () {
      _computeCurrent();
      UserDataStore.instance.setLastPosition(_kind, '${widget.surah.id}:$_current');
    });
  }

  String _citation(Ayah a) {
    return '${a.text} ﴿${ArabicFormat.digits(a.ayah)}﴾\n'
        '[سورة ${widget.surah.nameAr}: ${ArabicFormat.digits(a.ayah)}]';
  }

  Future<void> _onAyahTap(Ayah a) async {
    final bool fav = _favs.contains(a.ayah);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext c) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'سورة ${widget.surah.nameAr} · آية ${ArabicFormat.digits(a.ayah)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(fav ? Icons.bookmark_remove_rounded : Icons.bookmark_add_rounded),
                title: Text(fav ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة'),
                onTap: () async {
                  Navigator.of(c).pop();
                  final bool now = await UserDataStore.instance.toggleFavorite(_kind, a.ref);
                  if (!mounted) return;
                  setState(() {
                    if (now) {
                      _favs.add(a.ayah);
                    } else {
                      _favs.remove(a.ayah);
                    }
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('نسخ الآية'),
                onTap: () async {
                  Navigator.of(c).pop();
                  await Clipboard.setData(ClipboardData(text: _citation(a)));
                  _toast('تم نسخ الآية');
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('مشاركة الآية'),
                onTap: () async {
                  Navigator.of(c).pop();
                  final bool shared = await ShareService.shareText(_citation(a));
                  if (!shared) _toast('تعذّرت المشاركة؛ نُسخ النص إلى الحافظة');
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_rounded),
                title: const Text('حفظ كآخر موضع قراءة'),
                onTap: () {
                  Navigator.of(c).pop();
                  _current = a.ayah;
                  UserDataStore.instance.setLastPosition(_kind, a.ref);
                  _toast('تم حفظ الموضع');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  void _showFontSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext c) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: ValueListenableBuilder<double>(
              valueListenable: AppSettings.instance.quranFontSize,
              builder: (BuildContext c, double size, Widget? _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('حجم خط القراءة',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Row(
                      children: <Widget>[
                        IconButton(
                          tooltip: 'تصغير',
                          onPressed: () => AppSettings.instance.setQuranFontSize(size - 2),
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        Expanded(
                          child: Slider(
                            min: 20,
                            max: 44,
                            divisions: 24,
                            value: size,
                            onChanged: (double v) => AppSettings.instance.setQuranFontSize(v),
                          ),
                        ),
                        IconButton(
                          tooltip: 'تكبير',
                          onPressed: () => AppSettings.instance.setQuranFontSize(size + 2),
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                    Text('الحجم: ${ArabicFormat.digits(size.round())}',
                        style: TextStyle(color: AppTheme.muted(context))),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showInfo() {
    final Surah s = widget.surah;
    final List<MapEntry<String, String>> rows = <MapEntry<String, String>>[
      MapEntry<String, String>('اسم السورة', s.nameAr),
      if (s.nameTr.isNotEmpty) MapEntry<String, String>('الاسم بالحروف اللاتينية', s.nameTr),
      if (s.nameEn.isNotEmpty) MapEntry<String, String>('المعنى (الإنجليزية)', s.nameEn),
      if (s.typeAr.isNotEmpty) MapEntry<String, String>('النوع', s.typeAr),
      MapEntry<String, String>('رقم السورة', ArabicFormat.digits(s.id)),
      MapEntry<String, String>('عدد الآيات', ArabicFormat.digits(s.ayahCount)),
      if (s.order > 0) MapEntry<String, String>('ترتيب النزول', ArabicFormat.digits(s.order)),
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext c) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('معلومات السورة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                for (final MapEntry<String, String> r in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                            child: Text(r.key, style: TextStyle(color: AppTheme.muted(context)))),
                        Text(r.value, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Text('المصدر: Tanzil.net (رخصة CC BY 3.0)',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted(context))),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('سورة ${widget.surah.nameAr}'),
        actions: <Widget>[
          IconButton(
            tooltip: 'حجم الخط',
            onPressed: _showFontSheet,
            icon: const Icon(Icons.text_fields_rounded),
          ),
          IconButton(
            tooltip: 'معلومات السورة',
            onPressed: _showInfo,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    final List<Ayah>? ayahs = _ayahs;
    if (ayahs == null) return const Center(child: CircularProgressIndicator());

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification n) {
        if (n is ScrollEndNotification) _scheduleSave();
        return false;
      },
      child: SingleChildScrollView(
        key: _viewportKey,
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: ValueListenableBuilder<double>(
          valueListenable: AppSettings.instance.quranFontSize,
          builder: (BuildContext context, double size, Widget? _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _header(context),
                if (_bismillahHeader != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _bismillahHeader!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: size, height: 2.0),
                    ),
                  ),
                for (final Ayah a in ayahs) _tile(context, a, size),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final Surah s = widget.surah;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF0C5530), AppColors.forest],
        ),
      ),
      child: Column(
        children: <Widget>[
          Text(
            s.nameAr,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.goldSoft),
          ),
          const SizedBox(height: 4),
          Text(
            '${s.typeAr.isEmpty ? '' : '${s.typeAr} · '}${ArabicFormat.digits(s.ayahCount)} آية',
            style: TextStyle(fontSize: 13.5, color: Colors.white.withAlpha(200)),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, Ayah a, double size) {
    final bool fav = _favs.contains(a.ayah);
    final bool hl = _highlight == a.ayah;
    final Color accent = AppTheme.accent(context);
    return Container(
      key: _keyFor(a.ayah),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: hl ? AppColors.gold.withAlpha(60) : (fav ? AppColors.gold.withAlpha(24) : null),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onAyahTap(a),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(text: a.text),
                      TextSpan(
                        text: ' ﴿${ArabicFormat.digits(a.ayah)}﴾',
                        style: TextStyle(color: accent, fontSize: size * 0.8),
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: size, height: 2.0),
                  textAlign: TextAlign.justify,
                ),
              ),
              if (fav)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6, top: 6),
                  child: Icon(Icons.bookmark_rounded, size: 20, color: accent),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
