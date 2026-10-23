import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/prayer/prayer_calculator.dart';
import '../../../core/prayer/prayer_names.dart';
import '../../../core/prayer/prayer_service.dart';
import '../../../core/prayer/prayer_settings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_format.dart';

/// بطاقة الصلاة القادمة بالوقت المتبقي. المواقيت تُحسب على الجهاز؛ وإن لم يُضبط الموقع
/// تظهر حالة «اضبط موقعك» ولا يُعرض أي وقت.
class PrayerCard extends StatefulWidget {
  const PrayerCard({Key? key, required this.onOpenTimes, required this.onOpenSettings})
      : super(key: key);

  final VoidCallback onOpenTimes;
  final VoidCallback onOpenSettings;

  @override
  State<PrayerCard> createState() => _PrayerCardState();
}

class _PrayerCardState extends State<PrayerCard> {
  Timer? _timer;

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

  BoxDecoration get _bg => BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[Color(0xFF0C5530), AppColors.forest],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final PrayerSettings settings = PrayerSettings.instance;
    final Color soft = Colors.white.withAlpha(190);
    if (settings.place == null) return _empty(context, soft);

    final DateTime nowUtc = DateTime.now().toUtc();
    final PrayerSnapshot? snap = PrayerService.instance.snapshot(nowUtc);
    final PrayerDay? today = snap?.today;
    if (snap == null || today == null) {
      return _message(context, soft, snap?.problem ?? 'تعذّر حساب المواقيت.');
    }
    final NextPrayer? next = nextPrayer(today, snap.tomorrow, nowUtc);
    final PrayerService svc = PrayerService.instance;
    final bool h24 = settings.use24h;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _bg,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            next == null
                ? 'الصلاة القادمة'
                : (next.isTomorrow ? 'الصلاة القادمة (غداً)' : 'الصلاة القادمة'),
            style: const TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.goldSoft),
          ),
          const SizedBox(height: 6),
          if (next != null) ...<Widget>[
            Text(
              '${prayerNameAr(next.kind)} · ${ArabicFormat.clock(svc.toDisplay(next.time), use24h: h24)}',
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'بعد ${ArabicFormat.countdown(next.time.difference(nowUtc))}',
              style: TextStyle(fontSize: 15, color: soft),
            ),
          ],
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withAlpha(34)),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              for (final PrayerKind k in PrayerKind.values)
                Expanded(
                  child: _cell(
                    prayerNameAr(k),
                    ArabicFormat.clock(svc.toDisplay(today.times[k]!), use24h: h24),
                    next != null && !next.isTomorrow && next.kind == k,
                    soft,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${settings.place!.name} · ${settings.method.nameAr}'
            '${today.approximated ? ' · تقدير للعروض العالية' : ''}',
            style: TextStyle(fontSize: 12, color: soft),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: widget.onOpenTimes,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.forest,
            ),
            child: const Text('عرض المواقيت'),
          ),
        ],
      ),
    );
  }

  Widget _cell(String name, String time, bool highlight, Color soft) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: highlight
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppColors.gold.withAlpha(46),
            )
          : null,
      child: Column(
        children: <Widget>[
          Text(name, style: TextStyle(fontSize: 11.5, color: highlight ? AppColors.goldSoft : soft)),
          const SizedBox(height: 4),
          Text(
            time,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: highlight ? AppColors.goldSoft : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, Color soft) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _bg,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('الصلاة القادمة',
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.goldSoft)),
          const SizedBox(height: 8),
          const Text(
            'اضبط موقعك لعرض الصلاة القادمة',
            style: TextStyle(
                fontSize: 20, height: 1.45, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text('تُحسب المواقيت على جهازك دون إنترنت.',
              style: TextStyle(fontSize: 13.5, height: 1.6, color: soft)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: widget.onOpenSettings,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.forest,
            ),
            child: const Text('ضبط الموقع'),
          ),
        ],
      ),
    );
  }

  Widget _message(BuildContext context, Color soft, String text) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _bg,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(text, style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.white)),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: widget.onOpenSettings,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.forest,
            ),
            child: const Text('تغيير الموقع'),
          ),
        ],
      ),
    );
  }
}
