import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/app_section.dart';
import '../models/library_status.dart';
import 'content_config.dart';
import 'db_inspector.dart';
import 'errors.dart';
import 'http_support.dart';
import 'library_installer.dart';
import 'library_store.dart';
import 'manifest.dart';
import 'resumable_downloader.dart';

class LibraryProgress {
  LibraryStatus status = LibraryStatus.notDownloaded;
  int bytesDone = 0;
  int bytesTotal = 0;
  String? message;
}

enum ManifestState { idle, loading, ready, failed }

/// منسّق المكتبات: يعرض الحالة للواجهة ويدير التنزيل والاعتماد.
/// التنزيل يعمل والتطبيق مفتوح؛ عند إغلاقه يبقى الملف الجزئي ويُستأنف لاحقاً.
class LibraryManager extends ChangeNotifier {
  LibraryManager._();

  static final LibraryManager instance = LibraryManager._();

  static String? idFor(SectionId id) {
    switch (id) {
      case SectionId.quran:
        return 'quran';
      case SectionId.bukhari:
        return 'bukhari';
      case SectionId.muslim:
        return 'muslim';
      default:
        return null;
    }
  }

  LibraryStore? _store;
  LibraryInstaller? _installer;
  final ResumableDownloader _downloader = const ResumableDownloader();
  Map<String, InstalledLibrary> _installed = <String, InstalledLibrary>{};
  final Map<String, LibraryProgress> _progress = <String, LibraryProgress>{
    for (final String id in kLibraryIds) id: LibraryProgress(),
  };

  Manifest? _manifest;
  ManifestState _manifestState = ManifestState.idle;
  String? _manifestMessage;
  String? _storageError;
  bool _busy = false;
  bool _cancelRequested = false;
  DownloadControl? _control;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  Manifest? get manifest => _manifest;
  ManifestState get manifestState => _manifestState;
  String? get manifestMessage => _manifestMessage;
  String? get storageError => _storageError;
  bool get busy => _busy;

  LibraryProgress progressOf(String id) => _progress[id]!;
  LibraryStatus statusOf(String id) => _progress[id]!.status;

  bool get allReady =>
      kLibraryIds.every((String id) => _progress[id]!.status == LibraryStatus.ready);

  bool get anyPartial => kLibraryIds.any((String id) {
        final LibraryStatus s = _progress[id]!.status;
        return s == LibraryStatus.paused || s == LibraryStatus.failed;
      });

  bool get anyDamaged =>
      kLibraryIds.any((String id) => _progress[id]!.status == LibraryStatus.damaged);

  bool get canStart =>
      !_busy && _store != null && _manifest != null && !allReady;

  int get overallTotal => _manifest?.totalCompressed ?? 0;

  int get overallDone {
    final Manifest? m = _manifest;
    if (m == null) return 0;
    int total = 0;
    for (final LibraryEntry e in m.libraries) {
      final LibraryProgress p = _progress[e.id]!;
      if (p.status == LibraryStatus.ready) {
        total += e.sizeCompressed;
      } else {
        total += p.bytesDone > e.sizeCompressed ? e.sizeCompressed : p.bytesDone;
      }
    }
    return total;
  }

  /// ملف قاعدة المكتبة الجاهزة (للقارئ في المراحل التالية)، أو null إن لم تكن جاهزة.
  File? readyDbFile(String id) {
    final InstalledLibrary? rec = _installed[id];
    final LibraryStore? store = _store;
    if (rec == null || store == null || statusOf(id) != LibraryStatus.ready) return null;
    return store.dbFile(id, rec.contentVersion);
  }

  // ------------------------------------------------------------------ تهيئة

