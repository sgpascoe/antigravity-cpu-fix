#!/bin/bash
# Monitor Antigravity performance after fixes

echo "=== ANTIGRAVITY PERFORMANCE MONITOR ==="
echo ""

# Check if Antigravity is running
if ! pgrep -f "/usr/share/antigravity/antigravity" > /dev/null 2>&1; then
    echo "⚠️  Antigravity is not running"
    echo ""
    echo "Start it with: antigravity"
    exit 0
fi

echo "Monitoring for 10 seconds..."
echo ""

# Collect samples
TOTAL_CPU=0
SAMPLES=0
MAX_CPU=0
MIN_CPU=1000

for i in {1..10}; do
    CPU=$(ps aux | grep -E '/usr/share/antigravity/antigravity' | grep -v grep | awk '{sum+=$3} END {print sum}')
    
    if [[ "$CPU" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        TOTAL_CPU=$(echo "$TOTAL_CPU + $CPU" | bc)
        SAMPLES=$((SAMPLES + 1))
        
        # Track min/max
        if (( $(echo "$CPU > $MAX_CPU" | bc -l) )); then
            MAX_CPU=$CPU
        fi
        if (( $(echo "$CPU < $MIN_CPU" | bc -l) )); then
            MIN_CPU=$CPU
        fi
        
        printf "\r  Sample %d/10: %.1f%% CPU (Min: %.1f%%, Max: %.1f%%)" $i $CPU $MIN_CPU $MAX_CPU
    fi
    
    sleep 1
done

echo ""
echo ""

if [ $SAMPLES -eq 0 ]; then
    echo "⚠️  Could not collect samples"
    exit 1
fi

AVG_CPU=$(echo "scale=1; $TOTAL_CPU / $SAMPLES" | bc)

echo "Results:"
echo "  Average CPU: ${AVG_CPU}%"
echo "  Min CPU:     ${MIN_CPU}%"
echo "  Max CPU:     ${MAX_CPU}%"
echo ""

# Evaluate
if (( $(echo "$AVG_CPU < 10" | bc -l) )); then
    echo "✅ EXCELLENT - CPU usage is very low!"
elif (( $(echo "$AVG_CPU < 20" | bc -l) )); then
    echo "✅ GOOD - CPU usage is reasonable"
elif (( $(echo "$AVG_CPU < 50" | bc -l) )); then
    echo "⚠️  MODERATE - CPU usage is higher than expected"
    echo "   Consider closing unused workspace windows"
else
    echo "❌ HIGH - CPU usage is still very high"
    echo "   The fixes may not have taken effect yet"
    echo "   Make sure you restarted Antigravity after applying fixes"
fi

echo ""
echo "Process breakdown:"
ps aux | grep -E '/usr/share/antigravity/antigravity' | grep -v grep | awk '{printf "  PID %-8s: %5.1f%% CPU, %6.1f MB RAM\n", $2, $3, $6/1024}' | head -10

echo ""
echo "Total memory usage:"
TOTAL_RAM=$(ps aux | grep -E '/usr/share/antigravity/antigravity' | grep -v grep | awk '{sum+=$6} END {print sum/1024}')
echo "  ${TOTAL_RAM} MB ($(echo "scale=1; $TOTAL_RAM/1024" | bc) GB)"



