# Antigravity CPU Fix

**Goal:** make Antigravity usable by stopping the agent UI from burning CPU, without freezing the UI. Backups are automatic; rollback is simple.

## The short story (what/why)
- **Problem:** The agent UI (jetski) continuously re-rendered and read layout (`requestAnimationFrame` at 60 FPS, tight `setTimeout/queueMicrotask` loops, lots of `getBoundingClientRect`). Result: renderer CPU spikes even when “idle”. Multi-workspace setups add heavy LSP/tsserver load per window.
- **Fix:** Throttle the hottest UI loops to ~1s cadence (not 5s) and reduce LSP watcher/indexing overhead.
- **What you get:** Agent stays responsive, renderer CPU drops; remaining load mostly comes from however many workspaces/LSPs you keep open.

## Quick start (do this)
```bash
git clone https://github.com/sgpascoe/antigravity-cpu-fix.git
cd antigravity-cpu-fix
chmod +x fix-antigravity-balanced.sh auto-repatch-and-launch.sh

# Apply patch (backups auto-created)
sudo ./fix-antigravity-balanced.sh

# Launch with auto-repatch + devtools port 9223
./auto-repatch-and-launch.sh
```

## Rollback
Backups live in `/tmp/antigravity_backups_YYYYMMDD_HHMMSS/`.
```bash
TS=<timestamp>
sudo cp /tmp/antigravity_backups_$TS/main.js.backup /usr/share/antigravity/resources/app/out/jetskiAgent/main.js
sudo cp /tmp/antigravity_backups_$TS/workbench.desktop.main.js.backup /usr/share/antigravity/resources/app/out/vs/workbench/workbench.desktop.main.js
cp /tmp/antigravity_backups_$TS/settings.json.backup ~/.config/Antigravity/User/settings.json
```
Or reinstall Antigravity.

## What the patch actually changes
- Agent renderer (`jetskiAgent/main.js`):
  - `requestAnimationFrame` → `setTimeout(..., 1000)` (1 FPS)
  - `setTimeout`: 0–200ms → 1200ms; 200–1000ms → 1500ms
  - `setInterval` <1000ms → 1200–1500ms
  - `queueMicrotask` → `setTimeout(..., 50ms)`
- Settings (`~/.config/Antigravity/User/settings.json`):
  - Watch/search excludes for node_modules, .git, venv, dist/build, caches
  - TS server: `useFsEvents`, dynamic polling, async dir watch; `maxTsServerMemory: 2048`
  - Python: no indexing, no auto-import completions, workspace diagnostics
- Launcher flags (used by `auto-repatch-and-launch.sh`):
  - `--remote-debugging-port=9223 --remote-allow-origins=* --user-data-dir=/tmp/antigravity_devtools --disable-features=RendererCodeIntegrity`

## What to expect
- Renderer CPU should idle low; total CPU will still reflect how many workspaces/LSPs you run.
- Agent panel refreshes roughly once per second (by design for this “balanced” mode).

## Monitor
```bash
ps aux | grep antigravity | grep -v grep | awk '{sum+=$3} END {print "Total CPU: " sum"%"}'
```

## Notes / limits
- Antigravity updates overwrite bundled JS; rerun the patch or use `auto-repatch-and-launch.sh`.
- Multi-project setups still spawn multiple LSPs; close unneeded windows to cut that load.
- All changes are local and backed up; restoring is one copy away.
