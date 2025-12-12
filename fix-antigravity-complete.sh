#!/bin/bash
# Complete Antigravity CPU Fix with Before/After Benchmarking
# Includes Safe Mode and Robust Error Handling

set -euo pipefail

JETSKI_FILE="/usr/share/antigravity/resources/app/out/jetskiAgent/main.js"
WORKBENCH_FILE="/usr/share/antigravity/resources/app/out/vs/workbench/workbench.desktop.main.js"
BACKUP_DIR="/tmp/antigravity_backups_$(date +%Y%m%d_%H%M%S)"
BENCHMARK_DURATION=10

# Options
SAFE_MODE=false # User requested aggressive patch + limit override
FORCE_AGGRESSIVE=true
REVERT_ONLY=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper Functions (Output to stderr to avoid polluting capture vars)
log_header() {
    echo "" >&2
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}" >&2
    echo -e "${CYAN}║${NC} $1" >&2
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}" >&2
    echo "" >&2
}

log_step() {
    echo -e "${BLUE}▶${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}✓${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1" >&2
}

log_error() {
    echo -e "${RED}✗ $1${NC}" >&2
}

# Parse Arguments
for arg in "$@"; do
    case $arg in
        --aggressive)
            SAFE_MODE=false
            FORCE_AGGRESSIVE=true
            ;;
        --revert)
            REVERT_ONLY=true
            ;;
        *)
            ;;
    esac
done

