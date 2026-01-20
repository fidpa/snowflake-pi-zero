#!/bin/bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 Marc Allgeier
#
# Snowflake Pi Zero Installer
# Version: 1.3.0
# One-line install: curl -sSL https://raw.githubusercontent.com/fidpa/snowflake-pi-zero/main/install.sh | bash
#
# This script installs Tor Snowflake Proxy on Raspberry Pi Zero with monitoring and bandwidth management.

set -uo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

DEVICE_NAME="${DEVICE_NAME:-snowflake}"
INSTALL_DIR="${INSTALL_DIR:-/opt/snowflake}"
LOG_DIR="${LOG_DIR:-/var/log/snowflake}"
METRICS_DIR="${METRICS_DIR:-/var/lib/node_exporter/textfile_collector}"
SERVICE_USER="${SERVICE_USER:-$(whoami)}"
INTERFACE="${INTERFACE:-wlan0}"

BANDWIDTH_DAYTIME="${BANDWIDTH_DAYTIME:-6}"
BANDWIDTH_NIGHTTIME="${BANDWIDTH_NIGHTTIME:-20}"

DRY_RUN=false
SKIP_MONITORING=false

# ============================================================================
# COLORS & LOGGING
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

# ============================================================================
# USAGE
# ============================================================================

print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Install Tor Snowflake Proxy with monitoring and bandwidth management.

OPTIONS:
    --device NAME           Device identifier (default: snowflake)
    --install-dir DIR       Installation directory (default: /opt/snowflake)
    --daytime MBPS          Daytime bandwidth limit in Mbps (default: 6)
    --nighttime MBPS        Nighttime bandwidth limit in Mbps (default: 20)
    --interface IFACE       Network interface (default: wlan0)
    --no-monitoring         Skip Prometheus metrics setup
    --dry-run               Show what would be done without changes
    -h, --help              Show this help

EXAMPLES:
    # Standard install
    $0

    # Custom device name and limits
    $0 --device pi-zero-01 --daytime 10 --nighttime 30

    # Skip monitoring (proxy only)
    $0 --no-monitoring

EOF
}

# ============================================================================
# PARSE ARGUMENTS
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --device)
            DEVICE_NAME="$2"
            shift 2
            ;;
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --daytime)
            BANDWIDTH_DAYTIME="$2"
            shift 2
            ;;
        --nighttime)
            BANDWIDTH_NIGHTTIME="$2"
            shift 2
            ;;
        --interface)
            INTERFACE="$2"
            shift 2
            ;;
        --no-monitoring)
            SKIP_MONITORING=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# ============================================================================
# PREREQUISITES CHECK
# ============================================================================

check_prerequisites() {
    log "Checking prerequisites..."

    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot detect OS (missing /etc/os-release)"
        return 1
    fi

    # Check for required commands
    local missing=()
    for cmd in systemctl tc python3 ip; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required commands: ${missing[*]}"
        log "Install with: sudo apt install -y iproute2 python3 systemd"
        return 1
    fi

    # Check for root/sudo
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        warn "This script requires sudo privileges"
        log "You may be prompted for your password"
    fi

    success "Prerequisites check passed"
    return 0
}

# ============================================================================
# INSTALL SNOWFLAKE BINARY
# ============================================================================

install_binary() {
    log "Installing Snowflake binary..."

    if $DRY_RUN; then
        log "[DRY RUN] Would install: tor-snowflake-proxy"
        return 0
    fi

    if command -v snowflake-proxy &> /dev/null; then
        local binary_path=$(command -v snowflake-proxy)
        success "Snowflake binary already installed at: $binary_path"

        # Ensure install directory exists
        sudo mkdir -p "$INSTALL_DIR"

        # Create symlink if binary is not already in install directory
        if [[ "$binary_path" != "${INSTALL_DIR}/snowflake-proxy" ]]; then
            log "Creating symlink: ${INSTALL_DIR}/snowflake-proxy -> $binary_path"
            sudo ln -sf "$binary_path" "${INSTALL_DIR}/snowflake-proxy"
            success "Symlink created for systemd service"
        fi

        return 0
    fi

    # Try apt first
    if command -v apt &> /dev/null; then
        log "Installing via apt..."
        sudo apt update -qq
        if sudo apt install -y tor-snowflake-proxy 2>/dev/null; then
            success "Installed tor-snowflake-proxy via apt"

            # Create symlink to install directory (systemd service expects binary at $INSTALL_DIR)
            local binary_path
            if command -v snowflake-proxy &> /dev/null; then
                binary_path=$(command -v snowflake-proxy)
                log "Found binary at: $binary_path"

                # Ensure install directory exists
                sudo mkdir -p "$INSTALL_DIR"

                # Create symlink if binary is not already in install directory
                if [[ "$binary_path" != "${INSTALL_DIR}/snowflake-proxy" ]]; then
                    log "Creating symlink: ${INSTALL_DIR}/snowflake-proxy -> $binary_path"
                    sudo ln -sf "$binary_path" "${INSTALL_DIR}/snowflake-proxy"
                    success "Symlink created for systemd service"
                fi
            fi

            return 0
        fi
    fi

    warn "Could not install via apt"
    log "Please download snowflake-proxy binary from:"
    log "  https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/-/releases"
    log "  Place it in: ${INSTALL_DIR}/snowflake-proxy"
    return 1
}

