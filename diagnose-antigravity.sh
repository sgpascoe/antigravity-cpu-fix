#!/bin/bash
# Antigravity Resource Diagnostic Script

echo "=== ANTIGRAVITY RESOURCE DIAGNOSTIC ==="
echo ""

echo "1. MAIN INSTANCES:"
ps aux | grep -E "antigravity$" | grep -v grep | awk '{printf "  PID: %-6s CPU: %5s%% MEM: %5s%% RSS: %6sMB\n", $2, $3, $4, $6/1024}'
echo ""

echo "2. TOTAL PROCESSES:"
TOTAL=$(ps aux | grep antigravity | grep -v grep | wc -l)
echo "  Total Antigravity processes: $TOTAL"
echo ""

echo "3. LANGUAGE SERVERS (Memory Hogs):"
ps aux | grep "language_server_linux_x64" | grep -v grep | awk '{printf "  PID: %-6s CPU: %5s%% MEM: %5s%% RSS: %8sMB\n", $2, $3, $4, $6/1024}'
TOTAL_LS_MEM=$(ps aux | grep "language_server_linux_x64" | grep -v grep | awk '{sum+=$6} END {print sum/1024}')
echo "  Total Language Server Memory: ${TOTAL_LS_MEM}MB ($(echo "scale=1; $TOTAL_LS_MEM/1024" | bc)GB)"
echo ""

echo "4. OPEN WORKSPACES:"
ps aux | grep "language_server_linux_x64" | grep -v grep | grep -oP "workspace_id \K[^ ]+" | sort | uniq | while read ws; do
  echo "  - $ws"
done
echo ""

echo "5. HIGH CPU PROCESSES (>5%):"
ps aux | grep antigravity | grep -v grep | awk '$3 > 5.0 {printf "  PID: %-6s CPU: %5s%% %s\n", $2, $3, substr($0, index($0,$11))}'
echo ""

echo "6. ZYGOTE PROCESSES (Renderer processes):"
ZYGOTE_COUNT=$(ps aux | grep "antigravity.*--type=zygote" | grep -v grep | wc -l)
echo "  Count: $ZYGOTE_COUNT"
ps aux | grep "antigravity.*--type=zygote" | grep -v grep | awk '{sum+=$6} END {print "  Total Memory: " sum/1024 "MB"}' | head -1
echo ""

echo "7. TOTAL MEMORY USAGE:"
TOTAL_MEM=$(ps aux | grep antigravity | grep -v grep | awk '{sum+=$6} END {print sum/1024}')
echo "  Total Antigravity Memory: ${TOTAL_MEM}MB ($(echo "scale=1; $TOTAL_MEM/1024" | bc)GB)"
echo ""

echo "8. TOP CPU CONSUMERS:"
ps aux | grep antigravity | grep -v grep | sort -k3 -rn | head -5 | awk '{printf "  PID: %-6s CPU: %5s%% %s\n", $2, $3, substr($0, index($0,$11))}'
echo ""

echo "=== RECOMMENDATIONS ==="
if [ "$TOTAL" -gt 30 ]; then
  echo "⚠️  Too many processes ($TOTAL). Consider closing unused workspaces."
fi

if (( $(echo "$TOTAL_LS_MEM > 4000" | bc -l) )); then
  echo "⚠️  Language servers using >4GB. Each workspace spawns one - close unused workspaces."
fi

if [ "$ZYGOTE_COUNT" -gt 10 ]; then
  echo "⚠️  Too many renderer processes ($ZYGOTE_COUNT). This is normal but can be reduced."
fi

echo ""
echo "To reduce usage:"
echo "  1. Close unused workspace windows"
echo "  2. Use File > Add Folder to Workspace instead of opening multiple windows"
echo "  3. Check Settings > Extensions and disable unused ones"
echo "  4. Clear cache: Settings > Storage > Clear Cache"






















