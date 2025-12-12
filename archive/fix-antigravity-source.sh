#!/bin/bash
# Fix Antigravity's polling code at the source
# This patches the actual JavaScript code to fix the root cause

set -euo pipefail

FILE="/usr/share/antigravity/resources/app/out/jetskiAgent/main.js"
BACKUP="${FILE}.backup.$(date +%Y%m%d_%H%M%S)"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     FIXING ANTIGRAVITY POLLING CODE (SOURCE LEVEL)           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if file exists
if [ ! -f "$FILE" ]; then
    echo "❌ Error: File not found: $FILE"
    exit 1
fi

# Check if Antigravity is running
if pgrep -f "antigravity" > /dev/null; then
    echo "⚠️  WARNING: Antigravity is running!"
    echo "   Close it first, then run this script"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create backup
echo "📦 Creating backup..."
sudo cp "$FILE" "$BACKUP"
echo "✓ Backup created: $BACKUP"
echo ""

# Find polling patterns
echo "🔍 Analyzing polling patterns..."
echo ""

# Count setInterval and setTimeout calls
INTERVAL_COUNT=$(grep -o "setInterval" "$FILE" | wc -l)
TIMEOUT_COUNT=$(grep -o "setTimeout" "$FILE" | wc -l)
echo "Found $INTERVAL_COUNT setInterval calls"
echo "Found $TIMEOUT_COUNT setTimeout calls"

# Find short intervals (< 2000ms = likely polling)
echo ""
echo "Short intervals (< 2 seconds) that might be polling:"
(grep -n "setInterval" "$FILE"; grep -n "setTimeout" "$FILE") | python3 << 'PYEOF'
import sys
import re

for line in sys.stdin:
    match = re.search(r'(setInterval|setTimeout)\([^,)]*,\s*(\d+)', line)
    if match:
        func_type = match.group(1)
        interval = int(match.group(2))
        if interval < 2000:
            label = "BUSY LOOP" if interval == 0 else "aggressive polling" if interval <= 6 else "polling"
            print(f"  Line {line.split(':')[0]}: {func_type} {interval}ms ({label})")
PYEOF

echo ""
echo "📝 Creating Python script to patch the code..."
echo ""

# Create Python patching script
cat > /tmp/patch_antigravity.py << 'PYEOF'
#!/usr/bin/env python3
"""
Patch Antigravity's polling code to fix high CPU usage.

This script:
1. Finds setInterval calls with short intervals (< 2000ms)
2. Increases them to reasonable values (2000ms+)
3. Preserves the code structure
"""

import re
import sys
import shutil
from pathlib import Path

