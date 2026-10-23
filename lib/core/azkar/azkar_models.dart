class Dhikr {
  const Dhikr({
    required this.id,
    required this.text,
    this.count,
    this.reference,
    this.notes,
  });

  final String id;
  final String text;

  /// عدد التكرار إن ثبت في المصدر، وإلا null (فلا يُفترض عدد).
  final int? count;

  /// المصدر والتخريج كما ورد في الملف المعتمد، إن وُجد.
  final String? reference;
  final String? notes;
}

class AzkarCategory {
  const AzkarCategory({required this.id, required this.titleAr, required this.items});

  final String id;
  final String titleAr;
  final List<Dhikr> items;
}

class AzkarSource {
  const AzkarSource({
    required this.name,
    required this.url,
    required this.license,
    required this.licenseUrl,
    required this.version,
  });

  final String name;
  final String url;
  final String license;
  final String licenseUrl;
  final String version;
}

class AzkarData {
  const AzkarData({required this.source, required this.categories});

  final AzkarSource source;
  final List<AzkarCategory> categories;

  AzkarCategory? category(String id) {
    for (final AzkarCategory c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }
}
