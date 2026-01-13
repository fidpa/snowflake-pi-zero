#!/bin/bash
#
# tc-bandwidth-limiter.sh
# Version: 1.0.0
# Created: 11. Januar 2026
#
# Purpose: Limit egress bandwidth for Snowflake proxy using tc-netem TBF (Token Bucket Filter)
#
# Profiles:
#   - daytime:   6 Mbps (09:00-00:00)
#   - nighttime: 20 Mbps (00:00-09:00)
#   - remove:    Remove all bandwidth limits
#
# Usage:
#   ./tc-bandwidth-limiter.sh --interface wlan0 daytime
#   ./tc-bandwidth-limiter.sh --interface wlan0 nighttime
#   ./tc-bandwidth-limiter.sh --interface wlan0 remove

set -uo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Default interface (can be overridden with --interface)
INTERFACE="${SNOWFLAKE_INTERFACE:-wlan0}"
PROFILE=""

# Bandwidth profiles (in kbit for tc)
readonly DAYTIME_LIMIT="6mbit"     # 6 Mbps = 6000 kbit/s
readonly NIGHTTIME_LIMIT="20mbit"  # 20 Mbps = 20000 kbit/s
readonly BURST="32kbit"             # Allow brief bursts (32 KB)
readonly LATENCY="50ms"             # Maximum latency

# ============================================================================
# LOGGING
# ============================================================================

log() {
    logger -t tc-bandwidth-limiter "$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    logger -t tc-bandwidth-limiter -p user.err "ERROR: $*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

# ============================================================================
# USAGE
# ============================================================================

print_usage() {
    cat << EOF
Usage: $0 [--interface INTERFACE] <profile>

Limit egress bandwidth for Snowflake proxy using tc-netem Token Bucket Filter.

OPTIONS:
    --interface INTERFACE   Network interface (default: wlan0)

PROFILES:
    daytime     Apply 6 Mbps limit (09:00-00:00)
    nighttime   Apply 20 Mbps limit (00:00-09:00)
    remove      Remove all bandwidth limits

EXAMPLES:
    $0 --interface wlan0 daytime     # Limit to 6 Mbps
    $0 nighttime                     # Limit to 20 Mbps (default interface)
    $0 remove                        # Remove limits

TECHNICAL DETAILS:
    Daytime:   $DAYTIME_LIMIT ($BURST burst, $LATENCY latency)
    Nighttime: $NIGHTTIME_LIMIT ($BURST burst, $LATENCY latency)
    Method:    Token Bucket Filter (TBF)

EOF
}

# ============================================================================
# MAIN
# ============================================================================

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --interface)
            INTERFACE="$2"
            shift 2
            ;;
        daytime|nighttime|remove)
            PROFILE="$1"
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            error "Unknown argument: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

# Validate profile argument
if [[ -z "$PROFILE" ]]; then
    error "No profile specified"
    print_usage
    exit 1
fi

# Remove existing qdisc (always clean start)
tc qdisc del dev "$INTERFACE" root 2>/dev/null || true
log "Removed existing qdisc on $INTERFACE"

# Apply bandwidth limit based on profile
case "$PROFILE" in
    daytime)
        if tc qdisc add dev "$INTERFACE" root tbf rate "$DAYTIME_LIMIT" burst "$BURST" latency "$LATENCY"; then
            log "✅ DAYTIME profile applied: ${DAYTIME_LIMIT} on ${INTERFACE}"

            # Verify configuration
            tc qdisc show dev "$INTERFACE" | grep -q "tbf" && {
                log "Verification: TBF qdisc active"
            }
        else
            error "Failed to apply DAYTIME profile"
            exit 1
        fi
        ;;

    nighttime)
        if tc qdisc add dev "$INTERFACE" root tbf rate "$NIGHTTIME_LIMIT" burst "$BURST" latency "$LATENCY"; then
            log "✅ NIGHTTIME profile applied: ${NIGHTTIME_LIMIT} on ${INTERFACE}"

            # Verify configuration
            tc qdisc show dev "$INTERFACE" | grep -q "tbf" && {
                log "Verification: TBF qdisc active"
            }
        else
            error "Failed to apply NIGHTTIME profile"
            exit 1
        fi
        ;;

    remove)
        log "✅ Bandwidth limiting removed on ${INTERFACE}"
        ;;

    *)
        error "Invalid profile '$PROFILE' (use: daytime|nighttime|remove)"
        print_usage
        exit 1
        ;;
esac

# Show final configuration
log "Current tc qdisc configuration:"
tc qdisc show dev "$INTERFACE"

exit 0
