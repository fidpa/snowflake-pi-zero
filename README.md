# Snowflake Pi Zero

![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-Zero%202W-C51A4A?logo=raspberrypi)
![Tor Project](https://img.shields.io/badge/Tor-Snowflake-7D4698?logo=torproject)
![Prometheus](https://img.shields.io/badge/Prometheus-Metrics-E6522C?logo=prometheus)

Production-ready Tor Snowflake Proxy deployment for Raspberry Pi Zero.

## Table of Contents

- [Components](#components)
- [Features](#features)
- [Quick Start](#quick-start)
- [Component Overview](#component-overview)
- [Key Concepts](#key-concepts)
- [Requirements](#requirements)
- [Compatibility](#compatibility)
- [Use Cases](#use-cases)
- [Documentation](#documentation)
- [Performance Expectations](#performance-expectations)
- [See Also](#see-also)
- [License](#license)
- [Contributing](#contributing)

---

**The Problem**: Snowflake proxies help users in censored regions access Tor, but deploying them on resource-constrained devices requires careful configuration. Default setups lack monitoring, bandwidth control, and proper systemd integration. After running dual Snowflake proxies on Pi Zero 2W devices for production use, I've extracted a complete deployment stack with monitoring, bandwidth management, and operational documentation.

## Components

| Component | Description |
|-----------|-------------|
| **[scripts/](scripts/)** | Bandwidth limiter, metrics exporter, verification tools |
| **[systemd/](systemd/)** | Service templates with security hardening (sandboxing, resource limits) |
| **[monitoring/](monitoring/)** | Grafana dashboard, Prometheus config, alert rules |
| **[docs/](docs/)** | Installation, monitoring, troubleshooting, performance guides |

## Features

- ✅ **Automatic Bandwidth Limiting** - Time-based profiles (6 Mbps day / 20 Mbps night)
- ✅ **Prometheus Metrics** - Connected clients, traffic, uptime, service status
- ✅ **Grafana Dashboard** - Real-time visualization with alert thresholds
- ✅ **systemd Security Hardening** - Sandboxing, resource limits, auto-restart
- ✅ **Resource Optimized** - Runs on 512MB RAM Pi Zero 2W (15-40 MB memory usage)
- ✅ **One-Line Installer** - Idempotent setup with interactive prompts
- ✅ **Production-Proven** - Running on dual Pi Zero deployment (~11 connections/h, 2+ GB/day)

## Quick Start

```bash
# One-line install (interactive)
curl -sSL https://raw.githubusercontent.com/fidpa/snowflake-pi-zero/main/install.sh | bash

# Or with custom parameters
curl -sSL https://raw.githubusercontent.com/fidpa/snowflake-pi-zero/main/install.sh | bash -s -- \
  --device pi-zero-01 \
  --daytime 10 \
  --nighttime 30

# Manual installation
git clone https://github.com/fidpa/snowflake-pi-zero.git
cd snowflake-pi-zero

# 1. Install Snowflake binary
sudo apt update && sudo apt install -y tor-snowflake-proxy

# 2. Create service user
sudo useradd --system --no-create-home snowflake

# 3. Copy scripts and set permissions
sudo mkdir -p /opt/snowflake /var/log/snowflake
sudo cp scripts/*.sh scripts/*.py /opt/snowflake/
sudo chmod +x /opt/snowflake/*.sh
sudo chown -R snowflake:snowflake /opt/snowflake /var/log/snowflake

# 4. Install systemd services (replace placeholders)
for file in systemd/*.service systemd/*.timer; do
    sed -e 's|@DEVICE_NAME@|snowflake|g' \
        -e 's|@INSTALL_DIR@|/opt/snowflake|g' \
        -e 's|@LOG_DIR@|/var/log/snowflake|g' \
        -e 's|@SERVICE_USER@|pi|g' \
        "$file" | sudo tee "/etc/systemd/system/$(basename $file)" > /dev/null
done
sudo systemctl daemon-reload

# 5. Enable and start services
sudo systemctl enable --now snowflake-proxy.service
sudo systemctl enable --now snowflake-metrics-exporter.timer
sudo systemctl enable --now snowflake-metrics-server.service

# 6. Apply bandwidth limiting
sudo /opt/snowflake/tc-bandwidth-limiter.sh daytime
```

**Full guides**: See [docs/INSTALLATION.md](docs/INSTALLATION.md) for step-by-step instructions.

## Component Overview

### Scripts

| Script | Purpose |
|--------|---------|
| `tc-bandwidth-limiter.sh` | Apply day/night bandwidth profiles via tc-netem TBF |
| `snowflake-metrics-exporter.sh` | Parse logs, export Prometheus metrics |
| `snowflake-metrics-server.py` | HTTP endpoint for Prometheus scraping (:9092) |
| `verify-bandwidth.sh` | Verify bandwidth limiting is active |

### systemd Services

| Service | Type | Description |
|---------|------|-------------|
| `snowflake-proxy.service` | Main | Snowflake binary with security hardening |
| `snowflake-metrics-exporter.timer` | Timer | Export metrics every 5 minutes |
| `snowflake-metrics-server.service` | HTTP | Serve metrics on port 9092 |

### Metrics Exported

| Metric | Type | Description |
|--------|------|-------------|
| `snowflake_connected_clients` | Gauge | Tor clients in last interval |
| `snowflake_bytes_proxied_total` | Counter | Total bytes proxied |
| `snowflake_proxy_uptime_seconds` | Gauge | Process uptime |
| `snowflake_service_status` | Gauge | 1=running, 0=stopped |

## Key Concepts

### Bandwidth Profiles

Time-based bandwidth limiting prevents network saturation:

| Profile | Time Window | Rate | Use Case |
|---------|-------------|------|----------|
| **Daytime** | 09:00-00:00 | 6 Mbps | Shared household network |
| **Nighttime** | 00:00-09:00 | 20 Mbps | Low network usage period |

Automated switching via cron jobs at 00:00 and 09:00.

### systemd Security Hardening

All services run with comprehensive sandboxing:

```ini
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
RestrictNamespaces=true
MemoryMax=128M
CPUQuota=30%
```

### WiFi Signal Impact

Real-world finding: **Signal strength directly impacts WebRTC success rate.**

| Signal | Success Rate | Connections/h |
|--------|-------------|---------------|
| -66 dBm (Good) | ~70% | 7-8 |
| -72 dBm (Fair) | ~30% | 3-4 |

6 dBm difference = ~2.3x fewer successful connections. See [docs/PERFORMANCE.md](docs/PERFORMANCE.md).

## Requirements

**Minimum**:
- Raspberry Pi Zero 2W (or any Pi with 512MB+ RAM)
- Raspberry Pi OS (Debian-based)
- WiFi connectivity (or Ethernet adapter)
- systemd, Python 3.7+, iproute2 (tc command)

**Optional**:
- Prometheus + Grafana (for monitoring)
- Node Exporter (for textfile collector)
- Telegram Bot (for alerting)

## Compatibility

**Fully supported**:
- Raspberry Pi Zero 2W, Pi 3, Pi 4, Pi 5
- Raspberry Pi OS (Bookworm, Bullseye)
- Debian 11+, Ubuntu 22.04+

**Partial support** (no bandwidth limiting):
- Non-Linux systems (metrics and monitoring only)
- Containers (tc requires host network namespace)

## Use Cases

- ✅ **Support Internet Freedom** - Help users in censored regions access Tor
- ✅ **Portfolio Project** - Demonstrate DevOps skills (systemd, Prometheus, Bash/Python)
- ✅ **Home Lab** - Low-power, always-on Tor infrastructure
- ✅ **Dual-Device Setup** - Redundancy with automatic load distribution
- ✅ **Learning Resource** - Production-ready systemd service patterns

## Documentation

| Document | Description |
|----------|-------------|
| [docs/INSTALLATION.md](docs/INSTALLATION.md) | Step-by-step setup guide |
| [docs/MONITORING.md](docs/MONITORING.md) | Prometheus + Grafana configuration |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues and solutions |
| [docs/PERFORMANCE.md](docs/PERFORMANCE.md) | WiFi impact, optimization, benchmarks |
| [ARCHITECTURE.md](ARCHITECTURE.md) | System design and component details |

## Performance Expectations

Typical 24h stats per Pi Zero 2W:

| Metric | Expected Range |
|--------|---------------|
| Connections | 4-12 per device |
| Total Traffic | 1-3 GB per device |
| Memory Usage | 15-40 MB |
| CPU Usage | 2-10% |
| Uptime | 99%+ |

**Note**: Low connection frequency is normal - Tor broker distributes based on global demand.

## See Also

- [Snowflake Official Site](https://snowflake.torproject.org/) - Tor Project documentation
- [Snowflake GitLab](https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake) - Source code
- [Tor Forum](https://forum.torproject.net/) - Community support

## License

MIT License - see [LICENSE](LICENSE) for details.

## Author

Marc Allgeier ([@fidpa](https://github.com/fidpa))

**Why I Built This**: After deploying Snowflake proxies on Pi Zero devices, I realized there was no comprehensive guide for production setups. Default installations lack monitoring, bandwidth control conflicts with household usage, and troubleshooting without metrics is painful. This repo packages everything I learned into a deployable stack that helps both Tor users and infrastructure operators.

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Areas where help is appreciated**:
- Testing on other Raspberry Pi models
- Additional Grafana dashboard panels
- Ansible/Terraform automation
- Translation of documentation

For security vulnerabilities, please see [SECURITY.md](SECURITY.md).
