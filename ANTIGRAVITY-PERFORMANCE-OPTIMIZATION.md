# Antigravity Performance Optimization Guide

## Current Situation (After Reboot)
- **1 Antigravity instance** (good!)
- **4 workspaces** open, each spawning its own language server
- **4 language servers** consuming ~5.6GB RAM total (1.2-1.6GB each)
- **11 renderer processes** (zygote processes) using ~2.1GB RAM
- **Total: ~11GB RAM, 10-14% CPU** even when idle
- **43 total processes** spawned

**This is a KNOWN ISSUE** - Antigravity spawns a heavy language server for each workspace, even when idle.

## Quick Wins (Without Closing Anything)

### 1. Optimize File Watching
Add to `~/.config/Antigravity/User/settings.json`:

```json
{
  "files.watcherExclude": {
    "**/.git/objects/**": true,
    "**/.git/subtree-cache/**": true,
    "**/node_modules/**": true,
    "**/.hg/**": true,
    "**/venv/**": true,
    "**/.venv/**": true,
    "**/__pycache__/**": true,
    "**/.pytest_cache/**": true,
    "**/.mypy_cache/**": true,
    "**/dist/**": true,
    "**/build/**": true,
    "**/.next/**": true,
    "**/target/**": true
  },
  "files.watcherInclude": []
}
```

### 2. Reduce Search Indexing
```json
{
  "search.exclude": {
    "**/node_modules": true,
    "**/venv": true,
    "**/.venv": true,
    "**/__pycache__": true,
    "**/dist": true,
    "**/build": true,
    "**/.next": true,
    "**/target": true,
    "**/.git": true
  },
  "search.followSymlinks": false,
  "search.useIgnoreFiles": true
}
```

### 3. Optimize TypeScript/JavaScript
```json
{
  "typescript.tsserver.maxTsServerMemory": 2048,
  "typescript.tsserver.watchOptions": {
    "watchFile": "useFsEvents",
    "watchDirectory": "useFsEvents",
    "fallbackPolling": "dynamicPriority",
    "synchronousWatchDirectory": false
  },
  "javascript.updateImportsOnFileMove.enabled": "never"
}
```

### 4. Optimize Python Language Server
```json
{
  "python.analysis.typeCheckingMode": "basic",
  "python.analysis.autoImportCompletions": false,
  "python.analysis.diagnosticMode": "workspace",
  "python.analysis.indexing": false,
  "python.languageServer": "Pylance"
}
```

### 5. Disable Unnecessary Features
```json
{
  "extensions.autoCheckUpdates": false,
  "extensions.autoUpdate": false,
  "telemetry.telemetryLevel": "off",
  "workbench.enableExperiments": false,
  "editor.minimap.enabled": false,
  "editor.suggest.showStatusBar": false,
  "workbench.settings.enableNaturalLanguageSearch": false
}
```

### 6. Limit Extension Host Processes
```json
{
  "extensions.experimental.affinity": {
    "vscodevim.vim": 1
  }
}
```

## Better Solution: Consolidate Instances

### Check Which Windows Are Open
```bash
# See all Antigravity windows
wmctrl -l | grep -i antigravity
```

### Recommended Actions
1. **Close duplicate instances** - Keep only ONE Antigravity window open
2. **Use workspace folders** - Instead of opening 5 separate windows, use File > Add Folder to Workspace in a single window
3. **Close unused workspaces** - If you're not actively working on all 5 projects, close some windows

## Monitor Resource Usage

### Quick Diagnostic
Run the diagnostic script:
```bash
./diagnose-antigravity.sh
```

This shows:
- Main instances and their resource usage
- Language server memory consumption
- Open workspaces
- High CPU processes
- Total memory usage

### Manual Commands
```bash
# Total memory used by Antigravity
ps aux | grep antigravity | grep -v grep | awk '{sum+=$6} END {print sum/1024 " MB"}'

# CPU usage by instance
ps aux | grep -E "antigravity$" | grep -v grep | awk '{print $2, $3"% CPU", $4"% MEM"}'

# Watch language servers
watch -n 2 'ps aux | grep language_server_linux_x64 | grep -v grep | awk "{print \$2, \$6/1024\"MB\", \$3\"% CPU\"}"'
```

## Quick Apply (Automated)

Run the optimization script:
```bash
./optimize-antigravity.sh
```

This will:
- Backup your existing settings
- Apply all performance optimizations
- Preserve your existing preferences (theme, etc.)

Then **restart Antigravity** for changes to take effect.

## Manual Apply

1. Open Antigravity Settings: `Ctrl+,` (or `Cmd+,` on Mac)
2. Click the `{}` icon in top right to open `settings.json`
3. Add the optimization settings above
4. Restart Antigravity for changes to take effect

## Expected Results

After applying these settings:
- **File watchers**: Reduced by 60-80%
- **Memory usage**: Should drop by 2-4GB
- **CPU usage**: Should reduce by 20-30%
- **Startup time**: Faster

## If Still Lagging

1. **Check for problematic extensions**:
   ```bash
   # List installed extensions
   code --list-extensions
   ```

2. **Disable unused extensions** - Each extension can spawn processes

3. **Consider using workspace-specific settings** - Some projects don't need full language server features

4. **Check for large files** - Opening very large files can cause high memory usage

## Emergency: Quick Memory Relief

If you need immediate relief without closing windows:

```bash
# Restart language servers (they'll auto-restart)
pkill -f language_server_linux_x64

# Or restart just one instance's language servers
# (Find the workspace ID first, then kill its language server)
```


