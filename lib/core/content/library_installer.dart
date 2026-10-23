import 'dart:io';

import 'package:crypto/crypto.dart';

import 'db_inspector.dart';
import 'errors.dart';
import 'library_store.dart';
import 'manifest.dart';

Future<String> sha256OfFile(File f) async {
  final Digest d = await sha256.bind(f.openRead()).first;
  return d.toString();
}

/// يعتمد مكتبة منزَّلة: بصمة المضغوط، فك الضغط، بصمة القاعدة، فحص البنية،
/// ثم نقل ذري. لا يُحذف شيء سليم قبل نجاح البديل.
class LibraryInstaller {
  const LibraryInstaller(this.store, this.inspector);

  final LibraryStore store;
  final DbInspector inspector;

  Future<InstalledLibrary> install(LibraryEntry e, int contentVersion) async {
    final File part = store.partFile(e.id);
    final File tmp = store.tmpDb(e.id);
    try {
      // 1) سلامة الملف المضغوط
      if (!await part.exists() || await part.length() != e.sizeCompressed) {
        throw const IntegrityException('حجم الملف المنزَّل لا يطابق المتوقع');
      }
      if (await sha256OfFile(part) != e.sha256Compressed) {
        await store.deleteIfExists(part);
        throw const IntegrityException('بصمة الملف المنزَّل لا تطابق؛ سيُعاد تنزيله');
      }

      // 2) فك الضغط إلى ملف مؤقت
      await store.deleteIfExists(tmp);
      final IOSink sink = tmp.openWrite();
      try {
        await sink.addStream(part.openRead().transform(gzip.decoder));
      } on FileSystemException {
        throw const IntegrityException('تعذّر فك الضغط، تأكد من توفر مساحة');
      } catch (_) {
        throw const IntegrityException('الملف المضغوط تالف');
      } finally {
        try {
          await sink.close();
        } catch (_) {}
      }

      // 3) سلامة القاعدة بعد فك الضغط
      if (await tmp.length() != e.size || await sha256OfFile(tmp) != e.sha256) {
        throw const IntegrityException('القاعدة بعد فك الضغط لا تطابق البصمة');
      }

      // 4) فحص البنية والمحتوى
      final InspectionResult r = await inspector.inspect(tmp, e);
      if (!r.ok) {
        throw IntegrityException(r.problems.join('، '));
      }

      // 5) اعتماد ذري
      await store.dir(e.id).create(recursive: true);
      final File finalDb = store.dbFile(e.id, contentVersion);
      await tmp.rename(finalDb.path);
      await store.deleteIfExists(part);
      await _removeOtherVersions(e.id, finalDb);

      return InstalledLibrary(
        id: e.id,
        contentVersion: contentVersion,
        size: e.size,
        sizeCompressed: e.sizeCompressed,
        sha256: e.sha256,
        records: e.records,
        installedAt: DateTime.now().toUtc().toIso8601String(),
      );
    } on IntegrityException {
      await store.deleteIfExists(tmp);
      rethrow;
    }
  }

  Future<void> _removeOtherVersions(String id, File keep) async {
    try {
      await for (final FileSystemEntity f in store.dir(id).list()) {
        if (f is File && f.path.endsWith('.db') && f.path != keep.path) {
          await store.deleteIfExists(f);
        }
      }
    } catch (_) {}
  }
}