def patch_polling_intervals(content):
    """Patch setInterval and setTimeout calls with short intervals."""
    
    changes = []
    
    # Pattern 1: setInterval(func, number)
    # Matches: setInterval(U4t, 100) or setInterval((), 100)
    pattern1 = r'setInterval\(([^,)]+),\s*(\d+)([^0-9,])'
    
    def replace_interval1(match):
        func = match.group(1)
        interval = int(match.group(2))
        suffix = match.group(3)
        
        # Handle busy loops (0ms) and extremely aggressive polling (1-6ms)
        if interval < 2000 and interval >= 0:
            if interval == 0:
                new_interval = 2000  # Busy loop -> 2 seconds
            elif interval <= 6:
                new_interval = 2000  # 1-6ms busy loops -> 2 seconds
            elif interval < 100:
                new_interval = 2000  # Very short -> 2 seconds
            elif interval < 500:
                new_interval = 2000  # Short -> 2 seconds
            elif interval < 1000:
                new_interval = 2000  # Less than 1s -> 2 seconds
            else:
                new_interval = interval * 2  # Double it
            
            changes.append(f"  Line ~{content[:match.start()].count(chr(10))}: setInterval {interval}ms -> {new_interval}ms")
            return f'setInterval({func}, {new_interval}{suffix}'
        
        return match.group(0)
    
    patched = re.sub(pattern1, replace_interval1, content)
    
    # Pattern 2: setInterval(func, number, ...) with comma
    pattern2 = r'setInterval\(([^,)]+),\s*(\d+),'
    
    def replace_interval2(match):
        func = match.group(1)
        interval = int(match.group(2))
        
        if interval < 2000 and interval >= 0:
            if interval == 0:
                new_interval = 2000
            elif interval <= 6:
                new_interval = 2000
            elif interval < 100:
                new_interval = 2000
            elif interval < 500:
                new_interval = 2000
            elif interval < 1000:
                new_interval = 2000
            else:
                new_interval = interval * 2
            
            changes.append(f"  Line ~{content[:match.start()].count(chr(10))}: setInterval {interval}ms -> {new_interval}ms")
            return f'setInterval({func}, {new_interval},'
        
        return match.group(0)
    
    patched = re.sub(pattern2, replace_interval2, patched)
    
    # Pattern 3: setTimeout(func, number) - handle 0ms busy loops
    pattern3 = r'setTimeout\(([^,)]+),\s*(\d+)([^0-9,])'
    
    def replace_timeout1(match):
        func = match.group(1)
        interval = int(match.group(2))
        suffix = match.group(3)
        
        # setTimeout with 0ms or very short intervals (< 100ms) are busy loops
        if interval == 0:
            new_interval = 2000  # Busy loop -> 2 seconds
            changes.append(f"  Line ~{content[:match.start()].count(chr(10))}: setTimeout {interval}ms -> {new_interval}ms (busy loop)")
            return f'setTimeout({func}, {new_interval}{suffix}'
        elif interval < 100 and interval > 0:
            new_interval = 2000  # Very short -> 2 seconds
            changes.append(f"  Line ~{content[:match.start()].count(chr(10))}: setTimeout {interval}ms -> {new_interval}ms")
            return f'setTimeout({func}, {new_interval}{suffix}'
        
        return match.group(0)
    
    patched = re.sub(pattern3, replace_timeout1, patched)
    
    # Pattern 4: setTimeout(func, number, ...) with comma
    pattern4 = r'setTimeout\(([^,)]+),\s*(\d+),'
    
    def replace_timeout2(match):
        func = match.group(1)
        interval = int(match.group(2))
        
        if interval == 0:
            new_interval = 2000
            changes.append(f"  Line ~{content[:match.start()].count(chr(10))}: setTimeout {interval}ms -> {new_interval}ms (busy loop)")
            return f'setTimeout({func}, {new_interval},'
        elif interval < 100 and interval > 0:
            new_interval = 2000
            changes.append(f"  Line ~{content[:match.start()].count(chr(10))}: setTimeout {interval}ms -> {new_interval}ms")
            return f'setTimeout({func}, {new_interval},'
        
        return match.group(0)
    
    patched = re.sub(pattern4, replace_timeout2, patched)
    
    return patched, changes

def patch_request_animation_frame(content):
    """Add throttling to requestAnimationFrame loops."""
    
    # This is trickier - we'd need to find RAF loops and add throttling
    # For now, we'll focus on setInterval which is the main culprit
    
    # Pattern: requestAnimationFrame(function)
    # We could wrap it, but that's more complex
    # Let's skip this for now and focus on setInterval
    
    return content

def main():
    file_path = Path("/usr/share/antigravity/resources/app/out/jetskiAgent/main.js")
    
    if not file_path.exists():
        print(f"❌ File not found: {file_path}")
        sys.exit(1)
    
    print(f"📖 Reading {file_path}...")
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    original_size = len(content)
    print(f"   Original size: {original_size:,} bytes")
    print("")
    
    print("🔧 Patching setInterval and setTimeout calls...")
    patched_content, changes = patch_polling_intervals(content)
    
    if changes:
        print(f"   Made {len(changes)} changes:")
        for change in changes[:20]:  # Show first 20
            print(change)
        if len(changes) > 20:
            print(f"   ... and {len(changes) - 20} more")
    else:
        print("   No changes made (intervals already reasonable)")
    
    size_change = len(patched_content) - original_size
    if size_change != 0:
        print(f"   File size changed by {size_change} bytes")
    
    print("")
    print("💾 Writing patched file...")
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(patched_content)
    
    print("✓ File patched successfully!")
    print("")
    print("⚠️  NOTE: This patch will be overwritten when Antigravity updates.")
    print("   You may need to re-run this script after updates.")

if __name__ == "__main__":
    main()
PYEOF

chmod +x /tmp/patch_antigravity.py

echo "✓ Patching script created"
echo ""
echo "🚀 Running patch..."
echo ""

sudo python3 /tmp/patch_antigravity.py

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    PATCH COMPLETE                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "NEXT STEPS:"
echo "1. Restart Antigravity"
echo "2. Monitor CPU usage - it should be much lower"
echo ""
echo "If issues occur, restore from backup:"
echo "  sudo cp $BACKUP $FILE"
echo ""

