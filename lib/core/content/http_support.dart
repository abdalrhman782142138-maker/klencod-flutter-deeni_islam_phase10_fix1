import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'content_config.dart';
import 'errors.dart';

/// طلب GET يتبع التحويلات يدوياً: يشترط HTTPS في كل خطوة ويحافظ على ترويسة Range.
Future<HttpClientResponse> openGet(
  HttpClient client,
  Uri url, {
  int rangeStart = 0,
  bool allowInsecure = false,
}) async {
  Uri current = url;
  for (int hop = 0; hop < 6; hop++) {
    final bool ok = current.scheme == 'https' || (allowInsecure && current.scheme == 'http');
    if (!ok) {
      throw const DownloadException(DownloadErrorKind.source, 'رابط التنزيل غير آمن');
    }
    final HttpClientRequest req = await client.getUrl(current);
    req.followRedirects = false;
    req.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    if (rangeStart > 0) {
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=$rangeStart-');
    }
    final HttpClientResponse resp = await req.close();
    if (resp.isRedirect) {
      final String? loc = resp.headers.value(HttpHeaders.locationHeader);
      await resp.drain<void>();
      if (loc == null) {
        throw const DownloadException(DownloadErrorKind.source, 'تحويل بلا وجهة');
      }
      current = current.resolve(loc);
      continue;
    }
    return resp;
  }
  throw const DownloadException(DownloadErrorKind.source, 'تحويلات كثيرة');
}

/// جلب نص صغير (manifest) بحد أقصى للحجم.
Future<String> fetchText(Uri url, {bool allowInsecure = false}) async {
  final HttpClient client = HttpClient()
    ..autoUncompress = true
    ..connectionTimeout = ContentConfig.connectTimeout;
  try {
    final HttpClientResponse resp =
        await openGet(client, url, allowInsecure: allowInsecure);
    if (resp.statusCode != 200) {
      await resp.drain<void>();
      throw DownloadException(DownloadErrorKind.http, 'رد الخادم ${resp.statusCode}');
    }
    final BytesBuilder builder = BytesBuilder(copy: false);
    await for (final List<int> chunk in resp.timeout(ContentConfig.idleTimeout)) {
      builder.add(chunk);
      if (builder.length > ContentConfig.maxManifestBytes) {
        throw const DownloadException(DownloadErrorKind.source, 'قائمة المكتبات أكبر من المسموح');
      }
    }
    return utf8.decode(builder.takeBytes());
  } finally {
    client.close(force: true);
  }
}
