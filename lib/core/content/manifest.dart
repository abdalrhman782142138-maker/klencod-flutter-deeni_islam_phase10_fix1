import 'dart:convert';

const List<String> kLibraryIds = <String>['quran', 'bukhari', 'muslim'];

class ManifestException implements Exception {
  const ManifestException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LibraryEntry {
  const LibraryEntry({
    required this.id,
    required this.titleAr,
    required this.url,
    required this.sizeCompressed,
    required this.sha256Compressed,
    required this.size,
    required this.sha256,
    required this.records,
    required this.dbSchema,
    this.source,
    this.license,
  });

  final String id;
  final String titleAr;
  final Uri url;
  final int sizeCompressed;
  final String sha256Compressed;
  final int size;
  final String sha256;
  final int records;
  final int dbSchema;
  final String? source;
  final String? license;
}

class Manifest {
  const Manifest({required this.contentVersion, required this.libraries});

  final int contentVersion;
  final List<LibraryEntry> libraries;

  int get totalCompressed {
    int total = 0;
    for (final LibraryEntry e in libraries) {
      total += e.sizeCompressed;
    }
    return total;
  }

  LibraryEntry? entry(String id) {
    for (final LibraryEntry e in libraries) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// يفحص بنية الملف بصرامة؛ أي خلل يرفض الملف كله.
  static Manifest parse(String source, {bool allowInsecure = false}) {
    dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const ManifestException('ملف قائمة المكتبات تالف');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ManifestException('بنية قائمة المكتبات غير صالحة');
    }
    final Map<String, dynamic> root = decoded;
    if (root['schema'] != 1) {
      throw const ManifestException('إصدار قائمة المكتبات غير مدعوم');
    }
    final int version = _posInt(root, 'content_version');
    final dynamic rawLibs = root['libraries'];
    if (rawLibs is! List) {
      throw const ManifestException('قائمة المكتبات مفقودة');
    }
    final List<LibraryEntry> entries = <LibraryEntry>[];
    final Set<String> seen = <String>{};
    for (final dynamic raw in rawLibs) {
      if (raw is! Map<String, dynamic>) {
        throw const ManifestException('عنصر مكتبة غير صالح');
      }
      final String id = _str(raw, 'id');
      if (!kLibraryIds.contains(id)) {
        throw ManifestException('مكتبة غير معروفة: $id');
      }
      if (!seen.add(id)) {
        throw ManifestException('مكتبة مكررة: $id');
      }
      final Uri url = Uri.parse(_str(raw, 'url'));
      final bool secure = url.scheme == 'https';
      if (!(secure || (allowInsecure && url.scheme == 'http')) || url.host.isEmpty) {
        throw ManifestException('رابط غير آمن للمكتبة $id');
      }
      entries.add(LibraryEntry(
        id: id,
        titleAr: _str(raw, 'title_ar'),
        url: url,
        sizeCompressed: _posInt(raw, 'size_compressed'),
        sha256Compressed: _hex(raw, 'sha256_compressed'),
        size: _posInt(raw, 'size'),
        sha256: _hex(raw, 'sha256'),
        records: _posInt(raw, 'records'),
        dbSchema: _posInt(raw, 'db_schema'),
        source: raw['source'] is String ? raw['source'] as String : null,
        license: raw['license'] is String ? raw['license'] as String : null,
      ));
    }
    for (final String id in kLibraryIds) {
      if (!seen.contains(id)) {
        throw ManifestException('المكتبة $id غير موجودة في القائمة');
      }
    }
    return Manifest(contentVersion: version, libraries: entries);
  }

  static int _posInt(Map<String, dynamic> m, String key) {
    final dynamic v = m[key];
    if (v is int && v > 0) return v;
    throw ManifestException('حقل غير صالح: $key');
  }

  static String _str(Map<String, dynamic> m, String key) {
    final dynamic v = m[key];
    if (v is String && v.isNotEmpty) return v;
    throw ManifestException('حقل مفقود: $key');
  }

  static String _hex(Map<String, dynamic> m, String key) {
    final dynamic v = m[key];
    if (v is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(v)) return v;
    throw ManifestException('بصمة غير صالحة: $key');
  }
}
