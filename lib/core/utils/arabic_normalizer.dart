/// تطبيع النص العربي للبحث. يطابق tools/content/arnorm.py حرفياً
/// (يتحقق منه tools/content/tests/test_dart_contract.py).
/// النص المعروض للمستخدم لا يُعدَّل أبداً؛ التطبيع لعمود search والاستعلام فقط.
const List<List<int>> _kStripRanges = <List<int>>[
  <int>[0x0610, 0x061A],
  <int>[0x064B, 0x065F],
  <int>[0x0670, 0x0670],
  <int>[0x06D6, 0x06ED],
  <int>[0x0640, 0x0640],
];

const Map<int, String> _kCharMap = <int, String>{
  0x0623: 'ا',
  0x0625: 'ا',
  0x0622: 'ا',
  0x0671: 'ا',
  0x0649: 'ي',
  0x0660: '0',
  0x0661: '1',
  0x0662: '2',
  0x0663: '3',
  0x0664: '4',
  0x0665: '5',
  0x0666: '6',
  0x0667: '7',
  0x0668: '8',
  0x0669: '9',
  0x06F0: '0',
  0x06F1: '1',
  0x06F2: '2',
  0x06F3: '3',
  0x06F4: '4',
  0x06F5: '5',
  0x06F6: '6',
  0x06F7: '7',
  0x06F8: '8',
  0x06F9: '9',
};

String normalizeAr(String text) {
  final StringBuffer out = StringBuffer();
  for (final int r in text.runes) {
    bool skip = false;
    for (final List<int> range in _kStripRanges) {
      if (r >= range[0] && r <= range[1]) {
        skip = true;
        break;
      }
    }
    if (skip) continue;
    final String? mapped = _kCharMap[r];
    out.write(mapped ?? String.fromCharCode(r));
  }
  return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}
