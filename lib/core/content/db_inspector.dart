import 'dart:io';

import 'package:sqflite/sqflite.dart';

import 'manifest.dart';

class InspectionResult {
  const InspectionResult(this.problems);

  final List<String> problems;

  bool get ok => problems.isEmpty;
}

/// يفحص قاعدة مكتبة قبل اعتمادها. يطابق منطق tools/content/verify_library.py.
abstract class DbInspector {
  Future<InspectionResult> inspect(File db, LibraryEntry entry);
}

class SqfliteDbInspector implements DbInspector {
  const SqfliteDbInspector();

  @override
  Future<InspectionResult> inspect(File file, LibraryEntry e) async {
    final List<String> problems = <String>[];
    Database? db;
    try {
      db = await openDatabase(file.path, readOnly: true, singleInstance: false);
      final List<Map<String, Object?>> ic = await db.rawQuery('PRAGMA integrity_check');
      if (ic.isEmpty || ic.first.values.first != 'ok') {
        return const InspectionResult(<String>['فشل فحص سلامة قاعدة البيانات']);
      }
      final List<Map<String, Object?>> rows = await db.rawQuery('SELECT key, value FROM meta');
      final Map<String, String> meta = <String, String>{
        for (final Map<String, Object?> r in rows) '${r['key']}': '${r['value']}',
      };
      if (meta['library'] != e.id) problems.add('القاعدة لا تخص هذه المكتبة');
      if (meta['schema_version'] != '${e.dbSchema}') problems.add('إصدار بنية القاعدة مختلف');
      for (final String k in <String>['source', 'license']) {
        if ((meta[k] ?? '').isEmpty) problems.add('بيانات المصدر ناقصة ($k)');
      }
      if (e.id == 'quran') {
        await _checkQuran(db, meta, e, problems);
      } else {
        await _checkHadith(db, meta, e, problems);
      }
    } catch (_) {
      return const InspectionResult(<String>['تعذّر فتح قاعدة المكتبة أو قراءتها']);
    } finally {
      await db?.close();
    }
    return InspectionResult(problems);
  }

  Future<int> _count(Database db, String sql) async {
    return Sqflite.firstIntValue(await db.rawQuery(sql)) ?? -1;
  }

  Future<void> _checkQuran(
      Database db, Map<String, String> meta, LibraryEntry e, List<String> problems) async {
    final int surahs = await _count(db, 'SELECT COUNT(*) FROM surahs');
    final int ayahs = await _count(db, 'SELECT COUNT(*) FROM ayahs');
    if (surahs != 114) problems.add('عدد السور $surahs بدل 114');
    if (ayahs != 6236) problems.add('عدد الآيات $ayahs بدل 6236');
    if ('$ayahs' != meta['ayah_count'] || ayahs != e.records) {
      problems.add('عدد الآيات لا يطابق القائمة');
    }
    if (await _count(db, "SELECT COUNT(*) FROM ayahs WHERE text = ''") != 0) {
      problems.add('توجد آيات فارغة');
    }
    final int bad = await _count(
        db,
        'SELECT COUNT(*) FROM (SELECT s.id FROM surahs s LEFT JOIN ayahs a ON a.surah = s.id '
        'GROUP BY s.id HAVING COUNT(a.id) <> s.ayah_count)');
    if (bad != 0) problems.add('سور ناقصة الآيات: $bad');
  }

  Future<void> _checkHadith(
      Database db, Map<String, String> meta, LibraryEntry e, List<String> problems) async {
    final int n = await _count(db, 'SELECT COUNT(*) FROM hadiths');
    if (n <= 0) problems.add('لا توجد أحاديث');
    if ('$n' != meta['hadith_count'] || n != e.records) {
      problems.add('عدد الأحاديث لا يطابق القائمة');
    }
    if ((meta['numbering'] ?? '').isEmpty) problems.add('نظام الترقيم غير مذكور');
    final int orphans = await _count(
        db,
        'SELECT COUNT(*) FROM hadiths h LEFT JOIN books b ON b.id = h.book_id WHERE b.id IS NULL');
    if (orphans != 0) problems.add('أحاديث بلا كتاب: $orphans');
    final int empty = await _count(db, "SELECT COUNT(*) FROM hadiths WHERE text = ''");
    if (empty != 0 && (meta['empty_text_numbers'] ?? '').isEmpty) {
      problems.add('نصوص فارغة غير موثقة: $empty');
    }
  }
}
