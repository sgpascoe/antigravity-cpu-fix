#!/usr/bin/env python3
import hashlib
import os
import re
import sys

# 1. Validation
if len(sys.argv) < 2:
    print("❌ Error: Missing Argument. Usage: patch_code.py <AG_DIR>")
    sys.exit(1)

base_dir = sys.argv[1]
file_path = os.path.join(base_dir, "resources/app/out/jetskiAgent/main.js")
print(f"Targeting: {file_path}")

try:
    with open(file_path, "rb") as f:
        content = f.read()
except FileNotFoundError:
    print(f"❌ Critical: Could not find main.js at {file_path}")
    sys.exit(1)

original_hash = hashlib.md5(content).hexdigest()

# --- STRATEGY: The "SlowMo" Helper ---

# 1. Inject the Helper at top
#    - Uses a Universal Fetch Interceptor (Works in Renderer & Node)
#    - Reverted to (fn) for consistency
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
}
const __slowMo = (fn) => setTimeout(fn, 1200);
"""

# Match the double quotes used in the polyfill variable above
if b'u.includes("antigravity")' not in content:
    content = polyfill + b"\n" + content
    print("✓ Injected isolated '__slowMo' and fetch interceptor")

# 2. Replace 'queueMicrotask' -> '__slowMo'
content = re.sub(rb"\bqueueMicrotask\b", b"__slowMo", content)

# 3. Replace 'requestAnimationFrame' -> '__slowMo'
content = re.sub(rb"\brequestAnimationFrame\b", b"__slowMo", content)


# 4. Patch setInterval safely
def boost_interval(match):
    prefix = match.group(1)
    func_arg = match.group(2)
    return prefix + func_arg + b", 1200)"


content = re.sub(rb"(setInterval\s*\()(.*?),(\s*\d{1,3}\s*\))", boost_interval, content)

# 5. Write changes
new_hash = hashlib.md5(content).hexdigest()

if new_hash != original_hash:
    try:
        with open(file_path, "wb") as f:
            f.write(content)
        print("✓ Patched jetskiAgent/main.js successfully")
        print(f"  New Hash: {new_hash}")
    except Exception as e:
        print(f"❌ Error writing file: {e}")
        sys.exit(1)
else:
    print("⚠️  No changes made (File is already patched)")
