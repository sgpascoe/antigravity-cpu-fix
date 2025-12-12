#!/bin/bash
# Quick Antigravity CPU check - one-shot diagnostic

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== QUICK ANTIGRAVITY CHECK ===${NC}"
echo ""

# Renderer processes
RENDERER_CPU=$(ps aux | grep "/usr/share/antigravity.*--type=zygote" | grep -v grep | awk '{sum+=$3} END {printf "%.1f", sum}')
RENDERER_COUNT=$(ps aux | grep "/usr/share/antigravity.*--type=zygote" | grep -v grep | wc -l)
RENDERER_THREADS=$(ps aux | grep "/usr/share/antigravity.*--type=zygote" | grep -v grep | awk '{print $2}' | xargs -I {} ps -p {} -o nlwp --no-headers 2>/dev/null | awk '{sum+=$1} END {print sum}')

# Main process
MAIN_CPU=$(ps aux | grep -E "/usr/share/antigravity/antigravity$" | grep -v grep | awk '{print $3}' | head -1)
MAIN_CPU=${MAIN_CPU:-0}

# Language servers
LS_CPU=$(ps aux | grep "language_server_linux_x64" | grep -v grep | awk '{sum+=$3} END {printf "%.1f", sum}')
LS_COUNT=$(ps aux | grep "language_server_linux_x64" | grep -v grep | wc -l)

# Total
TOTAL_CPU=$(ps aux | grep -E "/usr/share/antigravity|antigravity-browser-profile" | grep -v grep | awk '{sum+=$3} END {printf "%.1f", sum}')
TOTAL_PROCESSES=$(ps aux | grep -E "/usr/share/antigravity|antigravity-browser-profile" | grep -v grep | wc -l)

# Windows
WINDOW_COUNT=$(wmctrl -l 2>/dev/null | grep -i antigravity | wc -l)

echo -e "${YELLOW}Renderer Processes:${NC}"
echo -e "  Count: ${RENDERER_COUNT}"
echo -e "  CPU: ${RED}${RENDERER_CPU}%${NC}"
echo -e "  Threads: ${RED}${RENDERER_THREADS}${NC} (embarrassing)"
echo ""

echo -e "${YELLOW}Main Process:${NC}"
echo -e "  CPU: ${MAIN_CPU}%"
echo ""

echo -e "${YELLOW}Language Servers:${NC}"
echo -e "  Count: ${LS_COUNT}"
echo -e "  CPU: ${LS_CPU}% (actually useful)"
echo ""

echo -e "${YELLOW}Total:${NC}"
echo -e "  Processes: ${TOTAL_PROCESSES}"
echo -e "  CPU: ${RED}${TOTAL_CPU}%${NC}"
echo -e "  Windows: ${WINDOW_COUNT}"
echo ""

# Status
if (( $(echo "$RENDERER_CPU > 50" | bc -l) )); then
    echo -e "${RED}🔴 CRITICAL: Renderers using >50% CPU${NC}"
    echo -e "   This is embarrassing for a Google product"
elif (( $(echo "$RENDERER_CPU > 20" | bc -l) )); then
    echo -e "${YELLOW}🟡 WARNING: Renderers using >20% CPU${NC}"
else
    echo -e "${GREEN}✓ Renderer CPU usage is reasonable${NC}"
fi

if [ "$WINDOW_COUNT" -gt 1 ]; then
    echo -e "${YELLOW}⚠️  ${WINDOW_COUNT} windows open (each spawns a renderer)${NC}"
fi

