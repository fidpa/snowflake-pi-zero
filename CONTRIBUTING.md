# Contributing to Snowflake Pi Zero

Thank you for considering contributing to Snowflake Pi Zero! This project helps run Snowflake Tor proxies on Raspberry Pi Zero 2W devices.

## 🎯 Project Scope

This is currently a **solo-maintained project** focused on:
- Raspberry Pi Zero 2W hardware optimization
- Snowflake Tor proxy automation
- systemd service integration
- Prometheus/Grafana monitoring

## 🐛 Reporting Issues

If you encounter bugs or have feature requests:

1. **Check existing issues** first to avoid duplicates
2. **Use descriptive titles** (e.g., "Service fails on WiFi disconnect" not "broken")
3. **Include system info**:
   - Pi Zero model (2W recommended)
   - OS version (`cat /etc/os-release`)
   - Script version (`git describe --tags`)
   - Relevant logs (`journalctl -u snowflake-proxy.service`)

## 💡 Suggesting Features

Feature requests are welcome! Please:
- Explain the **use case** (why is this useful?)
- Consider **scope** (does it fit the Pi Zero 2W focus?)
- Check if it conflicts with existing design goals (simplicity, minimal dependencies)

## 🔧 Pull Requests

**Note**: This is a solo-maintained project with limited review bandwidth. PRs are welcome but may take time to review.

### Before Submitting

1. **Test on actual Pi Zero 2W hardware** (not emulators)
2. **Follow existing code style**:
   - Bash: `set -uo pipefail`, ShellCheck clean
   - Python: Type hints (3.10+ syntax), `yaml.safe_load()`, no `shell=True`
3. **Update documentation** if behavior changes
4. **Keep PRs focused** - one feature/fix per PR

### PR Checklist

- [ ] Tested on Pi Zero 2W
- [ ] ShellCheck passes (if Bash)
- [ ] Documentation updated (README.md, docs/)
- [ ] Commit messages are clear (describe *why*, not just *what*)

## 📝 Code Style

**Bash Scripts**:
```bash
#!/usr/bin/env bash
set -uo pipefail  # Required for production scripts

# Use color logging for user-facing scripts
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m'  # No Color

log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
```

**Python Scripts**:
```python
#!/usr/bin/env python3
"""Docstring explaining script purpose."""

import sys
from pathlib import Path

def main() -> int:
    """Main entry point."""
    # Type hints required for all functions
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

## 🔐 Security

**Do not include**:
- Private Tor keys or credentials
- IP addresses or hostnames
- Personal identification information

See [SECURITY.md](SECURITY.md) for reporting vulnerabilities.

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License (same as the project).

## 🙏 Questions?

Open an issue with the `question` label - happy to help!

---

**Thank you for contributing!** Every bug report, feature request, and PR helps make this project better for the Tor community.
