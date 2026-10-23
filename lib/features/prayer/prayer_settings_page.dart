import 'package:flutter/material.dart';

import '../../core/prayer/cities.dart';
import '../../core/prayer/location_service.dart';
import '../../core/prayer/prayer_calculator.dart';
import '../../core/prayer/prayer_names.dart';
import '../../core/prayer/prayer_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/arabic_format.dart';

/// إعدادات المواقيت: الموقع (مدينة/إحداثيات/موقع الهاتف)، طريقة الحساب، العصر، المنطقة الزمنية، التعديل اليدوي.
class PrayerSettingsPage extends StatefulWidget {
  const PrayerSettingsPage({Key? key}) : super(key: key);

  @override
  State<PrayerSettingsPage> createState() => _PrayerSettingsPageState();
}

class _PrayerSettingsPageState extends State<PrayerSettingsPage> {
  final PrayerSettings _s = PrayerSettings.instance;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _s.addListener(_refresh);
  }

  @override
  void dispose() {
    _s.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  // ------------------------------------------------------------------ الموقع

  Future<void> _pickCity() async {
    final City? c = await showModalBottomSheet<City>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => const _CityPicker(),
    );
    if (c == null) return;
    await _s.setPlace(Place(name: c.nameAr, lat: c.lat, lon: c.lon, source: 'city'));
    _toast('${c.nameAr}: خط العرض ${ArabicFormat.number(c.lat)}، خط الطول ${ArabicFormat.number(c.lon)} (تقريبي)');
  }

  Future<void> _enterCoordinates() async {
    final Place? p = await showDialog<Place>(
      context: context,
      builder: (BuildContext ctx) => const _CoordinatesDialog(),
    );
    if (p != null) await _s.setPlace(p);
  }

  Future<void> _useDeviceLocation() async {
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('استخدام موقع الهاتف'),
          content: const Text(
            'سيطلب التطبيق إذن الموقع التقريبي مرة واحدة لتحديد مدينتك وحساب المواقيت. '
            'يبقى الموقع على جهازك ولا يُرسل لأي خادم. يمكنك بدلاً من ذلك اختيار مدينة أو إدخال الإحداثيات.',
            style: TextStyle(height: 1.7),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('متابعة')),
          ],
        );
      },
    );
    if (go != true) return;
    setState(() => _locating = true);
    try {
      final LocationResult r = await LocationService.request();
      await _s.setPlace(Place(name: 'موقع الهاتف', lat: r.lat, lon: r.lon, source: 'gps'));
      _toast('تم تحديد الموقع (الدقة التقريبية ${ArabicFormat.digits(r.accuracyMeters.round())} م)');
    } on LocationFailure catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('تعذّر تحديد الموقع.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // --------------------------------------------------------------------- بناء

  @override
  Widget build(BuildContext context) {
    final Color muted = AppTheme.muted(context);
    final Place? place = _s.place;
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات المواقيت')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            _title('الموقع'),
            _card(<Widget>[
              ListTile(
                leading: const Icon(Icons.place_rounded),
                title: Text(place?.name ?? 'لم يُحدَّد بعد'),
                subtitle: place == null
                    ? const Text('اختر مدينة أو أدخل الإحداثيات أو استخدم موقع الهاتف')
                    : Text(
                        '${place.sourceAr} · ${ArabicFormat.number(double.parse(place.lat.toStringAsFixed(4)))}، ${ArabicFormat.number(double.parse(place.lon.toStringAsFixed(4)))}'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.location_city_rounded),
                title: const Text('اختيار مدينة'),
                onTap: _pickCity,
              ),
              ListTile(
                leading: const Icon(Icons.edit_location_alt_rounded),
                title: const Text('إدخال الإحداثيات يدوياً'),
                onTap: _enterCoordinates,
              ),
              ListTile(
                leading: _locating
                    ? const SizedBox(
                        width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location_rounded),
                title: const Text('استخدام موقع الهاتف'),
                subtitle: const Text('يطلب إذن الموقع التقريبي عند الضغط فقط'),
                onTap: _locating ? null : _useDeviceLocation,
              ),
            ]),
            _title('طريقة الحساب'),
            _card(<Widget>[
              for (final PrayerMethod m in kPrayerMethods)
                ListTile(
                  title: Text(m.nameAr),
                  subtitle: Text(
                    m.ishaIntervalMinutes != null
                        ? 'الفجر ${ArabicFormat.number(m.fajrAngle)}° · العشاء بعد المغرب بـ${ArabicFormat.digits(m.ishaIntervalMinutes!)} دقيقة'
                        : 'الفجر ${ArabicFormat.number(m.fajrAngle)}° · العشاء ${ArabicFormat.number(m.ishaAngle ?? 0)}°',
                  ),
                  trailing: m.id == _s.methodId
                      ? Icon(Icons.check_circle_rounded, color: AppTheme.accent(context))
                      : null,
                  onTap: () => _s.setMethod(m.id),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Text(
                'تختلف الطرق في زاويتي الفجر والعشاء فقط تقريباً. اختر ما تعتمده الجهة الدينية في بلدك.',
                style: TextStyle(fontSize: 12.5, height: 1.6, color: muted),
              ),
            ),
            _title('وقت العصر'),
            _card(<Widget>[
              ListTile(
                title: const Text('الجمهور (الشافعي والمالكي والحنبلي)'),
                subtitle: const Text('يبدأ حين يصير ظل الشيء مثله'),
                trailing: !_s.hanafi ? Icon(Icons.check_circle_rounded, color: AppTheme.accent(context)) : null,
                onTap: () => _s.setHanafi(false),
              ),
              ListTile(
                title: const Text('الحنفي'),
                subtitle: const Text('يبدأ حين يصير ظل الشيء مثليه'),
                trailing: _s.hanafi ? Icon(Icons.check_circle_rounded, color: AppTheme.accent(context)) : null,
                onTap: () => _s.setHanafi(true),
              ),
            ]),
            _title('المنطقة الزمنية'),
            _card(<Widget>[
              SwitchListTile(
                title: const Text('استخدام توقيت الجهاز'),
                subtitle: const Text('يراعي التوقيت الصيفي والشتوي تلقائياً'),
                value: _s.autoTz,
                onChanged: _s.setAutoTz,
              ),
              if (!_s.autoTz)
                ListTile(
                  title: Text('الإزاحة عن UTC: ${_offsetLabel(_s.manualTzMinutes)}'),
                  subtitle: const Text('يدوي: لا يراعي التوقيت الصيفي، عدّله بنفسك عند تغيّره'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'نصف ساعة أقل',
                        onPressed: () => _s.setManualTzMinutes(_s.manualTzMinutes - 30),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      IconButton(
                        tooltip: 'نصف ساعة أكثر',
                        onPressed: () => _s.setManualTzMinutes(_s.manualTzMinutes + 30),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ),
            ]),
            _title('التعديل اليدوي بالدقائق'),
            _card(<Widget>[
              for (final PrayerKind k in PrayerKind.values)
                ListTile(
                  title: Text(prayerNameAr(k)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'تقديم دقيقة',
                        onPressed: () => _s.setAdjustment(k, (_s.adjustments[k] ?? 0) - 1),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(
                          _adjLabel(_s.adjustments[k] ?? 0),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'تأخير دقيقة',
                        onPressed: () => _s.setAdjustment(k, (_s.adjustments[k] ?? 0) + 1),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Text(
                'يُضاف التعديل إلى الوقت المحسوب (حتى ٣٠ دقيقة). مفيد لمطابقة إعلان مسجدك.',
                style: TextStyle(fontSize: 12.5, height: 1.6, color: muted),
              ),
            ),
            _title('عرض الوقت'),
            _card(<Widget>[
              SwitchListTile(
                title: const Text('نظام ٢٤ ساعة'),
                value: _s.use24h,
                onChanged: _s.setUse24h,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  String _offsetLabel(int minutes) {
    final String sign = minutes < 0 ? '-' : '+';
    final int a = minutes.abs();
    final String hh = (a ~/ 60).toString().padLeft(2, '0');
    final String mm = (a % 60).toString().padLeft(2, '0');
    return ArabicFormat.digits('$sign$hh:$mm');
  }

  String _adjLabel(int v) {
    if (v == 0) return '٠';
    return ArabicFormat.digits(v > 0 ? '+$v' : '$v');
  }

  Widget _title(String t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(children: children),
    );
  }
}

// ------------------------------------------------------------------ اختيار مدينة

class _CityPicker extends StatefulWidget {
  const _CityPicker({Key? key}) : super(key: key);

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final List<City> list = kCities
        .where((City c) => _q.isEmpty || c.nameAr.contains(_q) || c.countryAr.contains(_q))
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  autofocus: false,
                  onChanged: (String v) => setState(() => _q = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن مدينة أو دولة',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'لا توجد نتائج. استخدم «إدخال الإحداثيات يدوياً» لمدينتك.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.muted(context)),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (BuildContext c, int i) {
                          final City city = list[i];
                          return ListTile(
                            title: Text(city.nameAr),
                            subtitle: Text(city.countryAr),
                            onTap: () => Navigator.of(context).pop(city),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- إدخال الإحداثيات

class _CoordinatesDialog extends StatefulWidget {
  const _CoordinatesDialog({Key? key}) : super(key: key);

  @override
  State<_CoordinatesDialog> createState() => _CoordinatesDialogState();
}

class _CoordinatesDialogState extends State<_CoordinatesDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _lat = TextEditingController();
  final TextEditingController _lon = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  double? _parse(String raw) {
    final String s = ArabicFormat.toWestern(raw.trim()).replaceAll('٫', '.').replaceAll(',', '.');
    return double.tryParse(s);
  }

  void _save() {
    final double? lat = _parse(_lat.text);
    final double? lon = _parse(_lon.text);
    if (lat == null || lon == null) {
      setState(() => _error = 'أدخل رقمين صحيحين (مثال: 21.4225 و 39.8262).');
      return;
    }
    if (!PrayerSettings.validCoordinates(lat, lon)) {
      setState(() => _error = 'خط العرض بين -90 و 90، وخط الطول بين -180 و 180.');
      return;
    }
    final String name = _name.text.trim().isEmpty ? 'موقع يدوي' : _name.text.trim();
    Navigator.of(context).pop(Place(name: name, lat: lat, lon: lon, source: 'manual'));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إدخال الإحداثيات'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'اسم الموقع (اختياري)'),
            ),
            TextField(
              controller: _lat,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(labelText: 'خط العرض (شمالاً +، جنوباً -)'),
            ),
            TextField(
              controller: _lon,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(labelText: 'خط الطول (شرقاً +، غرباً -)'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error, height: 1.5)),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        TextButton(onPressed: _save, child: const Text('حفظ')),
      ],
    );
  }
}
