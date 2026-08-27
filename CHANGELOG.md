# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.5] - 2026-08-27: Removal entries name what went, not what was in it

An entry about something that should not have been public can restate the thing it removed.
The file leaves the tree but stays in the history, so a description of its contents turns a
missed artefact into a signposted one. The rule this repository follows now is to name what
was removed and why it did not belong, and to leave out what it held.

### Changed
- **Entries about removed material describe the removal, not the material.** The `[1.5.1]`
  and `[1.5.3]` sections say what left the repository and why it should not have been there;
  the descriptions of their contents are gone. What was removed, and the fact that it was
  removed, is unchanged.
- **The `[1.5.4]` section states what now holds instead of how much did not before.** The
  individual corrections stay where they are, each as its own entry; the summary of how many
  there were and how long they had stood is not part of a release page.

## [1.5.4] - 2026-08-27: Release notes carry their own headline

Every release page in this repository was rewritten in one editorial pass against the
release-message rules this portfolio follows: each entry now opens with what changes for the
operator, the sections describing an incident name the symptom first, and the release title
comes from the changelog instead of being typed by hand after the run.

Nothing about the released software changed. Every measured value, path and function name in
the older sections was verified against the tag it describes and kept; statements the code
contradicted were corrected, and those corrections are listed below.

### Changed
- **Release titles are now generated from the changelog instead of being typed by hand.**
  `.github/workflows/release.yml` reads the headline from the section heading
  (`## [X.Y.Z] - YYYY-MM-DD: <headline>`) and passes it to `softprops/action-gh-release` as
  `name:`. Without that input the action falls back to the tag name, which is why the titles
  of all nine earlier releases had to be set by hand after every run. The extraction is
  anchored to the start of the heading line, so a headline that mentions another version
  number cannot pull in the wrong section.
- **Every changelog entry now opens with the effect, not the file it happened in.** All
  sections from `[1.0.0]` to `[1.5.3]` were reformatted: a bold statement of what changes for
  the operator, followed by the file, function or config variable that carries it. The
  sections that describe an incident gained an introductory paragraph naming the symptom
  before the rubrics list the fixes.
- **Release titles use a colon as the separator.** All nine published releases were retitled
  from `vX.Y.Z - Headline` to `vX.Y.Z: Headline`.

### Fixed
- **The `[1.0.0]` section listed a memory limit the unit never carried.** It said
  `MemoryMax=256M`; `systemd/snowflake-proxy.service` has `MemoryMax=128M` in every tag from
  the first commit to `v1.5.3`. Corrected to 128M.
- **The `[1.1.0]` section now describes what that release actually shipped.** It is rewritten
  against the diff between the first commit and `v1.1.0`: the `snowflake_proxy_memory_bytes`
  metric in `snowflake-metrics-exporter.sh` and the `--daytime-limit` / `--nighttime-limit`
  options in `tc-bandwidth-limiter.sh`, which are what the release title referred to.
- **The `[1.5.3]` section named the wrong release for the placeholders it replaced.**
  Corrected against the tags.
- **`CHANGELOG.md`: removed five em dashes** from the `[1.5.1]` and `[1.5.3]` sections. The
  file is now plain ASCII.

### Notes
- **The tag `v1.0.0` does not mark the first release commit, and it is not moved.** It points
  at the same commit as `v1.2.0`, so the compare link between v1.0.0 and v1.1.0 shows a
  removal rather than the additions that release made. Build against `v1.1.0` or later if the
  distinction matters. A published tag is not moved, so this is documented rather than
  repaired.

## [1.5.3] - 2026-08-12: Generic placeholders in the example device locations

The two Python scripts carried example device locations from the author's own deployment
instead of generic placeholders. The `location` argument is a free-form string, so they never
affected how the code ran.

### Security
- **The example device locations are now generic.**
  `scripts/snowflake_metrics_addon.py` and `scripts/snowflake-metrics-server.py` used
  deployment-specific names as default parameter values, in docstrings and in usage examples.
  They now use the `pi-zero-01` and `pi-zero-02` placeholders that `README.md` and
  `install.sh` already used.

