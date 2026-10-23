enum DownloadErrorKind { network, http, storage, source }

/// أُوقف النقل بطلب المستخدم (إيقاف مؤقت أو إلغاء).
class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

class DownloadException implements Exception {
  const DownloadException(this.kind, this.message);

  final DownloadErrorKind kind;
  final String message;

  @override
  String toString() => message;
}

/// الملف المنزَّل لا يطابق البصمة أو الحجم أو بنية قاعدة البيانات المتوقعة.
class IntegrityException implements Exception {
  const IntegrityException(this.message);

  final String message;

  @override
  String toString() => message;
}
