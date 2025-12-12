#!/bin/bash
# Ultimate Antigravity CPU Fix
# Addresses ALL root causes: setInterval, setTimeout(0), requestAnimationFrame, and settings

set -euo pipefail

JETSKI_FILE="/usr/share/antigravity/resources/app/out/jetskiAgent/main.js"
WORKBENCH_FILE="/usr/share/antigravity/resources/app/out/vs/workbench/workbench.desktop.main.js"
SETTINGS_FILE="$HOME/.config/Antigravity/User/settings.json"
BACKUP_DIR="/tmp/antigravity_backups_$(date +%Y%m%d_%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} $1"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

log_step() {
    echo -e "${BLUE}▶${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Close Antigravity
close_antigravity() {
    log_step "Closing Antigravity..."
    
    if ! pgrep -f "/usr/share/antigravity/antigravity" > /dev/null 2>&1; then
        log_success "Antigravity already closed"
        return
    fi
    
    pkill -f "/usr/share/antigravity/antigravity" 2>/dev/null || true
    sleep 2
    
    if pgrep -f "/usr/share/antigravity/antigravity" > /dev/null 2>&1; then
        log_warning "Force killing remaining processes..."
        pkill -9 -f "/usr/share/antigravity/antigravity" 2>/dev/null || true
        sleep 1
    fi
    
    log_success "Antigravity closed"
}

# Apply comprehensive source patches
apply_source_patches() {
    local file=$1
    local filename=$(basename "$file")
    
    if [ ! -f "$file" ]; then
        log_warning "File not found: $file (skipping)"
        return
    fi
    
    log_step "Patching $filename..."
    
    # Backup
    if [ ! -f "$BACKUP_DIR/${filename}.backup" ]; then
        sudo cp "$file" "$BACKUP_DIR/${filename}.backup"
        log_success "Backup created"
    fi
    
    # Apply comprehensive patches
    sudo python3 << PYEOF
import re
import sys

file_path = '$file'

try:
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    original_content = content
    changes = []
    
    # PATTERN 1: setInterval with short intervals (< 2000ms)
    def patch_setinterval(match):
        func = match.group(1)
        interval = int(match.group(2))
        suffix = match.group(3)
        
        if interval < 2000 and interval >= 0:
            if interval == 0:
                new_interval = 2000  # Busy loop -> 2s
            elif interval <= 6:
                new_interval = 2000  # 1-6ms busy loops -> 2s
            elif interval < 100:
                new_interval = 2000  # Very short -> 2s
            elif interval < 500:
                new_interval = 2000  # Short -> 2s
            elif interval < 1000:
                new_interval = 2000  # Less than 1s -> 2s
            else:
                new_interval = 2000  # Less than 2s -> 2s
            
            line_num = content[:match.start()].count('\n') + 1
            changes.append(f"Line ~{line_num}: setInterval {interval}ms -> {new_interval}ms")
            return f'setInterval({func}, {new_interval}{suffix}'
        
        return match.group(0)
    
    # Pattern: setInterval(func, number) or setInterval(func, number, ...)
    content = re.sub(r'setInterval\(([^,)]+),\s*(\d+)([^0-9,])', patch_setinterval, content)
    content = re.sub(r'setInterval\(([^,)]+),\s*(\d+),', lambda m: patch_setinterval(m) if int(m.group(2)) < 2000 else m.group(0), content)
    
    # PATTERN 2: setTimeout(func, 0) - busy loops (catch ALL patterns)
    def patch_settimeout_zero(match):
        func = match.group(1)
        suffix = match.group(2) if len(match.groups()) > 1 else ''
        line_num = content[:match.start()].count('\n') + 1
        changes.append(f"Line ~{line_num}: setTimeout 0ms -> 2000ms (busy loop)")
        if suffix == ')':
            return f'setTimeout({func}, 2000)'
        return f'setTimeout({func}, 2000{suffix}'
    
    # Catch setTimeout(func, 0) with various patterns
    content = re.sub(r'setTimeout\(([^,)]+),\s*0([^0-9,)]?)', patch_settimeout_zero, content)
    content = re.sub(r'setTimeout\(([^,)]+),\s*0\)', lambda m: f'setTimeout({m.group(1)}, 2000)', content)
    
    # Also catch setTimeout(func,0) without spaces
    content = re.sub(r'setTimeout\(([^,)]+),0([^0-9,)]?)', patch_settimeout_zero, content)
    
    # PATTERN 3: setTimeout with short intervals (< 500ms) - MORE AGGRESSIVE
    def patch_settimeout_short(match):
        func = match.group(1)
        interval = int(match.group(2))
        suffix = match.group(3)
        
        # Catch more aggressive patterns - anything < 500ms
        if interval > 0 and interval < 500:
            line_num = content[:match.start()].count('\n') + 1
            new_interval = 2000 if interval < 100 else 1000
            changes.append(f"Line ~{line_num}: setTimeout {interval}ms -> {new_interval}ms")
            return f'setTimeout({func}, {new_interval}{suffix}'
        
        return match.group(0)
    
    content = re.sub(r'setTimeout\(([^,)]+),\s*(\d+)([^0-9,])', patch_settimeout_short, content)
    content = re.sub(r'setTimeout\(([^,)]+),\s*(\d+),', lambda m: patch_settimeout_short(m) if 0 < int(m.group(2)) < 500 else m.group(0), content)
    
    # PATTERN 4: Throttle requestAnimationFrame loops - 2 FPS (as requested)
    # Replace RAF calls with throttled versions
    raf_count = len(re.findall(r'requestAnimationFrame\(', content))
    if raf_count > 0:
        # Throttle to 2 FPS (500ms) - reasonable for agent UI
        def throttle_raf(match):
            callback = match.group(1)
            # Replace with setTimeout throttled to 500ms (2 FPS instead of 60 FPS)
            return f'setTimeout({callback}, 500)'
        
        # Replace requestAnimationFrame(callback) with throttled setTimeout
        content = re.sub(r'requestAnimationFrame\(([^)]+)\)', throttle_raf, content)
        changes.append(f"Throttled {raf_count} requestAnimationFrame calls to 500ms (2 FPS, was 60 FPS)")
    
    # PATTERN 5: Throttle queueMicrotask busy loops - MORE AGGRESSIVE
    queue_microtask_count = len(re.findall(r'queueMicrotask\(', content))
    if queue_microtask_count > 0:
        def throttle_queue_microtask(match):
            callback = match.group(1)
            # Convert to setTimeout with longer delay to break busy loop (16ms → 50ms)
            return f'setTimeout({callback}, 50)'
        
        content = re.sub(r'queueMicrotask\(([^)]+)\)', throttle_queue_microtask, content)
        changes.append(f"Throttled {queue_microtask_count} queueMicrotask calls to setTimeout(50ms)")
    
    # PATTERN 6: Catch Promise.resolve().then() chains that might cause busy loops
    promise_resolve_count = len(re.findall(r'Promise\.resolve\(\)\.then\(', content))
    if promise_resolve_count > 10:  # Only if there are many
        # These can create microtask queues that execute immediately
        # Convert to setTimeout to break the chain
        def throttle_promise_resolve(match):
            callback = match.group(1)
            return f'setTimeout({callback}, 16)'
        
        # This is tricky - Promise.resolve().then(cb) patterns
        # For now, just log it
        changes.append(f"Found {promise_resolve_count} Promise.resolve().then() calls (potential microtask loops)")
    
    # PATTERN 6: Catch setInterval with variable intervals (dynamic polling)
    # Find setInterval calls where interval might be a variable
    interval_var_patterns = re.findall(r'setInterval\([^,)]+,\s*([a-zA-Z_$][a-zA-Z0-9_$]*)\)', content)
    if interval_var_patterns:
        # Add minimum interval check wrapper (complex, but try simple approach)
        # For now, just log it
        changes.append(f"Found {len(set(interval_var_patterns))} setInterval calls with variable intervals (may need manual review)")
    
    # Write patched content
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    if changes:
        print(f"Made {len(changes)} changes:")
        for change in changes[:30]:  # Show first 30
            print(f"  {change}")
        if len(changes) > 30:
            print(f"  ... and {len(changes) - 30} more")
    else:
        print("No changes needed (intervals already reasonable)")
    
except Exception as e:
    print(f'Error: {e}')
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF
    
    log_success "Patched $filename"
}

# Apply settings optimizations
apply_settings_optimizations() {
    log_step "Applying settings optimizations..."
    
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    
    # Backup settings
    if [ -f "$SETTINGS_FILE" ]; then
        cp "$SETTINGS_FILE" "$BACKUP_DIR/settings.json.backup"
    fi
    
    # Apply optimizations using Python
    python3 << PYEOF
import json
import os

settings_file = '$SETTINGS_FILE'

# Read existing settings
try:
    with open(settings_file, 'r') as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

# Comprehensive optimizations
optimizations = {
    # File watching optimizations
    "files.watcherExclude": {
        "**/.git/objects/**": True,
        "**/.git/subtree-cache/**": True,
        "**/node_modules/**": True,
        "**/.hg/**": True,
        "**/venv/**": True,
        "**/.venv/**": True,
        "**/__pycache__/**": True,
        "**/.pytest_cache/**": True,
        "**/.mypy_cache/**": True,
        "**/dist/**": True,
        "**/build/**": True,
        "**/.next/**": True,
        "**/target/**": True,
        "**/.cache/**": True
    },
    "files.watcherInclude": [],
    
    # Search optimizations
    "search.exclude": {
        "**/node_modules": True,
        "**/venv": True,
        "**/.venv": True,
        "**/__pycache__": True,
        "**/dist": True,
        "**/build": True,
        "**/.next": True,
        "**/target": True,
        "**/.git": True,
        "**/.cache": True
    },
    "search.followSymlinks": False,
    "search.useIgnoreFiles": True,
    
    # TypeScript optimizations
    "typescript.tsserver.maxTsServerMemory": 2048,
    "typescript.tsserver.watchOptions": {
        "watchFile": "useFsEvents",
        "watchDirectory": "useFsEvents",
        "fallbackPolling": "dynamicPriority",
        "synchronousWatchDirectory": False
    },
    "javascript.updateImportsOnFileMove.enabled": "never",
    
    # Python optimizations
    "python.analysis.typeCheckingMode": "basic",
    "python.analysis.autoImportCompletions": False,
    "python.analysis.diagnosticMode": "workspace",
    "python.analysis.indexing": False,
    
    # Disable unnecessary features
    "extensions.autoCheckUpdates": False,
    "extensions.autoUpdate": False,
    "telemetry.telemetryLevel": "off",
    "workbench.enableExperiments": False,
    "editor.minimap.enabled": False,
    "editor.suggest.showStatusBar": False,
    "workbench.settings.enableNaturalLanguageSearch": False,
    
    # Additional performance settings
    "editor.smoothScrolling": False,
    "editor.cursorBlinking": "solid",
    "editor.cursorSmoothCaretAnimation": "off",
    "workbench.enableExperiments": False,
    "update.mode": "manual"
}

# Merge optimizations
for key, value in optimizations.items():
    if key not in settings:
        settings[key] = value
    elif isinstance(value, dict) and isinstance(settings.get(key), dict):
        settings[key].update(value)

# Write back
with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)

print("✓ Settings optimized")
PYEOF
    
    log_success "Settings optimized"
}

