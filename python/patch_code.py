#!/usr/bin/env python3
import hashlib
import os
import sys

if len(sys.argv) < 2:
    print("❌ Error: Missing Argument. Usage: patch_code.py <AG_DIR>")
    sys.exit(1)

base_dir = sys.argv[1]

# The primary entry point - jetskiAgent/main.js
# Note: resources/app/out/main.js is experimental and disabled for now
target_files = ["resources/app/out/jetskiAgent/main.js"]

polyfill = b"""{
  const _f = globalThis.fetch;
  if (_f) {
    globalThis.fetch = (u, o) => {
      if (typeof u === "string" && u.includes("antigravity")) {
        return Promise.reject(new TypeError("Blocked by Antigravity Patch"));
      }
      return _f(u, o);
    };
  }
  const _si = globalThis.setInterval;
  globalThis.setInterval = (fn, ms, ...args) => {
    if (typeof ms === 'number' && ms < 1000) ms = 1200;
    return _si(fn, ms, ...args);
  };
  globalThis.queueMicrotask = (fn) => setTimeout(fn, 1200);
  globalThis.requestAnimationFrame = (fn) => setTimeout(fn, 1200);
}
const __slowMo = (fn) => setTimeout(fn, 1200);
"""

for rel_path in target_files:
    file_path = os.path.join(base_dir, rel_path)
    if not os.path.exists(file_path):
        print(f"⚠️  Skipping: {rel_path} (Not found)")
        continue

    with open(file_path, "rb") as f:
        content = f.read()

    original_hash = hashlib.md5(content).hexdigest()

    if b"Blocked by Antigravity Patch" not in content:
        content = polyfill + b"\n" + content
        new_hash = hashlib.md5(content).hexdigest()

        try:
            with open(file_path, "wb") as f:
                f.write(content)
            print(f"✅ Patched: {rel_path}")
            print(f"  New Hash: {new_hash}")
        except Exception as e:
            print(f"❌ Error writing {rel_path}: {e}")
    else:
        print(f"ℹ️  Already Patched: {rel_path}")
