import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/quran/quran_models.dart';
import '../../core/quran/quran_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/user_data/user_data_store.dart';
import '../../core/utils/arabic_format.dart';
import '../library/welcome_download_page.dart';
import 'quran_reader_page.dart';

/// صفحة القرآن الكريم: السور، البحث، المفضلة، وبطاقة «تابع القراءة».
class QuranHomePage extends StatefulWidget {
  const QuranHomePage({Key? key}) : super(key: key);

  @override
  State<QuranHomePage> createState() => _QuranHomePageState();
}

class _QuranHomePageState extends State<QuranHomePage> {
  final QuranRepository _repo = QuranRepository.instance;
  final ValueNotifier<int> _refresh = ValueNotifier<int>(0);
  late Future<List<Surah>> _surahs;

  @override
  void initState() {
    super.initState();
    _surahs = _repo.surahs();
  }

  @override
  void dispose() {
    _refresh.dispose();
    super.dispose();
  }

  Future<void> _openReader(Surah s, {int? ayah}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext c) => QuranReaderPage(surah: s, targetAyah: ayah),
      ),
    );
    _refresh.value++;
  }

  Future<void> _openRef(String ref) async {
    final List<String> p = ref.split(':');
    if (p.length != 2) return;
    final int? sId = int.tryParse(p[0]);
    final int? aNo = int.tryParse(p[1]);
    if (sId == null || aNo == null) return;
    final Surah? s = await _repo.surah(sId);
    if (s != null && mounted) await _openReader(s, ayah: aNo);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('القرآن الكريم'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'السور'),
              Tab(text: 'البحث'),
              Tab(text: 'المفضلة'),
            ],
          ),
        ),
        body: FutureBuilder<List<Surah>>(
          future: _surahs,
          builder: (BuildContext context, AsyncSnapshot<List<Surah>> snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || snap.data == null) {
              return _unavailable(context, snap.error);
            }
            final List<Surah> surahs = snap.data!;
            return TabBarView(
              children: <Widget>[
                _SurahTab(
                  surahs: surahs,
                  refresh: _refresh,
                  onOpen: (Surah s) => _openReader(s),
                  onContinue: _openRef,
                ),
                _SearchTab(onOpenRef: _openRef),
                _FavoritesTab(refresh: _refresh, onOpenRef: _openRef),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _unavailable(BuildContext context, Object? error) {
    final String msg =
        error is QuranUnavailable ? error.message : 'تعذّر فتح مكتبة القرآن الكريم.';
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

// ---------------------------------------------------------------- تبويب السور

class _SurahTab extends StatelessWidget {
  const _SurahTab({
    Key? key,
    required this.surahs,
    required this.refresh,
    required this.onOpen,
    required this.onContinue,
  }) : super(key: key);

  final List<Surah> surahs;
  final ValueNotifier<int> refresh;
  final ValueChanged<Surah> onOpen;
  final ValueChanged<String> onContinue;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: surahs.length + 1,
      itemBuilder: (BuildContext context, int i) {
        if (i == 0) return _ContinueCard(refresh: refresh, surahs: surahs, onContinue: onContinue);
        final Surah s = surahs[i - 1];
        return _SurahRow(surah: s, onTap: () => onOpen(s));
      },
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    Key? key,
    required this.refresh,
    required this.surahs,
    required this.onContinue,
  }) : super(key: key);

  final ValueNotifier<int> refresh;
  final List<Surah> surahs;
  final ValueChanged<String> onContinue;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: refresh,
      builder: (BuildContext context, int _, Widget? __) {
        return FutureBuilder<String?>(
          future: UserDataStore.instance.lastPosition('quran'),
          builder: (BuildContext context, AsyncSnapshot<String?> snap) {
            final String? ref = snap.data;
            if (ref == null) return const SizedBox.shrink();
            final List<String> p = ref.split(':');
            final int? sId = p.length == 2 ? int.tryParse(p[0]) : null;
            final int? aNo = p.length == 2 ? int.tryParse(p[1]) : null;
            if (sId == null || aNo == null || sId < 1 || sId > surahs.length) {
              return const SizedBox.shrink();
            }
            final Surah s = surahs[sId - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Material(
                color: AppColors.gold.withAlpha(30),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onContinue(ref),
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
                              Text(
                                'سورة ${s.nameAr} · آية ${ArabicFormat.digits(aNo)}',
                                style: TextStyle(fontSize: 13.5, color: AppTheme.muted(context)),
                              ),
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
}

class _SurahRow extends StatelessWidget {
  const _SurahRow({Key? key, required this.surah, required this.onTap}) : super(key: key);

  final Surah surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color muted = AppTheme.muted(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
                ArabicFormat.digits(surah.id),
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.accent(context)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(surah.nameAr,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${surah.typeAr.isEmpty ? '' : '${surah.typeAr} · '}${ArabicFormat.digits(surah.ayahCount)} آية',
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                ],
              ),
            ),
            if (surah.nameEn.isNotEmpty)
              Text(surah.nameEn,
                  textDirection: TextDirection.ltr, style: TextStyle(fontSize: 12.5, color: muted)),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- تبويب البحث

class _SearchTab extends StatefulWidget {
  const _SearchTab({Key? key, required this.onOpenRef}) : super(key: key);

  final ValueChanged<String> onOpenRef;

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  static const int _limit = 100;
  final TextEditingController _ctl = TextEditingController();
  Timer? _debounce;
  List<Ayah> _results = <Ayah>[];
  bool _searched = false;
  bool _busy = false;
  bool _more = false;
  Map<int, Surah> _byId = <int, Surah>{};

  @override
  void initState() {
    super.initState();
    QuranRepository.instance.surahs().then((List<Surah> l) {
      if (mounted) setState(() => _byId = <int, Surah>{for (final Surah s in l) s.id: s});
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(v));
  }

  Future<void> _run(String raw) async {
    final String q = raw.trim();
    if (q.isEmpty) {
      setState(() {
        _results = <Ayah>[];
        _searched = false;
        _more = false;
      });
      return;
    }
    // اختصار: "2:255" أو "2 255" ينتقل مباشرة إلى الآية.
    final RegExpMatch? m = RegExp(r'^(\d{1,3})\s*[:\s]\s*(\d{1,3})$')
        .firstMatch(ArabicFormat.toWestern(q));
    if (m != null) {
      widget.onOpenRef('${m.group(1)}:${m.group(2)}');
      return;
    }
    setState(() => _busy = true);
    try {
      final List<Ayah> r = await QuranRepository.instance.search(q, limit: _limit);
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
        _results = <Ayah>[];
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
              hintText: 'ابحث في القرآن (دون تشكيل) أو اكتب رقم الآية مثل ٢:٢٥٥',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: !_searched
              ? Center(
                  child: Text('البحث يعمل على جهازك دون إنترنت.',
                      style: TextStyle(color: muted)))
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
                        final Ayah a = _results[i];
                        return _AyahResultTile(
                          title:
                              'سورة ${_byId[a.surah]?.nameAr ?? ArabicFormat.digits(a.surah)} · آية ${ArabicFormat.digits(a.ayah)}',
                          text: a.text,
                          onTap: () => widget.onOpenRef(a.ref),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _AyahResultTile extends StatelessWidget {
  const _AyahResultTile({
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
                      style: const TextStyle(fontSize: 19, height: 1.9)),
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

class _FavoritesTab extends StatefulWidget {
  const _FavoritesTab({Key? key, required this.refresh, required this.onOpenRef})
      : super(key: key);

  final ValueNotifier<int> refresh;
  final ValueChanged<String> onOpenRef;

  @override
  State<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavItem {
  const _FavItem(this.ref, this.title, this.text);

  final String ref;
  final String title;
  final String text;
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

  Future<void> _load() async {
    final List<String> refs = await UserDataStore.instance.favorites('quran');
    final List<_FavItem> items = <_FavItem>[];
    for (final String ref in refs) {
      final List<String> p = ref.split(':');
      final int? s = p.length == 2 ? int.tryParse(p[0]) : null;
      final int? a = p.length == 2 ? int.tryParse(p[1]) : null;
      if (s == null || a == null) continue;
      try {
        final Ayah? ayah = await QuranRepository.instance.ayah(s, a);
        final Surah? sur = await QuranRepository.instance.surah(s);
        if (ayah != null && sur != null) {
          items.add(_FavItem(
              ref, 'سورة ${sur.nameAr} · آية ${ArabicFormat.digits(a)}', ayah.text));
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _items = items);
  }

  Future<void> _remove(String ref) async {
    await UserDataStore.instance.toggleFavorite('quran', ref);
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
            'لا توجد آيات في المفضلة بعد. اضغط على أي آية أثناء القراءة ثم «إضافة إلى المفضلة».',
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
        return _AyahResultTile(
          title: it.title,
          text: it.text,
          onTap: () => widget.onOpenRef(it.ref),
          trailing: IconButton(
            tooltip: 'إزالة من المفضلة',
            onPressed: () => _remove(it.ref),
            icon: const Icon(Icons.bookmark_remove_rounded),
          ),
        );
      },
    );
  }
}
