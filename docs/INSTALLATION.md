# Installation Guide

## Prerequisites

### Hardware Requirements
- Raspberry Pi Zero 2W (or any Pi with 512MB+ RAM)
- WiFi connectivity (or Ethernet adapter)
- SD card with Raspberry Pi OS installed
- Stable internet connection

### Software Dependencies
```bash
sudo apt update
sudo apt install -y \
    python3 \
    python3-pip \
    iproute2 \
    systemd \
    prometheus-node-exporter
```

## Quick Install (Recommended)

```bash
curl -sSL https://raw.githubusercontent.com/fidpa/snowflake-pi-zero/main/install.sh | bash
```

This will:
1. Install Snowflake binary via apt
2. Create service user (`snowflake`)
3. Set up scripts and systemd services
4. Configure bandwidth limiting (optional)
5. Start services automatically

## Manual Installation

### Step 1: Install Snowflake Binary

```bash
sudo apt update
sudo apt install -y tor-snowflake-proxy
```

Or download from the [Tor Project releases](https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/-/releases).

### Step 2: Create Service User

```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin snowflake
```

### Step 3: Create Directories

```bash
# Installation directory
sudo mkdir -p /opt/snowflake
sudo chown snowflake:snowflake /opt/snowflake

# Log directory
sudo mkdir -p /var/log/snowflake
sudo chown snowflake:snowflake /var/log/snowflake

# Metrics directory (for Prometheus Node Exporter)
sudo mkdir -p /var/lib/node_exporter/textfile_collector
```

### Step 4: Copy Scripts

```bash
# Clone repository
git clone https://github.com/fidpa/snowflake-pi-zero.git
cd snowflake-pi-zero

# Copy scripts
sudo cp scripts/*.sh /opt/snowflake/
sudo cp scripts/*.py /opt/snowflake/
sudo chmod +x /opt/snowflake/*.sh
```

### Step 5: Install systemd Services

```bash
# Define your device name and install directory
DEVICE_NAME="snowflake"
INSTALL_DIR="/opt/snowflake"
LOG_DIR="/var/log/snowflake"
SERVICE_USER="pi"  # Replace with your username

# Generate service files from templates
for file in systemd/*.service systemd/*.timer; do
    filename=$(basename "$file")
    sed -e "s|@DEVICE_NAME@|${DEVICE_NAME}|g" \
        -e "s|@INSTALL_DIR@|${INSTALL_DIR}|g" \
        -e "s|@LOG_DIR@|${LOG_DIR}|g" \
        -e "s|@SERVICE_USER@|${SERVICE_USER}|g" \
        "$file" | sudo tee "/etc/systemd/system/${filename}" > /dev/null
done

# Reload systemd
sudo systemctl daemon-reload
```

### Step 6: Enable and Start Services

```bash
# Enable services
sudo systemctl enable snowflake-proxy.service
sudo systemctl enable snowflake-metrics-exporter.timer
sudo systemctl enable snowflake-metrics-server.service

# Start services
sudo systemctl start snowflake-proxy.service
sudo systemctl start snowflake-metrics-exporter.timer
sudo systemctl start snowflake-metrics-server.service
```

### Step 7: Configure Bandwidth Limiting (Optional)

```bash
# Apply daytime profile (6 Mbps)
sudo /opt/snowflake/tc-bandwidth-limiter.sh daytime

# Or apply nighttime profile (20 Mbps)
sudo /opt/snowflake/tc-bandwidth-limiter.sh nighttime
```

To automate bandwidth switching, add to crontab:
```bash
sudo crontab -e

# Add these lines:
0 9 * * * /opt/snowflake/tc-bandwidth-limiter.sh daytime
0 0 * * * /opt/snowflake/tc-bandwidth-limiter.sh nighttime
```

## Verification

### Check Service Status

```bash
# Snowflake proxy service
sudo systemctl status snowflake-proxy.service

# Metrics exporter timer
sudo systemctl status snowflake-metrics-exporter.timer

# Metrics HTTP server
sudo systemctl status snowflake-metrics-server.service
```

### Check Logs

```bash
# Snowflake proxy logs
sudo tail -f /var/log/snowflake/snowflake-proxy.log

# systemd journal
sudo journalctl -u snowflake-proxy.service -f
```

### Verify Bandwidth Limiting

```bash
/opt/snowflake/verify-bandwidth.sh
```

### Test Metrics Endpoint

```bash
# Should return Prometheus metrics
curl http://localhost:9092/metrics
```

## Troubleshooting

### Service Won't Start

Check logs:
```bash
sudo journalctl -u snowflake-proxy.service -n 50
```

Common issues:
- Binary permissions: `sudo chmod +x /opt/snowflake/snowflake-proxy`
- User permissions: Verify `snowflake` user exists
- Port conflicts: Check if port 9092 is already in use

### No Tor Connections

This is normal! Snowflake relies on Tor broker distributing connections. It may take hours to receive first connection.

Check service is running:
```bash
systemctl is-active snowflake-proxy.service
```

### High Memory Usage

Reduce capacity in systemd service:
```bash
sudo nano /etc/systemd/system/snowflake-proxy.service

# Change -capacity 5 to -capacity 3
ExecStart=/opt/snowflake/snowflake-proxy -capacity 3 -summary-interval 5m -verbose
```

Then reload and restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart snowflake-proxy.service
```

## Next Steps

- [Set up Prometheus monitoring](MONITORING.md)
- [Configure Grafana dashboard](MONITORING.md#grafana-dashboard)
- [Review troubleshooting guide](TROUBLESHOOTING.md)
- [Understand performance considerations](PERFORMANCE.md)