### Changed
- **The two Python scripts report version 1.1.1.** Header version bumped in
  `scripts/snowflake_metrics_addon.py` and `scripts/snowflake-metrics-server.py`.

## [1.5.2] - 2026-08-12: Scripts run straight after clone

### Fixed
- **`./install.sh` works after `git clone` without a shell prefix.** `install.sh`,
  `scripts/snowflake-metrics-exporter.sh` and `scripts/snowflake-metrics-server.py` were
  committed with mode `644` and are now `755`. Before this, running `./install.sh` failed
  with `Permission denied` and required `bash install.sh` instead.

## [1.5.1] - 2026-08-09: Internal drafts removed and release notes cut from the changelog

Two files that were never meant to be published had shipped with the releases before this one:
an internal pre-publication summary and a German marketing draft. Neither was referenced from
anywhere in the repository. The same pass fixed the release workflow, which produced empty
notes because this repository's commit subjects are bare version numbers.

### Removed
- **The repository no longer ships an internal pre-publication document.** `SUMMARY.md` was a
  working document that was never meant to be part of the public repository. Nothing linked to
  it and it had not been updated since the first release; `README.md` and `ARCHITECTURE.md`
  cover the same ground.
- **The repository no longer ships a German-language marketing draft.** `LINKEDIN_POST.md`
  does not belong in a public repository.

### Changed
- **A tagged release now publishes its changelog section instead of a bare compare link.**
  `.github/workflows/release.yml` cuts the release notes from `CHANGELOG.md`. This
  repository's commit subjects are bare version numbers, so `generate_release_notes` alone
  produced nothing but the compare link, and the real notes had to be pasted in by hand after
  every run. The job now fails instead of publishing an empty release when a version has no
  changelog section. `generate_release_notes` stays enabled, so the compare link is still
  appended.
- **`.shellcheckrc` no longer suggests a severity threshold it cannot set.** The
  `severity=warning` line was replaced with a comment explaining why it never worked.
  ShellCheck has no `severity` key for this file and discards unknown keys silently, verified
  against ShellCheck 0.9.0, where the SC2015 finding in `scripts/verify-bandwidth.sh` is
  reported with or without the line and only `--severity=error` on the command line changes
  it. The effective threshold is the `--severity=error` flag in `.github/workflows/lint.yml`,
  now documented there as well. The file header also described unrelated infrastructure and
  now names this project.

### Fixed
- **The 1.5.0 compare link at the end of the changelog resolves.** `CHANGELOG.md` was missing
  the `[1.5.0]` link reference.

### Security
- **A draft left in the working tree no longer reaches a commit by accident.** `.gitignore`
  gained `*_POST.md`, `TODO.md`, `NOTES.md`, `*_TEMPLATE.md`, `*.local`, `*.private`, `*.draft`
  and `.claude/`. Ignore rules only apply to untracked files, so this prevents the next such
  draft from being committed rather than repairing the two removed above.

## [1.5.0] - 2026-07-02: Metrics survive a corrupted log and the log stops growing

After a Pi Zero loses power, partial writes leave NUL bytes in the proxy log. Plain `grep`
then treats the file as binary and stops matching, so the exporter kept publishing the last
values it had parsed: `snowflake_connected_clients` and `snowflake_bytes_proxied_total` froze
without any error. The log had no rotation either, so it grew without bound and every power
loss added more NUL bytes to the same file.

### Added
- **The proxy log is rotated daily and kept for seven days.** `install.sh` installs
  `configs/snowflake-logrotate` to `/etc/logrotate.d/snowflake`. `copytruncate` is required
  because the systemd unit holds the file descriptor open through
  `StandardOutput=append:`; a rename-based rotation would leave the proxy writing to the
  renamed inode. Keeping the file small also bounds how much NUL-byte damage a single power
  loss can do.

