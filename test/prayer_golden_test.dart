import 'package:deeni_islam/core/prayer/prayer_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

// قيم ذهبية مولَّدة من tools/prayer/prayer_ref.py (المختبَر بحالات مرجعية منشورة).
// يتحقق هذا الاختبار أن نسخة Dart تطابق المرجع خلال ثانية واحدة (الفروق الرقمية فقط).
// لإعادة التوليد: python3 tools/prayer/gen_golden.py ثم حدّث القيم هنا من golden.json.

class _Case {
  const _Case(this.name, this.y, this.m, this.d, this.lat, this.lon, this.method, this.hanafi,
      this.tz, this.expected, this.approx);

  final String name;
  final int y;
  final int m;
  final int d;
  final double lat;
  final double lon;
  final String method;
  final bool hanafi;
  final int tz;
  final Map<String, double>? expected;
  final bool approx;
}

const List<_Case> _cases = <_Case>[
  _Case('makkah_uq', 2026, 10, 18, 21.4225, 39.8262, 'umm_al_qura', false, 180, <String, double>{'fajr': 1792288855.319165, 'sunrise': 1792293444.8275905, 'dhuhr': 1792314350.6328306, 'asr': 1792326333.2686844, 'maghrib': 1792335239.5137062, 'isha': 1792340639.5137062}, false),
  _Case('cairo_egypt', 2026, 7, 1, 30.0444, 31.2357, 'egypt', false, 180, <String, double>{'fajr': 1782868311.5260403, 'sunrise': 1782874647.4467456, 'dhuhr': 1782899936.7270315, 'asr': 1782912876.4504478, 'maghrib': 1782925219.0807047, 'isha': 1782930800.2777693}, false),
  _Case('cairo_mwl_hanafi', 2026, 10, 18, 30.0444, 31.2357, 'mwl', true, 180, <String, double>{'fajr': 1792291132.6091695, 'sunrise': 1792295924.5313478, 'dhuhr': 1792316412.0722988, 'asr': 1792330977.7065144, 'maghrib': 1792336875.0759535, 'isha': 1792341386.188671}, false),
  _Case('london_isna_dst', 2026, 3, 30, 51.5074, -0.1278, 'isna', false, 60, <String, double>{'fajr': 1774843508.471354, 'sunrise': 1774849229.2817562, 'dhuhr': 1774872296.4052844, 'asr': 1774884919.6273553, 'maghrib': 1774895426.9150138, 'isha': 1774901177.214936}, false),
  _Case('jakarta_karachi', 2026, 1, 15, -6.2088, 106.8456, 'karachi', false, 420, <String, double>{'fajr': 1768426421.9820755, 'sunrise': 1768430919.9012618, 'dhuhr': 1768453315.304466, 'asr': 1768465607.3016255, 'maghrib': 1768475707.703632, 'isha': 1768480201.1062362}, false),
  _Case('sydney_mwl', 2026, 12, 21, -33.8688, 151.2093, 'mwl', false, 660, <String, double>{'fajr': 1797785786.248964, 'sunrise': 1797792047.7774844, 'dhuhr': 1797817981.8630373, 'asr': 1797831475.0305545, 'maghrib': 1797843916.7040122, 'isha': 1797849766.1546602}, false),
  _Case('newyork_isna', 2026, 6, 21, 40.7128, -74.006, 'isna', false, -240, <String, double>{'fajr': 1782027910.7849333, 'sunrise': 1782033905.2218347, 'dhuhr': 1782061073.5950336, 'asr': 1782075489.0953417, 'maghrib': 1782088241.5488458, 'isha': 1782094235.5953681}, false),
  _Case('apia_mwl_dateline', 2026, 10, 18, -13.83, -171.76, 'mwl', false, 840, <String, double>{'fajr': 1792252021.7434666, 'sunrise': 1792256364.5620582, 'dhuhr': 1792278736.2227068, 'asr': 1792290239.2808745, 'maghrib': 1792301119.4700515, 'isha': 1792305212.5837996}, false),
  _Case('oslo_highlat', 2026, 6, 21, 59.9139, 10.7522, 'mwl', false, 120, <String, double>{'fajr': 1782004169.1308894, 'sunrise': 1782006828.325494, 'dhuhr': 1782040728.5555818, 'asr': 1782057625.2330997, 'maghrib': 1782074628.255294, 'isha': 1782077287.4498987}, true),
  _Case('tromso_polar', 2026, 6, 21, 69.6492, 18.9553, 'mwl', false, 120, null, false),
];

void main() {
  for (final _Case c in _cases) {
    test('golden: ${c.name}', () {
      final RawPrayerTimes? r = calculateRaw(
        y: c.y,
        m: c.m,
        d: c.d,
        lat: c.lat,
        lon: c.lon,
        method: prayerMethodById(c.method),
        hanafi: c.hanafi,
        tzOffsetMinutes: c.tz,
      );
      if (c.expected == null) {
        expect(r, isNull);
        return;
      }
      expect(r, isNotNull);
      expect(r!.approximated, c.approx);
      expect(r.fajr, closeTo(c.expected!['fajr']!, 1.0));
      expect(r.sunrise, closeTo(c.expected!['sunrise']!, 1.0));
      expect(r.dhuhr, closeTo(c.expected!['dhuhr']!, 1.0));
      expect(r.asr, closeTo(c.expected!['asr']!, 1.0));
      expect(r.maghrib, closeTo(c.expected!['maghrib']!, 1.0));
      expect(r.isha, closeTo(c.expected!['isha']!, 1.0));
    });
  }

  test('مكة أم القرى 2026-10-18 تطابق الجدول المنشور (UTC+3)', () {
    final PrayerDay? d = computePrayerDay(
      y: 2026,
      m: 10,
      d: 18,
      lat: 21.4225,
      lon: 39.8262,
      method: prayerMethodById('umm_al_qura'),
      tzOffsetMinutes: 180,
    );
    expect(d, isNotNull);
    String hm(PrayerKind k) {
      final DateTime t = d!.times[k]!.add(const Duration(hours: 3));
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }

    expect(hm(PrayerKind.fajr), '05:01');
    expect(hm(PrayerKind.sunrise), '06:17');
    expect(hm(PrayerKind.dhuhr), '12:06');
    expect(hm(PrayerKind.asr), '15:26');
    expect(hm(PrayerKind.maghrib), '17:54');
    expect(hm(PrayerKind.isha), '19:24');
  });

  test('الصلاة القادمة: بعد العشاء تكون فجر الغد', () {
    final PrayerDay today = computePrayerDay(
        y: 2026, m: 10, d: 18, lat: 21.4225, lon: 39.8262,
        method: prayerMethodById('mwl'), tzOffsetMinutes: 180)!;
    final PrayerDay tomorrow = computePrayerDay(
        y: 2026, m: 10, d: 19, lat: 21.4225, lon: 39.8262,
        method: prayerMethodById('mwl'), tzOffsetMinutes: 180)!;
    final DateTime afterIsha = today.times[PrayerKind.isha]!.add(const Duration(minutes: 1));
    final NextPrayer? n = nextPrayer(today, tomorrow, afterIsha);
    expect(n!.kind, PrayerKind.fajr);
    expect(n.isTomorrow, true);
    final NextPrayer? m = nextPrayer(today, tomorrow, today.times[PrayerKind.fajr]!.subtract(const Duration(minutes: 5)));
    expect(m!.kind, PrayerKind.fajr);
    expect(m.isTomorrow, false);
  });
}
