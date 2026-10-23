# الحصول على المحتوى الفعلي (القرآن والبخاري ومسلم)

بيئة البناء عندي بلا إنترنت، فالتنزيل يتم على جهازك بأمر واحد.

## أسهل طريقة (بحساب GitHub، من المتصفح أو الهاتف)
1. أنشئ مستودعاً جديداً (مثل `deeni-content`) وارفع إليه مجلد المشروع (أو ملفات `tools/content/`).
2. من زر **Code ← Codespaces ← Create codespace** (مجاني ضمن حصة شهرية).
3. في الطرفية:
   ```
   python3 tools/content/fetch_and_build.py --out build
   ```
4. سيعرض ترخيص hadith-api كما في مستودعه ويسألك «نعم؟». ثم يبني `quran.db` و`bukhari.db` و`muslim.db` ويفحصها،
   ويكتب `build/report.txt` (الأعداد والأحجام والبصمات).
5. أرسل لي `report.txt` (أو الملفات)، فأكمل الاختبار على القرآن الحقيقي وأضبط ما يلزم.

## إن فشل تنزيل Tanzil آلياً
حمّل يدوياً من http://tanzil.net/download/ : النوع **Uthmani**، الصيغة **Text (with aya numbers)** وكل علامات الوقف مفعّلة،
وحمّل http://tanzil.net/res/text/metadata/quran-data.xml ثم:
```
python3 tools/content/fetch_and_build.py --out build --quran-text quran-uthmani.txt --quran-meta quran-data.xml
```

## شروط الاستخدام (يجب احترامها)
- **Tanzil:** النسخ حرفي ولا يجوز تغيير النص؛ يُذكر المصدر (Tanzil Project) مع رابط tanzil.net؛ وإشعار الحقوق يبقى في الملفات المشتقة
  (الأداة تحفظه في `meta.license_notice` وترفض الملف إن غاب).
- **hadith-api:** يحمل الترخيص المذكور في مستودعه، لكنه لا يحسم حقوق النص نفسه، وطبعة النص العربي المطبوعة غير موثقة.
