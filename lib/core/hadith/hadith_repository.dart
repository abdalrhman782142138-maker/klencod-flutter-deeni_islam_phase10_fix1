import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../content/library_manager.dart';
import '../utils/arabic_normalizer.dart';
import 'hadith_models.dart';

class HadithUnavailable implements Exception {
  const HadithUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

/// قراءة كتاب حديث (البخاري أو مسلم) من قاعدة المكتبة المنزَّلة فقط. لا شبكة هنا.
/// لا يُحمَّل الكتاب كله في الذاكرة: تُقرأ الأحاديث على دفعات.
class HadithRepository {
  HadithRepository._(this.libraryId, this.title);

  static final HadithRepository bukhari = HadithRepository._('bukhari', 'صحيح البخاري');
  static final HadithRepository muslim = HadithRepository._('muslim', 'صحيح مسلم');

  static HadithRepository of(String libraryId) => libraryId == 'bukhari' ? bukhari : muslim;

  final String libraryId;
  final String title;

  // جمل SQL ثابتة (يجرّبها tools/content/tests/test_dart_contract.py على قاعدة فعلية).
  static const String _booksSql = 'SELECT id, name_ar, hadith_count FROM books ORDER BY id';
  static const String _cols = 'SELECT id, ord, number, book_id, text FROM hadiths WHERE ';
  static const String _nextSql =
      '${_cols}book_id = ? AND ord >= ? ORDER BY ord LIMIT ?';
  static const String _prevSql =
      '${_cols}book_id = ? AND ord < ? ORDER BY ord DESC LIMIT ?';
  static const String _byNumberSql = '${_cols}number = ?';
  static const String _beforeSql = 'SELECT 1 FROM hadiths WHERE book_id = ? AND ord < ? LIMIT 1';
  static const String _metaSql = 'SELECT key, value FROM meta';
  static const String _likeClause = "search LIKE ? ESCAPE '\\'";

  Database? _db;
  String? _path;
  List<HadithBook>? _books;
  Map<String, String>? _meta;

  Future<Database> _open() async {
    final File? f = LibraryManager.instance.readyDbFile(libraryId);
    if (f == null) {
      throw HadithUnavailable('مكتبة $title غير جاهزة. نزّلها أولاً.');
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
    _books = null;
    _meta = null;
    await db?.close();
  }

  Future<List<HadithBook>> books() async {
    if (_books != null) return _books!;
    final Database db = await _open();
    final List<Map<String, Object?>> rows = await db.rawQuery(_booksSql);
    _books = <HadithBook>[
      for (final Map<String, Object?> r in rows)
        HadithBook(id: r['id'] as int, nameAr: '${r['name_ar']}', count: r['hadith_count'] as int),
    ];
    return _books!;
  }

  Future<HadithBook?> book(int id) async {
    for (final HadithBook b in await books()) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// بيانات المصدر المخزنة في القاعدة (المصدر، الترخيص، نظام الترقيم...).
  Future<Map<String, String>> meta() async {
    if (_meta != null) return _meta!;
    final Database db = await _open();
    final List<Map<String, Object?>> rows = await db.rawQuery(_metaSql);
    _meta = <String, String>{
      for (final Map<String, Object?> r in rows) '${r['key']}': '${r['value']}',
    };
    return _meta!;
  }

  Hadith _row(Map<String, Object?> r) {
    return Hadith(
      id: r['id'] as int,
      ord: r['ord'] as int,
      number: '${r['number']}',
      bookId: r['book_id'] as int,
      text: '${r['text']}',
    );
  }

  /// أحاديث الكتاب بدءاً من الترتيب [fromOrd] (شامل).
  Future<List<Hadith>> nextChunk(int bookId, int fromOrd, int limit) async {
    final Database db = await _open();
    final List<Map<String, Object?>> rows =
        await db.rawQuery(_nextSql, <Object?>[bookId, fromOrd, limit]);
    return rows.map(_row).toList();
  }

  /// الأحاديث التي تسبق الترتيب [beforeOrd] مرتبةً تصاعدياً.
  Future<List<Hadith>> prevChunk(int bookId, int beforeOrd, int limit) async {
    final Database db = await _open();
    final List<Map<String, Object?>> rows =
        await db.rawQuery(_prevSql, <Object?>[bookId, beforeOrd, limit]);
    return rows.map(_row).toList().reversed.toList();
  }

  Future<bool> hasBefore(int bookId, int ord) async {
    final Database db = await _open();
    return (await db.rawQuery(_beforeSql, <Object?>[bookId, ord])).isNotEmpty;
  }

  Future<Hadith?> byNumber(String number) async {
    final Database db = await _open();
    final List<Map<String, Object?>> rows = await db.rawQuery(_byNumberSql, <Object?>[number]);
    return rows.isEmpty ? null : _row(rows.first);
  }

  /// بحث محلي على عمود search المطبَّع (كل الكلمات AND). العنصر الزائد = وجود المزيد.
  Future<List<Hadith>> search(String query, {int limit = 100}) async {
    final List<String> terms =
        normalizeAr(query).split(' ').where((String t) => t.isNotEmpty).toList();
    if (terms.isEmpty) return <Hadith>[];
    final Database db = await _open();
    final String where = List<String>.filled(terms.length, _likeClause).join(' AND ');
    final List<Object?> args = <Object?>[
      for (final String t in terms) '%${_escapeLike(t)}%',
      limit + 1,
    ];
    final List<Map<String, Object?>> rows =
        await db.rawQuery('$_cols$where ORDER BY ord LIMIT ?', args);
    return rows.map(_row).toList();
  }

  static String _escapeLike(String s) {
    return s.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
  }
}
