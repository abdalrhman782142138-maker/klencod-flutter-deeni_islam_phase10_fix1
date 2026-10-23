/// إعدادات مصدر المحتوى.
///
/// [manifestUrl] فارغ عمداً: مكان الاستضافة قرار معلّق عند المالك، ولا يُختلق رابط.
/// يُحدَّد إما بتعديل هذا الملف أو عند البناء: --dart-define=MANIFEST_URL=https://...
class ContentConfig {
  ContentConfig._();

  static const String manifestUrl =
      String.fromEnvironment('MANIFEST_URL', defaultValue: '');

  static const int maxManifestBytes = 256 * 1024;
  static const int maxRetries = 3;
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration idleTimeout = Duration(seconds: 30);

  static bool get isConfigured => manifestUrl.isNotEmpty;
}
