# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

**Contact**: security@fidpa.dev

We will respond within 72 hours and provide a timeline for fixes.

**Please do NOT open a public issue for security vulnerabilities.**

---

## Supported Versions

We provide security updates for the following versions:

| Version | Supported          | Notes                          |
| ------- | ------------------ | ------------------------------ |
| 1.x     | :white_check_mark: Yes | Active development             |
| 0.9.x   | :warning: Security fixes only | Upgrade to 1.0.0 recommended |
| < 0.9.0 | :x: No              | No longer supported            |

---

## Security Features

This project implements the following security measures:

### Snowflake Proxy Security
- **No User Data Storage**: Snowflake proxies never store user traffic
- **Minimal Logging**: Only operational metrics (connections, bytes transferred)
- **Process Isolation**: Dedicated user (`snowflake`) with minimal privileges
- **Memory-Only Operation**: No persistent state that could be seized

### systemd Hardening
- **PrivateTmp=true**: Isolated temp directories
- **NoNewPrivileges=true**: Prevents privilege escalation
- **ProtectSystem=strict**: Read-only root filesystem
- **ProtectHome=read-only**: Protected home directories
- **CapabilityBoundingSet=CAP_NET_BIND_SERVICE**: Only network capabilities
- **MemoryMax=256M**: Resource limits to prevent DoS

### Network Security
- **Bandwidth Limiting**: tc-netem prevents network saturation (default: 2 Mbit/s)
- **WiFi Monitoring**: Auto-recovery on connection loss
- **No Inbound Ports**: Snowflake uses WebRTC (outbound only)

### Operational Security
- **No Secrets in Code**: All configuration via environment variables
- **Minimal Dependencies**: Only Go runtime + system utilities
- **Reproducible Builds**: Install script is idempotent

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
2. **Bandwidth limits**: Default 2 Mbit/s prevents bandwidth abuse
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
- WiFi impact on Snowflake is minimal (low bandwidth required)

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
2. :white_check_mark: **Bandwidth Limits**: Keep default 2 Mbit/s or lower for home networks
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
