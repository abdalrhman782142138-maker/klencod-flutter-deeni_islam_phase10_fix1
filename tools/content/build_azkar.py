#!/usr/bin/env python3
"""يتحقق من ملف الأذكار القانوني ويكتب assets/azkar/azkar.json الذي يُضمَّن في التطبيق.

لا يولّد أذكاراً ولا يحوّلها من مصدر بعينه. يدخل إليه ملف بالمخطط أدناه (يُنتَج من مصدر موثق
مرخّص بمحوّل يُكتب عند اعتماد المصدر)، ويفشل عند أي خلل.

المخطط:
{ "schema": 1,
  "source": {"name": "...", "url": "...", "license": "...", "license_url": "...", "version": "..."},
  "categories": [ {"id": "morning", "title_ar": "...",
        "items": [ {"id": "1", "text": "...", "count": 3 | null, "reference": "..." | null, "notes": "..." | null} ]} ] }

الاستخدام: build_azkar.py --input canonical.json --out ../../assets/azkar/azkar.json
"""
import argparse, hashlib, json, os, re, sys
from arnorm import normalize_ar

REQUIRED_CATEGORIES = ["morning", "evening", "sleep", "wake", "after_prayer"]


class BuildError(Exception):
    pass


def validate(data, required=REQUIRED_CATEGORIES):
    if not isinstance(data, dict) or data.get("schema") != 1:
        raise BuildError("schema غير مدعوم (المتوقع 1)")
    src = data.get("source") or {}
    for k in ("name", "url", "license", "license_url", "version"):
        if not str(src.get(k) or "").strip():
            raise BuildError(f"بيانات المصدر ناقصة: source.{k}")
    cats = data.get("categories")
    if not isinstance(cats, list) or not cats:
        raise BuildError("لا توجد تصنيفات")
    ids, total = set(), 0
    for c in cats:
        cid = c.get("id")
        if not re.fullmatch(r"[a-z0-9_]+", str(cid or "")):
            raise BuildError(f"معرّف تصنيف غير صالح: {cid!r}")
        if cid in ids:
            raise BuildError(f"تصنيف مكرر: {cid}")
        ids.add(cid)
        if not str(c.get("title_ar") or "").strip():
            raise BuildError(f"عنوان التصنيف {cid} فارغ")
        items = c.get("items")
        if not isinstance(items, list) or not items:
            raise BuildError(f"التصنيف {cid} بلا أذكار")
        seen_ids, seen_text = set(), set()
        for it in items:
            iid = str(it.get("id") or "")
            if not iid or iid in seen_ids:
                raise BuildError(f"{cid}: معرّف ذكر مفقود أو مكرر ({iid!r})")
            seen_ids.add(iid)
            text = str(it.get("text") or "").strip()
            if not text:
                raise BuildError(f"{cid}/{iid}: نص فارغ")
            key = normalize_ar(text)
            if key in seen_text:
                raise BuildError(f"{cid}/{iid}: نص مكرر داخل التصنيف")
            seen_text.add(key)
            cnt = it.get("count")
            if cnt is not None and not (isinstance(cnt, int) and not isinstance(cnt, bool) and cnt >= 1):
                raise BuildError(f"{cid}/{iid}: عدد التكرار غير صالح ({cnt!r})")
            for opt in ("reference", "notes"):
                v = it.get(opt)
                if v is not None and not isinstance(v, str):
                    raise BuildError(f"{cid}/{iid}: الحقل {opt} يجب أن يكون نصاً")
            total += 1
    missing = [r for r in required if r not in ids]
    if missing:
        raise BuildError(f"تصنيفات مطلوبة غير موجودة: {missing}")
    return total


def build(input_path, out_path, required=REQUIRED_CATEGORIES):
    data = json.load(open(input_path, encoding="utf-8"))
    total = validate(data, required)
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    body = json.dumps(data, ensure_ascii=False, sort_keys=True, indent=1)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(body)
    return total, hashlib.sha256(body.encode("utf-8")).hexdigest()


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    try:
        n, h = build(a.input, a.out)
    except BuildError as e:
        print("فشل البناء:", e, file=sys.stderr)
        sys.exit(2)
    print(f"تم: {a.out} · {n} ذكراً · sha256={h}")
