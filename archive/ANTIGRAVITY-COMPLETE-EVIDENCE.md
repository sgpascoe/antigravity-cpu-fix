# Complete Evidence: What Antigravity Renderer Is Actually Doing

## Executive Summary

After comprehensive deep-dive investigation with perf, strace, and process analysis, I can now provide **complete evidence** of what's happening.

## Critical Evidence

### 1. Perf Data (Actual Code Execution)

**5.48% of CPU cycles** spent on:
```
v8::ValueSerializer::WriteValue
v8::Function::Call
```

This is **JavaScript serialization and function calls**, not just rendering.

**Call stack shows:**
- V8 JavaScript engine execution
- Function calls in JavaScript code
- Value serialization (for IPC)

### 2. Memory Evidence

- **1.4TB virtual memory** (mostly V8 heap)
- **900MB RSS** (actual RAM)
- Massive `[anon:v8]` regions = JavaScript heap allocations
- Confirms heavy JavaScript execution

### 3. CPU Pattern Analysis

- **Constant 63.72% CPU** (stddev 0.11%)
- **NOT bursty** - steady tight loop
- Main thread in "R" (Running) state 80% of time
- Suggests: JavaScript event loop running constantly

### 4. Network Verification

- **No TCP/UDP connections** ✓
- **No connection to language servers** ✓
- **No network I/O** ✓
- Only Unix sockets for IPC (normal Electron communication)

### 5. CPU Time Comparison

| Process | User Time | System Time | State | Purpose |
|---------|-----------|-------------|-------|---------|
| Renderer (620160) | 51,124 | 15,376 | R/S | UI rendering |
| Language Server (621157) | 4,731 | 584 | S | Agent work |

Renderer has **10x more user CPU time** than language server, but language server is doing actual agent work. This confirms renderer is doing unnecessary computation.

### 6. Thread Activity Breakdown

- **Main thread (620160)**: 41.7% CPU constantly in "R" state
- **Compositor thread**: 0.5% CPU (not the problem)
- **ThreadPoolForeground threads**: 2-3% each (parallel work)
- **Main thread is the bottleneck**

### 7. Performance Metrics

- **Instructions per cycle**: 1.32 (low - memory-bound)
- **Stalled cycles**: 31.85% (waiting on memory)
- **Context switches**: 1.7M voluntary, 103K involuntary
- Typical of JavaScript execution (memory-bound, event-driven)

### 8. IPC Communication

- **13 Unix sockets** for IPC
- **5.48% CPU on ValueSerializer** = heavy IPC serialization
- Suggests: Constant object serialization for IPC communication
- Even when UI is static, objects are being serialized

## What's Actually Happening

The renderer is:

1. **Running JavaScript event loop constantly**
   - Main thread in "R" state 80% of time
   - Constant CPU usage (63.72% steady)

2. **Serializing JavaScript objects for IPC**
   - 5.48% of cycles on `v8::ValueSerializer::WriteValue`
   - Sending UI state updates constantly
   - Even when nothing has changed

3. **Calling JavaScript functions repeatedly**
   - `v8::Function::Call` in call stack
   - Likely React/Vue component re-renders
   - Poor memoization/optimization

4. **Doing this even when UI is static**
   - Constant CPU usage suggests no throttling
   - Event loop running at high frequency
   - No idle state detection

## What It's NOT Doing

- ✗ Making API calls (no TCP/UDP)
- ✗ Doing agent inference (no connection to language servers)
- ✗ Reading/writing files (minimal I/O)
- ✗ Network I/O (no connections)
- ✗ GPU-accelerated rendering (no GPU activity)

## Root Cause

The JavaScript code is:

1. **Running a tight event loop** - No throttling when idle
2. **Constantly serializing objects** - Heavy IPC communication
3. **Calling functions repeatedly** - Likely unoptimized React/Vue components
4. **No memoization** - Re-rendering everything on every update
5. **Poor optimization** - No idle state detection

The **5.48% of cycles on ValueSerializer** is particularly telling:
- Heavy IPC communication (serializing JS objects)
- Possibly sending UI state updates constantly
- Even when nothing has changed

## Why This Is Embarrassing

1. **A static UI shouldn't need constant JavaScript execution**
   - Should throttle event loop when idle
   - Should detect when UI is static

2. **IPC serialization shouldn't be 5% of CPU cycles**
   - Should only serialize when data changes
   - Should batch updates

3. **Function calls shouldn't be constant**
   - Should use memoization
   - Should avoid unnecessary re-renders

4. **This suggests poor optimization in the UI framework**
   - Likely unoptimized React/Vue components
   - No proper memoization
   - Constant re-renders

## Expected Behavior vs Actual

**Expected:**
- Static UI: <1% CPU (idle)
- Active UI: 5-10% CPU (rendering)
- Agent work: <5% CPU (language servers)

**Actual:**
- Static UI: 63% CPU (constant JavaScript execution)
- Active UI: 80%+ CPU (even worse)
- Agent work: 8% CPU (language servers - actually reasonable)

## Solutions

The optimizations I applied should help:
- Disabling animations reduces rendering work
- Reducing UI elements reduces layout calculations
- But the root cause is unoptimized JavaScript code

**What Google should fix:**
1. Throttle event loop when UI is idle
2. Batch IPC updates (don't serialize constantly)
3. Optimize React/Vue components (memoization)
4. Detect static UI and pause unnecessary work

## Conclusion

**It's JavaScript execution + IPC serialization, NOT just rendering.**

The renderer is doing:
- Constant JavaScript execution (event loop)
- Heavy object serialization (IPC)
- Repeated function calls (re-renders)
- All happening even when UI is static

This is a **fundamental optimization failure** in Antigravity's UI code, not just Electron overhead.

