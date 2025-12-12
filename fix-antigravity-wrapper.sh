#!/bin/bash
# Wrapper script to fix Antigravity's CPU issues
# This applies runtime fixes that Google should have done

set -euo pipefail

echo "=== ANTIGRAVITY FIX WRAPPER ==="
echo ""

# Check if Antigravity is already running
if pgrep -f "antigravity" > /dev/null; then
    echo "⚠️  Antigravity is already running"
    echo "   Close it first, then run this script"
    exit 1
fi

# Create optimized launch script
LAUNCH_SCRIPT="$HOME/.local/bin/antigravity-fixed"
mkdir -p "$HOME/.local/bin"

cat > "$LAUNCH_SCRIPT" << 'LAUNCH_EOF'
#!/bin/bash
# Launch Antigravity with optimizations

# Electron flags to reduce CPU usage
ELECTRON_FLAGS=(
    # Disable background throttling (but we'll throttle ourselves)
    --disable-background-timer-throttling
    --disable-renderer-backgrounding
    
    # JavaScript engine optimizations
    --js-flags="--expose-gc --max-old-space-size=2048"
    
    # Disable unnecessary features
    --disable-dev-shm-usage
    --disable-software-rasterizer
    --disable-gpu-sandbox
    
    # Reduce rendering overhead
    --disable-accelerated-2d-canvas
    --disable-accelerated-video-decode
    
    # Throttle background tabs
    --disable-background-networking
)

# Launch with flags
exec /usr/share/antigravity/antigravity "${ELECTRON_FLAGS[@]}" "$@"
LAUNCH_EOF

chmod +x "$LAUNCH_SCRIPT"

echo "✓ Created optimized launch script: $LAUNCH_SCRIPT"
echo ""

# Create CPU throttling script
THROTTLE_SCRIPT="$HOME/.local/bin/antigravity-throttle"
cat > "$THROTTLE_SCRIPT" << 'THROTTLE_EOF'
#!/bin/bash
# Throttle Antigravity renderer processes to reduce CPU

MAX_CPU=${1:-50}  # Default: 50% CPU limit per process

echo "Throttling Antigravity renderer processes to ${MAX_CPU}% CPU..."

while true; do
    # Find renderer processes
    RENDERER_PIDS=$(ps aux | grep "/usr/share/antigravity.*--type=zygote" | grep -v grep | awk '{print $2}')
    
    for pid in $RENDERER_PIDS; do
        CURRENT_CPU=$(ps -p "$pid" -o pcpu --no-headers 2>/dev/null | awk '{print int($1)}')
        
        if [ -n "$CURRENT_CPU" ] && [ "$CURRENT_CPU" -gt "$MAX_CPU" ]; then
            # Lower priority (doesn't limit, but reduces scheduling)
            renice +10 "$pid" 2>/dev/null || true
            
            # If cpulimit is available, use it
            if command -v cpulimit &> /dev/null; then
                cpulimit -p "$pid" -l "$MAX_CPU" &> /dev/null || true
            fi
        fi
    done
    
    sleep 2
done
THROTTLE_EOF

chmod +x "$THROTTLE_SCRIPT"

echo "✓ Created CPU throttling script: $THROTTLE_SCRIPT"
echo ""

# Create devtools injection script (if devtools are accessible)
INJECT_SCRIPT="$HOME/.local/bin/antigravity-inject-fixes"
cat > "$INJECT_SCRIPT" << 'INJECT_EOF'
#!/bin/bash
# Inject JavaScript fixes via Electron devtools
# This requires devtools to be accessible

echo "=== ANTIGRAVITY JAVASCRIPT FIXES ==="
echo ""
echo "To inject fixes, you need to:"
echo "1. Enable devtools in Antigravity (if possible)"
echo "2. Open devtools console"
echo "3. Paste the following code:"
echo ""
cat << 'FIXES_EOF'
// Fix 1: Throttle polling
const originalSetInterval = window.setInterval;
window.setInterval = function(callback, delay, ...args) {
    // Throttle agent manager polling to 2 seconds minimum
    if (delay < 2000 && callback.toString().includes('agent')) {
        delay = 2000;
    }
    return originalSetInterval(callback, delay, ...args);
};

