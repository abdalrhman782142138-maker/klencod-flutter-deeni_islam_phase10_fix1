#!/usr/bin/env python3
"""يولّد زوج مفاتيح Ed25519 لتوقيع manifest. شغّله على جهازك أنت.
المفتاح الخاص يبقى عندك ولا يُرفع ولا يُرسل لأي أحد (ولا لي).
المفتاح العام (32 بايت base64) هو ما يُضمَّن في التطبيق."""
import base64, os, sys
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

out = sys.argv[1] if len(sys.argv) > 1 else "deeni_signing_private.pem"
if os.path.exists(out):
    sys.exit(f"{out} موجود؛ لن أستبدله")
k = Ed25519PrivateKey.generate()
fd = os.open(out, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, "wb") as f:
    f.write(k.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                            serialization.NoEncryption()))
pub = k.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
print("PUBLIC_KEY_B64 =", base64.b64encode(pub).decode())
