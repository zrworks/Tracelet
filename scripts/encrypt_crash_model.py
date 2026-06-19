#!/usr/bin/env python3
"""Encrypt a crash-detection model JSON into the Tracelet encrypted-blob format.

Blob layout (matches `CrashModel::from_encrypted` in the Rust core):

    [0x01][nonce:12 bytes][ciphertext + GCM tag]

AES-256-GCM with a 32-byte key. The plaintext is the random-forest JSON the
training notebook emits (the `*_rf_trees.json` file).

The encrypted blob is what you host at `crashModelUrl`; the 32-byte key is the
runtime secret you inject into `CrashModelLoader.decryptionKey` (Android) — it is
NEVER committed.

Usage:
    python3 scripts/encrypt_crash_model.py <model.json> [-o out.crashmodel] [--key <base64-32-bytes>]

If --key is omitted a fresh random key is generated and printed (base64). The
script prints the key (base64), the output path, and the blob's SHA-256 (hex) so
you can set `crashModelSha256`.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import os
import sys

try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
except ImportError:
    sys.exit(
        "Missing dependency: pip install cryptography\n"
        "(needed for AES-256-GCM encryption)"
    )


def main() -> int:
    ap = argparse.ArgumentParser(description="Encrypt a crash model JSON for Tracelet.")
    ap.add_argument("model_json", help="Path to the *_rf_trees.json model file.")
    ap.add_argument(
        "-o",
        "--output",
        help="Output blob path (default: <model>.crashmodel, which is gitignored).",
    )
    ap.add_argument(
        "--key",
        help="Base64-encoded 32-byte AES key. Omit to generate a fresh random key.",
    )
    args = ap.parse_args()

    if not os.path.isfile(args.model_json):
        sys.exit(f"Model file not found: {args.model_json}")

    with open(args.model_json, "rb") as f:
        plaintext = f.read()

    # Validate it is the expected forest JSON before encrypting (fail fast).
    try:
        import json

        doc = json.loads(plaintext)
        feats = doc.get("features")
        trees = doc.get("trees")
        if not isinstance(feats, list) or not isinstance(trees, list) or not trees:
            sys.exit("Model JSON missing non-empty 'features'/'trees' — wrong file?")
    except ValueError as e:
        sys.exit(f"Model file is not valid JSON: {e}")

    if args.key:
        key = base64.b64decode(args.key)
        if len(key) != 32:
            sys.exit(f"--key must decode to 32 bytes, got {len(key)}")
    else:
        key = os.urandom(32)

    nonce = os.urandom(12)
    ciphertext = AESGCM(key).encrypt(nonce, plaintext, None)
    blob = bytes([0x01]) + nonce + ciphertext

    out_path = args.output or (os.path.splitext(args.model_json)[0] + ".crashmodel")
    with open(out_path, "wb") as f:
        f.write(blob)

    sha256 = hashlib.sha256(blob).hexdigest()

    print(f"model features : {feats}")
    print(f"trees          : {len(trees)}")
    print(f"plaintext bytes: {len(plaintext):,}")
    print(f"blob bytes     : {len(blob):,}")
    print(f"output         : {out_path}")
    print(f"crashModelSha256: {sha256}")
    print(f"AES key (base64): {base64.b64encode(key).decode()}")
    print(
        "\nKeep the key secret (inject into CrashModelLoader.decryptionKey at runtime)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
