#!/bin/bash
# Comprehensive Antigravity CPU/Memory/Thread Monitoring Script
# Tracks the embarrassing resource usage of Google's Antigravity

set -euo pipefail

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INTERVAL=${1:-2}  # Update interval in seconds (default 2)
HISTORY_FILE="${HOME}/.antigravity_monitor_history.txt"
MAX_HISTORY=100

# Initialize history file
touch "$HISTORY_FILE"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     ANTIGRAVITY RESOURCE MONITOR (Google's Embarrassment)    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Monitoring every ${INTERVAL} seconds. Press Ctrl+C to stop."
echo ""

# Function to get process info
get_process_info() {
    local pid=$1
    if [ ! -d "/proc/$pid" ]; then
        return 1
    fi
    
    ps -p "$pid" -o pid,pcpu,pmem,rss,nlwp,etime,stat,cmd --no-headers 2>/dev/null || return 1
}

# Function to analyze renderer processes
analyze_renderers() {
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}RENDERER PROCESSES (The Embarrassing Part)${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local renderers=$(ps aux | grep "/usr/share/antigravity.*--type=zygote" | grep -v grep | awk '{print $2}')
    
    if [ -z "$renderers" ]; then
        echo -e "${GREEN}✓ No renderer processes found${NC}"
        return
    fi
    
    local total_cpu=0
    local total_mem=0
    local total_threads=0
    local count=0
    
    echo ""
    printf "%-8s %-8s %-8s %-10s %-8s %-12s %-6s\n" "PID" "CPU%" "MEM%" "RSS(MB)" "THREADS" "ETIME" "STATE"
    echo "────────────────────────────────────────────────────────────────────────────"
    
    for pid in $renderers; do
        local info=$(get_process_info "$pid")
        if [ -z "$info" ]; then
            continue
        fi
        
        local cpu=$(echo "$info" | awk '{print $2}')
        local mem=$(echo "$info" | awk '{print $3}')
        local rss=$(echo "$info" | awk '{printf "%.1f", $4/1024}')
        local threads=$(echo "$info" | awk '{print $5}')
        local etime=$(echo "$info" | awk '{print $6}')
        local state=$(echo "$info" | awk '{print $7}')
        
        # Color code based on CPU usage
        if (( $(echo "$cpu > 20" | bc -l) )); then
            color=$RED
        elif (( $(echo "$cpu > 10" | bc -l) )); then
            color=$YELLOW
        else
            color=$GREEN
        fi
        
        printf "${color}%-8s %-8s %-8s %-10s %-8s %-12s %-6s${NC}\n" \
            "$pid" "$cpu%" "$mem%" "$rss" "$threads" "$etime" "$state"
        
        total_cpu=$(echo "$total_cpu + $cpu" | bc -l)
        total_mem=$(echo "$total_mem + $mem" | bc -l)
        total_threads=$((total_threads + threads))
        count=$((count + 1))
    done
    
    echo ""
    echo -e "${BLUE}Summary:${NC}"
    echo -e "  Renderer processes: ${count}"
    echo -e "  Total CPU: ${RED}${total_cpu}%${NC}"
    echo -e "  Total Memory: ${total_mem}%"
    echo -e "  Total Threads: ${RED}${total_threads}${NC} (this is embarrassing)"
    
    # Check if CPU is excessive
    if (( $(echo "$total_cpu > 50" | bc -l) )); then
        echo ""
        echo -e "${RED}⚠️  WARNING: Using >50% CPU just to render UI!${NC}"
        echo -e "${RED}   This is what happens when Google releases unoptimized Electron apps${NC}"
    fi
    
    # Check thread count
    if [ $total_threads -gt 50 ]; then
        echo ""
        echo -e "${RED}⚠️  WARNING: ${total_threads} threads for UI rendering!${NC}"
        echo -e "${RED}   A simple UI should use <10 threads${NC}"
    fi
}

# Function to analyze main process
analyze_main() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}MAIN ANTIGRAVITY PROCESS${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local main_pid=$(ps aux | grep -E "/usr/share/antigravity/antigravity$" | grep -v grep | awk '{print $2}' | head -1)
    
    if [ -z "$main_pid" ]; then
        echo -e "${GREEN}✓ No main process found (Antigravity not running)${NC}"
        return
    fi
    
    local info=$(get_process_info "$main_pid")
    if [ -z "$info" ]; then
        return
    fi
    
    local cpu=$(echo "$info" | awk '{print $2}')
    local mem=$(echo "$info" | awk '{print $3}')
    local rss=$(echo "$info" | awk '{printf "%.1f", $4/1024}')
    local threads=$(echo "$info" | awk '{print $5}')
    local etime=$(echo "$info" | awk '{print $6}')
    
    echo ""
    echo -e "  PID: ${main_pid}"
    echo -e "  CPU: ${cpu}%"
    echo -e "  Memory: ${mem}% (${rss} MB)"
    echo -e "  Threads: ${threads}"
    echo -e "  Runtime: ${etime}"
}

