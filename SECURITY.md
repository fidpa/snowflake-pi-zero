# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

**Contact**: security@fidpa.dev

We will respond within 72 hours and provide a timeline for fixes.

**Please do NOT open a public issue for security vulnerabilities.**

---

## Supported Versions

We provide security updates for the following versions:

| Version | Supported | Notes |
| ------- | --------- | ----- |
| 1.x | :white_check_mark: Yes | The only release line; 1.0.0 was the first tag |

There is no 0.x line. Fixes land on the latest 1.x release, and the deployment
is a handful of files, so upgrading means re-running `install.sh`.

---

## Security Features

This project implements the following security measures:

### Snowflake Proxy Security
- **No traffic content on disk**: The proxy relays WebRTC data channels and
  writes none of their contents. What it does write is a log
  (`/var/log/snowflake/snowflake-proxy.log`, `-verbose`): connection counts and
  relayed byte totals per 5-minute summary interval, plus the proxy's own
  operational lines. `configs/snowflake-logrotate` bounds it at seven daily
  files, so it is persistent state, not memory-only.
- **Process isolation**: The proxy and the metrics exporter run as a dedicated
  system user (`snowflake`) created with `--no-create-home --shell
  /usr/sbin/nologin`. The metrics HTTP server runs as `@SERVICE_USER@`, the
  account that installed it, because it needs read access to the textfile
  collector.

### systemd Hardening

`snowflake-proxy.service` carries eleven sandboxing directives:
`NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome=true`, `PrivateTmp`,
`PrivateDevices`, `ProtectKernelTunables`, `ProtectKernelModules`,
`ProtectControlGroups`, `RestrictRealtime`, `RestrictNamespaces` and
`RestrictSUIDSGID`, plus `ProcSubset=pid`. Resource limits are
`MemoryMax=128M`, `MemoryHigh=96M` and `CPUQuota=30%`. The memory cap sits above
the 60-80 MB peak observed with five clients and below what would starve a
512 MB board.

`PrivateNetwork` is deliberately false: WebRTC and STUN need the real network
stack. No `CapabilityBoundingSet` is set, because the proxy binds no privileged
port and needs no capability to drop.

**This block applies to the proxy service alone.**
`snowflake-metrics-server.service` gets `MemoryMax=32M` and `CPUQuota=5%` and no
sandboxing; `snowflake-metrics-exporter.service` is a plain oneshot unit with
neither.

### Network Security
- **Bandwidth limiting**: `tc-bandwidth-limiter.sh` applies a TBF qdisc, 6 Mbps
  daytime and 20 Mbps nighttime by default, switched by cron at 00:00 and 09:00.
  It replaces the **root qdisc on the whole interface**, so the cap covers all
  egress traffic from the device and deletes any tc configuration already there.
- **The proxy opens no inbound port**: Snowflake is outbound WebRTC.
- **The metrics server does.** `snowflake-metrics-server.py` listens on
  `0.0.0.0:9092` and serves `/metrics` and `/health` to any host that can reach
  it, with no authentication and no TLS. It exposes five operational gauges and
  no traffic content, but it is the one listening socket this stack adds:
  restrict it with a firewall rule or bind the host to a trusted network. Skip
  it entirely with `install.sh --no-monitoring`.

### Operational Security
- **No secrets**: The stack holds no tokens, keys or credentials. Configuration
  is command-line flags and a few `SNOWFLAKE_*` environment variables.
- **Dependencies**: The `tor-snowflake-proxy` package from the distribution, a
  Python 3 interpreter for the metrics server (standard library only),
  `iproute2` for `tc`, and cron. `prometheus_client` is needed only if you use
  `snowflake_metrics_addon.py`.
- **Idempotent installer**: Re-running `install.sh` reuses an existing binary,
  user and directories, and rewrites its own cron lines instead of appending.
  `--dry-run` prints every step without touching the system. This is
  re-runnability, not a reproducible build: the installer fetches the scripts
  from `main` on GitHub, so two runs on different days can install different
  content.

---

## Known Security Considerations

### Tor Network Participation

:warning: **Trade-off**: Running a Snowflake proxy makes your Pi Zero a participant in the Tor network.

**What this means**:
- Your IP address will be visible to Snowflake clients (censored users)
- Your ISP can see you're connecting to Tor relays
- No user traffic content is ever visible to you

**Mitigation**:
1. **No action needed**: This is expected behavior for Snowflake proxies
2. **Bandwidth limits**: The default 6/20 Mbps profiles cap what the proxy can
   draw from the household uplink
3. **Monitoring**: Prometheus metrics expose only aggregate statistics

**Impact**: ISP may flag Tor participation. In most jurisdictions, running a Snowflake proxy is legal.

**Recommendation**:
- For **homelab**: Run on dedicated Pi Zero (not critical infrastructure)
- For **enterprise**: Check with legal/compliance before deployment

### WiFi Exposure

:warning: **Trade-off**: Pi Zero 2W uses WiFi, which is inherently less secure than wired connections.

**Mitigation**:
- Use WPA3 or WPA2 with strong passphrase
- Consider running on a separate VLAN/SSID
- Signal strength is the variable that actually moved connection success in
  this deployment (see [docs/PERFORMANCE.md](docs/PERFORMANCE.md)); nothing in
  this repository watches the link or reconnects it, so a flapping WiFi shows up
  as a quiet proxy, not as an alert

---

## Security Disclosure Timeline

If you report a vulnerability, we follow this process:

1. **Day 0**: Vulnerability reported
2. **Day 1-3**: Initial response + severity assessment
3. **Day 3-14**: Fix development (depending on severity)
4. **Day 14-21**: Fix deployed + Security Advisory published
5. **Day 21+**: Full public disclosure (if applicable)

**Critical vulnerabilities** (e.g., privilege escalation, data leakage) are prioritized and fixed within 7 days.

---

## Security Best Practices for Users

When deploying this Snowflake proxy:

1. :white_check_mark: **Dedicated Hardware**: Use a dedicated Pi Zero (not your main Pi)
2. :white_check_mark: **Bandwidth Limits**: Keep the 6/20 Mbps defaults or lower on a shared network, and remember the cap is interface-wide
3. :white_check_mark: **Monitor Metrics**: Set up Prometheus alerts for unusual activity
4. :white_check_mark: **Regular Updates**: Keep system packages updated (`apt upgrade`)
5. :white_check_mark: **Network Isolation**: Consider separate VLAN if available
6. :white_check_mark: **Keep Updated**: Monitor [Tor Project releases](https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/-/releases)

---

## Vulnerability Disclosure History

No security vulnerabilities have been reported as of 2026-01-20.

---

## Contact

For security-related questions or to report a vulnerability:

- **Email**: security@fidpa.dev
- **Response Time**: Within 72 hours

For general questions, use [GitHub Issues](https://github.com/fidpa/snowflake-pi-zero/issues).

---

**Last Updated**: 2026-01-20
