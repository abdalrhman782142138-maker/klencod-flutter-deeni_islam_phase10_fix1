import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/prayer/prayer_settings.dart';
import '../../core/qibla/compass_service.dart';
import '../../core/qibla/qibla_calculator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/arabic_format.dart';
import '../prayer/prayer_settings_page.dart';

/// القبلة والبوصلة. يُفرَّق بوضوح بين:
///  • اتجاه القبلة المحسوب رياضياً من موقعك (لا يحتاج حساسات)،
///  • واتجاه الهاتف الحالي من المستشعرات (يحتاج حساساً معايَراً).
/// لا يُعرض اتجاه حي مختلَق عند غياب الحساس أو عدم موثوقيته.
class QiblaPage extends StatefulWidget {
  const QiblaPage({Key? key}) : super(key: key);

  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> with WidgetsBindingObserver {
  final PrayerSettings _settings = PrayerSettings.instance;
  final HeadingFilter _filter = HeadingFilter(alpha: 0.2);

  StreamSubscription<CompassReading>? _sub;
  bool _checked = false;
  bool _sensorAvailable = false;
  bool _streamError = false;
  double? _declination;
  double? _lastKey; // لإعادة طلب الانحراف عند تغيّر الموقع

  double? _magnetic; // مصفّى
  int _accuracy = 0;
  bool _wasAligned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings.addListener(_onSettings);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings.removeListener(_onSettings);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _listen();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _sub?.cancel();
      _sub = null;
    }
  }

  void _onSettings() {
    _loadDeclination();
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    final bool ok = await CompassService.isAvailable();
    if (!mounted) return;
    setState(() {
      _checked = true;
      _sensorAvailable = ok;
    });
    await _loadDeclination();
    if (ok) _listen();
  }

  Future<void> _loadDeclination() async {
    final Place? p = _settings.place;
    if (p == null) {
      _declination = null;
      return;
    }
    final double key = p.lat * 1000 + p.lon;
    if (key == _lastKey && _declination != null) return;
    _lastKey = key;
    final double? d = await CompassService.declination(p.lat, p.lon);
    if (mounted) setState(() => _declination = d);
  }

  void _listen() {
    if (!_sensorAvailable || _sub != null) return;
    _filter.reset();
    _sub = CompassService.readings().listen(
      (CompassReading r) {
        if (!mounted) return;
        setState(() {
          _streamError = false;
          _accuracy = r.accuracy;
          _magnetic = _filter.add(r.magneticHeading);
        });
        _maybeHaptic();
      },
      onError: (Object _) {
        if (mounted) setState(() => _streamError = true);
      },
    );
  }

  /// أفضل اتجاه حقيقي متاح: مغناطيسي + انحراف. null إن لم تتوفر قراءة.
  double? get _heading {
    final double? m = _magnetic;
    if (m == null) return null;
    final double? d = _declination;
    return d == null ? m : trueHeading(m, d);
  }

  bool get _reliable => _accuracy >= 1 && !_streamError;

  void _maybeHaptic() {
    final Place? p = _settings.place;
    final double? h = _heading;
    if (p == null || h == null || !_reliable) return;
    final double? q = bearingToKaaba(p.lat, p.lon);
    if (q == null) return;
    final bool now = isAligned(q, h);
    if (now && !_wasAligned) HapticFeedback.mediumImpact();
    _wasAligned = now;
  }

  String _accuracyLabel(int a) {
    switch (a) {
      case 3:
        return 'عالية';
      case 2:
        return 'متوسطة';
      case 1:
        return 'منخفضة';
      default:
        return 'غير موثوقة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('القبلة والبوصلة')),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final Place? p = _settings.place;
    final Color muted = AppTheme.muted(context);
    if (p == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'لحساب اتجاه القبلة نحتاج موقعك. اختر مدينة أو أدخل الإحداثيات أو استخدم موقع الهاتف.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.7, color: muted),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _openLocation, child: const Text('ضبط الموقع')),
            ],
          ),
        ),
      );
    }

    final double? qibla = bearingToKaaba(p.lat, p.lon);
    final double dist = distanceToKaabaKm(p.lat, p.lon);
    if (qibla == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('موقعك الحالي عند الكعبة المشرفة؛ لا يوجد اتجاه يُحسب.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.7, color: muted)),
        ),
      );
    }

    final double? heading = _reliable ? _heading : null;
    final bool aligned = heading != null && isAligned(qibla, heading);
    final double? diff = heading == null ? null : signedAngleDiff(qibla, heading);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: <Widget>[
        _placeCard(context, p),
        const SizedBox(height: 14),
        Center(
          child: SizedBox(
            width: math.min(MediaQuery.of(context).size.width - 48, 340.0),
            height: math.min(MediaQuery.of(context).size.width - 48, 340.0),
            child: CustomPaint(
              painter: _CompassPainter(
                qibla: qibla,
                heading: heading,
                aligned: aligned,
                ring: AppTheme.border(context),
                ink: Theme.of(context).colorScheme.onSurface,
                muted: muted,
                gold: AppColors.gold,
                green: AppColors.emeraldBright,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _statusBanner(context, aligned, diff),
        const SizedBox(height: 14),
        _infoCard(context, <MapEntry<String, String>>[
          MapEntry<String, String>(
              'اتجاه القبلة المحسوب', '${ArabicFormat.number(double.parse(qibla.toStringAsFixed(1)))}° من الشمال الحقيقي'),
          MapEntry<String, String>('المسافة إلى الكعبة', '${ArabicFormat.grouped(dist.round())} كم'),
        ], 'محسوب رياضياً من موقعك، ولا يعتمد على حساسات الهاتف.'),
        const SizedBox(height: 10),
        _phoneCard(context),
        const SizedBox(height: 10),
        _calibrationCard(context),
        const SizedBox(height: 12),
        Text(
          'المستشعرات الإلكترونية تتأثر بالمعادن والمغانط والأجهزة القريبة. عند الشك تحقق من محراب مسجد قريب.',
          style: TextStyle(fontSize: 12, height: 1.7, color: muted),
        ),
      ],
    );
  }

  void _openLocation() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext c) => const PrayerSettingsPage()),
    );
  }

  Widget _placeCard(BuildContext context, Place p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.place_rounded, color: AppTheme.accent(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text(p.sourceAr, style: TextStyle(fontSize: 12.5, color: AppTheme.muted(context))),
              ],
            ),
          ),
          TextButton(onPressed: _openLocation, child: const Text('تغيير')),
        ],
      ),
    );
  }

  Widget _statusBanner(BuildContext context, bool aligned, double? diff) {
    final Color muted = AppTheme.muted(context);
    String text;
    Color color = muted;
    if (!_checked) {
      text = 'جارٍ فحص مستشعرات الهاتف…';
    } else if (!_sensorAvailable) {
      text = 'مستشعرات الاتجاه غير متوفرة في هذا الجهاز؛ لا تتوفر قراءة حية. استخدم الزاوية المحسوبة أدناه مع بوصلة أو معلم مثل محراب مسجد.';
    } else if (_streamError) {
      text = 'تعذّرت قراءة المستشعر الآن.';
    } else if (_magnetic == null) {
      text = 'بانتظار قراءة المستشعر…';
    } else if (_accuracy < 1) {
      text = 'قراءة المستشعر غير موثوقة الآن. عايِر البوصلة كما هو موضح أدناه.';
      color = Theme.of(context).colorScheme.error;
    } else if (aligned) {
      text = 'أنت باتجاه القبلة';
      color = AppColors.emeraldBright;
    } else if (diff != null) {
      final String dir = diff > 0 ? 'يميناً' : 'يساراً';
      text = 'انعطف $dir ${ArabicFormat.digits(diff.abs().round())}°';
      color = AppTheme.accent(context);
    } else {
      text = '';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withAlpha(24),
        border: Border.all(color: color.withAlpha(110)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: aligned ? 18 : 15, height: 1.6, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _phoneCard(BuildContext context) {
    final Color muted = AppTheme.muted(context);
    final double? h = _heading;
    final List<MapEntry<String, String>> rows = <MapEntry<String, String>>[];
    if (_sensorAvailable && h != null && !_streamError) {
      rows.add(MapEntry<String, String>(
          'اتجاه الهاتف الحالي',
          _reliable
              ? '${ArabicFormat.digits(h.round())}° ${_declination == null ? '(مغناطيسي)' : '(حقيقي)'}'
              : '—'));
      rows.add(MapEntry<String, String>('دقة المستشعر', _accuracyLabel(_accuracy)));
      rows.add(MapEntry<String, String>(
          'الانحراف المغناطيسي',
          _declination == null
              ? 'غير متاح'
              : '${ArabicFormat.number(double.parse(_declination!.toStringAsFixed(1)))}°'));
    }
    final String note = !_sensorAvailable
        ? 'لا توجد قراءة من المستشعرات.'
        : (_declination == null
            ? 'تعذّر حساب الانحراف المغناطيسي؛ القراءة مغناطيسية وقد تخطئ حتى ٢٠° في بعض البلدان.'
            : 'من حساسات الهاتف، مصحَّحة بالانحراف المغناطيسي المحسوب محلياً.');
    return _infoCard(context, rows, note, empty: muted);
  }

  Widget _infoCard(BuildContext context, List<MapEntry<String, String>> rows, String note, {Color? empty}) {
    final Color muted = AppTheme.muted(context);
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
          for (final MapEntry<String, String> r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: Text(r.key, style: TextStyle(color: muted))),
                  Text(r.value, style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.only(top: rows.isEmpty ? 0 : 6),
            child: Text(note, style: TextStyle(fontSize: 12.5, height: 1.6, color: muted)),
          ),
        ],
      ),
    );
  }

  Widget _calibrationCard(BuildContext context) {
    final Color muted = AppTheme.muted(context);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _sensorAvailable && _magnetic != null && _accuracy < 2,
          title: const Text('كيف أعاير البوصلة؟', style: TextStyle(fontWeight: FontWeight.w800)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '١) حرّك الهاتف في الهواء بشكل الرقم ٨ عدة مرات مع تدويره في كل اتجاه.\n'
              '٢) ابتعد عن المعادن والمغانط والمكبّرات وأغطية الهاتف المغناطيسية والأجهزة الكهربائية.\n'
              '٣) أمسك الهاتف أفقياً ثابتاً ثم انتظر استقرار القراءة.\n'
              '٤) إن بقيت الدقة «منخفضة» أو «غير موثوقة» فاعتمد الزاوية المحسوبة مع معلم آخر.',
              style: TextStyle(fontSize: 13.5, height: 1.8, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// قرص البوصلة. إن وُجد [heading] يدور القرص بحيث يشير الشمال الحقيقي صحيحاً،
/// فإذا واجه الهاتف القبلة صار علامة الكعبة في الأعلى. بدونه يُرسم قرص ثابت (الشمال أعلى).
class _CompassPainter extends CustomPainter {
  _CompassPainter({
    required this.qibla,
    required this.heading,
    required this.aligned,
    required this.ring,
    required this.ink,
    required this.muted,
    required this.gold,
    required this.green,
  });

  final double qibla;
  final double? heading;
  final bool aligned;
  final Color ring;
  final Color ink;
  final Color muted;
  final Color gold;
  final Color green;

  static const double _d2r = math.pi / 180.0;

  Offset _polar(Offset c, double r, double deg) {
    final double a = (deg - 90) * _d2r; // 0° للأعلى، مع عقارب الساعة
    return Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
  }

  void _label(Canvas canvas, String t, Offset at, Color color, double size) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: color),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double r = size.width / 2 - 6;
    final double rot = heading ?? 0.0; // درجات دوران القرص: -heading
    double dial(double bearing) => bearing - rot;

    final Paint ringPaint = Paint()
      ..color = aligned ? green : ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = aligned ? 5 : 2.5;
    canvas.drawCircle(c, r, ringPaint);
    canvas.drawCircle(c, r - 34, Paint()
      ..color = ring.withAlpha(120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    // تدريج كل ١٥° (أطول عند ٩٠°)
    final Paint tick = Paint()..color = muted..strokeWidth = 1.4;
    for (int d = 0; d < 360; d += 15) {
      final bool major = d % 90 == 0;
      canvas.drawLine(_polar(c, r - (major ? 16 : 9), dial(d.toDouble())),
          _polar(c, r, dial(d.toDouble())), tick..strokeWidth = major ? 2.4 : 1.2);
    }
    // الجهات الأربع (ش شرق ج غ بالعربية)
    _label(canvas, 'ش', _polar(c, r - 28, dial(0)), const Color(0xFFD14B4B), 16);
    _label(canvas, 'ق', _polar(c, r - 28, dial(90)), ink, 15);
    _label(canvas, 'ج', _polar(c, r - 28, dial(180)), ink, 15);
    _label(canvas, 'غ', _polar(c, r - 28, dial(270)), ink, 15);

    // خط واتجاه القبلة
    final double qd = dial(qibla);
    canvas.drawLine(c, _polar(c, r - 34, qd), Paint()
      ..color = gold
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round);
    final Offset marker = _polar(c, r - 52, qd);
    canvas.drawCircle(marker, 17, Paint()..color = aligned ? green : gold);
    final Path kaaba = Path()
      ..addRect(Rect.fromCenter(center: marker, width: 14, height: 14));
    canvas.drawPath(kaaba, Paint()..color = const Color(0xFF111111));
    canvas.drawRect(
        Rect.fromLTWH(marker.dx - 7, marker.dy - 3.5, 14, 2.2), Paint()..color = gold);

    // مؤشر ثابت للأعلى = اتجاه الهاتف (يظهر فقط مع قراءة موثوقة)
    if (heading != null) {
      final Path tri = Path()
        ..moveTo(c.dx, c.dy - r + 2)
        ..lineTo(c.dx - 9, c.dy - r - 4 + 20)
        ..lineTo(c.dx + 9, c.dy - r - 4 + 20)
        ..close();
      canvas.drawPath(tri, Paint()..color = ink);
    }
    canvas.drawCircle(c, 5, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(covariant _CompassPainter old) {
    return old.heading != heading || old.qibla != qibla || old.aligned != aligned ||
        old.ring != ring || old.ink != ink;
  }
}