### Fixed
- **Client and traffic metrics no longer freeze after a power loss.**
  `snowflake-metrics-exporter.sh` parses the proxy log byte-safely with
  `tail -n 2000 | grep -oaP` instead of `grep -oP` over the whole file.
- **The bundled Grafana dashboard imports with its panels.**
  `monitoring/grafana-dashboard.json` is now the raw dashboard model instead of the
  API-wrapped `{"dashboard": {...}}` form, which imported as an empty dashboard through the
  Grafana UI and broke file-based provisioning.

### Changed
- **The exporter reports version 1.2.0.** Header version bumped in
  `snowflake-metrics-exporter.sh`.
- **Both failure modes above are documented.** `docs/TROUBLESHOOTING.md` gained entries for
  stale metrics caused by NUL bytes in the log and for empty imported dashboards.

## [1.4.0] - 2026-01-21: ShellCheck and release automation in CI

### Added
- **Every push and pull request is checked by ShellCheck and a Bash syntax pass.**
  `.github/workflows/lint.yml` runs both; `.shellcheckrc` holds the configuration.
- **Pushing a version tag publishes a GitHub release.**
  `.github/workflows/release.yml` reacts to tags matching `v*`.

### Changed
- **The README shows the current CI state.** A GitHub Actions status badge was added to
  `README.md`.

## [1.3.0] - 2026-01-20: Log directory managed by systemd

The service file used a custom `@LOG_DIR@` placeholder and `ReadWritePaths=` to give the proxy
a writable log directory, which meant the installer had to create the directory and set its
permissions. systemd does both on its own with `LogsDirectory=`.

### Changed
- **Breaking: the log path is fixed at `/var/log/snowflake/` and a custom `LOG_DIR` no longer
  takes effect.** The systemd service template uses `LogsDirectory=snowflake` instead of
  `ReadWritePaths=@LOG_DIR@`, so systemd creates and manages the directory with the correct
  permissions. Installations that set a custom log path need the manual step below.

### Upgrade notes
If you previously used a custom `LOG_DIR`, update your service file manually:
```ini
# Old (no longer supported)
ReadWritePaths=/custom/log/path

# New
LogsDirectory=snowflake
StandardOutput=append:/var/log/snowflake/snowflake-proxy.log
```

## [1.2.0] - 2026-01-20: Community standards and navigable documentation

### Added
- **The repository states how to contribute, how to report a vulnerability and which conduct
  applies.** `CONTRIBUTING.md`, `SECURITY.md` and `CODE_OF_CONDUCT.md` (Contributor Covenant
  2.1) were added.
- **Changes are tracked in a changelog.** `CHANGELOG.md`, this file.
- **The documentation has an index.** `docs/README.md` lists the five documents under `docs/`.
- **Each documentation file states its point in the first paragraph.** TL;DR sections were
  added to `docs/INSTALLATION.md`, `docs/MONITORING.md`, `docs/PERFORMANCE.md` and
  `docs/TROUBLESHOOTING.md`.
- **The four longest documents can be navigated without scrolling.** Tables of contents were
  added to `README.md`, `docs/MONITORING.md`, `docs/PERFORMANCE.md` and
  `docs/TROUBLESHOOTING.md`.
- **The licence is machine-readable at the top of the installer.**
  `install.sh` carries an `SPDX-License-Identifier` header.

### Changed
- **The README points to the contribution and security policies.** Its Contributing section
  references `CONTRIBUTING.md` and `SECURITY.md`.

## [1.1.0] - 2026-01-17: Proxy memory exposed as a metric and configurable bandwidth limits

### Added
- **Proxy memory usage is now a Prometheus metric.**
  `snowflake-metrics-exporter.sh` exports `snowflake_proxy_memory_bytes` from the RSS of the
  `snowflake-proxy` process, making it the fifth metric alongside clients, bytes, uptime and
  service status. It reports 0 when the process is not running.
