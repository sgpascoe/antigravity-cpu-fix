#!/bin/bash
# Quick Antigravity Optimization Script
# Applies performance settings to reduce resource usage

SETTINGS_FILE="$HOME/.config/Antigravity/User/settings.json"
BACKUP_FILE="$HOME/.config/Antigravity/User/settings.json.backup.$(date +%Y%m%d_%H%M%S)"

echo "=== ANTIGRAVITY OPTIMIZATION ==="
echo ""

# Backup existing settings
if [ -f "$SETTINGS_FILE" ]; then
    echo "Backing up existing settings to: $BACKUP_FILE"
    cp "$SETTINGS_FILE" "$BACKUP_FILE"
fi

# Create settings directory if it doesn't exist
mkdir -p "$HOME/.config/Antigravity/User"

# Check if settings file exists and read it
if [ -f "$SETTINGS_FILE" ]; then
    # Use Python to merge settings (safer than sed for JSON)
    python3 << 'PYTHON_SCRIPT'
import json
import sys
import os

settings_file = os.path.expanduser("~/.config/Antigravity/User/settings.json")
backup_file = settings_file + ".backup." + os.popen("date +%Y%m%d_%H%M%S").read().strip()

# Read existing settings
try:
    with open(settings_file, 'r') as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

# Performance optimizations
optimizations = {
    # File watching optimizations
    "files.watcherExclude": {
        "**/.git/objects/**": True,
        "**/.git/subtree-cache/**": True,
        "**/node_modules/**": True,
        "**/.hg/**": True,
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
    
    # Search optimizations
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
    
    # TypeScript optimizations
    "typescript.tsserver.maxTsServerMemory": 2048,
    "typescript.tsserver.watchOptions": {
        "watchFile": "useFsEvents",
        "watchDirectory": "useFsEvents",
        "fallbackPolling": "dynamicPriority",
        "synchronousWatchDirectory": False
    },
    "javascript.updateImportsOnFileMove.enabled": "never",
    
    # Python optimizations
    "python.analysis.typeCheckingMode": "basic",
    "python.analysis.autoImportCompletions": False,
    "python.analysis.diagnosticMode": "workspace",
    "python.analysis.indexing": False,
    
    # Disable unnecessary features
    "extensions.autoCheckUpdates": False,
    "extensions.autoUpdate": False,
    "telemetry.telemetryLevel": "off",
    "workbench.enableExperiments": False,
    "editor.minimap.enabled": False,
    "editor.suggest.showStatusBar": False,
    "workbench.settings.enableNaturalLanguageSearch": False
}

# Merge optimizations (existing settings take precedence for user preferences)
for key, value in optimizations.items():
    if key not in settings:
        settings[key] = value
    elif isinstance(value, dict) and isinstance(settings.get(key), dict):
        # Merge dictionaries
        settings[key].update(value)

# Write back
with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)

print(f"✓ Settings optimized and saved to {settings_file}")
PYTHON_SCRIPT

else
    # Create new settings file with optimizations
    cat > "$SETTINGS_FILE" << 'EOF'
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
    "**/target/**": true,
    "**/.cache/**": true
  },
  "files.watcherInclude": [],
  "search.exclude": {
    "**/node_modules": true,
    "**/venv": true,
    "**/.venv": true,
    "**/__pycache__": true,
    "**/dist": true,
    "**/build": true,
    "**/.next": true,
    "**/target": true,
    "**/.git": true,
    "**/.cache": true
  },
  "search.followSymlinks": false,
  "search.useIgnoreFiles": true,
  "typescript.tsserver.maxTsServerMemory": 2048,
  "typescript.tsserver.watchOptions": {
    "watchFile": "useFsEvents",
    "watchDirectory": "useFsEvents",
    "fallbackPolling": "dynamicPriority",
    "synchronousWatchDirectory": false
  },
  "javascript.updateImportsOnFileMove.enabled": "never",
  "python.analysis.typeCheckingMode": "basic",
  "python.analysis.autoImportCompletions": false,
  "python.analysis.diagnosticMode": "workspace",
  "python.analysis.indexing": false,
  "extensions.autoCheckUpdates": false,
  "extensions.autoUpdate": false,
  "telemetry.telemetryLevel": "off",
  "workbench.enableExperiments": false,
  "editor.minimap.enabled": false,
  "editor.suggest.showStatusBar": false,
  "workbench.settings.enableNaturalLanguageSearch": false
}
EOF
    echo "✓ Created new optimized settings file"
fi

echo ""
echo "=== OPTIMIZATION COMPLETE ==="
echo ""
echo "Next steps:"
echo "1. Restart Antigravity for changes to take effect"
echo "2. Close unused workspace windows (you have 4 open)"
echo "3. Use 'File > Add Folder to Workspace' instead of opening multiple windows"
echo ""
echo "To see current resource usage, run:"
echo "  ./diagnose-antigravity.sh"
echo ""
echo "Settings file: $SETTINGS_FILE"
if [ -f "$BACKUP_FILE" ]; then
    echo "Backup saved to: $BACKUP_FILE"
fi























