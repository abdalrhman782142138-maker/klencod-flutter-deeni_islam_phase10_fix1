#!/usr/bin/env python3
"""ينزّل القرآن (Tanzil) والبخاري ومسلم (hadith-api) من مصادرها، ويبنيها ويتحقق منها بأدوات المشروع.

يعمل على جهازك أنت (Python 3.8+ دون حزم إضافية، ويحتاج إنترنت). المخرجات في --out:
  quran.db  bukhari.db  muslim.db   +  downloads/ (الملفات الأصلية)  +  report.txt (بصمات SHA-256 وأعداد وأحجام)

الأمر:
  python3 fetch_and_build.py --out build

ضمانات:
  • لا يعدّل نص المصدر. يفشل عند أي نقص ولا يُنتج قاعدة ناقصة.
  • يعرض نص ترخيص hadith-api كما ورد في المستودع ويطلب تأكيدك قبل المتابعة (أو --yes).
  • يسجّل بصمات الملفات الأصلية في report.txt لتثبيتها (pin) وإعادة الإنتاج لاحقاً.
المصادر (روابط رسمية/موثقة):
  Tanzil:  http://tanzil.net/download/  (الشروط: نسخ حرفي، لا تغيير للنص، ذكر المصدر ورابط tanzil.net)
  بيانات السور: http://tanzil.net/res/text/metadata/quran-data.xml
  hadith-api: https://github.com/fawazahmed0/hadith-api  (عبر jsDelivr بنسخة مثبتة @1)
"""
import argparse, hashlib, json, os, re, sys, time, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_quran_db as bq
import build_hadith_db as bh
import verify_library as vl

DEFAULTS = {
    # رابط نموذج التنزيل الرسمي في Tanzil (يمثل الخيارات: نص عثماني برقم الآية، مع علامات الوقف والسجدة)
    "tanzil_text": "http://tanzil.net/pub/download/index.php?marks=true&sajdah=true&rub=true&alef=true"
                   "&quranType=uthmani&outType=txt-2&agree=true",
    "tanzil_meta": "http://tanzil.net/res/text/metadata/quran-data.xml",
    "hadith_base": "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1",
    "hadith_license": "https://raw.githubusercontent.com/fawazahmed0/hadith-api/1/LICENSE",
}
UA = {"User-Agent": "DeeniIslam-content-builder/1.0 (+offline Islamic app; contact: owner)"}


class Fail(Exception):
    pass


def sha256_bytes(b):
    return hashlib.sha256(b).hexdigest()


def download(url, dest, retries=3, timeout=60):
    """تنزيل إلى ملف مؤقت ثم إعادة تسمية. يعيد (sha256, size)."""
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    last = None
    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r, open(dest + ".part", "wb") as f:
                h = hashlib.sha256(); n = 0
                while True:
                    chunk = r.read(1 << 16)
                    if not chunk:
                        break
                    f.write(chunk); h.update(chunk); n += len(chunk)
            if n == 0:
                raise Fail("ملف فارغ")
            os.replace(dest + ".part", dest)
            return h.hexdigest(), n
        except (urllib.error.URLError, OSError, Fail) as e:
            last = e
            time.sleep(1.5 * attempt)
    raise Fail(f"تعذّر تنزيل {url}: {last}")


def find_last_number(info, edition):
    """يبحث في info.json عن last_hadithnumber الخاص بإصدار؛ شكل الملف غير مؤكد فلا يُخمَّن: يعيد None إن لم يجد."""
    found = []

    def walk(node, path):
        if isinstance(node, dict):
            if "last_hadithnumber" in node and any(edition in p for p in path):
                found.append(node["last_hadithnumber"])
            for k, v in node.items():
                walk(v, path + [str(k)])
        elif isinstance(node, list):
            for i, v in enumerate(node):
                walk(v, path + [str(i)])
    walk(info, [])
    ints = [int(float(x)) for x in found if isinstance(x, (int, float, str)) and re.fullmatch(r"\d+(\.\d+)?", str(x))]
    return max(ints) if ints else None


def build_quran(dl, out, urls, log):
    text = os.path.join(dl, "quran-uthmani.txt")
    meta = os.path.join(dl, "quran-data.xml")
    h1, s1 = download(urls["tanzil_text"], text)
    h2, s2 = download(urls["tanzil_meta"], meta)
    head = open(text, encoding="utf-8").read(4000)
    if "Tanzil" not in head or "Creative Commons" not in head:
        raise Fail("ملف النص لا يحوي إشعار Tanzil/الترخيص في رأسه. حمّله يدوياً من http://tanzil.net/download/ (نص عثماني، صيغة «text with aya numbers»)"
                   " ثم أعد التشغيل مع --quran-text و--quran-meta.")
    return finish_quran(text, meta, out, (h1, s1), (h2, s2), log)


def finish_quran(text, meta, out, th, mh, log):
    db = os.path.join(out, "quran.db")
    r = bq.build(text, meta, db, "tanzil-1.1")
    problems = vl.verify(db)
    if problems:
        raise Fail("فحص quran.db فشل: " + "; ".join(problems))
    log.append(f"quran.db: {r['surah_count']} سورة، {r['ayah_count']} آية، {os.path.getsize(db):,} بايت")
    log.append(f"  نص Tanzil sha256={th[0]} ({th[1]:,} بايت)")
    log.append(f"  بيانات السور sha256={mh[0]} ({mh[1]:,} بايت)")


