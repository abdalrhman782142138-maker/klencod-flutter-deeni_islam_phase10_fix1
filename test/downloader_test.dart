import 'dart:io';

import 'package:deeni_islam/core/content/errors.dart';
import 'package:deeni_islam/core/content/resumable_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

/// خادم محلي يدعم Range. [cutAfter]: يقطع الاتصال بعد هذا العدد من البايتات
/// في أول طلب فقط. [ignoreRange]: يتجاهل Range ويرسل الملف كاملاً.
Future<HttpServer> _serve(
  List<int> data, {
  int? cutAfter,
  bool ignoreRange = false,
}) async {
  final HttpServer server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  bool cutDone = false;
  server.listen((HttpRequest req) async {
    final String? range = req.headers.value(HttpHeaders.rangeHeader);
    int start = 0;
    if (range != null && !ignoreRange) {
      start = int.parse(range.substring(6, range.length - 1));
    }
    final List<int> body = data.sublist(start);
    req.response.statusCode = start > 0 ? 206 : 200;
    if (start > 0) {
      req.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-${data.length - 1}/${data.length}',
      );
    }
    req.response.contentLength = body.length;
    if (cutAfter != null && !cutDone) {
      cutDone = true;
      req.response.add(body.sublist(0, cutAfter));
      await req.response.flush();
      final Socket s = await req.response.detachSocket(writeHeaders: false);
      s.destroy();
      return;
    }
    req.response.add(body);
    await req.response.close();
  });
  return server;
}

void main() {
  late Directory dir;
  final List<int> data = List<int>.generate(200000, (int i) => i % 251);
  const ResumableDownloader dl =
      ResumableDownloader(allowInsecure: true, retryDelay: Duration.zero);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dl_test');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('تنزيل كامل', () async {
    final HttpServer s = await _serve(data);
    final File part = File('${dir.path}/a.part');
    await dl.download(
      url: Uri.parse('http://127.0.0.1:${s.port}/f'),
      part: part,
      expectedSize: data.length,
      control: DownloadControl(),
      onProgress: (int d, int t) {},
    );
    expect(await part.readAsBytes(), data);
    await s.close(force: true);
  });

  test('يستأنف بعد انقطاع الاتصال دون إعادة ما نُزِّل', () async {
    final HttpServer s = await _serve(data, cutAfter: 50000);
    final File part = File('${dir.path}/b.part');
    await dl.download(
      url: Uri.parse('http://127.0.0.1:${s.port}/f'),
      part: part,
      expectedSize: data.length,
      control: DownloadControl(),
      onProgress: (int d, int t) {},
    );
    expect(await part.readAsBytes(), data);
    await s.close(force: true);
  });

  test('يستأنف من ملف جزئي موجود', () async {
    final HttpServer s = await _serve(data);
    final File part = File('${dir.path}/c.part');
    await part.writeAsBytes(data.sublist(0, 70000));
    int firstProgress = -1;
    await dl.download(
      url: Uri.parse('http://127.0.0.1:${s.port}/f'),
      part: part,
      expectedSize: data.length,
      control: DownloadControl(),
      onProgress: (int d, int t) {
        if (firstProgress < 0) firstProgress = d;
      },
    );
    expect(firstProgress, 70000);
    expect(await part.readAsBytes(), data);
    await s.close(force: true);
  });

  test('خادم يتجاهل Range: يبدأ الملف من جديد ويكتمل سليماً', () async {
    final HttpServer s = await _serve(data, ignoreRange: true);
    final File part = File('${dir.path}/d.part');
    await part.writeAsBytes(data.sublist(0, 70000));
    await dl.download(
      url: Uri.parse('http://127.0.0.1:${s.port}/f'),
      part: part,
      expectedSize: data.length,
      control: DownloadControl(),
      onProgress: (int d, int t) {},
    );
    expect(await part.readAsBytes(), data);
    await s.close(force: true);
  });

  test('حجم على الخادم يخالف القائمة يُرفض', () async {
    final HttpServer s = await _serve(data);
    final File part = File('${dir.path}/e.part');
    expect(
      () => dl.download(
        url: Uri.parse('http://127.0.0.1:${s.port}/f'),
        part: part,
        expectedSize: data.length + 10,
        control: DownloadControl(),
        onProgress: (int d, int t) {},
      ),
      throwsA(isA<DownloadException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await s.close(force: true);
  });

  test('الإيقاف يرمي DownloadCancelled ويُبقي الجزء للاستئناف', () async {
    final HttpServer s = await _serve(data);
    final File part = File('${dir.path}/f.part');
    final DownloadControl control = DownloadControl();
    await expectLater(
      dl.download(
        url: Uri.parse('http://127.0.0.1:${s.port}/f'),
        part: part,
        expectedSize: data.length,
        control: control,
        onProgress: (int d, int t) {
          if (d > 0) control.stop();
        },
      ),
      throwsA(isA<DownloadCancelled>()),
    );
    expect(await part.exists(), true);
    await s.close(force: true);
  });

  test('رابط HTTP يُرفض افتراضياً', () async {
    const ResumableDownloader strict = ResumableDownloader(retryDelay: Duration.zero);
    expect(
      () => strict.download(
        url: Uri.parse('http://127.0.0.1:9/f'),
        part: File('${dir.path}/g.part'),
        expectedSize: 10,
        control: DownloadControl(),
        onProgress: (int d, int t) {},
      ),
      throwsA(isA<DownloadException>()),
    );
  });
}