# Function to benchmark Antigravity CPU usage
benchmark_cpu() {
    local label=$1
    local duration=$2
    
    log_step "Benchmarking CPU for ${duration}s ($label)..."
    
    # Check if Antigravity is running
    if ! pgrep -f "/usr/share/antigravity/antigravity" > /dev/null 2>&1; then
        echo "0"
        return
    fi
    
    # Collect CPU samples
    local total=0
    local count=0
    
    for i in $(seq 1 $duration); do
        # Sum CPU of all antigravity processes
        local valid_cpu=0
        local current_sum=$(ps aux | grep -E '/usr/share/antigravity/antigravity' | grep -v 'grep' | awk '{sum+=$3} END {print sum}')
        
        # Validate output is numeric
        if [[ "$current_sum" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            # Show progress on stderr
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
    
    # Calculate average
    local avg=$(echo "scale=1; $total / $count" | bc)
    
    log_success "Average CPU: ${avg}%"
    echo "$avg"
}

# Function to close Antigravity
close_antigravity() {
    log_step "Closing Antigravity..."
    
    if ! pgrep -f "/usr/share/antigravity/antigravity" > /dev/null 2>&1; then
        log_success "Antigravity already closed"
        return
    fi
    
    # Try graceful close - strict path matching
    pkill -f "/usr/share/antigravity/antigravity" 2>/dev/null || true
    sleep 2
    
    # Force kill if still running
    if pgrep -f "/usr/share/antigravity/antigravity" > /dev/null 2>&1; then
        log_warning "Force killing remaining processes..."
        pkill -9 -f "/usr/share/antigravity/antigravity" 2>/dev/null || true
        sleep 1
    fi
    
    log_success "Antigravity closed"
}

# Function to open Antigravity
open_antigravity() {
    log_step "Opening Antigravity..."
    
    # Launch in background, disconnected
    nohup /usr/share/antigravity/antigravity > /dev/null 2>&1 &
    
    # Wait for startup (CPU spike needs to settle)
    log_step "Waiting for initialization (15s)..."
    for i in {1..15}; do
        echo -ne "   $i/15 seconds...\r" >&2
        sleep 1
    done
    echo "" >&2
}

# Function to verify JS syntax
verify_js_file() {
    local file=$1
    if command -v node >/dev/null 2>&1; then
        if ! node --check "$file" 2>/dev/null; then
            log_error "Syntax check failed for $file!"
            return 1
        fi
    else
        log_warning "Node.js not found, skipping syntax check."
    fi
    return 0
}

# Function to apply patches
apply_patch() {
    local file=$1
    local mode=$2 # "SAFE" or "AGGRESSIVE"
    
    if [ ! -f "$file" ]; then
        return
    fi
    
    local filename=$(basename "$file")
    log_step "Patching $filename ($mode Mode)..."
    
    # Backup if not exists in current backup dir
    if [ ! -f "$BACKUP_DIR/${filename}.backup" ]; then
        sudo cp "$file" "$BACKUP_DIR/${filename}.backup"
    fi
    
    # Python script to handle patching logic
    sudo python3 -c "
import re
import sys

file_path = '$file'
mode = '$mode'

try:
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()

    changes = 0
    orig_len = len(content)

    # PATTERN 1: setInterval(func, time)
    # Safe Mode: Patch only < 50ms -> 500ms
    # Aggressive Mode: Patch < 500ms -> 500-1000ms
    
    def patch_interval(match):
        global changes
        callback = match.group(1)
        interval = int(match.group(2))
        suffix = match.group(3)
        
        is_patched = False
        new_interval = interval
        
        if mode == 'AGGRESSIVE':
            if interval < 500 and interval > 0:
                new_interval = 1000 if interval < 50 else 500
                is_patched = True
        else: # SAFE MODE
            if interval < 50 and interval > 0:
                new_interval = 500
                is_patched = True
        
        if is_patched:
            changes += 1
            return f'setInterval({callback}, {new_interval}{suffix}'
        return match.group(0)

    content = re.sub(r'setInterval\(([^,)]+),\s*(\d+)([^0-9])', patch_interval, content)

    # PATTERN 2: setTimeout(func, 0)
    # Safe Mode: SKIP (Possible cause of limit/init issues)
    # Aggressive Mode: Patch -> 16ms
    
    if mode == 'AGGRESSIVE':
        def patch_timeout_zero(match):
            global changes
            changes += 1
            return f'setTimeout({match.group(1)}, 16)'
        content = re.sub(r'setTimeout\(([^,)]+),\s*0\)', patch_timeout_zero, content)

    # PATTERN 3: Short setTimeout (1-5ms)
    # Safe Mode: SKIP
    # Aggressive Mode: Patch -> 16ms
    
    if mode == 'AGGRESSIVE':
        def patch_short_timeout(match):
            global changes
            interval = int(match.group(2))
            if interval <= 5:
                changes += 1
                return f'setTimeout({match.group(1)}, 16)'
            return match.group(0)
        content = re.sub(r'setTimeout\(([^,)]+),\s*([1-5])\)', patch_short_timeout, content)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
        
    print(f'Made {changes} changes')

except Exception as e:
    print(f'Error: {e}')
    sys.exit(1)
"
    
    # Verify syntax
    if verify_js_file "$file"; then
        log_success "Patched $filename successfully"
    else
        log_error "Patch broke syntax! Restoring backup..."
        sudo cp "$BACKUP_DIR/${filename}.backup" "$file"
    fi
}

main() {
    log_header "ANTIGRAVITY CPU FIX - REVISED"
    
    # Safety Check
    if [ -n "${VSCODE_PID:-}" ] || [ -n "${ANTIGRAVITY_PID:-}" ] || [[ "${TERM_PROGRAM:-}" == *"Code"* ]]; then
        log_error "Running inside Antigravity! Please run from external terminal."
        exit 1
    fi
    
    if [ "$REVERT_ONLY" = true ]; then
        log_header "REVERTING CHANGES..."
        close_antigravity
        # Logic to find and restore backups (simplistic for now)
        # Assuming run immediately after
        if [ -d "$BACKUP_DIR" ]; then
             if [ -f "$BACKUP_DIR/main.js.backup" ]; then
                 sudo cp "$BACKUP_DIR/main.js.backup" "$JETSKI_FILE"
                 log_success "Restored jetskiAgent/main.js"
             fi
             if [ -f "$BACKUP_DIR/workbench.desktop.main.js.backup" ]; then
                 sudo cp "$BACKUP_DIR/workbench.desktop.main.js.backup" "$WORKBENCH_FILE"
                 log_success "Restored workbench.desktop.main.js"
             fi
        else
            log_error "No current backup directory found via script var."
            log_warning "Please restore manually if needed."
        fi
        exit 0
    fi
    
    mkdir -p "$BACKUP_DIR"
    log_success "Backup directory: $BACKUP_DIR"
    
    if [ "$SAFE_MODE" = true ]; then
        log_step "MODE: SAFE (Conservative)"
        log_warning "Only patching extreme intervals (<50ms). Preserving initialization logic."
    else
        log_step "MODE: AGGRESSIVE (Maximum CPU saving)"
    fi
    
    # 1. Benchmark
    BEFORE_CPU=$(benchmark_cpu "BEFORE" $BENCHMARK_DURATION)
    
    # 2. Close
    close_antigravity
    
    # 3. Patch
    MODE_STR="SAFE"
    if [ "$SAFE_MODE" = false ]; then MODE_STR="AGGRESSIVE"; fi
    
    apply_patch "$JETSKI_FILE" "$MODE_STR"
    apply_patch "$WORKBENCH_FILE" "$MODE_STR"
    
    # 4. Open
    open_antigravity
    
    # 5. Benchmark
    AFTER_CPU=$(benchmark_cpu "AFTER" $BENCHMARK_DURATION)
    
    # Results
    log_header "RESULTS"
    echo "" >&2
    echo -e "  ${YELLOW}BEFORE:${NC} ${BEFORE_CPU}% CPU" >&2
    echo -e "  ${GREEN}AFTER:${NC}  ${AFTER_CPU}% CPU" >&2
    
    if [[ "$BEFORE_CPU" != "0" ]] && [[ "$AFTER_CPU" != "0" ]]; then
        IMPROVEMENT=$(echo "scale=1; $BEFORE_CPU - $AFTER_CPU" | bc)
        echo -e "  ${CYAN}SAVED:${NC}   ${IMPROVEMENT}% CPU" >&2
    fi
    
    echo "" >&2
    log_success "Done! If issues persist, run with --revert (manual restore required if new session)"
}

main "$@"
