import 'package:flutter/material.dart';

/// أقسام التطبيق التسعة. كل قسم يُفعَّل في مرحلته المحددة في خطة العمل.
enum SectionId {
  quran,
  bukhari,
  muslim,
  azkar,
  prayerTimes,
  qibla,
  calendar,
  favorites,
  settings,
}

class AppSection {
  const AppSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.note,
  });

  final SectionId id;
  final String title;
  final String subtitle;
  final IconData icon;

  /// نص يظهر في صفحة «قيد الإنشاء» ليشرح حالة القسم بصدق.
  final String note;

  static const List<AppSection> libraries = <AppSection>[
    AppSection(
      id: SectionId.quran,
      title: 'القرآن الكريم',
      subtitle: '١١٤ سورة',
      icon: Icons.menu_book_rounded,
      note: 'سيُفتح القرآن الكريم هنا بعد تنزيل المكتبة والتحقق من اكتمالها.',
    ),
    AppSection(
      id: SectionId.bukhari,
      title: 'صحيح البخاري',
      subtitle: 'الكتب والأبواب والأحاديث',
      icon: Icons.auto_stories_rounded,
      note: 'سيُفتح صحيح البخاري هنا بعد تنزيل المكتبة والتحقق من اكتمالها.',
    ),
    AppSection(
      id: SectionId.muslim,
      title: 'صحيح مسلم',
      subtitle: 'الكتب والأبواب والأحاديث',
      icon: Icons.import_contacts_rounded,
      note: 'سيُفتح صحيح مسلم هنا بعد تنزيل المكتبة والتحقق من اكتمالها.',
    ),
  ];

  static const List<AppSection> tools = <AppSection>[
    AppSection(
      id: SectionId.azkar,
      title: 'الأذكار والأدعية',
      subtitle: 'الصباح والمساء وغيرها',
      icon: Icons.wb_twilight_rounded,
      note: 'قسم الأذكار قيد الإنشاء. ستعمل أذكاره دون إنترنت من أول تشغيل.',
    ),
    AppSection(
      id: SectionId.prayerTimes,
      title: 'مواقيت الصلاة',
      subtitle: 'تُحسب على جهازك',
      icon: Icons.schedule_rounded,
      note: 'حساب المواقيت قيد الإنشاء. لن تُعرض أوقات قبل أن تُحسب فعلياً.',
    ),
    AppSection(
      id: SectionId.qibla,
      title: 'القبلة والبوصلة',
      subtitle: 'اتجاه القبلة',
      icon: Icons.explore_rounded,
      note: 'قسم القبلة قيد الإنشاء.',
    ),
    AppSection(
      id: SectionId.calendar,
      title: 'التقويم',
      subtitle: 'هجري وميلادي',
      icon: Icons.calendar_month_rounded,
      note: 'التقويم الهجري قيد الإنشاء.',
    ),
    AppSection(
      id: SectionId.favorites,
      title: 'المفضلة',
      subtitle: 'آيات وأحاديث وأذكار',
      icon: Icons.bookmark_rounded,
      note: 'المفضلة قيد الإنشاء، وستُحفظ على جهازك فقط.',
    ),
    AppSection(
      id: SectionId.settings,
      title: 'الإعدادات',
      subtitle: 'الخط والموقع والتنبيهات',
      icon: Icons.settings_rounded,
      note: 'الإعدادات الكاملة قيد الإنشاء. الوضع الليلي متاح الآن من الصفحة الرئيسية.',
    ),
  ];
}
