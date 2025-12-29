#!/usr/bin/env python3
import json
import os
import sys

# 1. Setup
if len(sys.argv) < 2:
    print("❌ Error: Missing Argument. Usage: optimize_settings.py <CONFIG_BASE_DIR>")
    print("   Linux: python optimize_settings.py ~/.config")
    print('   macOS: python optimize_settings.py "$HOME/Library/Application Support"')
    sys.exit(1)

# Expand '~' and join with the standard Antigravity path
base_dir = os.path.expanduser(sys.argv[1])
settings_file = os.path.join(base_dir, "Antigravity", "User", "settings.json")

# 2. Validation
if not os.path.exists(settings_file):
    print(f"⚠️  Settings file not found at: {settings_file}")
    print(f"   (Checked inside base dir: {base_dir})")
    sys.exit(0)

print(f"🔧 Optimization Target: {settings_file}")

# 3. Apply Settings
with open(settings_file, "r") as f:
    try:
        settings = json.load(f)
    except json.JSONDecodeError:
        print("❌ Error parsing settings.json. Skipping.")
        sys.exit(0)

settings.update(
    {
        "telemetry.telemetryLevel": "off",
        "telemetry.enableTelemetry": False,
        "telemetry.enableCrashReporter": False,
        "redhat.telemetry.enabled": False,
        "google.telemetry.enabled": False,
        "cloudcode.telemetry.enabled": False,
        "files.watcherExclude": {
            "**/.git/objects/**": True,
            "**/.git/subtree-cache/**": True,
            "**/node_modules/**": True,
            "**/.venv/**": True,
            "**/__pycache__/**": True,
            "**/dist/**": True,
            "**/build/**": True,
            "**/.next/**": True,
            "**/target/**": True,
            "**/.cache/**": True,
        },
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
            "**/.cache": True,
        },
        "search.followSymlinks": False,
        "search.useIgnoreFiles": True,
        "typescript.tsserver.maxTsServerMemory": 2048,
        "typescript.tsserver.watchOptions": {
            "watchFile": "useFsEvents",
            "watchDirectory": "useFsEvents",
            "fallbackPolling": "dynamicPriority",
            "synchronousWatchDirectory": False,
        },
        "python.analysis.typeCheckingMode": "basic",
        "python.analysis.autoImportCompletions": False,
        "python.analysis.diagnosticMode": "workspace",
        "python.analysis.indexing": False,
        # UI / Rendering - Saves CPU & GPU
        "editor.minimap.enabled": False,
        "editor.smoothScrolling": False,
        "workbench.list.smoothScrolling": False,
        "window.autoDetectColorScheme": False,
        "workbench.reduceMotion": "on",
        # Background Processes - Saves CPU cycles
        "git.autorefresh": False,
        "extensions.autoUpdate": False,
        "debug.toolBarLocation": "docked",
    }
)

with open(settings_file, "w") as f:
    json.dump(settings, f, indent=2)

print("✓ Optimized settings")
