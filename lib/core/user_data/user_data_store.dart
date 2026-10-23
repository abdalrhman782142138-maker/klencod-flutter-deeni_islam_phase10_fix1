import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// بيانات المستخدم المحلية: المفضلة وآخر موضع للقراءة.
/// قاعدة مستقلة عن قواعد المكتبات، فلا تتأثر بإعادة تنزيلها أو إصلاحها.
class UserDataStore {
  UserDataStore._();

  static final UserDataStore instance = UserDataStore._();

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final Directory base = await getApplicationSupportDirectory();
    _db = await openDatabase(
      '${base.path}/user_data.db',
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute(
            'CREATE TABLE favorites(kind TEXT NOT NULL, ref TEXT NOT NULL, '
            'created_at INTEGER NOT NULL, PRIMARY KEY(kind, ref))');
        await db.execute(
            'CREATE TABLE last_position(library TEXT PRIMARY KEY, ref TEXT NOT NULL, '
            'updated_at INTEGER NOT NULL)');
      },
    );
    return _db!;
  }

  /// يعكس حالة المفضلة ويعيد الحالة الجديدة (true = مضافة). عند الفشل يعيد الحالة الحالية.
  Future<bool> toggleFavorite(String kind, String ref) async {
    try {
      final Database db = await _open();
      final List<Map<String, Object?>> rows = await db.rawQuery(
          'SELECT 1 FROM favorites WHERE kind = ? AND ref = ?', <Object?>[kind, ref]);
      if (rows.isEmpty) {
        await db.insert('favorites', <String, Object?>{
          'kind': kind,
          'ref': ref,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
        return true;
      }
      await db.delete('favorites', where: 'kind = ? AND ref = ?', whereArgs: <Object?>[kind, ref]);
      return false;
    } catch (_) {
      return isFavorite(kind, ref);
    }
  }

  Future<bool> isFavorite(String kind, String ref) async {
    try {
      final Database db = await _open();
      final List<Map<String, Object?>> rows = await db.rawQuery(
          'SELECT 1 FROM favorites WHERE kind = ? AND ref = ?', <Object?>[kind, ref]);
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// مراجع المفضلة لنوع معين (الأحدث أولاً)، مع تصفية اختيارية ببادئة مثل "2:".
  Future<List<String>> favorites(String kind, {String? prefix}) async {
    try {
      final Database db = await _open();
      final List<Map<String, Object?>> rows = prefix == null
          ? await db.rawQuery(
              'SELECT ref FROM favorites WHERE kind = ? ORDER BY created_at DESC',
              <Object?>[kind])
          : await db.rawQuery(
              'SELECT ref FROM favorites WHERE kind = ? AND ref LIKE ? ORDER BY created_at DESC',
              <Object?>[kind, '$prefix%']);
      return <String>[for (final Map<String, Object?> r in rows) '${r['ref']}'];
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> setLastPosition(String library, String ref) async {
    try {
      final Database db = await _open();
      await db.insert(
        'last_position',
        <String, Object?>{
          'library': library,
          'ref': ref,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<String?> lastPosition(String library) async {
    try {
      final Database db = await _open();
      final List<Map<String, Object?>> rows = await db.rawQuery(
          'SELECT ref FROM last_position WHERE library = ?', <Object?>[library]);
      return rows.isEmpty ? null : '${rows.first['ref']}';
    } catch (_) {
      return null;
    }
  }
}
