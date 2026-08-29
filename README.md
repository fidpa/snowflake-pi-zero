# Snowflake Pi Zero

![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![Release](https://img.shields.io/github/v/release/fidpa/snowflake-pi-zero)
![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-Zero%202W-C51A4A?logo=raspberrypi)
![Tor Project](https://img.shields.io/badge/Tor-Snowflake-7D4698?logo=torproject)
![Prometheus](https://img.shields.io/badge/Prometheus-Metrics-E6522C?logo=prometheus)
![CI](https://github.com/fidpa/snowflake-pi-zero/actions/workflows/lint.yml/badge.svg)
![Last Commit](https://img.shields.io/github/last-commit/fidpa/snowflake-pi-zero)

Deployment stack for a Tor Snowflake proxy on a Raspberry Pi Zero 2W: systemd
units, time-based bandwidth limiting, and Prometheus metrics.

## Table of Contents

- [Scope](#scope)
- [Known Limitations](#known-limitations)
- [Repository Layout](#repository-layout)
- [Features](#features)
- [Quick Start](#quick-start)
- [CLI Reference](#cli-reference)
- [Component Overview](#component-overview)
- [Key Concepts](#key-concepts)
- [Requirements](#requirements)
- [Compatibility](#compatibility)
- [Use Cases](#use-cases)
- [Documentation](#documentation)
- [Performance Expectations](#performance-expectations)
- [See Also](#see-also)
- [License](#license)
- [Author](#author)
- [Contributing](#contributing)

---

A Snowflake proxy is a few hundred lines of Go and a single binary. Running two
of them on Pi Zero 2W boards for months turned up the parts nobody ships with
the binary: the proxy competes with the household for uplink, it writes a log
that grows without bound, and when it stops producing connections there is no
way to tell whether the broker went quiet or the WiFi did. This repository is
what accumulated around those three problems.

## Scope

This is a deployment stack for a single-operator home setup: systemd units, two
Bash scripts, a small HTTP server, and the monitoring configuration to go with
them. It is **not** a Snowflake distribution (the proxy binary comes from the
Tor Project's package, see [NOTICE](NOTICE)), **not** a fleet management tool,
and **not** hardened for a network you do not control.

## Known Limitations

> [!IMPORTANT]
> Four boundaries worth knowing before you deploy:
>
> - **The metrics endpoint has no authentication and binds to `0.0.0.0`.**
>   `snowflake-metrics-server.py` serves `/metrics` and `/health` to anything
>   that can reach port 9092. It exposes operational counters only, no traffic
>   content, but it belongs behind a firewall rule or a trusted LAN, not on a
>   public interface.
> - **Bandwidth limiting applies to the whole interface, not to Snowflake.**
>   `tc-bandwidth-limiter.sh` replaces the root qdisc on `wlan0`, so the cap
>   covers every egress packet the device sends, and any tc configuration that
>   was there before is deleted. This is fine on a dedicated Pi and wrong on a
>   machine doing other work.
> - **`snowflake_bytes_proxied_total` is not a running total.** Despite the
>   `_total` suffix, the exporter reports the upload figure from the most recent
>   summary line in the log, which is per-interval and can go down. Download
>   traffic is not counted at all. Use it for "is traffic flowing", not for
>   accounting; see the caveat under [Metrics Exported](#metrics-exported).
> - **systemd hardening covers the proxy service only.** The sandboxing block
>   below lives in `snowflake-proxy.service`. The metrics server gets resource
>   limits and nothing else; the metrics exporter runs as a plain oneshot unit.

## Repository Layout

| Path | Contents |
|------|----------|
| **[install.sh](install.sh)** | Installer: binary, service user, scripts, units, logrotate, cron, verification |
| **[scripts/](scripts/)** | Bandwidth limiter, metrics exporter, HTTP server, verification tool |
| **[systemd/](systemd/)** | Four unit templates with `@PLACEHOLDER@` substitution |
| **[configs/](configs/)** | logrotate config for `/var/log/snowflake/*.log` |
| **[monitoring/](monitoring/)** | Grafana dashboard, Prometheus scrape snippet, alert rules |
| **[docs/](docs/)** | Installation, monitoring, troubleshooting, performance |

## Features

- **Time-based bandwidth caps** - Two tc TBF profiles (6 Mbps daytime, 20 Mbps
  nighttime by default), switched by two root cron jobs at 00:00 and 09:00
- **Prometheus metrics** - Five gauges scraped from a textfile collector, served
  over HTTP on port 9092
- **Grafana dashboard and alert rules** - Service-down, memory over 120 MB, and
  a one-hour no-connections notice, ready to import
- **systemd sandboxing on the proxy** - Eleven sandboxing directives plus
  `MemoryMax=128M` and `CPUQuota=30%`, sized for 512 MB of RAM
- **Log rotation that survives an open descriptor** - `copytruncate`, because
  the unit redirects with `StandardOutput=append:` and a rename-based rotation
  would leave the proxy writing to the old inode
- **Idempotent installer** - Re-running it reuses an existing binary, user, and
  directories, and replaces its own cron lines rather than appending to them
- **Documented deployment data** - WiFi signal, memory, CPU and traffic figures
  from two devices in continuous operation, in [docs/PERFORMANCE.md](docs/PERFORMANCE.md)

## Quick Start

The installer prompts for confirmation, so download it and run it rather than
piping it into a shell (a piped script gets no terminal to read the answer
from). Reading it first is a good idea anyway:

```bash
curl -sSLO https://raw.githubusercontent.com/fidpa/snowflake-pi-zero/main/install.sh
less install.sh
bash install.sh --dry-run          # show every step, change nothing
bash install.sh                    # defaults: 6/20 Mbps on wlan0
bash install.sh --device pi-zero-01 --daytime 10 --nighttime 30 --interface eth0
```

The installer downloads the scripts and unit templates from `main` on GitHub,
not from the working directory, so a clone is not required.

<details>
<summary>Manual installation</summary>

```bash
git clone https://github.com/fidpa/snowflake-pi-zero.git
cd snowflake-pi-zero

# 1. Install the Snowflake binary and link it where the unit expects it
sudo apt update && sudo apt install -y tor-snowflake-proxy
sudo mkdir -p /opt/snowflake /var/log/snowflake
sudo ln -sf "$(command -v snowflake-proxy)" /opt/snowflake/snowflake-proxy

# 2. Create the service user the proxy and exporter run as
sudo useradd --system --no-create-home --shell /usr/sbin/nologin snowflake

# 3. Copy scripts and the textfile collector directory
sudo cp scripts/*.sh scripts/*.py /opt/snowflake/
sudo chmod +x /opt/snowflake/*.sh /opt/snowflake/*.py
sudo mkdir -p /var/lib/node_exporter/textfile_collector
sudo chown -R snowflake:snowflake /opt/snowflake /var/log/snowflake \
                                  /var/lib/node_exporter/textfile_collector

# 4. Install the units. SERVICE_USER is the account running the metrics server;
#    it needs read access to the textfile collector, so use your own login.
for file in systemd/*.service systemd/*.timer; do
    sed -e 's|@DEVICE_NAME@|snowflake|g' \
        -e 's|@INSTALL_DIR@|/opt/snowflake|g' \
        -e 's|@LOG_DIR@|/var/log/snowflake|g' \
        -e "s|@SERVICE_USER@|$(whoami)|g" \
        "$file" | sudo tee "/etc/systemd/system/$(basename "$file")" > /dev/null
done
sudo systemctl daemon-reload

# 5. Rotate the log, or it grows until the card fills up
sudo install -m 644 -o root -g root configs/snowflake-logrotate \
    /etc/logrotate.d/snowflake

# 6. Enable and start
sudo systemctl enable --now snowflake-proxy.service
sudo systemctl enable --now snowflake-metrics-exporter.timer
sudo systemctl enable --now snowflake-metrics-server.service

# 7. Apply a bandwidth profile and add the cron jobs that switch it
sudo /opt/snowflake/tc-bandwidth-limiter.sh daytime
```

</details>

**Full guide**: [docs/INSTALLATION.md](docs/INSTALLATION.md).

## CLI Reference

`install.sh --help`:

```
Usage: install.sh [OPTIONS]

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
```

`tc-bandwidth-limiter.sh --help`:

```
Usage: tc-bandwidth-limiter.sh [OPTIONS] <profile>

Limit egress bandwidth for Snowflake proxy using tc-netem Token Bucket Filter.

OPTIONS:
    --interface INTERFACE       Network interface (default: wlan0)
    --daytime-limit MBPS        Daytime bandwidth limit in Mbps (default: 6)
    --nighttime-limit MBPS      Nighttime bandwidth limit in Mbps (default: 20)

PROFILES:
    daytime     Apply daytime bandwidth limit (09:00-00:00)
    nighttime   Apply nighttime bandwidth limit (00:00-09:00)
    remove      Remove all bandwidth limits

TECHNICAL DETAILS:
    Current Daytime:   6mbit (32kbit burst, 50ms latency)
    Current Nighttime: 20mbit (32kbit burst, 50ms latency)
    Method:            Token Bucket Filter (TBF)
```

`verify-bandwidth.sh` takes `--interface INTERFACE` and nothing else.
`snowflake-metrics-server.py` and `snowflake-metrics-exporter.sh` each take a
single positional device name.

Both limiter defaults also read from the environment
(`SNOWFLAKE_INTERFACE`, `SNOWFLAKE_DAYTIME_LIMIT`, `SNOWFLAKE_NIGHTTIME_LIMIT`),
which is how the units pass them through; a command-line flag wins over both.

## Component Overview

### Scripts

| Script | Purpose |
|--------|---------|
| `tc-bandwidth-limiter.sh` | Apply or remove a tc TBF profile on one interface (needs root) |
| `snowflake-metrics-exporter.sh` | Parse the proxy log, write `snowflake_<device>.prom` |
| `snowflake-metrics-server.py` | Serve that file on `:9092/metrics`, stdlib only |
| `snowflake_metrics_addon.py` | Import into an existing `prometheus_client` exporter instead of running the server |
| `verify-bandwidth.sh` | Show the active qdisc and compare it against the profile the clock implies |

### systemd Units

| Unit | Type | Description |
|------|------|-------------|
| `snowflake-proxy.service` | Main | Proxy with `-capacity 5`, sandboxing, and resource limits |
| `snowflake-metrics-exporter.service` | Oneshot | One export run, triggered by the timer |
| `snowflake-metrics-exporter.timer` | Timer | 2 min after boot, then every 5 min |
| `snowflake-metrics-server.service` | HTTP | Serves port 9092, `MemoryMax=32M`, `CPUQuota=5%` |

### Metrics Exported

| Metric | Type | Description |
|--------|------|-------------|
| `snowflake_connected_clients` | Gauge | Connections in the last summary interval, not currently open ones |
| `snowflake_bytes_proxied_total` | Counter | Upload bytes from the last summary line; per-interval and can decrease |
| `snowflake_proxy_uptime_seconds` | Gauge | Process uptime from `ps -o etimes=` |
| `snowflake_proxy_memory_bytes` | Gauge | Process RSS |
| `snowflake_service_status` | Gauge | 1=running, 0=stopped |

All five carry a `device` label. Every one of them falls back to `0` when the
log or the process is missing, so a stopped exporter and an idle proxy look
alike; `snowflake_service_status` is what tells them apart.
`snowflake_metrics_addon.py` re-exports four of the five - it does not read
`snowflake_proxy_memory_bytes`.

## Key Concepts

### Bandwidth Profiles

| Profile | Time Window | Default Rate | Rationale |
|---------|-------------|--------------|-----------|
| Daytime | 09:00-00:00 | 6 Mbps | Shared household network |
| Nighttime | 00:00-09:00 | 20 Mbps | Low household usage |

Both are TBF with a 32 kbit burst and 50 ms latency. Switching is two root cron
jobs at 00:00 and 09:00, written by the installer; the profile is a clock
convention, not something the script enforces, so `daytime` at midnight applies
the daytime rate without complaint.

### systemd Hardening

`snowflake-proxy.service` runs the proxy under a dedicated `snowflake` user with:

```ini
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictRealtime=true
RestrictNamespaces=true
RestrictSUIDSGID=true
ProcSubset=pid
MemoryMax=128M
MemoryHigh=96M
CPUQuota=30%
```

That is the eleven the feature list counts; `ProcSubset=pid` narrows `/proc` on
top of them, and `PrivateNetwork` stays false because WebRTC and STUN need the
real network stack. The 128 MB cap sits above the 60-80 MB peak observed with
five clients and below what would hurt a 512 MB board. See
[SECURITY.md](SECURITY.md) for the threat model these directives address.

### WiFi Signal and WebRTC Success

Signal strength, not NAT type, decided how many connections a device completed:

| Signal | Connection success rate |
|--------|------------------------|
| -66 dBm (good) | ~70% |
| -72 dBm (fair) | ~30% |

Measured how: two Pi Zero 2W boards on the same broker and the same household
uplink, differing in placement, observed in continuous operation. This is a
deployment observation, not a controlled experiment - the two devices differ in
one obvious variable and possibly others. The mechanism is plausible and the
direction held: the WebRTC data channel has to come up inside the broker's
timeout, and a weak link spends that budget on retransmissions.
Both devices sat at 4 to 8 completed connections a day;
[docs/PERFORMANCE.md](docs/PERFORMANCE.md) has the per-device figures and the
tuning that followed.

## Requirements

**Minimum**:
- Raspberry Pi Zero 2W, or any Pi with 512 MB of RAM
- Raspberry Pi OS or another Debian-based system with systemd
- Python 3 from the distribution (the metrics server imports only the standard
  library; no lower bound is declared or tested)
- `iproute2` for `tc`, and `cron` for profile switching
- WiFi or an Ethernet adapter

**Optional**:
- Prometheus and Grafana, for the dashboard and alert rules
- Node Exporter, if you would rather collect the `.prom` file than scrape port 9092
- `prometheus_client`, only for `snowflake_metrics_addon.py`

## Compatibility

**Tested**:
- Raspberry Pi Zero 2W on Raspberry Pi OS Bookworm

**Should work, untested**:
- Pi 3, Pi 4, Pi 5, and Bullseye - same OS family, same units, more headroom
- Debian 11+ and Ubuntu 22.04+ on other hardware, as long as the interface name
  is passed with `--interface`

**Not supported**:
- Containers: `tc` needs the host network namespace, and the units assume
  system-wide systemd
- Anything without systemd: the scripts would survive, the units would not

## Use Cases

**Good fit**:
- Running a Snowflake proxy at home without it eating the household uplink
- A low-power always-on box you want to see in Grafana next to everything else
- Two devices for redundancy, since either can fail without the other noticing
- Reading systemd unit hardening in a small, complete, working example

**Poor fit**:
- Anything multi-tenant: one proxy, one device name, one metrics file
- A machine with other network duties, because the bandwidth cap is
  interface-wide
- Fleets past a handful of devices, where the per-device cron and unit
  substitution turns into configuration management you do not have

## Documentation

| Document | Description |
|----------|-------------|
| [docs/INSTALLATION.md](docs/INSTALLATION.md) | Step-by-step setup guide |
| [docs/MONITORING.md](docs/MONITORING.md) | Prometheus and Grafana configuration |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues and solutions |
| [docs/PERFORMANCE.md](docs/PERFORMANCE.md) | WiFi impact, optimization, benchmarks |
| [ARCHITECTURE.md](ARCHITECTURE.md) | System design and component details |
| [CHANGELOG.md](CHANGELOG.md) | Release history |

## Performance Expectations

Per device over 24 hours, from two Pi Zero 2W boards on a household connection:

| Metric | Normal range |
|--------|--------------|
| Connections | 4-12 |
| Total traffic | 1-3 GB |
| Memory | 15-40 MB, peaking at 60-80 MB with five clients |
| CPU | 2-10% |
| Uptime | 95-99% |

Per-connection traffic is the volatile figure - 24 to 200 MB is typical and
936 MB was the largest single connection seen. A quiet day is not a fault: the
Tor broker hands out offers by global demand, and a device can sit at zero for
hours with nothing wrong. [docs/PERFORMANCE.md](docs/PERFORMANCE.md) has the
low and high bands and what each one implies.

## See Also

- [Snowflake Official Site](https://snowflake.torproject.org/) - Tor Project documentation
- [Snowflake GitLab](https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake) - Source code
- [Tor Forum](https://forum.torproject.net/) - Community support

## License

MIT - see [LICENSE](LICENSE). The Snowflake proxy binary is not part of this
repository and carries the Tor Project's BSD 3-Clause License; see
[NOTICE](NOTICE).

## Author

Marc Allgeier ([@fidpa](https://github.com/fidpa))

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The gaps I know about: nobody has run
this on a Pi 4 or 5, the Grafana dashboard covers the service and traffic but
not the WiFi signal that turned out to matter most, and the per-device cron and
`sed` substitution is the part that would need replacing first for a fleet.

For security vulnerabilities, see [SECURITY.md](SECURITY.md).