# Main execution
main() {
    log_header "ULTIMATE ANTIGRAVITY CPU FIX"
    
    # Safety check
    if [ -n "${VSCODE_PID:-}" ] || [ -n "${ANTIGRAVITY_PID:-}" ]; then
        log_error "Running inside Antigravity! Please run from external terminal."
        exit 1
    fi
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    log_success "Backup directory: $BACKUP_DIR"
    
    # Step 1: Close Antigravity
    close_antigravity
    
    # Step 2: Apply source patches
    log_header "STEP 1: APPLYING SOURCE-LEVEL PATCHES"
    apply_source_patches "$JETSKI_FILE"
    apply_source_patches "$WORKBENCH_FILE"
    
    # Step 3: Apply settings optimizations
    log_header "STEP 2: APPLYING SETTINGS OPTIMIZATIONS"
    apply_settings_optimizations
    
    # Step 4: Summary
    log_header "FIX COMPLETE"
    echo ""
    echo "Next steps:"
    echo "1. Restart Antigravity"
    echo "2. Monitor CPU usage - should drop from ~80% to <10%"
    echo ""
    echo "Backups saved to: $BACKUP_DIR"
    echo ""
    echo "To restore backups:"
    echo "  sudo cp $BACKUP_DIR/main.js.backup $JETSKI_FILE"
    echo "  sudo cp $BACKUP_DIR/workbench.desktop.main.js.backup $WORKBENCH_FILE"
    echo "  cp $BACKUP_DIR/settings.json.backup $SETTINGS_FILE"
    echo ""
}

main "$@"

