#!/bin/bash
# Antigravity CPU Fix - Reduces CPU usage from 80-280% to <20% when idle
# Fixes aggressive polling loops that cause excessive CPU usage

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

# Benchmark CPU usage
benchmark_cpu() {
    local label=$1
    local duration=${2:-10}
    
    log_step "Benchmarking CPU for ${duration}s ($label)..."
    
    if ! pgrep -f "/usr/share/antigravity/antigravity" > /dev/null 2>&1; then
        echo "0"
        return
    fi
    
    local total=0
    local count=0
    
    for i in $(seq 1 $duration); do
        local current_sum=$(ps aux | grep -E '/usr/share/antigravity/antigravity' | grep -v grep | awk '{sum+=$3} END {print sum}')
        
        if [[ "$current_sum" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            echo -ne "   Sample $i/$duration: ${current_sum}% CPU\r" >&2
            total=$(echo "$total + $current_sum" | bc)
            count=$((count + 1))
        fi
        sleep 1
    done
    echo "" >&2
    
    if [ $count -eq 0 ]; then
        echo "0"
        return
    fi
    
    local avg=$(echo "scale=1; $total / $count" | bc)
    log_success "Average CPU: ${avg}%"
    echo "$avg"
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

# Open Antigravity
open_antigravity() {
    log_step "Opening Antigravity..."
    nohup /usr/share/antigravity/antigravity > /dev/null 2>&1 &
    
    log_step "Waiting for initialization (15s)..."
    for i in {1..15}; do
        echo -ne "   $i/15 seconds...\r" >&2
        sleep 1
    done
    echo "" >&2
}

# Apply source patches
apply_source_patches() {
    local file=$1
    local filename=$(basename "$file")
    
    if [ ! -f "$file" ]; then
        log_warning "File not found: $file (skipping)"
        return
    fi
    
    log_step "Patching $filename..."
    
    if [ ! -f "$BACKUP_DIR/${filename}.backup" ]; then
        sudo cp "$file" "$BACKUP_DIR/${filename}.backup"
        log_success "Backup created"
    fi
    
    sudo python3 << PYEOF
import re
import sys

file_path = '$file'

try:
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    changes = []
    
    # PATTERN 1: setInterval with short intervals (< 2000ms)
    def patch_setinterval(match):
        func = match.group(1)
        interval = int(match.group(2))
        suffix = match.group(3)
        
        if interval < 2000 and interval >= 0:
            new_interval = 2000
            line_num = content[:match.start()].count('\n') + 1
            changes.append(f"Line ~{line_num}: setInterval {interval}ms -> {new_interval}ms")
            return f'setInterval({func}, {new_interval}{suffix}'
        
        return match.group(0)
    
    content = re.sub(r'setInterval\(([^,)]+),\s*(\d+)([^0-9,])', patch_setinterval, content)
    content = re.sub(r'setInterval\(([^,)]+),\s*(\d+),', lambda m: patch_setinterval(m) if int(m.group(2)) < 2000 else m.group(0), content)
    
    # PATTERN 2: setTimeout(func, 0) - busy loops
    def patch_settimeout_zero(match):
        func = match.group(1)
        suffix = match.group(2) if len(match.groups()) > 1 else ''
        line_num = content[:match.start()].count('\n') + 1
        changes.append(f"Line ~{line_num}: setTimeout 0ms -> 5000ms (busy loop)")
        if suffix == ')':
            return f'setTimeout({func}, 5000)'
        return f'setTimeout({func}, 5000{suffix}'
    
    content = re.sub(r'setTimeout\(([^,)]+),\s*0([^0-9,)]?)', patch_settimeout_zero, content)
    content = re.sub(r'setTimeout\(([^,)]+),\s*0\)', lambda m: f'setTimeout({m.group(1)}, 5000)', content)
    content = re.sub(r'setTimeout\(([^,)]+),0([^0-9,)]?)', patch_settimeout_zero, content)
    
    # PATTERN 3: setTimeout with short intervals (< 500ms)
    def patch_settimeout_short(match):
        func = match.group(1)
        interval = int(match.group(2))
        suffix = match.group(3)
        
        if interval > 0 and interval < 500:
            new_interval = 5000
            line_num = content[:match.start()].count('\n') + 1
            changes.append(f"Line ~{line_num}: setTimeout {interval}ms -> {new_interval}ms")
            return f'setTimeout({func}, {new_interval}{suffix}'
        
        return match.group(0)
    
    content = re.sub(r'setTimeout\(([^,)]+),\s*(\d+)([^0-9,])', patch_settimeout_short, content)
    content = re.sub(r'setTimeout\(([^,)]+),\s*(\d+),', lambda m: patch_settimeout_short(m) if 0 < int(m.group(2)) < 500 else m.group(0), content)
    
    # PATTERN 4: Throttle requestAnimationFrame loops to 5000ms (0.2 FPS)
    raf_count = len(re.findall(r'requestAnimationFrame\(', content))
    if raf_count > 0:
        def throttle_raf(match):
            callback = match.group(1)
            return f'setTimeout({callback}, 5000)'
        
        content = re.sub(r'requestAnimationFrame\(([^)]+)\)', throttle_raf, content)
        changes.append(f"Throttled {raf_count} requestAnimationFrame calls to 5000ms (0.2 FPS)")
    
    # PATTERN 5: Throttle queueMicrotask busy loops
    queue_microtask_count = len(re.findall(r'queueMicrotask\(', content))
    if queue_microtask_count > 0:
        def throttle_queue_microtask(match):
            callback = match.group(1)
            return f'setTimeout({callback}, 50)'
        
        content = re.sub(r'queueMicrotask\(([^)]+)\)', throttle_queue_microtask, content)
        changes.append(f"Throttled {queue_microtask_count} queueMicrotask calls to setTimeout(50ms)")
    
    # Write patched content
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    if changes:
        print(f"Made {len(changes)} changes:")
        for change in changes[:30]:
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
    
    if [ -f "$SETTINGS_FILE" ]; then
        cp "$SETTINGS_FILE" "$BACKUP_DIR/settings.json.backup"
    fi
    
    python3 << PYEOF
import json
import os

settings_file = '$SETTINGS_FILE'

try:
    with open(settings_file, 'r') as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

optimizations = {
    "files.watcherExclude": {
        "**/.git/objects/**": True,
        "**/.git/subtree-cache/**": True,
        "**/node_modules/**": True,
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
    "typescript.tsserver.maxTsServerMemory": 2048,
    "typescript.tsserver.watchOptions": {
        "watchFile": "useFsEvents",
        "watchDirectory": "useFsEvents",
        "fallbackPolling": "dynamicPriority",
        "synchronousWatchDirectory": False
    },
    "javascript.updateImportsOnFileMove.enabled": "never",
    "python.analysis.typeCheckingMode": "basic",
    "python.analysis.autoImportCompletions": False,
    "python.analysis.diagnosticMode": "workspace",
    "python.analysis.indexing": False,
    "extensions.autoCheckUpdates": False,
    "extensions.autoUpdate": False,
    "telemetry.telemetryLevel": "off",
    "workbench.enableExperiments": False,
    "editor.minimap.enabled": False,
    "editor.suggest.showStatusBar": False,
    "workbench.settings.enableNaturalLanguageSearch": False,
    "editor.smoothScrolling": False,
    "editor.cursorBlinking": "solid",
    "editor.cursorSmoothCaretAnimation": "off",
    "update.mode": "manual"
}

for key, value in optimizations.items():
    if key not in settings:
        settings[key] = value
    elif isinstance(value, dict) and isinstance(settings.get(key), dict):
        settings[key].update(value)

with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)

print("✓ Settings optimized")
PYEOF
    
    log_success "Settings optimized"
}

# Main execution
main() {
    log_header "ANTIGRAVITY CPU FIX"
    
    if [ -n "${VSCODE_PID:-}" ] || [ -n "${ANTIGRAVITY_PID:-}" ]; then
        log_error "Running inside Antigravity! Please run from external terminal."
        exit 1
    fi
    
    mkdir -p "$BACKUP_DIR"
    log_success "Backup directory: $BACKUP_DIR"
    
    # Benchmark before
    BEFORE_CPU=$(benchmark_cpu "BEFORE" 10)
    
    # Close Antigravity
    close_antigravity
    
    # Apply patches
    log_header "STEP 1: APPLYING SOURCE-LEVEL PATCHES"
    apply_source_patches "$JETSKI_FILE"
    apply_source_patches "$WORKBENCH_FILE"
    
    # Apply settings
    log_header "STEP 2: APPLYING SETTINGS OPTIMIZATIONS"
    apply_settings_optimizations
    
    # Open Antigravity
    open_antigravity
    
    # Benchmark after
    AFTER_CPU=$(benchmark_cpu "AFTER" 10)
    
    # Results
    log_header "RESULTS"
    echo ""
    echo -e "  ${YELLOW}BEFORE:${NC} ${BEFORE_CPU}% CPU"
    echo -e "  ${GREEN}AFTER:${NC}  ${AFTER_CPU}% CPU"
    
    if [[ "$BEFORE_CPU" != "0" ]] && [[ "$AFTER_CPU" != "0" ]]; then
        IMPROVEMENT=$(echo "scale=1; $BEFORE_CPU - $AFTER_CPU" | bc)
        echo -e "  ${CYAN}SAVED:${NC}   ${IMPROVEMENT}% CPU"
    fi
    
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

