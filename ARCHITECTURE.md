# Architecture Overview

## System Design

### High-Level Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                      Raspberry Pi Zero 2W                      │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    systemd Services                       │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │                                                           │  │
│  │  ┌───────────────────────────────────────────────────┐   │  │
│  │  │        snowflake-proxy.service (Main)           │   │  │
│  │  │  - Binary: /opt/snowflake/snowflake-proxy       │   │  │
│  │  │  - Capacity: 5 concurrent Tor clients           │   │  │
│  │  │  - User: snowflake (unprivileged)               │   │  │
│  │  │  - Memory: Max 128MB, High 96MB                 │   │  │
│  │  │  - CPU: 30% quota                                │   │  │
│  │  │  - Restart: on-failure (5 burst/5min)           │   │  │
│  │  │  - Logs: /var/log/snowflake/snowflake-proxy.log │   │  │
│  │  └───────────────────────────────────────────────────┘   │  │
│  │                         │                                 │  │
│  │                         ↓ (metrics every 5min)            │  │
│  │  ┌───────────────────────────────────────────────────┐   │  │
│  │  │  snowflake-metrics-exporter.timer & .service    │   │  │
│  │  │  - Parse logs for connection count & traffic     │   │  │
│  │  │  - Export to textfile collector (.prom format)   │   │  │
│  │  │  - Schedule: Boot+2min, then every 5min          │   │  │
│  │  └───────────────────────────────────────────────────┘   │  │
│  │                         │                                 │  │
│  │                         ↓                                 │  │
│  │  ┌───────────────────────────────────────────────────┐   │  │
│  │  │     snowflake-metrics-server.service             │   │  │
│  │  │  - HTTP server on 0.0.0.0:9092                   │   │  │
│  │  │  - Endpoints: /metrics, /health                  │   │  │
│  │  │  - Reads: /var/lib/node_exporter/textfile_       │   │  │
│  │  │            collector/snowflake_{device}.prom     │   │  │
│  │  │  - Memory: Max 32MB, CPU 5%                      │   │  │
│  │  └───────────────────────────────────────────────────┘   │  │
│  │                                                           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │               Traffic Control (tc-netem)                  │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  Interface: wlan0 (WiFi)                                 │  │
│  │  Method: Token Bucket Filter (TBF)                       │  │
│  │                                                           │  │
│  │  Profiles:                                               │  │
│  │  - Daytime (09:00-00:00):   6 Mbps                      │  │
│  │  - Nighttime (00:00-09:00): 20 Mbps                     │  │
│  │  - Burst: 32 kbit, Latency: 50ms                        │  │
│  │                                                           │  │
│  │  Automated switching: cron jobs at 00:00 and 09:00      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTP GET :9092/metrics
                              ↓
                    ┌──────────────────┐
                    │   Prometheus     │
                    │  (scrape every   │
                    │    30 seconds)   │
                    └──────────────────┘
                              │
                              ↓
                    ┌──────────────────┐
                    │     Grafana      │
                    │   (dashboard)    │
                    └──────────────────┘
```

---

## Component Details

### 1. Snowflake Proxy Service

**Purpose**: Run Tor Snowflake proxy binary as systemd service

**Binary**: `/opt/snowflake/snowflake-proxy`
- Source: `apt install tor-snowflake-proxy` or manual download from Tor Project
- Architecture: ARMv8 (aarch64) for Pi Zero 2W
- License: BSD 3-Clause (Tor Project)

**Command-line arguments**:
```bash
snowflake-proxy -capacity 5 -summary-interval 5m -verbose
```

**Security Hardening** (systemd):
- **User isolation**: Runs as `snowflake` user (no shell, no home directory)
- **Filesystem protection**: `ProtectSystem=strict`, `ProtectHome=true`
- **Namespace restrictions**: `RestrictNamespaces=true`, `PrivateTmp=true`
- **No privilege escalation**: `NoNewPrivileges=true`, `RestrictSUIDSGID=true`
- **Limited /proc access**: `ProcSubset=pid` (only sees own process)

**Resource limits**:
- Memory: 128MB hard limit, 96MB soft warning
- CPU: 30% quota (prevents runaway)
- Restart policy: On failure, max 5 restarts per 5 minutes

**Why these limits?**
- Pi Zero 2W has 512MB total RAM
- Leaves ~400MB for OS + other services
- CPU quota prevents thermal throttling

---

### 2. Metrics Exporter

**Purpose**: Parse Snowflake logs and export Prometheus metrics

**Components**:
- **Timer**: `snowflake-metrics-exporter.timer`
  - Schedule: Boot + 2 minutes, then every 5 minutes
  - Persistent: Resumes after reboot
- **Service**: `snowflake-metrics-exporter.service`
  - Type: Oneshot (runs once, completes)
  - Script: `/opt/snowflake/snowflake-metrics-exporter.sh`

**Parsing logic**:
```bash
# Extract connected clients from logs
grep -oP 'there (were|have been) \K\d+(?= connections?)' /var/log/snowflake/snowflake-proxy.log

