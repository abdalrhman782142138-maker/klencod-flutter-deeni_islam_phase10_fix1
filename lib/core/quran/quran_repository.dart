import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../content/library_manager.dart';
import '../utils/arabic_normalizer.dart';
import 'quran_models.dart';

class QuranUnavailable implements Exception {
  const QuranUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

/// قراءة القرآن من قاعدة المكتبة المنزَّلة فقط. لا شبكة هنا إطلاقاً.
/// لا تُفتح القاعدة إلا إذا كانت المكتبة بحالة «جاهزة» بعد التحقق منها.
class QuranRepository {
  QuranRepository._();

  static final QuranRepository instance = QuranRepository._();

  // جمل SQL ثابتة (يجرّبها tools/content/tests/test_dart_contract.py على قاعدة فعلية).
  static const String _surahsSql =
      'SELECT id, name_ar, name_tr, name_en, type, revelation_order, ayah_count FROM surahs ORDER BY id';
  static const String _ayahsSql =
      'SELECT surah, ayah, text FROM ayahs WHERE surah = ? ORDER BY ayah';
  static const String _ayahSql =
      'SELECT surah, ayah, text FROM ayahs WHERE surah = ? AND ayah = ?';
  static const String _searchPrefix = 'SELECT surah, ayah, text FROM ayahs WHERE ';
  static const String _likeClause = "search LIKE ? ESCAPE '\\'";

  Database? _db;
  String? _path;
  List<Surah>? _surahs;

  Future<Database> _open() async {
    final File? f = LibraryManager.instance.readyDbFile('quran');
    if (f == null) {
      throw const QuranUnavailable('مكتبة القرآن الكريم غير جاهزة. نزّلها أولاً.');
    }
    if (_db != null && _path == f.path) return _db!;
    await close();
    _db = await openDatabase(f.path, readOnly: true, singleInstance: false);
    _path = f.path;
    return _db!;
  }

  Future<void> close() async {
    final Database? db = _db;
    _db = null;
    _path = null;
    _surahs = null;
    await db?.close();
  }

  Future<List<Surah>> surahs() async {
    if (_surahs != null) return _surahs!;
    final Database db = await _open();
    final List<Map<String, Object?>> rows = await db.rawQuery(_surahsSql);
    _surahs = <Surah>[
      for (final Map<String, Object?> r in rows)
        Surah(
          id: r['id'] as int,
          nameAr: '${r['name_ar']}',
          nameTr: '${r['name_tr'] ?? ''}',
          nameEn: '${r['name_en'] ?? ''}',
          type: '${r['type'] ?? ''}',
          order: (r['revelation_order'] as int?) ?? 0,
          ayahCount: r['ayah_count'] as int,
        ),
    ];
    return _surahs!;
  }

  Future<Surah?> surah(int id) async {
    for (final Surah s in await surahs()) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<List<Ayah>> ayahsOf(int surahId) async {
    final Database db = await _open();
    final List<Map<String, Object?>> rows = await db.rawQuery(_ayahsSql, <Object?>[surahId]);
    return <Ayah>[
      for (final Map<String, Object?> r in rows)
        Ayah(r['surah'] as int, r['ayah'] as int, '${r['text']}'),
    ];
  }

  Future<Ayah?> ayah(int surahId, int ayahNo) async {
    final Database db = await _open();
    final List<Map<String, Object?>> rows =
        await db.rawQuery(_ayahSql, <Object?>[surahId, ayahNo]);
    if (rows.isEmpty) return null;
    final Map<String, Object?> r = rows.first;
    return Ayah(r['surah'] as int, r['ayah'] as int, '${r['text']}');
  }

  /// نص البسملة كما في المصدر نفسه (الآية 1 من الفاتحة)، دون كتابته يدوياً.
  Future<String?> bismillahText() async => (await ayah(1, 1))?.text;

  /// بحث محلي على عمود search المطبَّع. كل كلمة يجب أن ترد (AND).
  /// يعيد حتى [limit] نتيجة، والعنصر الأخير الزائد يدل على وجود المزيد.
  Future<List<Ayah>> search(String query, {int limit = 100}) async {
    final List<String> terms = normalizeAr(query)
        .split(' ')
        .where((String t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return <Ayah>[];
    final Database db = await _open();
    final String where = List<String>.filled(terms.length, _likeClause).join(' AND ');
    final List<Object?> args = <Object?>[
      for (final String t in terms) '%${_escapeLike(t)}%',
      limit + 1,
    ];
    final List<Map<String, Object?>> rows =
        await db.rawQuery('$_searchPrefix$where ORDER BY surah, ayah LIMIT ?', args);
    return <Ayah>[
      for (final Map<String, Object?> r in rows)
        Ayah(r['surah'] as int, r['ayah'] as int, '${r['text']}'),
    ];
  }

  static String _escapeLike(String s) {
    return s.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
  }
}
