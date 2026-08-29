# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.7] - 2026-08-30: Documentation measured against the code it describes

`SECURITY.md` listed a `CapabilityBoundingSet` that appears in no unit, a
`MemoryMax=256M` against the unit's `128M`, and a "WiFi Monitoring: Auto-recovery
on connection loss" feature that exists nowhere in this repository. The README
opened its bandwidth section with a 2 Mbit/s default the scripts have never used
and claimed "All services run with comprehensive sandboxing" for two units that
have none. None of this was caught by a workflow, because nothing here reads
prose: `lint.yml` runs ShellCheck and `bash -n`, and both were green throughout.
This release is one pass over the four documents that make claims about the
code, each claim taken back to the unit, script or default it comes from.

### Changed

- **The README states what this stack does not do.** A `## Scope` section and a
  Known Limitations callout now name the four boundaries that were absent: the
  metrics endpoint binds `0.0.0.0:9092` without authentication, the tc profile
  caps the whole interface rather than Snowflake, `snowflake_bytes_proxied_total`
  reports a per-interval upload figure that can decrease, and the systemd
  sandboxing block applies to `snowflake-proxy.service` alone. The previous text
  read "All services run with comprehensive sandboxing", which the two metrics
  units do not.
- **The Quick Start no longer pipes the installer into a shell.**
  `install.sh` asks for confirmation with `read -p`, which gets no terminal when
  the script arrives on stdin, so the advertised one-liner ended at
  "Installation cancelled". The documented path downloads the script, offers
  `--dry-run`, and then runs it. The manual path gained the two steps it was
  missing (the textfile collector directory and the logrotate config) and no
  longer substitutes `pi` for `@SERVICE_USER@`.
- **The component tables match the tree.** `install.sh` and `configs/` were
  absent from the layout table, `snowflake_metrics_addon.py` from the scripts
  table, `snowflake-metrics-exporter.service` from the units table, and
  `snowflake_proxy_memory_bytes` from the metrics table, which listed four of
  the exporter's five metrics.
- **A CLI reference quotes both `--help` outputs verbatim.** `install.sh` and
  `tc-bandwidth-limiter.sh` had documented flags scattered through prose; the
  option blocks are now the programs' own, word for word.
- **Compatibility separates tested from assumed.** Pi 3/4/5, Bullseye, Debian 11+
  and Ubuntu 22.04+ were listed as "fully supported" without having been run
  there; they are now "should work, untested", and the tested row names the one
  configuration that has actually been in service.
- **The numbers carry their measuring conditions.** The feature list claimed
  "~11 connections/h" against a performance table giving 4-12 connections per
  device per day; the hourly figure is gone from the README and the 24h ranges
  cite the deployment they come from. The WiFi finding says how it was observed
  (two boards, same broker, differing placement) and that it is not a controlled
  experiment.
- **Template phrasing and slogan labels are gone.** The `**The Problem**:` opener,
  the "Why I Built This" restatement of it, the checkmark-prefixed feature
  slogans ("Resource Optimized", "Production-Proven"), and "Contributions
  welcome!" were replaced by text that states facts; `Use Cases` gained a
  "Poor fit" column of equal weight.

- **`install.sh` header version raised to 1.3.1.** The file changed, so its
  version line moves with it.

### Fixed

- **`SECURITY.md` describes the units that exist.** It claimed
  `ProtectHome=read-only` (the unit sets `true`), `MemoryMax=256M` (it is
  `128M`), a `CapabilityBoundingSet=CAP_NET_BIND_SERVICE` that appears in no
  unit, and a 2 Mbit/s bandwidth default against the scripts' 6 and 20 Mbps. It
  also listed "WiFi Monitoring: Auto-recovery on connection loss", a feature
  this repository does not contain in any form, and "No Inbound Ports", while
  `snowflake-metrics-server.py` binds `0.0.0.0:9092` without authentication.
  "Memory-Only Operation: No persistent state" stood in the same file as a
  logrotate config for the proxy's log. Every claim in that section now names
  the unit, script or default it comes from, and the hardening block says it
  covers the proxy service alone.
- **The supported-versions table lists a release line that exists.** It offered
  security fixes for 0.9.x and declared everything below 0.9.0 unsupported; the
  changelog starts at 1.0.0 and there has never been a 0.x tag.
- **`install.sh` reports one version.** The header comment said 1.3.0 while the
  startup banner printed v1.0.0. The version is now a single `INSTALLER_VERSION`
  constant that the banner reads, and the header no longer advertises the
  `curl | bash` one-liner that its own confirmation prompt cannot survive.
- **`docs/PERFORMANCE.md` states connection counts per day, not per hour.** Two
  tables labelled their counts "per hour", which contradicted the rest of the
  document: the per-device 7 and 4 sum to the 11 the load-distribution section
  reports, and that 11 is the count the bandwidth section pairs with a daily
  2-5 GB, against a stated normal band of 4-12 per device per 24h. Read as an
  hourly rate those same devices would complete 168-192 connections a day. The
  counts are per day; the label was wrong, and the correction is noted in the
  document itself.

## [1.5.6] - 2026-08-28: GitHub identifies the license as MIT

GitHub reported no license for this project, and has done so since the first
commit: `LICENSE` carried the MIT text followed by a note about the Tor
Project's proxy binary.
GitHub's license detection reads any addition to the MIT text as a modification.
The license field on the repository page therefore stayed empty, and a
repository without a detected license matches no `license:` filter in GitHub
search, while the README badge said MIT. The note itself was correct and stays,
in the file where such information belongs.

### Changed

- **The license field on the repository page says MIT.** `LICENSE` now carries
  the MIT text and nothing else; with the note removed it is byte-identical to
  that of a repository GitHub reports as `mit`. Nothing about the terms changed:
  the proxy binary was never covered, because `install_binary()` in `install.sh`
  installs the `tor-snowflake-proxy` package through the system package manager
  or points at the Tor Project's release page, and this repository has never
  contained it.
- **The BSD 3-Clause reference has its own file.** `NOTICE` names the Snowflake
  proxy binary, where it comes from, and the license it carries. `README.md`
  points at it from the `## License` section, which read "MIT License - see
  LICENSE for details" and named no third-party terms.

### Upgrade notes

None. This release changes no code and no terms; it moves an informational note
out of `LICENSE` and into `NOTICE`.

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

[1.5.7]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.5.6...v1.5.7
[1.5.6]: https://github.com/fidpa/snowflake-pi-zero/compare/v1.5.5...v1.5.6
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
