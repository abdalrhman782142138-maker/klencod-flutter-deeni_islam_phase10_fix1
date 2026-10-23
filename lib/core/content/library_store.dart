import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class InstalledLibrary {
  const InstalledLibrary({
    required this.id,
    required this.contentVersion,
    required this.size,
    required this.sizeCompressed,
    required this.sha256,
    required this.records,
    required this.installedAt,
  });

  final String id;
  final int contentVersion;
  final int size;
  final int sizeCompressed;
  final String sha256;
  final int records;
  final String installedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'content_version': contentVersion,
        'size': size,
        'size_compressed': sizeCompressed,
        'sha256': sha256,
        'records': records,
        'installed_at': installedAt,
      };

  static InstalledLibrary? fromJson(dynamic j) {
    if (j is! Map<String, dynamic>) return null;
    final dynamic id = j['id'];
    final dynamic v = j['content_version'];
    final dynamic size = j['size'];
    final dynamic sc = j['size_compressed'];
    final dynamic sha = j['sha256'];
    final dynamic rec = j['records'];
    final dynamic at = j['installed_at'];
    if (id is! String || v is! int || size is! int || sc is! int) return null;
    if (sha is! String || rec is! int || at is! String) return null;
    return InstalledLibrary(
      id: id,
      contentVersion: v,
      size: size,
      sizeCompressed: sc,
      sha256: sha,
      records: rec,
      installedAt: at,
    );
  }
}

/// مواضع ملفات المكتبات في مساحة التطبيق الداخلية (لا إذن تخزين عام).
///
/// libraries/<id>/<contentVersion>.db   المكتبة المعتمدة
/// libraries/<id>/<id>.db.gz.part       تنزيل جزئي قابل للاستئناف
/// libraries/<id>/<id>.db.tmp           قاعدة قيد الفحص قبل الاعتماد
/// libraries/state.json                 سجل المكتبات المثبتة (يُكتب ذرياً)
class LibraryStore {
  LibraryStore(this.root);

  final Directory root;

  static Future<LibraryStore> open() async {
    final Directory base = await getApplicationSupportDirectory();
    final Directory root = Directory('${base.path}/libraries');
    await root.create(recursive: true);
    return LibraryStore(root);
  }

  Directory dir(String id) => Directory('${root.path}/$id');
  File dbFile(String id, int version) => File('${root.path}/$id/$version.db');
  File partFile(String id) => File('${root.path}/$id/$id.db.gz.part');
  File tmpDb(String id) => File('${root.path}/$id/$id.db.tmp');
  File get _state => File('${root.path}/state.json');
  File get _manifestCache => File('${root.path}/manifest_cache.json');

  Future<Map<String, InstalledLibrary>> loadInstalled() async {
    final Map<String, InstalledLibrary> out = <String, InstalledLibrary>{};
    try {
      if (!await _state.exists()) return out;
      final dynamic j = jsonDecode(await _state.readAsString());
      if (j is Map<String, dynamic> && j['libraries'] is List) {
        for (final dynamic item in j['libraries'] as List<dynamic>) {
          final InstalledLibrary? lib = InstalledLibrary.fromJson(item);
          if (lib != null) out[lib.id] = lib;
        }
      }
    } catch (_) {
      // سجل تالف: تُعاد حالة كل مكتبة من الملفات الفعلية ولا يتوقف التطبيق.
    }
    return out;
  }

  /// كتابة ذرية: ملف مؤقت ثم إعادة تسمية، فلا يبقى سجل نصف مكتوب.
  Future<void> saveInstalled(Map<String, InstalledLibrary> libs) async {
    final File tmp = File('${_state.path}.tmp');
    final String body = jsonEncode(<String, dynamic>{
      'schema': 1,
      'libraries': libs.values.map((InstalledLibrary l) => l.toJson()).toList(),
    });
    await tmp.writeAsString(body, flush: true);
    await tmp.rename(_state.path);
  }

  Future<void> writeManifestCache(String text) async {
    final File tmp = File('${_manifestCache.path}.tmp');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(_manifestCache.path);
  }

  Future<String?> readManifestCache() async {
    try {
      if (await _manifestCache.exists()) return await _manifestCache.readAsString();
    } catch (_) {}
    return null;
  }

  Future<void> deleteIfExists(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
