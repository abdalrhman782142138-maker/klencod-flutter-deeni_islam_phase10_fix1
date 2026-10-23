import 'package:deeni_islam/core/utils/arabic_format.dart';
import 'package:deeni_islam/core/utils/arabic_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // نفس نواقل الاختبار في tools/content/tests/test_pipeline.py
  test('تطبيع مطابق لنسخة Python', () {
    expect(normalizeAr('بِسْمِ ٱللَّهِ'), 'بسم الله');
    expect(normalizeAr('مُوسَىٰ'), 'موسي');
    expect(normalizeAr('أَإِيمَانٌ ١٢'), 'اايمان 12');
    expect(normalizeAr('ـــ'), '');
    expect(normalizeAr('  كلمة   أخرى '), 'كلمة اخري');
  });

  test('تنسيق الأرقام والأحجام', () {
    expect(ArabicFormat.digits(2026), '٢٠٢٦');
    expect(ArabicFormat.toWestern('٢:٢٥٥'), '2:255');
    expect(ArabicFormat.percent(0.456), '٤٥٪');
    expect(ArabicFormat.bytes(5 * 1024 * 1024), '٥٫٠ ميغابايت');
  });
}
