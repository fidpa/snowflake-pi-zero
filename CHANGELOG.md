# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-01-20

### Changed
- **BREAKING**: systemd service now uses `LogsDirectory=snowflake` instead of `ReadWritePaths=@LOG_DIR@`
  - Log path is now fixed to `/var/log/snowflake/` (Best Practice 2025)
  - systemd automatically creates and manages the directory with correct permissions
  - Custom `@LOG_DIR@` placeholder no longer supported in service file
- Simplified logging configuration in systemd service template

### Migration
If you previously used a custom `LOG_DIR`, update your service file manually:
```ini
# Old (no longer supported)
ReadWritePaths=/custom/log/path

# New (Best Practice 2025)
LogsDirectory=snowflake
StandardOutput=append:/var/log/snowflake/snowflake-proxy.log
```

## [1.2.0] - 2026-01-20

### Added
- CONTRIBUTING.md with contribution guidelines
- CODE_OF_CONDUCT.md (Contributor Covenant 2.1)
- SECURITY.md with vulnerability reporting policy
- CHANGELOG.md (this file)
- docs/README.md navigation index
- TL;DR sections for all documentation files (INSTALLATION, MONITORING, PERFORMANCE, TROUBLESHOOTING)
- Table of Contents for longer documentation files (README.md, MONITORING.md, PERFORMANCE.md, TROUBLESHOOTING.md)
- SPDX-License-Identifier header in install.sh

### Changed
- README.md now references CONTRIBUTING.md and SECURITY.md in Contributing section
- Documentation improvements across all docs/ files

## [1.1.0] - 2026-01-17

### Added
- `snowflake_metrics_addon.py` for extended Prometheus metrics
- Improved `install.sh` with symlink handling
- Better error messages during installation
- Extended systemd security hardening

### Changed
- Updated TROUBLESHOOTING.md with more common issues
- Improved bandwidth verification script

### Fixed
- Symlink handling in install script
- Service restart behavior on OOM conditions

## [1.0.0] - 2026-01-13

### Added
- Initial release
- `install.sh` - One-line installation script
- `tc-bandwidth-limiter.sh` - Time-based bandwidth limiting
- `snowflake-metrics-exporter.sh` - Prometheus metrics collection
- `snowflake-metrics-server.py` - HTTP metrics endpoint
- `verify-bandwidth.sh` - Bandwidth verification utility
- systemd service templates with security hardening
- Prometheus metrics exporter (4 core metrics)
- Grafana dashboard template
- Complete documentation suite:
  - INSTALLATION.md - Step-by-step setup guide
  - MONITORING.md - Prometheus + Grafana configuration
  - PERFORMANCE.md - WiFi impact analysis, optimization
  - TROUBLESHOOTING.md - Common issues and solutions
  - ARCHITECTURE.md - Technical deep-dive

### Security
- systemd hardening (PrivateTmp, NoNewPrivileges, ProtectSystem)
- Dedicated service user (`snowflake`)
- Memory and CPU limits (MemoryMax=256M, CPUQuota=30%)

---

[1.3.0]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/fidpa/snowflake-pi-zero/releases/tag/v1.0.0
