class HadithBook {
  const HadithBook({required this.id, required this.nameAr, required this.count});

  final int id;
  final String nameAr;
  final int count;
}

class Hadith {
  const Hadith({
    required this.id,
    required this.ord,
    required this.number,
    required this.bookId,
    required this.text,
  });

  final int id;

  /// الترتيب داخل المكتبة كما في المصدر (للتنقل المتسلسل).
  final int ord;

  /// رقم الحديث بنظام ترقيم المصدر (نص، لأن بعض الأنظمة تستخدم أرقاماً فرعية).
  final String number;
  final int bookId;
  final String text;
}
