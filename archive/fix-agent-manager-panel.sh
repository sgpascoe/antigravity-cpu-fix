#!/bin/bash
# Fix Agent Manager Panel High CPU Usage

echo "=== AGENT MANAGER PANEL OPTIMIZATION ==="
echo ""

SETTINGS_FILE="$HOME/.config/Antigravity/User/settings.json"

# Check if settings file exists
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "Error: Settings file not found at $SETTINGS_FILE"
    exit 1
fi

echo "Current agent manager panel processes:"
ps aux | grep "chrome.*gemini.*antigravity" | grep -v grep | awk '{printf "  PID: %-6s CPU: %5s%% MEM: %5s%%\n", $2, $3, $4}'
echo ""

echo "Current renderer processes (zygote) CPU usage:"
ps aux | grep "antigravity.*--type=zygote" | grep -v grep | awk '{sum+=$3; count++} END {if(count>0) printf "  Average: %.1f%% CPU across %d processes\n", sum/count, count}'
echo ""

# Add agent manager optimizations using Python
python3 << 'PYTHON_SCRIPT'
import json
import os

settings_file = os.path.expanduser("~/.config/Antigravity/User/settings.json")

# Read existing settings
try:
    with open(settings_file, 'r') as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError) as e:
    print(f"Error reading settings: {e}")
    exit(1)

# Agent manager optimizations
agent_settings = {
    "antigravity.agentManager.autoRefresh": False,
    "antigravity.agentManager.pollInterval": 10000,  # Increase poll interval to 10 seconds
    "workbench.panel.defaultLocation": "bottom",
    "workbench.panel.opensMaximized": "never"
}

# Merge settings
for key, value in agent_settings.items():
    settings[key] = value

# Write back
try:
    with open(settings_file, 'w') as f:
        json.dump(settings, f, indent=2)
    print("✓ Agent manager panel optimizations applied")
    print("")
    print("Settings added:")
    for key, value in agent_settings.items():
        print(f"  {key}: {value}")
except Exception as e:
    print(f"Error writing settings: {e}")
    exit(1)
PYTHON_SCRIPT

echo ""
echo "=== OPTIMIZATIONS APPLIED ==="
echo ""
echo "Changes made:"
echo "  • Disabled auto-refresh in agent manager panel"
echo "  • Increased poll interval to 10 seconds (was likely 1-2 seconds)"
echo "  • Optimized panel behavior"
echo ""
echo "NEXT STEPS:"
echo "1. RESTART ANTIGRAVITY for changes to take effect"
echo "2. The agent manager panel will still work, but won't constantly refresh"
echo "3. You can manually refresh it when needed"
echo ""
echo "If CPU is still high after restart, try:"
echo "  • Closing the agent manager panel when not in use"
echo "  • View > Appearance > Panel (toggle it off)"
echo "  • Or use Ctrl+J to toggle panel visibility"






















