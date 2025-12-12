#!/usr/bin/env bash
# Balanced Antigravity agent UI patch:
# - Targets jetskiAgent/main.js only (agent renderer)
# - Throttles busy timers moderately (keeps UI responsive)
# - Leaves workbench untouched
# - Makes a dated backup for rollback

set -euo pipefail

JETSKI_FILE="/usr/share/antigravity/resources/app/out/jetskiAgent/main.js"
BACKUP_DIR="/tmp/antigravity_backups_$(date +%Y%m%d_%H%M%S)"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        BALANCED ANTIGRAVITY AGENT PATCH (TIMERS)             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [ ! -f "$JETSKI_FILE" ]; then
  echo "❌ File not found: $JETSKI_FILE"
  exit 1
fi

mkdir -p "$BACKUP_DIR"

# Backup
sudo cp "$JETSKI_FILE" "$BACKUP_DIR/main.js.backup"
echo "✓ Backup created at $BACKUP_DIR/main.js.backup"

sudo python3 <<'PY'
import re, sys

file_path = "/usr/share/antigravity/resources/app/out/jetskiAgent/main.js"

with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
    content = f.read()

changes = []

def line_no(pos: int) -> int:
    return content.count("\n", 0, pos) + 1

# setInterval throttling: sub-1s -> ~1.2–1.5s
def patch_interval(match):
    func, interval, suffix = match.group(1), int(match.group(2)), match.group(3)
    if interval < 1000 and interval >= 0:
        if interval <= 200:
            new = 1200
        else:
            new = 1500
        changes.append(f"Line ~{line_no(match.start())}: setInterval {interval} -> {new}")
        return f"setInterval({func}, {new}{suffix}"
    return match.group(0)

content = re.sub(r"setInterval\(([^,)]+),\s*(\d+)([^0-9,])", patch_interval, content)
content = re.sub(r"setInterval\(([^,)]+),\s*(\d+),", lambda m: patch_interval(m) if 0 <= int(m.group(2)) < 1000 else m.group(0), content)

# setTimeout throttling: 0–200ms -> 1200ms; 200–1000ms -> 1500ms
def patch_timeout(match):
    func, interval, suffix = match.group(1), int(match.group(2)), match.group(3)
    if interval == 0 or interval <= 200:
        new = 1200
    elif interval < 1000:
        new = 1500
    else:
        return match.group(0)
    changes.append(f"Line ~{line_no(match.start())}: setTimeout {interval} -> {new}")
    return f"setTimeout({func}, {new}{suffix}"

content = re.sub(r"setTimeout\(([^,)]+),\s*(\d+)([^0-9,])", patch_timeout, content)
content = re.sub(r"setTimeout\(([^,)]+),\s*(\d+),", lambda m: patch_timeout(m) if int(m.group(2)) < 1000 else m.group(0), content)

# requestAnimationFrame -> setTimeout 1000ms (1 FPS)
raf_count = len(re.findall(r"requestAnimationFrame\(", content))
if raf_count:
    content = re.sub(r"requestAnimationFrame\(([^)]+)\)", r"setTimeout(\1, 1000)", content)
    changes.append(f"Throttled {raf_count} requestAnimationFrame calls to 1000ms")

# queueMicrotask -> setTimeout 50ms (break microtask storms)
qm_count = len(re.findall(r"queueMicrotask\(", content))
if qm_count:
    content = re.sub(r"queueMicrotask\(([^)]+)\)", r"setTimeout(\1, 50)", content)
    changes.append(f"Throttled {qm_count} queueMicrotask calls to 50ms")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

if changes:
    print(f"✓ Patched jetskiAgent/main.js with {len(changes)} changes:")
    for c in changes[:30]:
        print("  -", c)
    if len(changes) > 30:
        print(f"  ... and {len(changes) - 30} more")
else:
    print("No changes applied (timers already above thresholds)")
PY

echo ""
echo "DONE. Balanced timers applied to jetskiAgent/main.js only."
echo "Backup: $BACKUP_DIR/main.js.backup"
echo "Restore with: sudo cp $BACKUP_DIR/main.js.backup $JETSKI_FILE"

