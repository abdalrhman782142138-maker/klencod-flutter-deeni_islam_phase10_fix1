import 'dart:async';
import 'dart:io';

import 'content_config.dart';
import 'errors.dart';
import 'http_support.dart';

typedef ProgressCallback = void Function(int bytesDone, int bytesTotal);

/// يتحكم في تنزيل جارٍ: الإيقاف المؤقت والإلغاء كلاهما يستدعيان [stop].
/// الفرق في المدير: الإلغاء يحذف الملف الجزئي، والإيقاف يُبقيه للاستئناف.
class DownloadControl {
  bool _stopped = false;
  HttpClient? _client;

  bool get isStopped => _stopped;

  void stop() {
    _stopped = true;
    _client?.close(force: true);
  }
}

/// تنزيل قابل للاستئناف بملف `.part`، فلا يُعاد تنزيل ما اكتمل.
class ResumableDownloader {
  const ResumableDownloader({
    this.allowInsecure = false,
    this.retryDelay = const Duration(seconds: 2),
  });

  /// للاختبار المحلي فقط (خادم HTTP على الجهاز نفسه).
  final bool allowInsecure;
  final Duration retryDelay;

  Future<void> download({
    required Uri url,
    required File part,
    required int expectedSize,
    required DownloadControl control,
    required ProgressCallback onProgress,
  }) async {
    await part.parent.create(recursive: true);
    int have = await part.exists() ? await part.length() : 0;
    if (have > expectedSize) {
      await part.delete();
      have = 0;
    }
    onProgress(have, expectedSize);
    if (have == expectedSize) return;

    int attempt = 0;
    while (true) {
      if (control.isStopped) throw const DownloadCancelled();
      try {
        await _attempt(url, part, expectedSize, control, onProgress);
        return;
      } on DownloadCancelled {
        rethrow;
      } on DownloadException catch (e) {
        if (e.kind != DownloadErrorKind.network || attempt >= ContentConfig.maxRetries) {
          rethrow;
        }
      }
      attempt++;
      await Future<void>.delayed(retryDelay * attempt);
    }
  }

  Future<void> _attempt(
    Uri url,
    File part,
    int expectedSize,
    DownloadControl control,
    ProgressCallback onProgress,
  ) async {
    final int start = await part.exists() ? await part.length() : 0;
    if (start == expectedSize) return;

    final HttpClient client = HttpClient()
      ..autoUncompress = false
      ..connectionTimeout = ContentConfig.connectTimeout;
    control._client = client;
    IOSink? sink;
    try {
      final HttpClientResponse resp =
          await openGet(client, url, rangeStart: start, allowInsecure: allowInsecure);

      bool append = false;
      int done = 0;
      if (resp.statusCode == 206) {
        final String? cr = resp.headers.value(HttpHeaders.contentRangeHeader);
        if (start == 0 || cr == null || !cr.startsWith('bytes $start-')) {
          await resp.drain<void>();
          throw const DownloadException(DownloadErrorKind.source, 'استجابة نطاق غير متوقعة');
        }
        append = true;
        done = start;
      } else if (resp.statusCode == 200) {
        if (resp.contentLength != -1 && resp.contentLength != expectedSize) {
          await resp.drain<void>();
          throw const DownloadException(
              DownloadErrorKind.source, 'حجم الملف على الخادم يخالف القائمة');
        }
        // الخادم تجاهل Range أو التنزيل يبدأ من الصفر: نبدأ الملف من جديد.
      } else if (resp.statusCode == 416) {
        await resp.drain<void>();
        if (await part.exists()) await part.delete();
        throw const DownloadException(DownloadErrorKind.network, 'أُعيد ضبط التنزيل');
      } else {
        await resp.drain<void>();
        throw DownloadException(DownloadErrorKind.http, 'رد الخادم ${resp.statusCode}');
      }

      sink = part.openWrite(mode: append ? FileMode.append : FileMode.write);
      await for (final List<int> chunk in resp.timeout(ContentConfig.idleTimeout)) {
        if (control.isStopped) throw const DownloadCancelled();
        sink.add(chunk);
        done += chunk.length;
        if (done > expectedSize) {
          throw const DownloadException(DownloadErrorKind.source, 'الملف أكبر من المتوقع');
        }
        onProgress(done, expectedSize);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (done != expectedSize) {
        throw const DownloadException(DownloadErrorKind.network, 'انقطع الاتصال قبل اكتمال الملف');
      }
    } on DownloadCancelled {
      rethrow;
    } on DownloadException {
      if (control.isStopped) throw const DownloadCancelled();
      rethrow;
    } on FileSystemException {
      if (control.isStopped) throw const DownloadCancelled();
      throw const DownloadException(DownloadErrorKind.storage, 'تعذّر الكتابة على التخزين، تأكد من توفر مساحة');
    } catch (_) {
      // انقطاع شبكة أو مهلة أو إغلاق قسري: إن كان بطلب المستخدم فهو إيقاف.
      if (control.isStopped) throw const DownloadCancelled();
      throw const DownloadException(DownloadErrorKind.network, 'تعذّر الاتصال بالإنترنت');
    } finally {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      client.close(force: true);
      control._client = null;
    }
  }
}