  Future<void> init() async {
    try {
      _store = await LibraryStore.open();
    } catch (_) {
      _storageError = 'تعذّر الوصول إلى مساحة التخزين';
      notifyListeners();
      return;
    }
    final LibraryStore store = _store!;
    _installer = LibraryInstaller(store, const SqfliteDbInspector());
    _installed = await store.loadInstalled();
    for (final String id in kLibraryIds) {
      final LibraryProgress p = _progress[id]!;
      final InstalledLibrary? rec = _installed[id];
      if (rec != null) {
        final File f = store.dbFile(id, rec.contentVersion);
        if (await f.exists() && await f.length() == rec.size) {
          p.status = LibraryStatus.ready;
          p.bytesTotal = rec.sizeCompressed;
          p.bytesDone = rec.sizeCompressed;
        } else {
          p.status = LibraryStatus.damaged;
          p.message = 'ملف المكتبة مفقود أو ناقص';
        }
      } else {
        final File part = store.partFile(id);
        if (await part.exists()) {
          final int len = await part.length();
          if (len > 0) {
            p.status = LibraryStatus.paused;
            p.bytesDone = len;
          }
        }
      }
    }
    notifyListeners();
  }

  // ---------------------------------------------------------- قائمة المكتبات

  Future<void> loadManifest() async {
    if (_manifestState == ManifestState.loading || _busy) return;
    if (!ContentConfig.isConfigured) {
      _manifestState = ManifestState.failed;
      _manifestMessage = 'مصدر التنزيل غير مُعدّ بعد في هذا الإصدار من التطبيق.';
      notifyListeners();
      return;
    }
    _manifestState = ManifestState.loading;
    _manifestMessage = null;
    notifyListeners();
    try {
      final String text = await fetchText(Uri.parse(ContentConfig.manifestUrl));
      final Manifest m = Manifest.parse(text);
      _manifest = m;
      _manifestState = ManifestState.ready;
      _applySizes(m);
      try {
        await _store?.writeManifestCache(text);
      } catch (_) {}
    } catch (e) {
      final String? cached = await _store?.readManifestCache();
      Manifest? fallback;
      if (cached != null) {
        try {
          fallback = Manifest.parse(cached);
        } catch (_) {}
      }
      if (fallback != null) {
        _manifest = fallback;
        _manifestState = ManifestState.ready;
        _manifestMessage = 'تعذّر الاتصال؛ تُعرض الأحجام المحفوظة من آخر اتصال.';
        _applySizes(fallback);
      } else {
        _manifestState = ManifestState.failed;
        _manifestMessage = _friendly(e);
      }
    }
    notifyListeners();
  }

  void _applySizes(Manifest m) {
    for (final LibraryEntry e in m.libraries) {
      final LibraryProgress p = _progress[e.id]!;
      p.bytesTotal = e.sizeCompressed;
    }
  }

  // ------------------------------------------------------------ تحكم المستخدم

  Future<void> start() async {
    final Manifest? m = _manifest;
    if (_busy || m == null || _store == null) return;
    _busy = true;
    _cancelRequested = false;
    _control = DownloadControl();
    notifyListeners();
    try {
      for (final LibraryEntry e in m.libraries) {
        if (_progress[e.id]!.status == LibraryStatus.ready) continue;
        if (_control!.isStopped) break;
        final bool carryOn = await _runOne(m, e);
        if (!carryOn) break;
      }
    } finally {
      _busy = false;
      _control = null;
      if (_cancelRequested) {
        _cancelRequested = false;
        await _discardPartials();
      }
      notifyListeners();
    }
  }

  void pause() {
    _control?.stop();
  }

  Future<void> cancel() async {
    if (_busy) {
      _cancelRequested = true;
      _control?.stop();
      return;
    }
    await _discardPartials();
    notifyListeners();
  }

