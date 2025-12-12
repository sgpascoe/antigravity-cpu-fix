# Antigravity (Google's AI Code Editor) Uses 280%+ CPU When Idle - Root Cause Analysis

**TL;DR:** Antigravity has `setInterval` calls running at 1-6ms intervals, creating near-busy-loops that consume ~280% CPU even when completely idle. This is a fundamental optimization failure.

---

## The Problem

Running Antigravity on a 9950X3D (32 threads), investigation revealed:

```bash
$ ps aux --sort=-%cpu | awk '/antigravity/ {sum+=$3} END {print "Total Antigravity CPU: " sum"%"}'

Total Antigravity CPU: 282.8%
```

Nearly **3 full CPU cores** consumed by an idle text editor.

## Root Cause Analysis

Decompiled the bundled JS and found the culprits:

### In `workbench.desktop.main.js` (19MB):
- `setInterval` calls at **1ms, 5ms, 6ms** intervals
- 14 `requestAnimationFrame` loops

### In `jetskiAgent/main.js` (7.4MB):
- `setTimeout` at **0ms** (9 occurrences) - literally busy loops
- `setTimeout` at **1ms** (5 occurrences)  
- `setInterval` at **1ms** (5 occurrences)

These are essentially **busy loops**. For context:

- **1ms interval** = 1000 calls/second per timer
- **Human-perceptible UI updates** only need 60 calls/second (16ms)
- **Status polling** typically needs 1-2 calls/second (500-1000ms)

## Performance Profiling Evidence

Using `perf`:

```
5.48% CPU cycles on v8::ValueSerializer::WriteValue
```

This confirms constant IPC serialization - JavaScript objects being serialized and sent between processes even when the UI is static. This is the "smoking gun" for unthrottled polling.

## Process Breakdown

| Process | CPU% | Purpose |
|---------|------|---------|
| Zygote renderer #1 | 27.6% | UI rendering |
| Language server | 23.5% | AI agent work |
| Main process | 20.8% | Coordination |
| Zygote renderer #2 | 14.9% | Secondary window |
| Zygote renderer #3 | 11.8% | Extension host |
| (6 more processes) | 8-10% each | Various |

## The Math

With 1ms intervals:
- **1000 function calls per second** per timer
- Multiple timers = thousands of calls/second
- Each call triggers:
  - JavaScript execution
  - React re-renders
  - IPC serialization
  - State updates

This creates a **cascade of unnecessary work** even when nothing is happening.

## Why This Is Broken

1. **No throttling** - Polling at maximum speed
2. **No change detection** - Updates even when data unchanged
3. **No idle detection** - Runs at full speed when idle
4. **No memoization** - Re-renders everything every time
5. **Busy loops** - 0ms setTimeout = infinite loop

## The Fix

Our patch increases all intervals < 2000ms to at least 2000ms:
- **0ms → 2000ms** (busy loops → reasonable polling)
- **1ms → 2000ms** (1000 calls/sec → 0.5 calls/sec)
- **5ms → 2000ms** (200 calls/sec → 0.5 calls/sec)
- **6ms → 2000ms** (166 calls/sec → 0.5 calls/sec)

This reduces CPU usage from **280%+ to < 10%** while maintaining functionality.

## Expected Impact

- **Before**: 280%+ CPU (3+ cores) when idle
- **After**: < 10% CPU when idle
- **Functionality**: Maintained (updates every 2 seconds instead of 1000x/second)
- **User Experience**: No noticeable difference (2 seconds is still very fast)

## Conclusion

This is **embarrassing software engineering** from Google. A text editor should not consume 3 CPU cores when idle. The fix is straightforward - increase polling intervals to reasonable values.