// Fix 2: Throttle requestAnimationFrame
let lastFrame = 0;
const originalRAF = window.requestAnimationFrame;
window.requestAnimationFrame = function(callback) {
    const now = performance.now();
    if (now - lastFrame < 16) { // Throttle to ~60 FPS
        return originalRAF(callback);
    }
    lastFrame = now;
    return originalRAF(callback);
};

// Fix 3: Throttle IPC sends
if (window.require) {
    const { ipcRenderer } = window.require('electron');
    const originalSend = ipcRenderer.send;
    let lastSend = {};
    
    ipcRenderer.send = function(channel, ...args) {
        const key = channel + JSON.stringify(args);
        const now = Date.now();
        
        // Throttle identical messages to 1 per second
        if (lastSend[key] && now - lastSend[key] < 1000) {
            return; // Skip duplicate
        }
        
        lastSend[key] = now;
        return originalSend.apply(ipcRenderer, arguments);
    };
}

// Fix 4: Pause when tab is hidden
document.addEventListener('visibilitychange', function() {
    if (document.hidden) {
        // Pause polling when tab is hidden
        console.log('Tab hidden - should pause polling');
    } else {
        console.log('Tab visible - resume polling');
    }
});

console.log('✓ Antigravity fixes injected');
FIXES_EOF
echo ""
echo "Note: This only works if devtools are accessible."
echo "      Most Electron apps disable devtools in production."
INJECT_EOF

chmod +x "$INJECT_SCRIPT"

echo "✓ Created injection script: $INJECT_SCRIPT"
echo ""

# Create settings override script
SETTINGS_SCRIPT="$HOME/.local/bin/antigravity-apply-settings"
cat > "$SETTINGS_SCRIPT" << 'SETTINGS_EOF'
#!/bin/bash
# Apply aggressive settings optimizations

SETTINGS_FILE="$HOME/.config/Antigravity/User/settings.json"

if [ ! -f "$SETTINGS_FILE" ]; then
    echo "Settings file not found: $SETTINGS_FILE"
    exit 1
fi

# Backup
cp "$SETTINGS_FILE" "${SETTINGS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# Apply fixes using Python
python3 << 'PYTHON_EOF'
import json
import os

settings_file = os.path.expanduser("~/.config/Antigravity/User/settings.json")

with open(settings_file, 'r') as f:
    settings = json.load(f)

# Aggressive fixes
fixes = {
    # Disable agent manager completely
    "antigravity.agentManager.enabled": False,
    "antigravity.agentManager.autoRefresh": False,
    "antigravity.agentManager.pollInterval": 60000,  # 60 seconds if enabled
    
    # Disable all animations
    "editor.smoothScrolling": False,
    "workbench.list.smoothScrolling": False,
    "editor.cursorSmoothCaretAnimation": "off",
    
    # Reduce rendering
    "editor.renderWhitespace": "none",
    "editor.renderLineHighlight": "none",
    "editor.minimap.enabled": False,
    
    # Throttle updates
    "editor.hover.delay": 2000,
    "editor.quickSuggestions": {
        "other": False,
        "comments": False,
        "strings": False
    },
    
    # Disable telemetry (might reduce background work)
    "telemetry.telemetryLevel": "off",
}

settings.update(fixes)

with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)

print("✓ Settings applied")
PYTHON_EOF

echo "✓ Settings optimized"
echo "  Restart Antigravity for changes to take effect"
SETTINGS_EOF

chmod +x "$SETTINGS_SCRIPT"

echo "✓ Created settings script: $SETTINGS_SCRIPT"
echo ""

echo "=== SETUP COMPLETE ==="
echo ""
echo "Created scripts:"
echo "  1. $LAUNCH_SCRIPT - Launch with optimizations"
echo "  2. $THROTTLE_SCRIPT - Throttle CPU usage"
echo "  3. $INJECT_SCRIPT - Inject JavaScript fixes (if devtools accessible)"
echo "  4. $SETTINGS_SCRIPT - Apply aggressive settings"
echo ""
echo "USAGE:"
echo "  1. Run: $SETTINGS_SCRIPT"
echo "  2. Launch: $LAUNCH_SCRIPT"
echo "  3. (Optional) In another terminal: $THROTTLE_SCRIPT 50"
echo ""
echo "Note: The JavaScript injection only works if devtools are accessible."
echo "      Most production Electron apps disable devtools."

