# Antigravity CPU Fix

Stop Antigravity’s agent UI from burning CPU. This repo applies a gentle throttle (about 1s cadence) so the agent stays usable while cutting the idle renderer load, and trims LSP watcher overhead. Backups are automatic and a rollback is simple.

## What’s inside (kept lean)
- `fix-antigravity-balanced.sh` — one-time patch with backups.
- `auto-repatch-and-launch.sh` — reapply after updates and launch with a devtools port (9223) for profiling.
- `fix-antigravity.sh` — original scripted flow (kept for completeness).
- `monitor-antigravity-cpu.sh` — quick CPU watcher.
- `archive/` — deep-dive docs and legacy variants (not needed for normal use).

## Quick start
```bash
git clone https://github.com/sgpascoe/antigravity-cpu-fix.git
cd antigravity-cpu-fix
chmod +x fix-antigravity-balanced.sh auto-repatch-and-launch.sh

# Apply the balanced patch (creates backups)
sudo ./fix-antigravity-balanced.sh

# Launch Antigravity with auto-repatch + devtools port (9223)
./auto-repatch-and-launch.sh
```

## Rollback (fast)
Backups live in `/tmp/antigravity_backups_YYYYMMDD_HHMMSS/`.
```bash
TS=<your backup timestamp>
sudo cp /tmp/antigravity_backups_$TS/main.js.backup /usr/share/antigravity/resources/app/out/jetskiAgent/main.js
sudo cp /tmp/antigravity_backups_$TS/workbench.desktop.main.js.backup /usr/share/antigravity/resources/app/out/vs/workbench/workbench.desktop.main.js
cp /tmp/antigravity_backups_$TS/settings.json.backup ~/.config/Antigravity/User/settings.json
```
Or reinstall Antigravity if you prefer.

## What it changes (balanced patch)
- Agent renderer (`jetskiAgent/main.js`):
  - `requestAnimationFrame` → `setTimeout(..., 1000)` (1 FPS)
  - `setTimeout`: 0–200ms → 1200ms; 200–1000ms → 1500ms
  - `setInterval` <1000ms → 1200–1500ms
  - `queueMicrotask` → `setTimeout(..., 50ms)`
- Settings (`~/.config/Antigravity/User/settings.json`):
  - Watch/search excludes for node_modules, .git, venv, dist/build, caches
  - TS server: `useFsEvents`, dynamic polling, async dir watch; `maxTsServerMemory: 2048`
  - Python: no indexing, no auto-import completions, workspace diagnostics
- Launcher flags (optional, used by `auto-repatch-and-launch.sh`):
  - `--remote-debugging-port=9223 --remote-allow-origins=* --user-data-dir=/tmp/antigravity_devtools --disable-features=RendererCodeIntegrity`

## Why this helps (short version)
- The agent UI was repainting and reading layout continuously (Preact diff + `getBoundingClientRect`). Throttling those loops cuts renderer CPU.
- LSP/tsserver load scales with the number of workspaces. The settings reduce watcher/indexing cost but don’t remove per-workspace LSPs; close unneeded windows for best results.

## Requirements
- Linux; Antigravity at `/usr/share/antigravity/`; `sudo`; `python3`.

## Monitor quickly
```bash
ps aux | grep antigravity | grep -v grep | awk '{sum+=$3} END {print "Total CPU: " sum"%"}'
```

## Limitations
- Updates overwrite bundled JS; rerun the patch or use `auto-repatch-and-launch.sh`.
- Multiple projects still spawn multiple LSPs; that remaining load is normal per workspace.
- The agent panel updates about once per second (by design for this balanced mode).
