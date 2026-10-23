/// تنسيق التاريخ والأرقام بالعربية (دون الحاجة إلى مكتبات خارجية).
class ArabicFormat {
  ArabicFormat._();

  static const List<String> _weekdays = <String>[
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  static const List<String> _gregorianMonths = <String>[
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  /// يحوّل الأرقام الغربية إلى أرقام عربية-هندية (٠١٢٣...).
  static String digits(Object value) {
    const String western = '0123456789';
    const String eastern = '٠١٢٣٤٥٦٧٨٩';
    final StringBuffer out = StringBuffer();
    for (final int unit in value.toString().codeUnits) {
      final int i = western.indexOf(String.fromCharCode(unit));
      out.write(i >= 0 ? eastern[i] : String.fromCharCode(unit));
    }
    return out.toString();
  }

  /// مثال: الجمعة ١٦ أكتوبر ٢٠٢٦
  static String gregorianLong(DateTime d) {
    final String weekday = _weekdays[d.weekday - 1];
    final String month = _gregorianMonths[d.month - 1];
    return '$weekday ${digits(d.day)} $month ${digits(d.year)}';
  }

  /// حجم بالبايت بصيغة عربية: ١٢٫٣ ميغابايت
  static String bytes(int n) {
    if (n < 1024 * 1024) {
      return '${digits((n / 1024).round())} كيلوبايت';
    }
    final double mb = n / (1024 * 1024);
    final String s = digits(mb.toStringAsFixed(mb >= 100 ? 0 : 1)).replaceAll('.', '٫');
    return '$s ميغابايت';
  }

  static String percent(double fraction) {
    final int p = (fraction * 100).floor().clamp(0, 100).toInt();
    return '${digits(p)}٪';
  }

  /// يحوّل الأرقام العربية-الهندية إلى غربية (لتحليل مدخلات المستخدم).
  static String toWestern(String value) {
    const String eastern = '٠١٢٣٤٥٦٧٨٩';
    final StringBuffer out = StringBuffer();
    for (final int unit in value.codeUnits) {
      final int i = eastern.indexOf(String.fromCharCode(unit));
      out.write(i >= 0 ? '$i' : String.fromCharCode(unit));
    }
    return out.toString();
  }

  /// وقت الساعة من حقول [t] المحلية: ٥:٠١ ص أو ١٧:٠١ حسب [use24h].
  static String clock(DateTime t, {bool use24h = false}) {
    final String mm = t.minute.toString().padLeft(2, '0');
    if (use24h) {
      return digits('${t.hour.toString().padLeft(2, '0')}:$mm');
    }
    final int h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '${digits('$h12:$mm')} ${t.hour < 12 ? 'ص' : 'م'}';
  }

  /// مدة متبقية: ٢ س ٣٠ د ١٢ ث
  static String countdown(Duration d) {
    final int total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final int h = total ~/ 3600;
    final int m = (total % 3600) ~/ 60;
    final int s = total % 60;
    final List<String> parts = <String>[];
    if (h > 0) parts.add('${digits(h)} س');
    if (h > 0 || m > 0) parts.add('${digits(m)} د');
    parts.add('${digits(s)} ث');
    return parts.join(' ');
  }

  /// رقم عشري بصيغة عربية دون أصفار زائدة: ١٩٫٥ أو ١٨
  static String number(double v) {
    final String s = v == v.roundToDouble() ? v.round().toString() : v.toString();
    return digits(s).replaceAll('.', '٫');
  }

  /// عدد صحيح بفاصل آلاف عربي: ١٠٬٣٠٦
  static String grouped(int n) {
    final String raw = n.abs().toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) out.write('٬');
      out.write(raw[i]);
    }
    return digits(out.toString());
  }

  /// اسم يوم الأسبوع (DateTime.weekday: 1 = الاثنين ... 7 = الأحد).
  static String weekdayAr(int weekday) => _weekdays[weekday - 1];

  /// اسم الشهر الميلادي (1..12).
  static String gregorianMonthAr(int month) => _gregorianMonths[month - 1];
}
