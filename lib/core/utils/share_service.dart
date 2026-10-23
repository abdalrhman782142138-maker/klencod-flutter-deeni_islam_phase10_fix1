import 'package:flutter/services.dart';

/// مشاركة نص عبر نافذة المشاركة في أندرويد (قناة أصلية صغيرة، بلا حزمة ولا إذن).
/// إن تعذّرت تُنسخ النص إلى الحافظة ويُعاد false.
class ShareService {
  ShareService._();

  static const MethodChannel _channel = MethodChannel('com.deeniislam.app/share');

  static Future<bool> shareText(String text) async {
    try {
      final dynamic ok = await _channel.invokeMethod<dynamic>('shareText', text);
      return ok == true;
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      return false;
    }
  }
}