def build_hadith(dl, out, urls, log, assume_yes):
    base = urls["hadith_base"].rstrip("/")
    lic_path = os.path.join(dl, "hadith-api-LICENSE.txt")
    lh, _ = download(urls["hadith_license"], lic_path)
    lic_text = open(lic_path, encoding="utf-8", errors="replace").read()
    first = next((l.strip() for l in lic_text.splitlines() if l.strip()), "")
    print("\n──────── ترخيص hadith-api كما ورد في المستودع (أول 12 سطراً) ────────")
    print("\n".join(lic_text.splitlines()[:12]))
    print("──────────────────────────────────────────────────────────────────\n"
          "تنبيه: ترخيص المستودع يخص مشروعه، ولا يحسم حقوق نصوص الأحاديث نفسها. طبعة النص العربي المطبوعة غير موثقة\n"
          "في المصدر (حقول المؤلف/المصدر: Unknown)؛ سيذكر التطبيق ذلك ولا يدّعي مطابقة طبعة محددة.")
    if not assume_yes:
        if input("هل قرأتَ الترخيص وتقبل استخدام هذا المصدر؟ اكتب نعم للمتابعة: ").strip() not in ("نعم", "y", "yes", "Y"):
            raise Fail("أُوقف بطلبك قبل بناء مكتبتي الحديث.")
    try:
        info_h, _ = download(f"{base}/info.json", os.path.join(dl, "hadith-info.json"))
        info = json.load(open(os.path.join(dl, "hadith-info.json"), encoding="utf-8"))
    except Fail:
        info, info_h = {}, "-"
    for lib, edition, title in (("bukhari", "ara-bukhari", "صحيح البخاري"), ("muslim", "ara-muslim", "صحيح مسلم")):
        path = os.path.join(dl, f"{edition}.json")
        h, size = download(f"{base}/editions/{edition}.json", path)
        expected_last = find_last_number(info, edition)
        ns = argparse.Namespace(edition=path, library=lib, title=title, out=os.path.join(out, f"{lib}.db"),
                                source="fawazahmed0/hadith-api", source_version=f"{base.split('@')[-1]} sha256:{h[:12]}",
                                license=first, license_url=urls["hadith_license"], numbering="hadith-api hadithnumber",
                                expected_last=expected_last, expected_count=None, allow_empty=0, fts=False)
        r = bh.build(ns)
        problems = vl.verify(ns.out)
        if problems:
            raise Fail(f"فحص {lib}.db فشل: " + "; ".join(problems))
        log.append(f"{lib}.db: {r['hadith_count']} حديثاً، {r['book_count']} كتاباً، آخر رقم {r['last_number']}"
                   f" (المرجع من info.json: {expected_last if expected_last is not None else 'لم يُعثر عليه؛ قارن الأعداد يدوياً'}),"
                   f" {os.path.getsize(ns.out):,} بايت")
        log.append(f"  {edition}.json sha256={h} ({size:,} بايت)")
    log.append(f"  info.json sha256={info_h}; LICENSE sha256={lh}")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="build")
    ap.add_argument("--skip-quran", action="store_true")
    ap.add_argument("--skip-hadith", action="store_true")
    ap.add_argument("--yes", action="store_true", help="تخطي سؤال تأكيد الترخيص (للتشغيل الآلي بعد قراءته)")
    ap.add_argument("--quran-text", help="ملف نص Tanzil محمّل يدوياً بدل التنزيل")
    ap.add_argument("--quran-meta", help="ملف quran-data.xml محمّل يدوياً")
    for k in DEFAULTS:
        ap.add_argument("--" + k.replace("_", "-"), default=DEFAULTS[k])
    a = ap.parse_args(argv)
    urls = {k: getattr(a, k) for k in DEFAULTS}
    out = os.path.abspath(a.out); dl = os.path.join(out, "downloads"); os.makedirs(dl, exist_ok=True)
    log = [f"تاريخ البناء (UTC): {time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime())}"]
    try:
        if not a.skip_quran:
            if a.quran_text and a.quran_meta:
                th = (sha256_bytes(open(a.quran_text, 'rb').read()), os.path.getsize(a.quran_text))
                mh = (sha256_bytes(open(a.quran_meta, 'rb').read()), os.path.getsize(a.quran_meta))
                finish_quran(a.quran_text, a.quran_meta, out, th, mh, log)
            else:
                build_quran(dl, out, urls, log)
        if not a.skip_hadith:
            build_hadith(dl, out, urls, log, a.yes)
    except (Fail, bq.BuildError, bh.BuildError) as e:
        print("\nفشل: " + str(e), file=sys.stderr)
        return 2
    report = "\n".join(log)
    open(os.path.join(out, "report.txt"), "w", encoding="utf-8").write(report + "\n")
    print("\n" + report + f"\n\nتم. المخرجات في: {out}\nالخطوة التالية: make_manifest.py ثم الرفع إلى GitHub Release.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
