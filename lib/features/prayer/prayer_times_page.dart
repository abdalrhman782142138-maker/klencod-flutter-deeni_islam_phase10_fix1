import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/prayer/prayer_calculator.dart';
import '../../core/prayer/prayer_names.dart';
import '../../core/prayer/prayer_service.dart';
import '../../core/prayer/prayer_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/arabic_format.dart';
import 'prayer_settings_page.dart';

/// مواقيت يوم محدد (اليوم افتراضياً) مع تمييز الصلاة القادمة والوقت المتبقي وتصفح الأيام.
class PrayerTimesPage extends StatefulWidget {
  const PrayerTimesPage({Key? key}) : super(key: key);

  @override
  State<PrayerTimesPage> createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends State<PrayerTimesPage> {
  final PrayerService _svc = PrayerService.instance;
  Timer? _timer;
  int _offsetDays = 0;

  @override
  void initState() {
    super.initState();
    PrayerSettings.instance.addListener(_refresh);
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer _) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    PrayerSettings.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext c) => const PrayerSettingsPage()),
    );
  }

  String _methodLine(PrayerSettings s) {
    final PrayerMethod m = s.method;
    final String isha = m.ishaIntervalMinutes != null
        ? 'العشاء بعد المغرب بـ${ArabicFormat.digits(m.ishaIntervalMinutes!)} دقيقة'
        : 'العشاء ${ArabicFormat.number(m.ishaAngle ?? 0)}°';
    final String asr = s.hanafi ? 'العصر: مثلا الظل (حنفي)' : 'العصر: مثل الظل (جمهور)';
    return 'الفجر ${ArabicFormat.number(m.fajrAngle)}° · $isha · $asr';
  }

  void _compare(DateTime civil) {
    final PrayerSettings s = PrayerSettings.instance;
    final Place p = s.place!;
    final int tz = _svc.tzOffsetFor(civil.year, civil.month, civil.day);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext c) {
        final Color muted = AppTheme.muted(context);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: <Widget>[
              const Text('مقارنة طرق الحساب',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'تختلف الطرق أساساً في زاويتي الفجر والعشاء؛ أما الظهر والمغرب فمتقاربة. اختر ما تعتمده جهتك المحلية.',
                style: TextStyle(fontSize: 12.5, height: 1.6, color: muted),
              ),
              const SizedBox(height: 10),
              for (final PrayerMethod m in kPrayerMethods)
                Builder(builder: (BuildContext _) {
                  final PrayerDay? d = computePrayerDay(
                    y: civil.year,
                    m: civil.month,
                    d: civil.day,
                    lat: p.lat,
                    lon: p.lon,
                    method: m,
                    hanafi: s.hanafi,
                    tzOffsetMinutes: tz,
                  );
                  String t(PrayerKind k) => d == null
                      ? '—'
                      : ArabicFormat.clock(_svc.toDisplay(d.times[k]!), use24h: s.use24h);
                  final bool current = m.id == s.methodId;
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppTheme.border(context))),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            m.nameAr,
                            style: TextStyle(
                                fontWeight: current ? FontWeight.w800 : FontWeight.w500),
                          ),
                        ),
                        Text('الفجر ${t(PrayerKind.fajr)}  ·  العشاء ${t(PrayerKind.isha)}',
                            style: TextStyle(fontSize: 12.5, color: muted)),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final PrayerSettings s = PrayerSettings.instance;
    final Color muted = AppTheme.muted(context);
    final Color accent = AppTheme.accent(context);
    final DateTime nowUtc = DateTime.now().toUtc();

    Widget body;
    if (s.place == null) {
      body = _noPlace(context, muted);
    } else {
      final DateTime baseCivil = _svc.civilNow(nowUtc);
      final DateTime civil =
          DateTime.utc(baseCivil.year, baseCivil.month, baseCivil.day).add(Duration(days: _offsetDays));
      final PrayerDay? day = _svc.dayFor(civil);
      final bool isToday = _offsetDays == 0;
      final PrayerSnapshot? snap = isToday ? _svc.snapshot(nowUtc) : null;
      final NextPrayer? next =
          (isToday && day != null) ? nextPrayer(day, snap?.tomorrow, nowUtc) : null;

      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.place_rounded, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(s.place!.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('${s.place!.sourceAr} · ${s.method.nameAr}',
                          style: TextStyle(fontSize: 12.5, color: muted)),
                    ],
                  ),
                ),
                TextButton(onPressed: _openSettings, child: const Text('تغيير')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              IconButton(
                tooltip: 'اليوم السابق',
                onPressed: () => setState(() => _offsetDays--),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(ArabicFormat.gregorianLong(civil),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    if (!isToday)
                      TextButton(
                        onPressed: () => setState(() => _offsetDays = 0),
                        child: const Text('العودة إلى اليوم'),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'اليوم التالي',
                onPressed: () => setState(() => _offsetDays++),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (day == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'لا يمكن حساب المواقيت في هذا الموقع في هذا التاريخ (الشمس لا تشرق أو لا تغرب). جرّب موقعاً آخر.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.7, color: muted),
              ),
            )
          else ...<Widget>[
            if (day.approximated)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withAlpha(100)),
                ),
                child: Text(
                  'في هذا الموقع والتاريخ لا تبلغ الشمس زاوية الفجر أو العشاء، فهما مقدّران بسُبع الليل. تحقق من جهتك المحلية.',
                  style: TextStyle(fontSize: 12.5, height: 1.6, color: muted),
                ),
              ),
            for (final PrayerKind k in PrayerKind.values)
              _row(context, k, day, next, nowUtc, s),
          ],
          const SizedBox(height: 14),
          Text(_methodLine(s), style: TextStyle(fontSize: 12.5, height: 1.6, color: muted)),
          if (s.method.noteAr.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(s.method.noteAr, style: TextStyle(fontSize: 12, height: 1.6, color: muted)),
          ],
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _compare(civil),
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text('مقارنة طرق الحساب'),
          ),
          const SizedBox(height: 14),
          Text(
            'المواقيت محسوبة على جهازك دون إنترنت. قد تختلف عن إعلان مسجدك بدقائق؛ اتبع الجهة المحلية المعتمدة.',
            style: TextStyle(fontSize: 12, height: 1.7, color: muted),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
        actions: <Widget>[
          IconButton(
            tooltip: 'إعدادات المواقيت',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }

  Widget _row(BuildContext context, PrayerKind k, PrayerDay day, NextPrayer? next,
      DateTime nowUtc, PrayerSettings s) {
    final bool isNext = next != null && !next.isTomorrow && next.kind == k;
    final Color accent = AppTheme.accent(context);
    final Color muted = AppTheme.muted(context);
    final DateTime shown = _svc.toDisplay(day.times[k]!);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isNext ? AppColors.gold.withAlpha(36) : AppTheme.surface(context),
        border: Border.all(color: isNext ? AppColors.gold.withAlpha(140) : AppTheme.border(context)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(prayerNameAr(k),
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                        color: isNext ? accent : null)),
                if (isNext)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('بعد ${ArabicFormat.countdown(next.time.difference(nowUtc))}',
                        style: TextStyle(fontSize: 12.5, color: muted)),
                  ),
              ],
            ),
          ),
          Text(ArabicFormat.clock(shown, use24h: s.use24h),
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: isNext ? accent : null)),
        ],
      ),
    );
  }

  Widget _noPlace(BuildContext context, Color muted) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'اضبط موقعك ليحسب التطبيق المواقيت على جهازك دون إنترنت.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.7, color: muted),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _openSettings, child: const Text('ضبط الموقع')),
          ],
        ),
      ),
    );
  }
}
