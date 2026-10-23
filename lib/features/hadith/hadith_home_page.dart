import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/hadith/hadith_models.dart';
import '../../core/hadith/hadith_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/user_data/user_data_store.dart';
import '../../core/utils/arabic_format.dart';
import '../library/welcome_download_page.dart';
import 'hadith_reader_page.dart';

/// صفحة كتاب حديث (البخاري أو مسلم): الكتب، البحث، المفضلة، وبطاقة «تابع القراءة».
class HadithHomePage extends StatefulWidget {
  const HadithHomePage({Key? key, required this.libraryId}) : super(key: key);

  final String libraryId;

  @override
  State<HadithHomePage> createState() => _HadithHomePageState();
}

class _HadithHomePageState extends State<HadithHomePage> {
  final ValueNotifier<int> _refresh = ValueNotifier<int>(0);
  late final HadithRepository _repo;
  late Future<List<HadithBook>> _books;

  @override
  void initState() {
    super.initState();
    _repo = HadithRepository.of(widget.libraryId);
    _books = _repo.books();
  }

  @override
  void dispose() {
    _refresh.dispose();
    super.dispose();
  }

  Future<void> _openBook(HadithBook b, {int? ord, String? number}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext c) => HadithReaderPage(
          repo: _repo,
          book: b,
          startOrd: ord,
          highlightNumber: number,
        ),
      ),
    );
    _refresh.value++;
  }

  /// يفتح الكتاب عند حديث برقمه (نظام ترقيم المصدر). يعيد false إن لم يوجد.
  Future<bool> _openNumber(String number) async {
    final Hadith? h = await _repo.byNumber(number);
    if (h == null) return false;
    final HadithBook? b = await _repo.book(h.bookId);
    if (b == null || !mounted) return false;
    await _openBook(b, ord: h.ord, number: h.number);
    return true;
  }

  void _showAbout() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext c) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: FutureBuilder<Map<String, String>>(
              future: _repo.meta(),
              builder: (BuildContext c, AsyncSnapshot<Map<String, String>> snap) {
                final Map<String, String>? m = snap.data;
                final Color muted = AppTheme.muted(context);
                if (m == null) {
                  return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
                }
                final List<MapEntry<String, String>> rows = <MapEntry<String, String>>[
                  MapEntry<String, String>('المصدر', m['source'] ?? '—'),
                  MapEntry<String, String>('الترخيص', m['license'] ?? '—'),
                  MapEntry<String, String>('نظام الترقيم', m['numbering'] ?? '—'),
                  MapEntry<String, String>(
                      'عدد الأحاديث', ArabicFormat.digits(m['hadith_count'] ?? '—')),
                  MapEntry<String, String>(
                      'عدد الكتب', ArabicFormat.digits(m['book_count'] ?? '—')),
                ];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('عن ${_repo.title}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    for (final MapEntry<String, String> r in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SizedBox(width: 110, child: Text(r.key, style: TextStyle(color: muted))),
                            Expanded(child: Text(r.value, style: const TextStyle(fontWeight: FontWeight.w700))),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      'الأرقام وفق نظام ترقيم المصدر المذكور أعلاه. لا يدّعي التطبيق مطابقة طبعة مطبوعة محددة.',
                      style: TextStyle(fontSize: 12.5, height: 1.6, color: muted),
                    ),
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_repo.title),
          actions: <Widget>[
            IconButton(
              tooltip: 'عن المكتبة',
              onPressed: _showAbout,
              icon: const Icon(Icons.info_outline_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'الكتب'),
              Tab(text: 'البحث'),
              Tab(text: 'المفضلة'),
            ],
          ),
        ),
        body: FutureBuilder<List<HadithBook>>(
          future: _books,
          builder: (BuildContext context, AsyncSnapshot<List<HadithBook>> snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || snap.data == null) {
              return _unavailable(context, snap.error);
            }
            final List<HadithBook> books = snap.data!;
            return TabBarView(
              children: <Widget>[
                _BooksTab(
                  repo: _repo,
                  books: books,
                  refresh: _refresh,
                  onOpen: (HadithBook b) => _openBook(b),
                  onContinue: _openNumber,
                ),
                _SearchTab(repo: _repo, books: books, onOpenNumber: _openNumber),
                _FavoritesTab(
                  repo: _repo,
                  books: books,
                  refresh: _refresh,
                  onOpenNumber: _openNumber,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _unavailable(BuildContext context, Object? error) {
    final String msg =
        error is HadithUnavailable ? error.message : 'تعذّر فتح مكتبة ${_repo.title}.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.7)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (BuildContext c) => const WelcomeDownloadPage()),
                );
              },
              child: const Text('فتح شاشة التنزيل'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- تبويب الكتب

class _BooksTab extends StatelessWidget {
  const _BooksTab({
    Key? key,
    required this.repo,
    required this.books,
    required this.refresh,
    required this.onOpen,
    required this.onContinue,
  }) : super(key: key);

  final HadithRepository repo;
  final List<HadithBook> books;
  final ValueNotifier<int> refresh;
  final ValueChanged<HadithBook> onOpen;
  final Future<bool> Function(String number) onContinue;

  @override
  Widget build(BuildContext context) {
    final Color muted = AppTheme.muted(context);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: books.length + 1,
      itemBuilder: (BuildContext context, int i) {
        if (i == 0) {
          return ValueListenableBuilder<int>(
            valueListenable: refresh,
            builder: (BuildContext context, int _, Widget? __) {
              return FutureBuilder<String?>(
                future: UserDataStore.instance.lastPosition(repo.libraryId),
                builder: (BuildContext context, AsyncSnapshot<String?> snap) {
                  final String? number = snap.data;
                  if (number == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Material(
                      color: AppColors.gold.withAlpha(30),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => onContinue(number),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.gold.withAlpha(100)),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.auto_stories_rounded, color: AppTheme.accent(context)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const Text('تابع القراءة',
                                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 2),
                                    Text('حديث رقم ${ArabicFormat.digits(number)}',
                                        style: TextStyle(fontSize: 13.5, color: muted)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_left_rounded),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        }
        final HadithBook b = books[i - 1];
        return InkWell(
          onTap: () => onOpen(b),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border(context))),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withAlpha(36),
                  ),
                  child: Text(
                    ArabicFormat.digits(i),
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.accent(context)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(b.nameAr,
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${ArabicFormat.digits(b.count)} حديثاً',
                          style: TextStyle(fontSize: 13, color: muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --------------------------------------------------------------- تبويب البحث

class _SearchTab extends StatefulWidget {
  const _SearchTab({
    Key? key,
    required this.repo,
    required this.books,
    required this.onOpenNumber,
  }) : super(key: key);

  final HadithRepository repo;
  final List<HadithBook> books;
  final Future<bool> Function(String number) onOpenNumber;

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  static const int _limit = 100;
  final TextEditingController _ctl = TextEditingController();
  Timer? _debounce;
  List<Hadith> _results = <Hadith>[];
  bool _searched = false;
  bool _busy = false;
  bool _more = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  String _bookName(int id) {
    for (final HadithBook b in widget.books) {
      if (b.id == id) return b.nameAr;
    }
    return '';
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(v));
  }

  Future<void> _run(String raw) async {
    final String q = ArabicFormat.toWestern(raw.trim());
    if (q.isEmpty) {
      setState(() {
        _results = <Hadith>[];
        _searched = false;
        _more = false;
      });
      return;
    }
    // رقم فقط: انتقال مباشر إلى الحديث بحسب ترقيم المصدر.
    if (RegExp(r'^\d{1,6}$').hasMatch(q)) {
      final bool ok = await widget.onOpenNumber(q);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد حديث بهذا الرقم في ترقيم المصدر')),
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final List<Hadith> r = await widget.repo.search(q, limit: _limit);
      if (!mounted) return;
      setState(() {
        _more = r.length > _limit;
        _results = _more ? r.sublist(0, _limit) : r;
        _searched = true;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = <Hadith>[];
        _searched = true;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color muted = AppTheme.muted(context);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _ctl,
            onChanged: _onChanged,
            onSubmitted: _run,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'ابحث في نص الحديث (دون تشكيل) أو اكتب رقم الحديث',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: !_searched
              ? Center(child: Text('البحث يعمل على جهازك دون إنترنت.', style: TextStyle(color: muted)))
              : _results.isEmpty
                  ? Center(child: Text('لا توجد نتائج.', style: TextStyle(color: muted)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: _results.length + (_more ? 1 : 0),
                      itemBuilder: (BuildContext context, int i) {
                        if (i == _results.length) {
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'عُرض أول ${ArabicFormat.digits(_limit)} نتيجة. دقّق كلمات البحث لتضييقها.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: muted),
                            ),
                          );
                        }
                        final Hadith h = _results[i];
                        return _HadithResultTile(
                          title: '${_bookName(h.bookId)} · حديث رقم ${ArabicFormat.digits(h.number)}',
                          text: h.text,
                          onTap: () => widget.onOpenNumber(h.number),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _HadithResultTile extends StatelessWidget {
  const _HadithResultTile({
    Key? key,
    required this.title,
    required this.text,
    required this.onTap,
    this.trailing,
  }) : super(key: key);

  final String title;
  final String text;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border(context))),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accent(context))),
                  const SizedBox(height: 6),
                  Text(text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16.5, height: 1.8)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ تبويب المفضلة

class _FavItem {
  const _FavItem(this.number, this.title, this.text);

  final String number;
  final String title;
  final String text;
}

class _FavoritesTab extends StatefulWidget {
  const _FavoritesTab({
    Key? key,
    required this.repo,
    required this.books,
    required this.refresh,
    required this.onOpenNumber,
  }) : super(key: key);

  final HadithRepository repo;
  final List<HadithBook> books;
  final ValueNotifier<int> refresh;
  final Future<bool> Function(String number) onOpenNumber;

  @override
  State<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<_FavoritesTab> {
  List<_FavItem>? _items;

  @override
  void initState() {
    super.initState();
    widget.refresh.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.refresh.removeListener(_load);
    super.dispose();
  }

  String _bookName(int id) {
    for (final HadithBook b in widget.books) {
      if (b.id == id) return b.nameAr;
    }
    return '';
  }

  Future<void> _load() async {
    final List<String> refs = await UserDataStore.instance.favorites(widget.repo.libraryId);
    final List<_FavItem> items = <_FavItem>[];
    for (final String n in refs) {
      try {
        final Hadith? h = await widget.repo.byNumber(n);
        if (h != null) {
          items.add(_FavItem(
              n, '${_bookName(h.bookId)} · حديث رقم ${ArabicFormat.digits(n)}', h.text));
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _items = items);
  }

  Future<void> _remove(String number) async {
    await UserDataStore.instance.toggleFavorite(widget.repo.libraryId, number);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final List<_FavItem>? items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'لا توجد أحاديث في المفضلة بعد. اضغط على أي حديث أثناء القراءة ثم «إضافة إلى المفضلة».',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.7, color: AppTheme.muted(context)),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int i) {
        final _FavItem it = items[i];
        return _HadithResultTile(
          title: it.title,
          text: it.text,
          onTap: () => widget.onOpenNumber(it.number),
          trailing: IconButton(
            tooltip: 'إزالة من المفضلة',
            onPressed: () => _remove(it.number),
            icon: const Icon(Icons.bookmark_remove_rounded),
          ),
        );
      },
    );
  }
}