- **The bandwidth limits can be set without editing the script.**
  `tc-bandwidth-limiter.sh` accepts `--daytime-limit` and `--nighttime-limit` in Mbps and
  reads the environment variables `SNOWFLAKE_DAYTIME_LIMIT` and `SNOWFLAKE_NIGHTTIME_LIMIT`.
  The defaults are unchanged at 6 Mbps daytime and 20 Mbps nighttime. `install.sh` passes the
  configured values through to the script and into the two cron entries it writes.

### Changed
- **The metrics server accepts any device name.**
  `snowflake-metrics-server.py` no longer rejects arguments outside a fixed pair of location
  names, so a device can be called whatever the deployment calls it.
- **The metrics directory is owned by the service user after installation.**
  `install.sh` includes `$METRICS_DIR` in the `chown snowflake:snowflake` call alongside the
  install and log directories.

### Fixed
- **The proxy service starts when the Snowflake binary lives outside the install directory.**
  `install.sh` creates a symlink at `${INSTALL_DIR}/snowflake-proxy`, both when the binary is
  already present and when it was just installed through apt. The systemd unit expects the
  binary at that path.
- **`snowflake-metrics-exporter.service` starts as the service user.** Its `User=` line still
  carried the `@SERVICE_USER@` placeholder and now reads `snowflake`.
- **The troubleshooting guide names the package that exists.** `docs/TROUBLESHOOTING.md`
  recommended `stuntman-client`; the package providing `stunclient` is `stun-client`.

## [1.0.0] - 2026-01-13: Tor Snowflake proxy on a Pi Zero, with metrics and bandwidth limits

First public release. It installs a Tor Snowflake proxy on a Raspberry Pi Zero, keeps it from
saturating the WiFi link, and exposes what it is doing to Prometheus.

### Added
- **One command installs the proxy, the units and the monitoring.** `install.sh`.
- **The proxy runs under a lower bandwidth cap during the day than at night.**
  `tc-bandwidth-limiter.sh` applies a tc-netem Token Bucket Filter, 6 Mbps from 09:00 and
  20 Mbps from midnight, switched by two cron entries.
- **Four Prometheus metrics describe the proxy.**
  `snowflake-metrics-exporter.sh` writes `snowflake_connected_clients`,
  `snowflake_bytes_proxied_total`, `snowflake_proxy_uptime_seconds` and
  `snowflake_service_status` to the node exporter textfile collector.
- **The metrics are also available over HTTP.** `snowflake-metrics-server.py` serves them on
  port 9092 for setups that scrape directly, and `snowflake_metrics_addon.py` registers them
  with `prometheus_client`.
- **The applied bandwidth limit can be verified on the device.** `verify-bandwidth.sh`.
- **Prometheus and Grafana can be wired up from the shipped files.**
  `monitoring/prometheus-snippet.yml`, `monitoring/alerts-example.yml` and
  `monitoring/grafana-dashboard.json`.
- **The setup is documented end to end.** `docs/INSTALLATION.md` for the setup,
  `docs/MONITORING.md` for Prometheus and Grafana, `docs/PERFORMANCE.md` for the WiFi impact,
  `docs/TROUBLESHOOTING.md` for common failures, and `ARCHITECTURE.md` for the design.

### Security
- **The proxy runs unprivileged and cannot reach the rest of the filesystem.**
  `systemd/snowflake-proxy.service` sets `User=snowflake`, `NoNewPrivileges=true`,
  `ProtectSystem=strict` and `PrivateTmp=true`.
- **A runaway proxy cannot starve the Pi Zero.** The same unit sets `MemoryMax=128M` and
  `CPUQuota=30%`.

---

[1.5.5]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.5.4...v1.5.5
[1.5.4]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.5.3...v1.5.4
[1.5.3]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.5.2...v1.5.3
[1.5.2]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.5.1...v1.5.2
[1.5.1]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/fidpa/snowflake-pi-zero/releases/tag/v1.0.0
