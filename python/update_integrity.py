#!/usr/bin/env python3
import base64
import hashlib
import json
import os
import sys

# 1. Setup
if len(sys.argv) < 2:
    print("❌ Error: Missing Argument. Usage: update_integrity.py <AG_DIR>")
    sys.exit(1)

base_dir = sys.argv[1]
product_json_path = os.path.join(base_dir, "resources/app/product.json")
file_path = os.path.join(base_dir, "resources/app/out/jetskiAgent/main.js")
target_suffix = "jetskiAgent/main.js"

if not os.path.exists(product_json_path):
    print("⚠️  product.json not found. Skipping integrity fix.")
    sys.exit(0)

# Read existing data
with open(product_json_path, "r") as f:
    data = json.load(f)

checksums = data.get("checksums", {})

# 2. Find Key
target_key = None
if "out/jetskiAgent/main.js" in checksums:
    target_key = "out/jetskiAgent/main.js"
else:
    for key in checksums.keys():
        if key.endswith(target_suffix):
            target_key = key
            break

# 3. Update Logic
needs_save = False

if target_key:
    print(f"ℹ️  Found checksum key: {target_key}")
    old_hash = checksums[target_key]

    # --- DETECTION LOGIC ---
    algo = "sha256"
    encoding = "hex"

    if len(old_hash) == 32:
        algo, encoding = "md5", "hex"
    elif len(old_hash) == 44 and old_hash.endswith("="):
        algo, encoding = "sha256", "base64"
    elif len(old_hash) == 43:
        algo, encoding = "sha256", "base64_unpadded"

    # --- GENERATION LOGIC ---
    try:
        with open(file_path, "rb") as f:
            content = f.read()
    except FileNotFoundError:
        print(f"❌ Error: Could not read target file: {file_path}")
        sys.exit(1)

    h_obj = hashlib.new(algo)
    h_obj.update(content)

    if encoding == "base64":
        new_hash = base64.b64encode(h_obj.digest()).decode("utf-8")
    elif encoding == "base64_unpadded":
        new_hash = base64.b64encode(h_obj.digest()).decode("utf-8").rstrip("=")
    else:
        new_hash = h_obj.hexdigest()

    # --- COMPARE ---
    if new_hash != old_hash:
        checksums[target_key] = new_hash
        data["checksums"] = checksums
        needs_save = True
        print(f"✓ Checksum mismatch detected. Updating (Format: {encoding})")
        print(f"  Old: {old_hash}")
        print(f"  New: {new_hash}")
    else:
        print("✓ Checksum verified and up-to-date. No changes needed.")

else:
    print("⚠️  Specific checksum key not found.")
    # Only nuke if checksums actually exist
    if "checksums" in data and data["checksums"]:
        print("☢️  NUCLEAR OPTION: Removing ALL checksums to force valid state.")
        del data["checksums"]
        needs_save = True
        print("✓ Integrity check disabled entirely.")
    else:
        print("ℹ️  Checksums already empty or missing.")

# 4. Write (Only if changed)
if needs_save:
    try:
        with open(product_json_path, "w") as f:
            json.dump(data, f, indent=2)
        print("💾 product.json updated successfully.")
    except Exception as e:
        print(f"❌ Error writing product.json: {e}")
        sys.exit(1)
