#!/bin/bash
#
# snowflake-metrics-exporter.sh
# Version: 1.0.0
# Created: 11. Januar 2026
#
# Purpose: Export Snowflake proxy metrics to Prometheus textfile collector
#
# Metrics:
#   - snowflake_connected_clients: Number of currently connected Tor clients
#   - snowflake_bytes_proxied_total: Total bytes proxied through Snowflake
#   - snowflake_proxy_uptime_seconds: Snowflake proxy uptime in seconds
#   - snowflake_service_status: Service status (1=running, 0=stopped)
#
# Usage:
#   ./snowflake-metrics-exporter.sh <device-name>

set -uo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly DEVICE_NAME="${1:-snowflake}"
readonly LOG_FILE="${SNOWFLAKE_LOG_DIR:-/var/log/snowflake}/snowflake-proxy.log"
readonly METRICS_FILE="${SNOWFLAKE_METRICS_DIR:-/var/lib/node_exporter/textfile_collector}/snowflake_${DEVICE_NAME}.prom"

# ============================================================================
# FUNCTIONS
# ============================================================================

log() {
    logger -t snowflake-metrics "[$DEVICE_NAME] $*"
}

get_connected_clients() {
    # Parse last summary interval from logs
    # Example log lines:
    #   "In the last 5m0s, there were 1 connections."
    #   "In the last 1h0m0s, there have been 3 connections."
    grep -oP 'there (were|have been) \K\d+(?= connections?)' "$LOG_FILE" 2>/dev/null | tail -1 || echo "0"
}

get_bytes_proxied() {
    # Parse total bytes from logs
    # Example: "Traffic Relayed ↑ 2011 KB, ↓ 146 KB."
    # We extract the upload bytes (↑) and convert KB to bytes
    local kb_uploaded=$(grep -oP 'Traffic Relayed ↑ \K\d+(?= KB)' "$LOG_FILE" 2>/dev/null | tail -1)
    if [[ -n "$kb_uploaded" ]]; then
        echo $((kb_uploaded * 1024))
    else
        echo "0"
    fi
}

get_uptime_seconds() {
    # Get process uptime in seconds
    if pgrep -x snowflake-proxy >/dev/null 2>&1; then
        ps -C snowflake-proxy -o etimes= 2>/dev/null | tr -d ' ' || echo "0"
    else
        echo "0"
    fi
}

get_service_status() {
    if systemctl is-active snowflake-proxy.service >/dev/null 2>&1; then
        echo "1"
    else
        echo "0"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

# Check if log file exists
if [[ ! -f "$LOG_FILE" ]]; then
    log "WARNING: Log file not found at $LOG_FILE"
    CONNECTED_CLIENTS=0
    BYTES_PROXIED=0
else
    CONNECTED_CLIENTS=$(get_connected_clients)
    BYTES_PROXIED=$(get_bytes_proxied)
fi

UPTIME_SECONDS=$(get_uptime_seconds)
SERVICE_STATUS=$(get_service_status)

# Generate Prometheus metrics
cat > "$METRICS_FILE" << EOF
# HELP snowflake_connected_clients Number of Tor clients connected in last summary interval
# TYPE snowflake_connected_clients gauge
snowflake_connected_clients{device="$DEVICE_NAME"} $CONNECTED_CLIENTS

# HELP snowflake_bytes_proxied_total Total bytes proxied through Snowflake in last interval
# TYPE snowflake_bytes_proxied_total counter
snowflake_bytes_proxied_total{device="$DEVICE_NAME"} $BYTES_PROXIED

# HELP snowflake_proxy_uptime_seconds Snowflake proxy uptime in seconds
# TYPE snowflake_proxy_uptime_seconds gauge
snowflake_proxy_uptime_seconds{device="$DEVICE_NAME"} $UPTIME_SECONDS

# HELP snowflake_service_status Snowflake service status (1=running, 0=stopped)
# TYPE snowflake_service_status gauge
snowflake_service_status{device="$DEVICE_NAME"} $SERVICE_STATUS
EOF

log "Metrics exported: clients=$CONNECTED_CLIENTS, bytes=$BYTES_PROXIED, uptime=${UPTIME_SECONDS}s, status=$SERVICE_STATUS"

exit 0
