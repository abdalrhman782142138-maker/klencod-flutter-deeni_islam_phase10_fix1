import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/hadith/hadith_models.dart';
import '../../core/hadith/hadith_repository.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/user_data/user_data_store.dart';
import '../../core/utils/arabic_format.dart';
import '../../core/utils/share_service.dart';

/// قارئ كتاب من كتب الحديث: يحمّل الأحاديث على دفعات (لا يُحمَّل الكتاب كله).
/// يبدأ من [startOrd] إن وُجد (نتيجة بحث/مفضلة/متابعة القراءة)، وإلا من أول الكتاب.
class HadithReaderPage extends StatefulWidget {
  const HadithReaderPage({
    Key? key,
    required this.repo,
    required this.book,
    this.startOrd,
    this.highlightNumber,
  }) : super(key: key);

  final HadithRepository repo;
  final HadithBook book;
  final int? startOrd;
  final String? highlightNumber;

  @override
  State<HadithReaderPage> createState() => _HadithReaderPageState();
}

class _HadithReaderPageState extends State<HadithReaderPage> {
  static const int _chunk = 40;

  final ScrollController _scroll = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  final Map<String, GlobalKey> _keys = <String, GlobalKey>{};

  List<Hadith> _items = <Hadith>[];
  Set<String> _favs = <String>{};
  bool _hasPrev = false;
  bool _hasNext = false;
  bool _loadingMore = false;
  bool _ready = false;
  String? _error;
  String? _currentNumber;
  String? _highlight;
  Timer? _saveTimer;
  Timer? _highlightTimer;

