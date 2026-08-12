# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.2] - 2026-08-12

### Fixed
- `install.sh`, `scripts/snowflake-metrics-exporter.sh`,
  `scripts/snowflake-metrics-server.py`: set the executable bit (was `644`, now
  `755`). Without it, `./install.sh` after `git clone` failed with
  `Permission denied` and required `bash install.sh` instead.

## [1.5.1] - 2026-08-09

### Removed
- `SUMMARY.md` — an internal pre-publication document that had been shipped since the
  very first commit. It carried a private working path, the original private device
  IPs and device names it claimed to have sanitised, and a marketing section. Nothing
  linked to it and it had not been updated since v1.0.0; `README.md` and
  `ARCHITECTURE.md` cover the same ground.
- `LINKEDIN_POST.md` — a German-language marketing draft that does not belong in a
  public repository.

### Changed
- `.github/workflows/release.yml`: release notes are now cut from `CHANGELOG.md`
  instead of being generated from commit messages. This repository's commit subjects
  are bare version numbers, so `generate_release_notes` alone produced nothing but the
  compare link and the real notes had to be pasted in by hand after every run. The job
  now fails instead of publishing an empty release when a version has no changelog
  section. `generate_release_notes` stays enabled, so the compare link is still
  appended.
- `.shellcheckrc`: replaced the `severity=warning` line with a comment explaining why
  it never worked. ShellCheck has no `severity` key for this file and discards unknown
  keys silently — verified against ShellCheck 0.9.0, where the SC2015 finding in
  `scripts/verify-bandwidth.sh` is reported with or without the line, and only
  `--severity=warning` on the command line suppresses it. The effective threshold is
  `--severity=error` in `.github/workflows/lint.yml`, now documented there as well.
  The file header also described unrelated infrastructure and now names this project.

### Fixed
- `CHANGELOG.md`: added the missing `[1.5.0]` link reference at the end of the file.

### Security
- `.gitignore`: added `*_POST.md`, `TODO.md`, `NOTES.md`, `*_TEMPLATE.md`, `*.local`,
  `*.private`, `*.draft` and `.claude/`. Ignore rules only apply to untracked files, so
  this prevents the next such draft from being committed rather than repairing the two
  above.

## [1.5.0] - 2026-07-02

### Added
- `configs/snowflake-logrotate` and `install.sh` now installs `/etc/logrotate.d/snowflake`
  (daily rotation, 7-day retention, `copytruncate`). Prevents unbounded log growth and
  bounds NUL-byte accumulation from partial writes after a Pi Zero power loss.

### Fixed
- `snowflake-metrics-exporter.sh`: parse the proxy log byte-safely
  (`tail -n 2000 | grep -oaP`). Previously plain `grep` treated a NUL-corrupted log as
  binary and returned stale `connected_clients` / `bytes_proxied` values (frozen metrics).
- `monitoring/grafana-dashboard.json`: now shipped as the raw dashboard model instead of
  the API-wrapped `{"dashboard": {...}}` form. The wrapped form imported as an empty
  dashboard (no panels) via the Grafana UI and broke file-based provisioning.

### Changed
- `snowflake-metrics-exporter.sh` version bumped to 1.2.0.
- `docs/TROUBLESHOOTING.md`: added entries for stale metrics (NUL bytes in log) and
  empty imported dashboards.

## [1.4.0] - 2026-01-21

### Added
- CI/CD pipeline with GitHub Actions
  - `.github/workflows/lint.yml` - ShellCheck and Bash syntax validation on push/PR
  - `.github/workflows/release.yml` - Automated GitHub releases on version tags
- `.shellcheckrc` - ShellCheck configuration (Best Practices 2025)
- CI status badge in README.md

### Changed
- README.md now displays live CI/CD status via GitHub Actions badge

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

[1.5.2]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.5.1...v1.5.2
[1.5.1]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/fidpa/snowflake-pi-zero/releases/tag/v1.0.0
