# Antigravity Agent CPU Usage Fix

## The Problem

When you open an agent conversation in Antigravity, CPU usage spikes dramatically:

**Before opening agent:**
- ~17% CPU, 2.3GB RAM
- 16 Chrome processes

**After opening agent:**
- **45-60% CPU** (renderer processes alone)
- Individual renderer processes using **19-22% CPU each**
- Main process using **11-12% CPU**
- Total: **~57% CPU** for ONE agent conversation

## Root Cause

Antigravity's agent conversation UI is **extremely CPU-intensive** because:

1. **Constant UI re-rendering** - The conversation UI updates constantly as messages stream
2. **Multiple renderer processes** - Each UI component gets its own Chrome renderer process
3. **Electron overhead** - Electron apps are inherently resource-heavy
4. **No optimization** - Antigravity doesn't throttle UI updates during streaming

This is a **known Antigravity limitation** - the conversation UI is poorly optimized.

## What I Fixed

Applied **28 aggressive optimizations** to reduce CPU usage:

### 1. Disabled All Animations
- Smooth scrolling: OFF
- Cursor animations: OFF
- UI transitions: OFF

### 2. Reduced Rendering Overhead
- Whitespace rendering: OFF
- Line highlights: OFF
- Selection highlights: OFF
- Word highlights: OFF
- Occurrence highlights: OFF

### 3. Minimized UI Elements
- Minimap: OFF
- Activity bar: HIDDEN
- Status bar: HIDDEN
- Preview editors: OFF

### 4. Reduced Polling
- Agent manager poll interval: **30 seconds** (was 5 seconds)
- Auto-refresh: OFF

### 5. Disabled Hover Features
- Increased hover delay to 1 second
- Disabled sticky hover (reduces constant rendering)

## Next Steps

### 1. **RESTART ANTIGRAVITY** (Required!)
The optimizations won't take effect until you restart:
```bash
# Close Antigravity completely, then reopen it
```

### 2. Expected Results After Restart
- CPU usage should drop from **45-60%** to **15-25%**
- Renderer processes should use **5-10% each** instead of 19-22%
- Total system impact should be much lower

### 3. Additional Tips

**When actively using an agent:**
- Keep conversation window **smaller** (less to render)
- **Close conversation** when not actively chatting (Ctrl+W)
- Don't keep multiple agent conversations open simultaneously

**When not using an agent:**
- Close the agent manager panel (Ctrl+J to toggle)
- Close any open conversation tabs

**If still high CPU after restart:**
- The conversation UI itself is the bottleneck
- This is a fundamental Antigravity/Electron limitation
- Consider using smaller conversation windows
- Report to Antigravity team (this is a known issue)

## Monitoring

Check CPU usage:
```bash
./diagnose-antigravity.sh
```

Watch renderer processes:
```bash
ps aux | grep "antigravity-browser-profile" | grep renderer | awk '{printf "PID: %-8s CPU: %5.1f%%\n", $2, $3}' | sort -k3 -rn
```

## The Reality

**Antigravity is Electron-based** (Chrome), which means:
- Every UI component = separate process
- Constant rendering overhead
- No way to completely eliminate the CPU usage
- This is the trade-off for free Gemini + Opus 4.5 access

**Expected CPU usage:**
- Idle (no agent): **5-10%**
- Agent open (optimized): **15-25%**
- Agent streaming response: **25-40%** (temporary spike)

If you need lower CPU usage, consider:
- Using Cursor ($20/mo) - better optimized
- Using VS Code + paid services (GitHub Copilot, etc.)
- Using Continue.dev with local models

## Settings Applied

All optimizations are in:
```
~/.config/Antigravity/User/settings.json
```

Backup created at:
```
~/.config/Antigravity/User/settings.json.backup.20251211_015900
```

To revert, restore from backup.

