#!/bin/bash
# Aggressive Antigravity Performance Fix
# This applies ALL optimizations and provides workspace management tips

echo "=== AGGRESSIVE ANTIGRAVITY FIX ==="
echo ""

# Check current state
echo "Current state:"
TOTAL_PROCESSES=$(ps aux | grep antigravity | grep -v grep | wc -l)
TOTAL_RAM=$(ps aux | grep antigravity | grep -v grep | awk '{sum+=$6} END {print sum/1024}')
LS_COUNT=$(ps aux | grep "language_server_linux_x64" | grep -v grep | wc -l)
LS_RAM=$(ps aux | grep "language_server_linux_x64" | grep -v grep | awk '{sum+=$6} END {print sum/1024}')

echo "  Processes: $TOTAL_PROCESSES"
echo "  Total RAM: ${TOTAL_RAM}MB ($(echo "scale=1; $TOTAL_RAM/1024" | bc)GB)"
echo "  Language Servers: $LS_COUNT (using ${LS_RAM}MB / $(echo "scale=1; $LS_RAM/1024" | bc)GB)"
echo ""

# Apply optimizations
echo "1. Applying performance optimizations..."
if [ -f "./optimize-antigravity.sh" ]; then
    ./optimize-antigravity.sh
else
    echo "   ⚠️  optimize-antigravity.sh not found, skipping..."
fi
echo ""

# Show workspaces
echo "2. Current workspaces (each spawns a language server):"
ps aux | grep "language_server_linux_x64" | grep -v grep | grep -oP "workspace_id \K[^ ]+" | sort | uniq | nl
echo ""

# Provide recommendations
echo "3. IMMEDIATE ACTIONS:"
echo ""
echo "   ⚠️  YOU HAVE $LS_COUNT WORKSPACES OPEN"
echo ""
echo "   Option A: Close 2-3 workspace windows (recommended)"
echo "      - Keep only the workspace you're actively using"
echo "      - This will immediately free ~3-4GB RAM"
echo ""
echo "   Option B: Consolidate into one window"
echo "      - Close all Antigravity windows"
echo "      - Open ONE window"
echo "      - Use File > Add Folder to Workspace for other projects"
echo "      - This reduces language servers from $LS_COUNT to 1"
echo ""
echo "   Option C: Emergency kill worst language servers"
echo "      - Run: ./kill-worst-language-servers.sh"
echo "      - They'll restart when you use those workspaces"
echo ""

# Check for file watching issues
echo "4. Checking file watching..."
MAIN_PID=$(ps aux | grep -E "antigravity$" | grep -v grep | awk '{print $2}' | head -1)
if [ ! -z "$MAIN_PID" ]; then
    FILE_HANDLES=$(lsof -p $MAIN_PID 2>/dev/null | wc -l)
    echo "   Main process has $FILE_HANDLES open file handles"
    if [ "$FILE_HANDLES" -gt 300 ]; then
        echo "   ⚠️  HIGH - File watching may be excessive"
        echo "   The optimizations should help, but closing workspaces will help more"
    else
        echo "   ✓ Reasonable"
    fi
fi
echo ""

echo "=== NEXT STEPS ==="
echo ""
echo "1. RESTART ANTIGRAVITY (required for optimizations to take effect)"
echo "2. Close unused workspace windows (biggest impact)"
echo "3. Monitor with: ./diagnose-antigravity.sh"
echo ""
echo "Expected improvement after closing 2 workspaces:"
echo "  - RAM: ~13GB → ~7GB"
echo "  - CPU: ~112% → ~50%"
echo "  - Processes: ~52 → ~30"























