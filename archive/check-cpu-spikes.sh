#!/bin/bash
# Monitor for CPU spikes and identify which processes are causing them

echo "=== ANTIGRAVITY CPU SPIKE MONITOR ==="
echo "Monitoring for 30 seconds..."
echo ""

MAX_CPU=0
SPIKE_COUNT=0
SPIKE_THRESHOLD=100  # Alert if CPU > 100%

for i in {1..30}; do
    CPU=$(ps aux | grep -E '/usr/share/antigravity/antigravity' | grep -v grep | awk '{sum+=$3} END {print sum}')
    
    if [[ "$CPU" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        if (( $(echo "$CPU > $MAX_CPU" | bc -l) )); then
            MAX_CPU=$CPU
        fi
        
        if (( $(echo "$CPU > $SPIKE_THRESHOLD" | bc -l) )); then
            SPIKE_COUNT=$((SPIKE_COUNT + 1))
            echo "⚠️  SPIKE DETECTED at sample $i: ${CPU}% CPU"
            
            # Show which processes are using CPU
            echo "   Top processes:"
            ps aux | grep -E '/usr/share/antigravity/antigravity' | grep -v grep | sort -k3 -rn | head -5 | awk '{printf "     PID %-8s: %5.1f%% CPU, %6.1f MB RAM - %s\n", $2, $3, $6/1024, substr($0, index($0,$11))}'
            echo ""
        fi
        
        printf "\r  Sample %d/30: %.1f%% CPU (Max: %.1f%%, Spikes: %d)" $i $CPU $MAX_CPU $SPIKE_COUNT
    fi
    
    sleep 1
done

echo ""
echo ""
echo "Results:"
echo "  Maximum CPU: ${MAX_CPU}%"
echo "  Spikes > ${SPIKE_THRESHOLD}%: ${SPIKE_COUNT}"
echo ""

if (( $(echo "$MAX_CPU > 200" | bc -l) )); then
    echo "❌ CRITICAL - CPU spikes over 200% detected!"
    echo "   The fixes may not be fully effective."
    echo "   Consider:"
    echo "   1. Restart Antigravity"
    echo "   2. Check if patches were applied correctly"
    echo "   3. Monitor which specific processes spike"
elif (( $(echo "$MAX_CPU > 100" | bc -l) )); then
    echo "⚠️  HIGH - CPU spikes over 100% detected"
    echo "   Some optimization may be needed"
else
    echo "✅ CPU usage is reasonable"
fi



