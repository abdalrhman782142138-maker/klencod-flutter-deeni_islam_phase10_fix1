import 'package:flutter/material.dart';

import '../../core/azkar/azkar_models.dart';
import '../../core/azkar/azkar_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/user_data/user_data_store.dart';
import '../../core/utils/arabic_format.dart';
import 'azkar_category_page.dart';

/// الأذكار والأدعية: التصنيفات والمفضلة. تعمل دون إنترنت لأنها مضمَّنة في التطبيق.
class AzkarHomePage extends StatefulWidget {
  const AzkarHomePage({Key? key}) : super(key: key);

  @override
  State<AzkarHomePage> createState() => _AzkarHomePageState();
}

class _AzkarHomePageState extends State<AzkarHomePage> {
  late Future<AzkarData> _data;
  final ValueNotifier<int> _refresh = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _data = AzkarRepository.instance.load();
  }

  @override
  void dispose() {
    _refresh.dispose();
    super.dispose();
  }

  Future<void> _open(AzkarCategory c, {String? focus}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext x) => AzkarCategoryPage(category: c, focusId: focus),
      ),
    );
    _refresh.value++;
  }

  void _about(AzkarData data) {
    final AzkarSource s = data.source;
    final Color muted = AppTheme.muted(context);
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
                const Text('عن الأذكار',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                _row('المصدر', s.name, muted),
                _row('الإصدار', s.version, muted),
                _row('الترخيص', s.license, muted),
                const SizedBox(height: 8),
                Text('الأذكار مضمَّنة في التطبيق وتعمل دون إنترنت.',
                    style: TextStyle(fontSize: 12.5, color: muted)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(String k, String v, Color muted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 90, child: Text(k, style: TextStyle(color: muted))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AzkarData>(
      future: _data,
      builder: (BuildContext context, AsyncSnapshot<AzkarData> snap) {
        final AzkarData? data = snap.data;
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('الأذكار والأدعية'),
              actions: <Widget>[
                if (data != null)
                  IconButton(
                    tooltip: 'عن الأذكار',
                    onPressed: () => _about(data),
                    icon: const Icon(Icons.info_outline_rounded),
                  ),
              ],
              bottom: data == null
                  ? null
                  : const TabBar(tabs: <Widget>[Tab(text: 'التصنيفات'), Tab(text: 'المفضلة')]),
            ),
            body: snap.connectionState != ConnectionState.done
                ? const Center(child: CircularProgressIndicator())
                : data == null
                    ? _unavailable(snap.error)
                    : TabBarView(
                        children: <Widget>[
                          _Categories(data: data, onOpen: _open),
                          _Favorites(data: data, refresh: _refresh, onOpen: _open),
                        ],
                      ),
          ),
        );
      },
    );
  }

  Widget _unavailable(Object? error) {
    final String msg =
        error is AzkarUnavailable ? error.message : 'تعذّر فتح الأذكار.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(msg,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.8)),
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({Key? key, required this.data, required this.onOpen}) : super(key: key);

  final AzkarData data;
  final void Function(AzkarCategory c, {String? focus}) onOpen;

  @override
  Widget build(BuildContext context) {
    final Color muted = AppTheme.muted(context);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: data.categories.length,
      itemBuilder: (BuildContext context, int i) {
        final AzkarCategory c = data.categories[i];
        return InkWell(
          onTap: () => onOpen(c),
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
                  child: Icon(Icons.wb_twilight_rounded, size: 20, color: AppTheme.accent(context)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(c.titleAr,
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${ArabicFormat.digits(c.items.length)} ذكراً',
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

class _FavEntry {
  const _FavEntry(this.category, this.dhikr);

  final AzkarCategory category;
  final Dhikr dhikr;
}

class _Favorites extends StatefulWidget {
  const _Favorites({Key? key, required this.data, required this.refresh, required this.onOpen})
      : super(key: key);

  final AzkarData data;
  final ValueNotifier<int> refresh;
  final void Function(AzkarCategory c, {String? focus}) onOpen;

  @override
  State<_Favorites> createState() => _FavoritesState();
}

class _FavoritesState extends State<_Favorites> {
  List<_FavEntry>? _items;

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
    final List<String> refs = await UserDataStore.instance.favorites(kAzkarKind);
    final List<_FavEntry> out = <_FavEntry>[];
    for (final String r in refs) {
      final int i = r.indexOf(':');
      if (i < 0) continue;
      final AzkarCategory? c = widget.data.category(r.substring(0, i));
      if (c == null) continue;
      for (final Dhikr d in c.items) {
        if (d.id == r.substring(i + 1)) out.add(_FavEntry(c, d));
      }
    }
    if (mounted) setState(() => _items = out);
  }

  @override
  Widget build(BuildContext context) {
    final List<_FavEntry>? items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'لا توجد أذكار في المفضلة بعد. اضغط على أي ذكر ثم «إضافة إلى المفضلة».',
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
        final _FavEntry e = items[i];
        return InkWell(
          onTap: () => widget.onOpen(e.category, focus: e.dhikr.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border(context))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(e.category.titleAr,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accent(context))),
                const SizedBox(height: 6),
                Text(e.dhikr.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, height: 1.8)),
              ],
            ),
          ),
        );
      },
    );
  }
}
