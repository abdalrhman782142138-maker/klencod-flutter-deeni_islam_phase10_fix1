import 'package:flutter/material.dart';

import '../../core/calendar/calendar_settings.dart';
import '../../core/calendar/hijri_calendar.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/arabic_format.dart';

enum _Mode { gregorian, hijri }

/// التقويم الهجري والميلادي: عرض شهري بالتقويمين، تصفح الأشهر، تصحيح يدوي للهجري.
/// الحساب جدولي محلي (بلا إنترنت) وقد يختلف يوماً أو يومين عن التقويم الرسمي ورؤية الهلال.
class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final CalendarSettings _cs = CalendarSettings.instance;
  _Mode _mode = _Mode.gregorian;
  late int _gy;
  late int _gm;
  late int _hy;
  late int _hm;
  DateTime? _selected;

  // أعمدة الأسبوع تبدأ من السبت.
  static const List<String> _cols = <String>['سبت', 'أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة'];

  DateTime get _today {
    final DateTime n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _cs.addListener(_onSettings);
    _goToday();
  }

  @override
  void dispose() {
    _cs.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  void _goToday() {
    final DateTime t = _today;
    _gy = t.year;
    _gm = t.month;
    final YearMonthDay? h = _cs.hijriOf(t);
    _hy = h?.year ?? 1;
    _hm = h?.month ?? 1;
    _selected = null;
  }

  void _shift(int delta) {
    setState(() {
      if (_mode == _Mode.gregorian) {
        final int idx = _gy * 12 + (_gm - 1) + delta;
        _gy = idx ~/ 12;
        _gm = idx % 12 + 1;
      } else {
        final int idx = _hy * 12 + (_hm - 1) + delta;
        final int ny = idx ~/ 12;
        if (ny >= 1) {
          _hy = ny;
          _hm = idx % 12 + 1;
        }
      }
    });
  }

  /// خلايا الشهر المعروض: كل خلية = يوم ميلادي (DateTime) مع تاريخه الهجري، أو null للفراغ.
  List<DateTime?> _cells() {
    final List<DateTime> days = <DateTime>[];
    if (_mode == _Mode.gregorian) {
      final int n = DateTime(_gy, _gm + 1, 0).day;
      for (int d = 1; d <= n; d++) {
        days.add(DateTime(_gy, _gm, d));
      }
    } else {
      final int n = hijriMonthLength(_hy, _hm);
      for (int d = 1; d <= n; d++) {
        final YearMonthDay g = gregorianFromHijri(_hy, _hm, d, _cs.hijriOffset);
        days.add(DateTime(g.year, g.month, g.day));
      }
    }
    if (days.isEmpty) return <DateTime?>[];
    final int lead = (days.first.weekday + 1) % 7; // السبت = 0
    final List<DateTime?> cells = <DateTime?>[for (int i = 0; i < lead; i++) null, ...days];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  String get _title {
    if (_mode == _Mode.gregorian) {
      return '${ArabicFormat.gregorianMonthAr(_gm)} ${ArabicFormat.digits(_gy)}';
    }
    return '${kHijriMonthsAr[_hm - 1]} ${ArabicFormat.digits(_hy)} هـ';
  }

  /// الشهر الميلادي/الهجري المقابل في أول وآخر الشهر المعروض (للعنوان الفرعي).
  String get _subtitle {
    final List<DateTime> c = _cells().whereType<DateTime>().toList();
    if (c.isEmpty) return '';
    if (_mode == _Mode.hijri) {
      final DateTime a = c.first;
      final DateTime b = c.last;
      final String ma = ArabicFormat.gregorianMonthAr(a.month);
      final String mb = ArabicFormat.gregorianMonthAr(b.month);
      return a.month == b.month
          ? '$ma ${ArabicFormat.digits(a.year)} م'
          : '$ma - $mb ${ArabicFormat.digits(b.year)} م';
    }
    final YearMonthDay? a = _cs.hijriOf(c.first);
    final YearMonthDay? b = _cs.hijriOf(c.last);
    if (a == null || b == null) return '';
    return a.month == b.month
        ? '${kHijriMonthsAr[a.month - 1]} ${ArabicFormat.digits(a.year)} هـ'
        : '${kHijriMonthsAr[a.month - 1]} - ${kHijriMonthsAr[b.month - 1]} ${ArabicFormat.digits(b.year)} هـ';
  }

  void _showDay(DateTime d) {
    setState(() => _selected = d);
    final YearMonthDay? h = _cs.hijriOf(d);
    final Color muted = AppTheme.muted(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext c) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(ArabicFormat.weekdayAr(d.weekday),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text('الميلادي: ${ArabicFormat.gregorianLong(d)}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 6),
                Text('الهجري: ${h == null ? '—' : CalendarSettings.formatHijri(h)}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                Text(
                  'تقديري: قد يختلف يوماً أو يومين عن التقويم الرسمي ورؤية الهلال في بلدك.',
                  style: TextStyle(fontSize: 12.5, height: 1.6, color: muted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color muted = AppTheme.muted(context);
    final Color accent = AppTheme.accent(context);
    final DateTime today = _today;
    final String? hToday = _cs.hijriText(today);
    final List<DateTime?> cells = _cells();

    return Scaffold(
      appBar: AppBar(title: const Text('التقويم')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            // اليوم بالتقويمين
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF0C5530), AppColors.forest],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('اليوم · ${ArabicFormat.weekdayAr(today.weekday)}',
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.goldSoft)),
                  const SizedBox(height: 6),
                  Text(hToday ?? '—',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(ArabicFormat.gregorianLong(today),
                      style: TextStyle(fontSize: 15, color: Colors.white.withAlpha(200))),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // اختيار التقويم المعروض
            Row(
              children: <Widget>[
                Expanded(child: _modeButton('ميلادي', _Mode.gregorian)),
                const SizedBox(width: 10),
                Expanded(child: _modeButton('هجري', _Mode.hijri)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'الشهر السابق',
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Text(_title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(_subtitle, style: TextStyle(fontSize: 12.5, color: muted)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'الشهر التالي',
                  onPressed: () => _shift(1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => setState(_goToday),
                child: const Text('العودة إلى اليوم'),
              ),
            ),
            Row(
              children: <Widget>[
                for (final String c in _cols)
                  Expanded(
                    child: Center(
                      child: Text(c,
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700, color: muted)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (int r = 0; r < cells.length ~/ 7; r++)
              Row(
                children: <Widget>[
                  for (int c = 0; c < 7; c++)
                    Expanded(child: _cell(context, cells[r * 7 + c], today, accent, muted)),
                ],
              ),
            const SizedBox(height: 16),
            _correctionCard(context, muted),
            const SizedBox(height: 12),
            _noteCard(context, muted),
          ],
        ),
      ),
    );
  }

  Widget _modeButton(String label, _Mode m) {
    final bool on = _mode == m;
    return OutlinedButton(
      onPressed: () => setState(() {
        _mode = m;
        _selected = null;
      }),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 46),
        backgroundColor: on ? AppColors.gold.withAlpha(40) : null,
        side: BorderSide(color: on ? AppColors.gold : AppTheme.border(context)),
      ),
      child: Text(label, style: TextStyle(fontWeight: on ? FontWeight.w800 : FontWeight.w500)),
    );
  }

  Widget _cell(BuildContext context, DateTime? d, DateTime today, Color accent, Color muted) {
    if (d == null) return const SizedBox(height: 56);
    final YearMonthDay? h = _cs.hijriOf(d);
    final bool isToday = d == today;
    final bool sel = _selected != null && d == _selected;
    final String main = _mode == _Mode.gregorian
        ? ArabicFormat.digits(d.day)
        : ArabicFormat.digits(h?.day ?? 0);
    final String sub = _mode == _Mode.gregorian
        ? (h == null ? '' : ArabicFormat.digits(h.day))
        : ArabicFormat.digits(d.day);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDay(d),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isToday ? AppColors.gold.withAlpha(50) : (sel ? AppColors.gold.withAlpha(24) : null),
            border: Border.all(
              color: isToday ? AppColors.gold : (sel ? AppColors.gold.withAlpha(120) : Colors.transparent),
              width: isToday ? 1.6 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(main,
                  style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                      color: isToday ? accent : null)),
              Text(sub, style: TextStyle(fontSize: 10.5, color: muted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _correctionCard(BuildContext context, Color muted) {
    final int off = _cs.hijriOffset;
    final String label = off == 0
        ? 'بلا تصحيح'
        : '${off > 0 ? 'تقديم' : 'تأخير'} ${ArabicFormat.digits(off.abs())} ${off.abs() == 1 ? 'يوم' : 'أيام'}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('تصحيح التاريخ الهجري',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('وافِق إعلان الجهة المعتمدة في بلدك (مثل بدء رمضان والعيدين).',
              style: TextStyle(fontSize: 12.5, height: 1.6, color: muted)),
          Row(
            children: <Widget>[
              IconButton(
                tooltip: 'تأخير يوم',
                onPressed: off <= -kMaxHijriOffset ? null : () => _cs.setHijriOffset(off - 1),
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              Expanded(
                child: Center(
                  child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              IconButton(
                tooltip: 'تقديم يوم',
                onPressed: off >= kMaxHijriOffset ? null : () => _cs.setHijriOffset(off + 1),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
              if (off != 0) TextButton(onPressed: () => _cs.setHijriOffset(0), child: const Text('إعادة')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noteCard(BuildContext context, Color muted) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: const Text('كيف يُحسب التاريخ الهجري؟ ولماذا قد يختلف؟',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'الحساب هنا جدولي (حسابي) يعمل على جهازك دون إنترنت: دورة من ٣٠ سنة فيها ١١ سنة كبيسة وأشهر بين ٢٩ و٣٠ يوماً. '
              'وهو لا يرصد الهلال ولا يطابق جدول أم القرى الرسمي مطابقة تامة، فقد يختلف يوماً أو يومين، '
              'وقد تختلف بداية الشهر من بلد إلى آخر بحسب رؤية الهلال. '
              'في اختبار على ١١ تاريخاً منشوراً لأم القرى (٢٠٢٥–٢٠٢٧) طابق الحساب ٧ تواريخ تماماً وأخطأ الباقي بيوم واحد. '
              'اليوم الهجري يبدأ شرعاً عند الغروب، والعرض هنا بحسب منتصف الليل. '
              'اعتمد دائماً إعلان الجهة الشرعية في بلدك لبداية رمضان والعيدين، وصحّح التاريخ يدوياً من الأعلى.',
              style: TextStyle(fontSize: 13.5, height: 1.8, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