# Extract bytes proxied (upload KB)
grep -oP 'Traffic Relayed ↑ \K\d+(?= KB)' /var/log/snowflake/snowflake-proxy.log

# Get process uptime
ps -C snowflake-proxy -o etimes=

# Check service status
systemctl is-active snowflake-proxy.service
```

**Metrics generated**:
- `snowflake_connected_clients{device="..."}` - Gauge
- `snowflake_bytes_proxied_total{device="..."}` - Counter
- `snowflake_proxy_uptime_seconds{device="..."}` - Gauge
- `snowflake_service_status{device="..."}` - Gauge (1=running, 0=stopped)

**Output**: `/var/lib/node_exporter/textfile_collector/snowflake_{device}.prom`

**Why every 5 minutes?**
- Balance between freshness and CPU usage
- Matches Snowflake's `-summary-interval 5m`

---

### 3. Metrics HTTP Server

**Purpose**: Expose metrics via HTTP for Prometheus scraping

**Implementation**: Python 3 HTTP server
- Port: `9092` (bound to `0.0.0.0`)
- Endpoints:
  - `/metrics` - Prometheus exposition format
  - `/health` - Health check (returns "OK")
  - `/` - Alias for `/metrics`

**Logic**:
```python
# Read metrics from textfile collector
metrics_file = Path(f"/var/lib/node_exporter/textfile_collector/snowflake_{device}.prom")
content = metrics_file.read_text()
# Serve as HTTP response
```

**Resource limits**:
- Memory: 32MB max
- CPU: 5% quota
- Restart: Always (auto-recover)

**Why separate HTTP server?**
- Node Exporter textfile collector doesn't expose HTTP endpoint
- Allows multi-device scraping (each device has unique port)
- Lightweight Python implementation (~70 lines)

---

### 4. Bandwidth Limiting (tc-netem)

**Purpose**: Limit egress bandwidth to prevent network saturation

**Method**: Token Bucket Filter (TBF)
```bash
tc qdisc add dev wlan0 root tbf rate 6mbit burst 32kbit latency 50ms
```

**TBF parameters**:
- **Rate**: Maximum sustained bandwidth (6 Mbps or 20 Mbps)
- **Burst**: Allow brief bursts (32 kbit = 4 KB)
- **Latency**: Maximum delay (50ms)

**Profiles**:
| Time Window | Rate | Rationale |
|-------------|------|-----------|
| **09:00-00:00** (Daytime) | 6 Mbps | Conservative (shared network) |
| **00:00-09:00** (Nighttime) | 20 Mbps | Aggressive (low household usage) |

**Automated switching**: Cron jobs at 00:00 and 09:00
```bash
0 9 * * * /opt/snowflake/tc-bandwidth-limiter.sh daytime
0 0 * * * /opt/snowflake/tc-bandwidth-limiter.sh nighttime
```

**Verification**: `verify-bandwidth.sh` script
- Checks current qdisc configuration
- Detects expected profile based on time
- Reports mismatch if any

---

## Data Flow

### 1. Tor Connection Flow

```
Tor User (Censored Region)
    ↓ (WebRTC SDP offer via Tor Broker)
Snowflake Proxy (Pi Zero)
    ↓ (Encrypted WebRTC connection)
Tor Network (Middle Relays)
    ↓
Destination Website
```

**Key points**:
- Pi Zero acts as **middle relay only** (not exit)
- All traffic is **end-to-end encrypted** by Tor
- Proxy operator **cannot see user data**
- Connection established via **WebRTC** (UDP-based)

### 2. Metrics Flow

```
Snowflake Proxy (logs to file)
    ↓ (every 5min via timer)
Metrics Exporter (parses logs)
    ↓ (writes .prom file)
Textfile Collector
    ↓ (HTTP :9092/metrics)
Metrics Server (reads .prom file)
    ↓ (scrape every 30s)
Prometheus (stores time-series)
    ↓ (queries)
Grafana Dashboard (visualization)
```

---

## Deployment Patterns

### Single Device

**Use case**: Testing, low-capacity support

**Capacity**: 5 concurrent Tor users
**Redundancy**: None
**Maintenance**: Simple

### Dual Device (Recommended)

**Use case**: Production home deployment

**Capacity**: 10 concurrent Tor users
**Redundancy**: High (one can fail)
**Load distribution**: Automatic (Tor broker)

**Prometheus configuration**:
```yaml
static_configs:
  - targets:
      - '192.168.1.100:9092'  # Device 1
      - '192.168.1.101:9092'  # Device 2
