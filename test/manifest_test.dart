import 'dart:convert';

import 'package:deeni_islam/core/content/manifest.dart';
import 'package:flutter_test/flutter_test.dart';

final String _h = 'a' * 64;

Map<String, dynamic> _lib(String id, {String url = 'https://example.invalid/x.gz'}) {
  return <String, dynamic>{
    'id': id,
    'title_ar': id,
    'url': url,
    'size_compressed': 100,
    'sha256_compressed': _h,
    'size': 300,
    'sha256': _h,
    'records': 5,
    'db_schema': 1,
  };
}

String _manifest({List<Map<String, dynamic>>? libs, int schema = 1}) {
  return jsonEncode(<String, dynamic>{
    'schema': schema,
    'content_version': 1,
    'libraries': libs ??
        <Map<String, dynamic>>[_lib('quran'), _lib('bukhari'), _lib('muslim')],
  });
}

void main() {
  test('يقبل قائمة صحيحة ويحسب المجموع', () {
    final Manifest m = Manifest.parse(_manifest());
    expect(m.libraries.length, 3);
    expect(m.totalCompressed, 300);
    expect(m.entry('quran')!.records, 5);
  });

  test('يرفض الرابط غير الآمن', () {
    expect(
      () => Manifest.parse(_manifest(libs: <Map<String, dynamic>>[
        _lib('quran', url: 'http://example.invalid/x.gz'),
        _lib('bukhari'),
        _lib('muslim'),
      ])),
      throwsA(isA<ManifestException>()),
    );
  });

  test('يرفض بصمة غير صالحة', () {
    final Map<String, dynamic> bad = _lib('quran')..['sha256'] = 'xyz';
    expect(
      () => Manifest.parse(_manifest(libs: <Map<String, dynamic>>[
        bad,
        _lib('bukhari'),
        _lib('muslim'),
      ])),
      throwsA(isA<ManifestException>()),
    );
  });

  test('يرفض نقص مكتبة أو تكرارها أو إصداراً غير مدعوم', () {
    expect(
      () => Manifest.parse(_manifest(libs: <Map<String, dynamic>>[_lib('quran'), _lib('bukhari')])),
      throwsA(isA<ManifestException>()),
    );
    expect(
      () => Manifest.parse(_manifest(libs: <Map<String, dynamic>>[
        _lib('quran'),
        _lib('quran'),
        _lib('muslim'),
      ])),
      throwsA(isA<ManifestException>()),
    );
    expect(() => Manifest.parse(_manifest(schema: 2)), throwsA(isA<ManifestException>()));
    expect(() => Manifest.parse('not json'), throwsA(isA<ManifestException>()));
  });
}
