class Surah {
  const Surah({
    required this.id,
    required this.nameAr,
    required this.nameTr,
    required this.nameEn,
    required this.type,
    required this.order,
    required this.ayahCount,
  });

  final int id;
  final String nameAr;
  final String nameTr;
  final String nameEn;
  final String type;
  final int order;
  final int ayahCount;

  /// نوع السورة كما في المصدر (Meccan / Medinan).
  String get typeAr {
    if (type == 'Meccan') return 'مكية';
    if (type == 'Medinan') return 'مدنية';
    return type;
  }
}

class Ayah {
  const Ayah(this.surah, this.ayah, this.text);

  final int surah;
  final int ayah;
  final String text;

  String get ref => '$surah:$ayah';
}
