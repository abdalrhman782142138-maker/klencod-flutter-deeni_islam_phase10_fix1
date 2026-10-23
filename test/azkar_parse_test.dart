import 'dart:convert';

import 'package:deeni_islam/core/azkar/azkar_models.dart';
import 'package:deeni_islam/core/azkar/azkar_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// بيانات اختبارية صناعية لمنطق التحليل فقط (ليست أذكاراً حقيقية).
String _json({int schema = 1, String text = 'نص اختباري', Object? count = 3}) {
  return jsonEncode(<String, dynamic>{
    'schema': schema,
    'source': <String, dynamic>{
      'name': 'fixture',
      'url': 'https://example.invalid',
      'license': 'L',
      'license_url': 'https://example.invalid/l',
      'version': '1',
    },
    'categories': <dynamic>[
      <String, dynamic>{
        'id': 'morning',
        'title_ar': 'تصنيف',
        'items': <dynamic>[
          <String, dynamic>{'id': '1', 'text': text, 'count': count, 'reference': null, 'notes': null},
        ],
      },
    ],
  });
}

void main() {
  test('يحلّل ملفاً صحيحاً', () {
    final AzkarData d = AzkarRepository.parse(_json());
    expect(d.categories.single.items.single.count, 3);
    expect(d.category('morning')!.titleAr, 'تصنيف');
  });

  test('عدد غير صالح يصبح null ولا يُفترض عدد', () {
    expect(AzkarRepository.parse(_json(count: 0)).categories.single.items.single.count, null);
    expect(AzkarRepository.parse(_json(count: null)).categories.single.items.single.count, null);
  });

  test('يرفض schema غير مدعوم أو نصاً فارغاً', () {
    expect(() => AzkarRepository.parse(_json(schema: 2)), throwsA(isA<AzkarUnavailable>()));
    expect(() => AzkarRepository.parse(_json(text: '  ')), throwsA(isA<AzkarUnavailable>()));
  });
}
