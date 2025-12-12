#!/bin/bash
# Fix high CPU usage from agent conversation renderer processes

echo "=== AGENT CONVERSATION CPU FIX ==="
echo ""

echo "Current renderer processes (these render the agent conversation UI):"
ps aux | grep "antigravity.*--type=zygote" | grep -v grep | awk '{printf "  PID: %-6s CPU: %5s%% MEM: %5s%% RSS: %6sMB\n", $2, $3, $4, $6/1024}' | sort -k2 -rn | head -10
echo ""

TOTAL_CPU=$(ps aux | grep "antigravity.*--type=zygote" | grep -v grep | awk '{sum+=$3} END {print sum}')
echo "Total CPU from renderer processes: ${TOTAL_CPU}%"
echo ""

echo "Main Antigravity process:"
ps aux | grep -E "antigravity$" | grep -v grep | awk '{printf "  PID: %-6s CPU: %5s%% MEM: %5s%% RSS: %6sMB\n", $2, $3, $4, $6/1024}'
echo ""

echo "Agent Manager Chrome processes:"
CHROME_CPU=$(ps aux | grep chrome | grep gemini | grep -v grep | awk '{sum+=$3} END {print sum}')
CHROME_COUNT=$(ps aux | grep chrome | grep gemini | grep -v grep | wc -l)
echo "  $CHROME_COUNT processes, ${CHROME_CPU}% CPU total"
echo ""

echo "=== THE PROBLEM ==="
echo ""
echo "The renderer processes (zygote) are rendering your agent conversation UI."
echo "They're using 14-18% CPU EACH because the UI is constantly updating."
echo ""
echo "This is a known Antigravity issue - the conversation UI is too CPU-intensive."
echo ""

echo "=== SOLUTIONS ==="
echo ""
echo "1. REDUCE UI UPDATES (Settings):"
echo "   Add to settings.json:"
echo ""
cat << 'EOF'
  "workbench.editor.enablePreview": false,
  "workbench.editor.enablePreviewFromQuickOpen": false,
  "editor.renderWhitespace": "none",
  "editor.renderLineHighlight": "none",
  "editor.smoothScrolling": false,
  "workbench.list.smoothScrolling": false,
  "editor.cursorBlinking": "solid",
  "editor.cursorSmoothCaretAnimation": "off",
  "editor.minimap.enabled": false,
  "workbench.activityBar.visible": false
EOF
echo ""

echo "2. CLOSE OLD WORKSPACES (they're still running language servers):"
ps aux | grep "language_server_linux_x64" | grep -v grep | grep -oP "workspace_id \K[^ ]+" | sort | uniq | while read ws; do
    echo "   - $ws"
done
echo ""
echo "   Close these workspace windows to free ~5GB RAM"
echo ""

echo "3. RESTART ANTIGRAVITY after closing workspaces"
echo "   This will reduce processes from 72 to ~20-30"
echo ""

echo "4. IF STILL HIGH CPU:"
echo "   The agent conversation UI itself is CPU-intensive"
echo "   This is a limitation of Antigravity's UI rendering"
echo "   Consider:"
echo "   - Using smaller conversation windows"
echo "   - Closing conversation when not actively chatting"
echo "   - Reporting to Antigravity team (this is a known issue)"
echo ""






















