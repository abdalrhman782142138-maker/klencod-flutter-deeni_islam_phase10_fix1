/// حالة مكتبة من المكتبات الثلاث (القرآن، البخاري، مسلم).
enum LibraryStatus {
  notDownloaded,
  downloading,
  paused,
  verifying,
  ready,
  failed,
  damaged,
}

extension LibraryStatusLabel on LibraryStatus {
  String get label {
    switch (this) {
      case LibraryStatus.notDownloaded:
        return 'غير منزّلة';
      case LibraryStatus.downloading:
        return 'جارٍ التنزيل';
      case LibraryStatus.paused:
        return 'متوقفة مؤقتاً';
      case LibraryStatus.verifying:
        return 'جارٍ التحقق';
      case LibraryStatus.ready:
        return 'جاهزة';
      case LibraryStatus.failed:
        return 'تعذّر التنزيل';
      case LibraryStatus.damaged:
        return 'تحتاج إصلاحاً';
    }
  }
}
