import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'azkar_models.dart';

class AzkarUnavailable implements Exception {
  const AzkarUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

/// الأذكار مضمَّنة في التطبيق (assets/azkar/azkar.json) وتعمل دون إنترنت من أول تشغيل.
/// الملف يُنتَج بأداة tools/content/build_azkar.py من مصدر موثق. إن لم يُضمَّن بعد
/// يُعلَن ذلك للمستخدم ولا تُعرض أي أذكار بديلة.
class AzkarRepository {
  AzkarRepository._();

  static final AzkarRepository instance = AzkarRepository._();
  static const String assetPath = 'assets/azkar/azkar.json';

  AzkarData? _data;

  Future<AzkarData> load() async {
    if (_data != null) return _data!;
    String raw;
    try {
      raw = await rootBundle.loadString(assetPath);
    } catch (_) {
      throw const AzkarUnavailable('بيانات الأذكار غير مضمَّنة في هذا الإصدار من التطبيق بعد.');
    }
    try {
      _data = parse(raw);
    } on AzkarUnavailable {
      rethrow;
    } catch (_) {
      throw const AzkarUnavailable('ملف الأذكار تالف ولا يمكن عرضه.');
    }
    return _data!;
  }

  static AzkarData parse(String raw) {
    final dynamic root = jsonDecode(raw);
    if (root is! Map<String, dynamic> || root['schema'] != 1) {
      throw const AzkarUnavailable('إصدار ملف الأذكار غير مدعوم.');
    }
    final dynamic src = root['source'];
    if (src is! Map<String, dynamic>) {
      throw const AzkarUnavailable('بيانات مصدر الأذكار مفقودة.');
    }
    final AzkarSource source = AzkarSource(
      name: '${src['name']}',
      url: '${src['url']}',
      license: '${src['license']}',
      licenseUrl: '${src['license_url']}',
      version: '${src['version']}',
    );
    final dynamic cats = root['categories'];
    if (cats is! List || cats.isEmpty) {
      throw const AzkarUnavailable('لا توجد تصنيفات أذكار.');
    }
    final List<AzkarCategory> out = <AzkarCategory>[];
    for (final dynamic c in cats) {
      final Map<String, dynamic> cm = c as Map<String, dynamic>;
      final List<Dhikr> items = <Dhikr>[];
      for (final dynamic i in cm['items'] as List<dynamic>) {
        final Map<String, dynamic> im = i as Map<String, dynamic>;
        final String text = '${im['text']}';
        if (text.trim().isEmpty) {
          throw const AzkarUnavailable('ذكر بلا نص في الملف.');
        }
        final dynamic cnt = im['count'];
        items.add(Dhikr(
          id: '${im['id']}',
          text: text,
          count: cnt is int && cnt >= 1 ? cnt : null,
          reference: im['reference'] is String ? im['reference'] as String : null,
          notes: im['notes'] is String ? im['notes'] as String : null,
        ));
      }
      out.add(AzkarCategory(id: '${cm['id']}', titleAr: '${cm['title_ar']}', items: items));
    }
    return AzkarData(source: source, categories: out);
  }
}
