#!/usr/bin/env python3
"""يضغط قواعد المكتبات (gzip حتمي) ويولّد manifest.json بالأحجام وبصمات SHA-256، ويوقّعه اختيارياً.

الاستخدام:
  make_manifest.py --version 1 --base-url https://HOST/PATH --out dist \
      quran=quran.db bukhari=bukhari.db muslim=muslim.db [--sign key.pem]

الملفات الناتجة في dist/: <id>.db.gz و manifest.json و manifest.json.sig (عند التوقيع).
"""
import argparse, base64, gzip, hashlib, json, os, shutil, sqlite3, sys

TITLES = {"quran": "القرآن الكريم", "bukhari": "صحيح البخاري", "muslim": "صحيح مسلم"}


def sha256_file(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def gzip_deterministic(src, dst):
    with open(src, "rb") as fi, open(dst, "wb") as fo:
        with gzip.GzipFile(filename="", mode="wb", fileobj=fo, mtime=0, compresslevel=9) as g:
            shutil.copyfileobj(fi, g)


def build(version, base_url, out, libs, sign_key=None):
    os.makedirs(out, exist_ok=True)
    entries = []
    for lib_id, path in libs:
        db = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        meta = dict(db.execute("SELECT key, value FROM meta")); db.close()
        gz = os.path.join(out, f"{lib_id}.db.gz")
        gzip_deterministic(path, gz)
        entries.append({
            "id": lib_id, "title_ar": TITLES.get(lib_id, lib_id),
            "file": os.path.basename(gz), "url": f"{base_url.rstrip('/')}/{os.path.basename(gz)}",
            "size_compressed": os.path.getsize(gz), "sha256_compressed": sha256_file(gz),
            "size": os.path.getsize(path), "sha256": sha256_file(path),
            "records": int(meta.get("ayah_count") or meta.get("hadith_count") or 0),
            "source": meta.get("source"), "license": meta.get("license"),
            "db_schema": int(meta.get("schema_version", 0)),
        })
    manifest = {"schema": 1, "content_version": version, "libraries": entries,
                "total_size_compressed": sum(e["size_compressed"] for e in entries),
                "total_size": sum(e["size"] for e in entries)}
    data = json.dumps(manifest, ensure_ascii=False, sort_keys=True, indent=2).encode("utf-8")
    mp = os.path.join(out, "manifest.json")
    with open(mp, "wb") as f:
        f.write(data)
    if sign_key:
        from cryptography.hazmat.primitives import serialization
        key = serialization.load_pem_private_key(open(sign_key, "rb").read(), password=None)
        with open(mp + ".sig", "w") as f:
            f.write(base64.b64encode(key.sign(data)).decode())
    return manifest


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--version", type=int, required=True)
    p.add_argument("--base-url", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--sign")
    p.add_argument("libs", nargs="+", help="id=path")
    a = p.parse_args()
    libs = [tuple(x.split("=", 1)) for x in a.libs]
    m = build(a.version, a.base_url, a.out, libs, a.sign)
    for e in m["libraries"]:
        print(f"{e['id']}: {e['size_compressed']:,} B (مضغوط) / {e['size']:,} B · {e['records']} سجلاً")
    print(f"المجموع المضغوط: {m['total_size_compressed']:,} B")