```

**Unequal load is normal**: WiFi signal strength impacts success rate

### Fleet (5+ devices)

**Use case**: High-capacity support, network operators

**Capacity**: 25+ concurrent Tor users
**Centralized monitoring**: Single Prometheus + Grafana
**Complexity**: Higher (network segmentation, automated deployment)

---

## Security Considerations

### Attack Surface

**Exposed services**:
- Snowflake proxy: WebRTC UDP (ephemeral ports)
- Metrics server: HTTP 9092 (LAN only)

**NOT exposed**:
- SSH (use firewall to restrict)
- systemd journal (local only)

### Defense in Depth

1. **systemd sandboxing**: Restricts proxy to minimal privileges
2. **Unprivileged user**: `snowflake` user has no shell access
3. **Resource limits**: Prevents DoS via memory/CPU exhaustion
4. **Bandwidth limiting**: Prevents network saturation
5. **Tor encryption**: All proxied traffic is encrypted

### Privacy

**What the proxy operator can see**:
- Number of connections
- Total bytes proxied
- Connection duration

**What the proxy operator CANNOT see**:
- User IP addresses (hidden by Tor)
- Visited websites
- Traffic content (encrypted by Tor)

---

## Failure Modes & Recovery

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Service crash | systemd restart (30s delay) | Automatic (5 retries/5min) |
| High memory | OOM killer (>128MB) | Service restart via systemd |
| WiFi signal loss | Connection timeouts | Manual intervention (relocate device) |
| Power loss | N/A | Services auto-start on boot |
| Binary corruption | systemctl status "failed" | Reinstall via apt |

**Metrics indicate failures**:
- `snowflake_service_status == 0` → Service down
- `snowflake_connected_clients == 0` for >24h → Network issue
- `snowflake_proxy_uptime_seconds` resets → Restart occurred

---

## Performance Bottlenecks

### 1. WiFi Signal Strength

**Impact**: 6 dBm signal drop = ~2.3x fewer successful connections

**Mitigation**:
- Relocate device closer to router
- Use external antenna (USB WiFi adapter)
- Switch to Ethernet adapter

### 2. Memory Constraints

**Impact**: 512MB total RAM, ~128MB allocated to proxy

**Mitigation**:
- Reduce capacity (5 → 3 clients)
- Lower MemoryMax to trigger earlier OOM kill
- Monitor `ps aux | grep snowflake` for leaks

### 3. CPU Throttling

**Impact**: Pi Zero 2W throttles at ~80°C

**Mitigation**:
- Passive heatsink
- CPUQuota=30% in systemd service
- Reduce client capacity

---

## Monitoring & Observability

### Key Metrics to Track

| Metric | Alert Threshold | Action |
|--------|----------------|--------|
| Service status | Down for >5 min | Restart service |
| Memory usage | >120 MB | Reduce capacity or restart |
| CPU usage | >30% sustained | Check for runaway process |
| Connections | 0 for >24h | Investigate WiFi/NAT |

### Logs

**Locations**:
- Service logs: `/var/log/snowflake/snowflake-proxy.log`
- systemd journal: `journalctl -u snowflake-proxy.service`

**Important log patterns**:
- `"In the last 5m0s, there were X connections"` → Connection count
- `"Traffic Relayed ↑ X KB, ↓ Y KB"` → Traffic volume
- `"Timed out waiting for client"` → Connection timeout (poor WiFi)

---

## Scalability

### Horizontal Scaling

Add more Pi Zero devices:
- Each device = +5 clients capacity
- Linear scaling (no coordination needed)
- Prometheus scrapes all devices

### Vertical Scaling

Limited by hardware:
- Pi Zero 2W: Max ~5-7 clients (memory constrained)
- Pi 4 (4GB RAM): Can handle ~20 clients
- Pi 5 (8GB RAM): Can handle ~50 clients

**Not recommended**: Snowflake is designed for distributed deployment, not single high-capacity nodes.

---

## Future Enhancements

Potential improvements (not yet implemented):

1. **IPv6 support**: Dual-stack for better NAT traversal
2. **Dynamic capacity**: Adjust based on memory/CPU usage
3. **Automated WiFi optimization**: Signal strength monitoring + alerts
4. **Traffic shaping**: QoS for Snowflake traffic prioritization
5. **Multi-profile bandwidth**: More granular time-based limits

---

## References

- [Snowflake Technical Design](https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/-/wikis/Technical%20Overview)
- [systemd Sandboxing](https://www.freedesktop.org/software/systemd/man/systemd.exec.html)
- [Linux Traffic Control (tc)](https://man7.org/linux/man-pages/man8/tc.8.html)
- [Prometheus Exposition Format](https://prometheus.io/docs/instrumenting/exposition_formats/)