  HadithRepository get _repo => widget.repo;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _highlightTimer?.cancel();
    _computeCurrent();
    final String? n = _currentNumber;
    if (n != null) UserDataStore.instance.setLastPosition(_repo.libraryId, n);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final List<Hadith> items =
          await _repo.nextChunk(widget.book.id, widget.startOrd ?? 0, _chunk);
      if (items.isEmpty) {
        throw HadithUnavailable('لا توجد أحاديث في هذا الكتاب.');
      }
      final bool prev = await _repo.hasBefore(widget.book.id, items.first.ord);
      final List<String> favRefs = await UserDataStore.instance.favorites(_repo.libraryId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _hasPrev = prev;
        _hasNext = items.length == _chunk;
        _favs = favRefs.toSet();
        _ready = true;
        _currentNumber = items.first.number;
      });
      UserDataStore.instance.setLastPosition(_repo.libraryId, items.first.number);
      if (widget.highlightNumber != null) _flash(widget.highlightNumber!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is HadithUnavailable ? e.message : 'تعذّر فتح الكتاب.';
      });
    }
  }

  Future<void> _loadNext() async {
    if (_loadingMore || !_hasNext || _items.isEmpty) return;
    _loadingMore = true;
    try {
      final List<Hadith> more =
          await _repo.nextChunk(widget.book.id, _items.last.ord + 1, _chunk);
      if (!mounted) return;
      setState(() {
        _items = <Hadith>[..._items, ...more];
        _hasNext = more.length == _chunk;
      });
    } catch (_) {
      if (mounted) setState(() => _hasNext = false);
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _loadPrev() async {
    if (_loadingMore || !_hasPrev || _items.isEmpty) return;
    _loadingMore = true;
    try {
      final List<Hadith> before =
          await _repo.prevChunk(widget.book.id, _items.first.ord, _chunk);
      final bool prev = before.isEmpty
          ? false
          : await _repo.hasBefore(widget.book.id, before.first.ord);
      if (!mounted) return;
      setState(() {
        _items = <Hadith>[...before, ..._items];
        _hasPrev = prev;
      });
    } catch (_) {
      if (mounted) setState(() => _hasPrev = false);
    } finally {
      _loadingMore = false;
    }
  }

  GlobalKey _keyFor(String number) => _keys.putIfAbsent(number, () => GlobalKey());

  void _flash(String number) {
    setState(() => _highlight = number);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _highlight = null);
    });
  }

  /// أول حديث ما زال جزء منه ظاهراً أسفل أعلى منطقة القراءة.
  void _computeCurrent() {
    final RenderObject? vp = _viewportKey.currentContext?.findRenderObject();
    if (vp is! RenderBox || !vp.attached) return;
    final double vpTop = vp.localToGlobal(Offset.zero).dy;
    String? best;
    double bestTop = double.infinity;
    for (final MapEntry<String, GlobalKey> e in _keys.entries) {
      final RenderObject? ro = e.value.currentContext?.findRenderObject();
      if (ro is! RenderBox || !ro.attached) continue;
      final double top = ro.localToGlobal(Offset.zero).dy;
      if (top + ro.size.height > vpTop + 12 && top < bestTop) {
        bestTop = top;
        best = e.key;
      }
    }
    if (best != null) _currentNumber = best;
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () {
      _computeCurrent();
      final String? n = _currentNumber;
      if (n != null) UserDataStore.instance.setLastPosition(_repo.libraryId, n);
    });
  }

  String _citation(Hadith h) {
    return '${h.text}\n[${_repo.title} · ${widget.book.nameAr} · '
        'حديث رقم ${ArabicFormat.digits(h.number)} (ترقيم المصدر)]';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  Future<void> _onTap(Hadith h) async {
    final bool fav = _favs.contains(h.number);
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
                    'حديث رقم ${ArabicFormat.digits(h.number)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(fav ? Icons.bookmark_remove_rounded : Icons.bookmark_add_rounded),
                title: Text(fav ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة'),
                onTap: () async {
                  Navigator.of(c).pop();
                  final bool now =
                      await UserDataStore.instance.toggleFavorite(_repo.libraryId, h.number);
                  if (!mounted) return;
                  setState(() {
                    if (now) {
                      _favs.add(h.number);
                    } else {
                      _favs.remove(h.number);
                    }
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('نسخ الحديث'),
                onTap: () async {
                  Navigator.of(c).pop();
                  await Clipboard.setData(ClipboardData(text: _citation(h)));
                  _toast('تم نسخ الحديث');
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('مشاركة الحديث'),
                onTap: () async {
                  Navigator.of(c).pop();
                  final bool shared = await ShareService.shareText(_citation(h));
                  if (!shared) _toast('تعذّرت المشاركة؛ نُسخ النص إلى الحافظة');
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_rounded),
                title: const Text('حفظ كآخر موضع قراءة'),
                onTap: () {
                  Navigator.of(c).pop();
                  _currentNumber = h.number;
                  UserDataStore.instance.setLastPosition(_repo.libraryId, h.number);
                  _toast('تم حفظ الموضع');
                },
              ),
            ],
          ),
        );
      },
    );
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
              valueListenable: AppSettings.instance.hadithFontSize,
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
                          onPressed: () => AppSettings.instance.setHadithFontSize(size - 2),
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        Expanded(
                          child: Slider(
                            min: 16,
                            max: 40,
                            divisions: 24,
                            value: size,
                            onChanged: (double v) => AppSettings.instance.setHadithFontSize(v),
                          ),
                        ),
                        IconButton(
                          tooltip: 'تكبير',
                          onPressed: () => AppSettings.instance.setHadithFontSize(size + 2),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.nameAr, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          IconButton(
            tooltip: 'حجم الخط',
            onPressed: _showFontSheet,
            icon: const Icon(Icons.text_fields_rounded),
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
    if (!_ready) return const Center(child: CircularProgressIndicator());

    final int lead = _hasPrev ? 1 : 0;
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification n) {
        if (n is ScrollEndNotification) _scheduleSave();
        return false;
      },
      child: ValueListenableBuilder<double>(
        valueListenable: AppSettings.instance.hadithFontSize,
        builder: (BuildContext context, double size, Widget? _) {
          return ListView.builder(
            key: _viewportKey,
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            itemCount: lead + _items.length + 1,
            itemBuilder: (BuildContext context, int i) {
              if (_hasPrev && i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: _loadPrev,
                    child: const Text('عرض الأحاديث السابقة'),
                  ),
                );
              }
              final int idx = i - lead;
              if (idx == _items.length) {
                return _footer(context);
              }
              return _tile(context, _items[idx], size);
            },
          );
        },
      ),
    );
  }

  Widget _footer(BuildContext context) {
    if (_hasNext) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadNext());
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text('نهاية الكتاب', style: TextStyle(color: AppTheme.muted(context))),
      ),
    );
  }

  Widget _tile(BuildContext context, Hadith h, double size) {
    final bool fav = _favs.contains(h.number);
    final bool hl = _highlight == h.number;
    final Color accent = AppTheme.accent(context);
    return Container(
      key: _keyFor(h.number),
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: hl
            ? AppColors.gold.withAlpha(60)
            : (fav ? AppColors.gold.withAlpha(24) : AppTheme.surface(context)),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _onTap(h),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    'حديث رقم ${ArabicFormat.digits(h.number)}',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: accent),
                  ),
                  const Spacer(),
                  if (fav) Icon(Icons.bookmark_rounded, size: 20, color: accent),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                h.text,
                textAlign: TextAlign.justify,
                style: TextStyle(fontSize: size, height: 1.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