# ============================================================================
# CREATE SERVICE USER
# ============================================================================

create_service_user() {
    log "Creating service user..."

    if $DRY_RUN; then
        log "[DRY RUN] Would create user: snowflake"
        return 0
    fi

    if id snowflake &> /dev/null; then
        success "User 'snowflake' already exists"
        return 0
    fi

    sudo useradd --system --no-create-home --shell /usr/sbin/nologin snowflake
    success "Created user 'snowflake'"
}

# ============================================================================
# CREATE DIRECTORIES
# ============================================================================

create_directories() {
    log "Creating directories..."

    local dirs=(
        "$INSTALL_DIR"
        "$LOG_DIR"
        "$METRICS_DIR"
    )

    for dir in "${dirs[@]}"; do
        if $DRY_RUN; then
            log "[DRY RUN] Would create: $dir"
        else
            sudo mkdir -p "$dir"
            log "Created: $dir"
        fi
    done

    if ! $DRY_RUN; then
        sudo chown snowflake:snowflake "$INSTALL_DIR" "$LOG_DIR" "$METRICS_DIR"
        success "Directories created with correct permissions"
    fi
}

# ============================================================================
# INSTALL SCRIPTS
# ============================================================================

install_scripts() {
    log "Installing scripts..."

    local repo_url="https://raw.githubusercontent.com/fidpa/snowflake-pi-zero/main"
    local scripts=(
        "tc-bandwidth-limiter.sh"
        "snowflake-metrics-exporter.sh"
        "snowflake-metrics-server.py"
        "snowflake_metrics_addon.py"
        "verify-bandwidth.sh"
    )

    for script in "${scripts[@]}"; do
        if $DRY_RUN; then
            log "[DRY RUN] Would download: $script"
        else
            if curl -sSL -o "/tmp/$script" "${repo_url}/scripts/${script}"; then
                sudo cp "/tmp/$script" "${INSTALL_DIR}/"
                sudo chmod +x "${INSTALL_DIR}/${script}"
                log "Installed: $script"
            else
                warn "Failed to download: $script"
            fi
        fi
    done

    success "Scripts installed"
}

# ============================================================================
# INSTALL SYSTEMD SERVICES
# ============================================================================

install_services() {
    log "Installing systemd services..."

    local services=(
        "snowflake-proxy.service"
        "snowflake-metrics-exporter.service"
        "snowflake-metrics-exporter.timer"
        "snowflake-metrics-server.service"
    )

    local repo_url="https://raw.githubusercontent.com/fidpa/snowflake-pi-zero/main"

    for service in "${services[@]}"; do
        if $DRY_RUN; then
            log "[DRY RUN] Would install: $service"
            continue
        fi

        # Download template
        if ! curl -sSL -o "/tmp/$service" "${repo_url}/systemd/${service}"; then
            warn "Failed to download: $service"
            continue
        fi

        # Replace placeholders
        sed -e "s|@DEVICE_NAME@|${DEVICE_NAME}|g" \
            -e "s|@INSTALL_DIR@|${INSTALL_DIR}|g" \
            -e "s|@LOG_DIR@|${LOG_DIR}|g" \
            -e "s|@SERVICE_USER@|${SERVICE_USER}|g" \
            "/tmp/$service" | sudo tee "/etc/systemd/system/${service}" > /dev/null

        log "Installed: $service"
    done

    if ! $DRY_RUN; then
        sudo systemctl daemon-reload
        success "Systemd services installed"
    fi
}

# ============================================================================
# CONFIGURE BANDWIDTH LIMITING
# ============================================================================

