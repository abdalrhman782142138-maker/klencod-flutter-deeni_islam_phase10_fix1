import 'package:flutter/material.dart';

import '../../core/calendar/calendar_settings.dart';
import '../../core/content/library_manager.dart';
import '../../core/models/app_section.dart';
import '../../core/models/library_status.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/arabic_format.dart';
import '../common/section_placeholder_page.dart';
import '../library/welcome_download_page.dart';
import '../prayer/prayer_settings_page.dart';
import '../prayer/prayer_times_page.dart';
import '../azkar/azkar_home_page.dart';
import '../calendar/calendar_page.dart';
import '../hadith/hadith_home_page.dart';
import '../qibla/qibla_page.dart';
import '../quran/quran_home_page.dart';
import 'widgets/library_section.dart';
import 'widgets/prayer_card.dart';
import 'widgets/tool_tile.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  void _openSection(BuildContext context, AppSection s) {
    final String? libId = LibraryManager.idFor(s.id);
    if (libId != null) {
      if (LibraryManager.instance.statusOf(libId) == LibraryStatus.ready) {
        if (s.id == SectionId.quran) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (BuildContext c) => const QuranHomePage()),
          );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext c) => HadithHomePage(libraryId: libId),
          ),
        );
      } else {
        _openDownload(context);
      }
      return;
    }
    if (s.id == SectionId.prayerTimes) {
      _openPrayerTimes(context);
      return;
    }
    if (s.id == SectionId.calendar) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (BuildContext c) => const CalendarPage()),
      );
      return;
    }
    if (s.id == SectionId.qibla) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (BuildContext c) => const QiblaPage()),
      );
      return;
    }
    if (s.id == SectionId.azkar) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (BuildContext c) => const AzkarHomePage()),
      );
      return;
    }
    _push(context, s.title, s.icon, s.note);
  }

  void _openPrayerTimes(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext c) => const PrayerTimesPage()),
    );
  }

  void _openPrayerSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext c) => const PrayerSettingsPage()),
    );
  }

  void _openDownload(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext c) => const WelcomeDownloadPage(),
      ),
    );
  }

  void _push(BuildContext context, String title, IconData icon, String msg) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext c) {
          return SectionPlaceholderPage(title: title, icon: icon, message: msg);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = AppTheme.isDark(context);
    final Color muted = AppTheme.muted(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: <Widget>[
            // الترويسة: الشعار واسم التطبيق والتاريخ وزر الوضع الليلي
            Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 48,
                    height: 48,
                    semanticLabel: 'شعار ديني الإسلام',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'ديني الإسلام',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      AnimatedBuilder(
                        animation: CalendarSettings.instance,
                        builder: (BuildContext context, Widget? _) {
                          final DateTime now = DateTime.now();
                          final String? h = CalendarSettings.instance.hijriText(now);
                          return Text(
                            h == null
                                ? ArabicFormat.gregorianLong(now)
                                : '$h · ${ArabicFormat.gregorianLong(now)}',
                            style: TextStyle(fontSize: 13, color: muted),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: dark ? 'الوضع الفاتح' : 'الوضع الداكن',
                  iconSize: 24,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: () {
                    AppSettings.instance.setThemeMode(
                      dark ? ThemeMode.light : ThemeMode.dark,
                    );
                  },
                  icon: Icon(
                    dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            PrayerCard(
              onOpenTimes: () => _openPrayerTimes(context),
              onOpenSettings: () => _openPrayerSettings(context),
            ),
            const SizedBox(height: 26),
            const _SectionTitle('المكتبة'),
            const SizedBox(height: 12),
            LibrarySection(
              onOpen: (AppSection s) => _openSection(context, s),
              onDownload: () => _openDownload(context),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('الأدوات اليومية'),
            const SizedBox(height: 12),
            ..._toolRows(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _toolRows(BuildContext context) {
    final List<AppSection> tools = AppSection.tools;
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < tools.length; i += 2) {
      final AppSection a = tools[i];
      final AppSection? b = i + 1 < tools.length ? tools[i + 1] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: ToolTile(section: a, onTap: () => _openSection(context, a)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: b == null
                      ? const SizedBox.shrink()
                      : ToolTile(section: b, onTap: () => _openSection(context, b)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return rows;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {Key? key}) : super(key: key);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    );
  }
}
