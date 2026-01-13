#!/bin/bash
#
# verify-bandwidth.sh
# Version: 1.0.0
# Created: 11. Januar 2026
#
# Purpose: Verify tc-netem bandwidth limiting configuration
#
# Usage:
#   ./verify-bandwidth.sh [--interface INTERFACE]

set -uo pipefail

INTERFACE="${SNOWFLAKE_INTERFACE:-wlan0}"
readonly TC="/usr/sbin/tc"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --interface)
            INTERFACE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

echo "=== Snowflake Bandwidth Limiter Verification ==="
echo ""

# 1. Current tc-netem Configuration
echo "📊 Current tc-netem Configuration:"
sudo "$TC" qdisc show dev "$INTERFACE" | grep -q "tbf" && {
    sudo "$TC" qdisc show dev "$INTERFACE"
    echo "✅ TBF qdisc is active"
} || {
    echo "❌ No TBF qdisc configured (bandwidth unlimited)"
}
echo ""

# 2. Interface Statistics
echo "📈 Interface Statistics:"
ip -s link show "$INTERFACE" | grep -A 5 "$INTERFACE"
echo ""

# 3. Expected Profile (based on current time)
echo "⏰ Expected Profile Detection:"
HOUR=$(date +%H)
if [ "$HOUR" -ge 0 ] && [ "$HOUR" -lt 9 ]; then
    echo "Current Time: $(date '+%H:%M')"
    echo "Expected: NIGHTTIME profile (20 Mbps, 00:00-09:00)"
else
    echo "Current Time: $(date '+%H:%M')"
    echo "Expected: DAYTIME profile (6 Mbps, 09:00-00:00)"
fi
echo ""

# 4. Actual Rate Limit
echo "🔧 Actual Rate Limit:"
RATE=$(sudo "$TC" qdisc show dev "$INTERFACE" | grep -oP 'rate \K[^ ]+' || echo "none")
echo "Configured Rate: $RATE"

if [[ "$RATE" != "none" ]]; then
    # Convert to Mbps for readability
    if [[ "$RATE" =~ ([0-9]+)([MK]?)bit ]]; then
        VALUE="${BASH_REMATCH[1]}"
        UNIT="${BASH_REMATCH[2]}"

        if [[ "$UNIT" == "M" ]]; then
            echo "  → ${VALUE} Mbps"
        elif [[ "$UNIT" == "K" ]]; then
            MBPS=$((VALUE / 1000))
            echo "  → ${MBPS} Mbps (approx)"
        fi
    fi
fi
echo ""

# 5. Profile Match Check
echo "✅ Profile Match Check:"
if [[ "$RATE" == "6Mbit" ]] && (( HOUR >= 9 )); then
    echo "✅ MATCH: Daytime profile correctly applied (6 Mbps)"
elif [[ "$RATE" == "20Mbit" ]] && (( HOUR >= 0 && HOUR < 9 )); then
    echo "✅ MATCH: Nighttime profile correctly applied (20 Mbps)"
elif [[ "$RATE" == "none" ]]; then
    echo "⚠️  WARNING: No bandwidth limit configured"
else
    echo "❌ MISMATCH: Current rate ($RATE) does not match expected profile"
fi

exit 0