  /// يحذف المكتبات التالفة ويعيد تنزيلها. لا يمس المكتبات السليمة.
  Future<void> repairDamaged() async {
    final LibraryStore? store = _store;
    if (store == null || _busy) return;
    for (final String id in kLibraryIds) {
      if (statusOf(id) != LibraryStatus.damaged) continue;
      final InstalledLibrary? rec = _installed.remove(id);
      if (rec != null) await store.deleteIfExists(store.dbFile(id, rec.contentVersion));
      final LibraryProgress p = _progress[id]!;
      p.status = LibraryStatus.notDownloaded;
      p.bytesDone = 0;
      p.message = null;
    }
    await store.saveInstalled(_installed);
    notifyListeners();
    await start();
  }

  // ------------------------------------------------------------------- داخلي

  Future<bool> _runOne(Manifest m, LibraryEntry e) async {
    final LibraryStore store = _store!;
    final LibraryProgress p = _progress[e.id]!;
    p.status = LibraryStatus.downloading;
    p.bytesTotal = e.sizeCompressed;
    p.message = null;
    notifyListeners();
    try {
      await _downloader.download(
        url: e.url,
        part: store.partFile(e.id),
        expectedSize: e.sizeCompressed,
        control: _control!,
        onProgress: (int done, int total) {
          p.bytesDone = done;
          _throttledNotify();
        },
      );
      p.status = LibraryStatus.verifying;
      notifyListeners();
      final InstalledLibrary rec = await _installer!.install(e, m.contentVersion);
      _installed[e.id] = rec;
      await store.saveInstalled(_installed);
      p.status = LibraryStatus.ready;
      p.bytesDone = e.sizeCompressed;
      notifyListeners();
      return true;
    } on DownloadCancelled {
      if (_cancelRequested) {
        await _discardOne(e.id);
      } else {
        p.status = LibraryStatus.paused;
        final File part = store.partFile(e.id);
        p.bytesDone = await part.exists() ? await part.length() : 0;
      }
      notifyListeners();
      return false;
    } on IntegrityException catch (err) {
      p.status = LibraryStatus.failed;
      p.bytesDone = 0;
      p.message = err.message;
      await store.deleteIfExists(store.partFile(e.id));
      notifyListeners();
      return true; // تستمر بقية المكتبات
    } on DownloadException catch (err) {
      final File part = store.partFile(e.id);
      p.bytesDone = await part.exists() ? await part.length() : 0;
      if (err.kind == DownloadErrorKind.network) {
        p.status = LibraryStatus.paused;
        p.message = '${err.message}. اضغط «استئناف» لإكمال ما بقي دون إعادة ما نُزِّل.';
      } else {
        p.status = LibraryStatus.failed;
        p.message = err.message;
      }
      notifyListeners();
      return false;
    } catch (_) {
      p.status = LibraryStatus.failed;
      p.message = 'حدث خطأ غير متوقع أثناء التنزيل';
      notifyListeners();
      return false;
    }
  }

  Future<void> _discardOne(String id) async {
    final LibraryStore? store = _store;
    if (store != null) {
      await store.deleteIfExists(store.partFile(id));
      await store.deleteIfExists(store.tmpDb(id));
    }
    final LibraryProgress p = _progress[id]!;
    p.status = LibraryStatus.notDownloaded;
    p.bytesDone = 0;
    p.message = null;
  }

  Future<void> _discardPartials() async {
    for (final String id in kLibraryIds) {
      final LibraryStatus s = statusOf(id);
      if (s == LibraryStatus.ready || s == LibraryStatus.damaged) continue;
      await _discardOne(id);
    }
  }

  void _throttledNotify() {
    final DateTime now = DateTime.now();
    if (now.difference(_lastNotify).inMilliseconds >= 120) {
      _lastNotify = now;
      notifyListeners();
    }
  }

  String _friendly(Object e) {
    if (e is ManifestException) return e.message;
    if (e is DownloadException) return e.message;
    if (e is IOException || e is TimeoutException) {
      return 'تعذّر الاتصال بالإنترنت. تحقق من الشبكة ثم أعد المحاولة.';
    }
    return 'تعذّر جلب قائمة المكتبات.';
  }
}