# Function to analyze language servers
analyze_language_servers() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}LANGUAGE SERVERS (The Actually Useful Part)${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local ls_processes=$(ps aux | grep "language_server_linux_x64" | grep -v grep)
    
    if [ -z "$ls_processes" ]; then
        echo -e "${GREEN}✓ No language servers found${NC}"
        return
    fi
    
    local total_cpu=0
    local total_mem=0
    local count=0
    
    echo ""
    printf "%-8s %-8s %-10s %-30s\n" "PID" "CPU%" "MEM(MB)" "WORKSPACE"
    echo "────────────────────────────────────────────────────────────────────────────"
    
    echo "$ls_processes" | while read line; do
        local pid=$(echo "$line" | awk '{print $2}')
        local cpu=$(echo "$line" | awk '{print $3}')
        local mem=$(echo "$line" | awk '{printf "%.1f", $6/1024}')
        local workspace=$(echo "$line" | grep -oP "workspace_id \K[^ ]+" || echo "unknown")
        
        printf "%-8s %-8s %-10s %-30s\n" "$pid" "$cpu%" "$mem" "$workspace"
        
        total_cpu=$(echo "$total_cpu + $cpu" | bc -l)
        count=$((count + 1))
    done
    
    echo ""
    echo -e "  Language servers: ${count}"
    echo -e "  Total CPU: ${total_cpu}%"
    echo -e "  ${GREEN}Note: These are actually doing useful work (unlike renderers)${NC}"
}

# Function to get total stats
get_total_stats() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}TOTAL SYSTEM IMPACT${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local all_processes=$(ps aux | grep -E "/usr/share/antigravity|antigravity-browser-profile" | grep -v grep)
    
    if [ -z "$all_processes" ]; then
        echo -e "${GREEN}✓ Antigravity not running${NC}"
        return
    fi
    
    local total_cpu=$(echo "$all_processes" | awk '{sum+=$3} END {printf "%.1f", sum}')
    local total_mem=$(echo "$all_processes" | awk '{sum+=$6} END {printf "%.1f", sum/1024}')
    local total_processes=$(echo "$all_processes" | wc -l)
    
    echo ""
    echo -e "  Total processes: ${total_processes}"
    echo -e "  Total CPU: ${RED}${total_cpu}%${NC}"
    echo -e "  Total Memory: ${total_mem} MB ($(echo "scale=2; $total_mem/1024" | bc) GB)"
    
    # Calculate cores used (assuming 32-thread CPU)
    local cores_used=$(echo "scale=1; $total_cpu / 100 * 32" | bc)
    echo -e "  Cores/Threads used: ${RED}${cores_used}${NC} out of 32"
    
    # Save to history
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp|$total_cpu|$total_mem|$total_processes" >> "$HISTORY_FILE"
    
    # Keep history file manageable
    tail -n $MAX_HISTORY "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
    
    # Show trend if we have history
    if [ $(wc -l < "$HISTORY_FILE") -gt 1 ]; then
        echo ""
        echo -e "${BLUE}Recent trend:${NC}"
        tail -n 5 "$HISTORY_FILE" | awk -F'|' '{printf "  %s: %.1f%% CPU, %.1f MB\n", $1, $2, $3}'
    fi
}

# Function to check windows
check_windows() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}ANTIGRAVITY WINDOWS${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if ! command -v wmctrl &> /dev/null; then
        echo -e "${YELLOW}  wmctrl not installed (install with: sudo apt install wmctrl)${NC}"
        return
    fi
    
    local windows=$(wmctrl -l | grep -i antigravity)
    
    if [ -z "$windows" ]; then
        echo -e "${GREEN}✓ No Antigravity windows found${NC}"
        return
    fi
    
    local count=$(echo "$windows" | wc -l)
    echo ""
    echo -e "  Windows open: ${count}"
    echo ""
    echo "$windows" | while read line; do
        echo -e "  • ${line}"
    done
    
    if [ $count -gt 1 ]; then
        echo ""
        echo -e "${YELLOW}⚠️  Multiple windows = multiple renderers = more CPU${NC}"
        echo -e "${YELLOW}   Consider closing some windows${NC}"
    fi
}

# Function to show recommendations
show_recommendations() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}RECOMMENDATIONS${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local renderer_cpu=$(ps aux | grep "/usr/share/antigravity.*--type=zygote" | grep -v grep | awk '{sum+=$3} END {printf "%.1f", sum}')
    local window_count=$(wmctrl -l 2>/dev/null | grep -i antigravity | wc -l)
    
    echo ""
    
    if (( $(echo "$renderer_cpu > 50" | bc -l) )); then
        echo -e "${RED}🔴 CRITICAL: Renderer CPU >50%${NC}"
        echo -e "   • Close agent manager panel (Ctrl+J)"
        echo -e "   • Close conversation tabs when not in use"
        echo -e "   • Close one Antigravity window (currently: ${window_count} open)"
    fi
    
    if [ "$window_count" -gt 1 ]; then
        echo -e "${YELLOW}🟡 WARNING: Multiple windows open${NC}"
        echo -e "   • Each window spawns a renderer process"
        echo -e "   • Close windows you're not using"
        echo -e "   • Use File > Add Folder to Workspace instead"
    fi
    
    local total_cpu=$(ps aux | grep -E "/usr/share/antigravity|antigravity-browser-profile" | grep -v grep | awk '{sum+=$3} END {printf "%.1f", sum}')
    
    if (( $(echo "$total_cpu > 80" | bc -l) )); then
        echo ""
        echo -e "${RED}💀 EMBARRASSING: Antigravity using >80% CPU${NC}"
        echo -e "   This is what happens when Google releases unoptimized software"
        echo -e "   Consider using Cursor ($20/mo) or VS Code + Copilot instead"
    fi
}

# Main monitoring loop
while true; do
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     ANTIGRAVITY RESOURCE MONITOR (Google's Embarrassment)    ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Last updated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    analyze_renderers
    analyze_main
    analyze_language_servers
    get_total_stats
    check_windows
    show_recommendations
    
    echo ""
    echo -e "${BLUE}Press Ctrl+C to stop monitoring${NC}"
    sleep "$INTERVAL"
done