configure_bandwidth() {
    log "Configuring bandwidth limiting..."

    if $DRY_RUN; then
        log "[DRY RUN] Daytime: ${BANDWIDTH_DAYTIME} Mbps, Nighttime: ${BANDWIDTH_NIGHTTIME} Mbps"
        return 0
    fi

    # Determine current profile
    local hour=$(date +%H)
    local profile
    if [[ $hour -ge 9 ]] && [[ $hour -lt 24 ]]; then
        profile="daytime"
    else
        profile="nighttime"
    fi

    log "Applying $profile profile..."
    sudo "${INSTALL_DIR}/tc-bandwidth-limiter.sh" --interface "$INTERFACE" --daytime-limit "$BANDWIDTH_DAYTIME" --nighttime-limit "$BANDWIDTH_NIGHTTIME" "$profile"

    # Add cron jobs
    log "Setting up automatic profile switching..."
    (sudo crontab -l 2>/dev/null | grep -v tc-bandwidth-limiter; cat << EOF
0 9 * * * ${INSTALL_DIR}/tc-bandwidth-limiter.sh --interface ${INTERFACE} --daytime-limit ${BANDWIDTH_DAYTIME} --nighttime-limit ${BANDWIDTH_NIGHTTIME} daytime
0 0 * * * ${INSTALL_DIR}/tc-bandwidth-limiter.sh --interface ${INTERFACE} --daytime-limit ${BANDWIDTH_DAYTIME} --nighttime-limit ${BANDWIDTH_NIGHTTIME} nighttime
EOF
    ) | sudo crontab -

    success "Bandwidth limiting configured"
}

# ============================================================================
# START SERVICES
# ============================================================================

start_services() {
    log "Starting services..."

    local services=(
        "snowflake-proxy.service"
        "snowflake-metrics-exporter.timer"
    )

    if ! $SKIP_MONITORING; then
        services+=("snowflake-metrics-server.service")
    fi

    for service in "${services[@]}"; do
        if $DRY_RUN; then
            log "[DRY RUN] Would enable and start: $service"
        else
            sudo systemctl enable "$service"
            sudo systemctl start "$service"
            log "Started: $service"
        fi
    done

    success "Services started"
}

# ============================================================================
# VERIFICATION
# ============================================================================

verify_installation() {
    log "Verifying installation..."

    if $DRY_RUN; then
        log "[DRY RUN] Verification skipped"
        return 0
    fi

    local failed=false

    # Check service status
    if systemctl is-active snowflake-proxy.service &> /dev/null; then
        success "✅ Snowflake proxy is running"
    else
        error "❌ Snowflake proxy is not running"
        failed=true
    fi

    # Check logs exist
    if [[ -f "${LOG_DIR}/snowflake-proxy.log" ]]; then
        success "✅ Log file exists"
    else
        warn "⚠️  Log file not yet created (may take a few seconds)"
    fi

    # Check metrics endpoint
    if ! $SKIP_MONITORING; then
        if curl -s http://localhost:9092/health &> /dev/null; then
            success "✅ Metrics endpoint responding"
        else
            warn "⚠️  Metrics endpoint not responding (check service)"
        fi
    fi

    # Check bandwidth limit
    if sudo tc qdisc show dev "$INTERFACE" | grep -q "tbf"; then
        success "✅ Bandwidth limiting active"
    else
        warn "⚠️  Bandwidth limiting not active"
    fi

    if $failed; then
        error "Installation verification failed"
        return 1
    fi

    success "Installation verified"
    return 0
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "  Snowflake Pi Zero Installer v1.0.0"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "Device Name:      $DEVICE_NAME"
    echo "Install Dir:      $INSTALL_DIR"
    echo "Interface:        $INTERFACE"
    echo "Bandwidth:        ${BANDWIDTH_DAYTIME} Mbps (day) / ${BANDWIDTH_NIGHTTIME} Mbps (night)"
    echo "Monitoring:       $(if $SKIP_MONITORING; then echo "Disabled"; else echo "Enabled"; fi)"
    echo "Dry Run:          $(if $DRY_RUN; then echo "Yes"; else echo "No"; fi)"
    echo ""

    if ! $DRY_RUN; then
        read -p "Continue with installation? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Installation cancelled"
            exit 0
        fi
    fi

    check_prerequisites || exit 1
    install_binary || exit 1
    create_service_user || exit 1
    create_directories || exit 1
    install_scripts || exit 1
    install_services || exit 1
    configure_bandwidth || exit 1
    start_services || exit 1
    verify_installation || exit 1

    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "  Installation Complete!"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "Next steps:"
    echo "  1. Check service status:"
    echo "     systemctl status snowflake-proxy.service"
    echo ""
    echo "  2. View logs:"
    echo "     tail -f ${LOG_DIR}/snowflake-proxy.log"
    echo ""
    echo "  3. Test metrics endpoint:"
    echo "     curl http://localhost:9092/metrics"
    echo ""
    echo "  4. Verify bandwidth limit:"
    echo "     ${INSTALL_DIR}/verify-bandwidth.sh"
    echo ""
    echo "Documentation:"
    echo "  https://github.com/fidpa/snowflake-pi-zero"
    echo ""
    echo "Note: It may take hours or days to receive first Tor connection."
    echo "      This is normal - be patient!"
    echo ""
}

main "$@"
