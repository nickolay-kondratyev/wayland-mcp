# Implementation Review: simplify-setup (Private Notes)

## Checklist

- [x] Bash syntax check passes (`bash -n setup_on_fedora.sh` -- OK)
- [x] No `sanity_check.sh` found in repo (N/A)
- [x] Double shebang bug fixed (removed `#!/bin/bash`, kept `#!/usr/bin/env bash`)
- [x] `install_if_missing` function: correct pattern, proper error handling, proper quoting
- [x] All references to `setup.sh` updated in `README.md`, `VM_SETUP_CLAUDE_CODE.md`, `SECURITY_REVIEW.md`
- [x] No stale `setup.sh` references in non-.ai_out tracked files
- [x] Existing permissions logic (steps 2-7) preserved byte-for-byte
- [x] `__enable_bash_strict_mode__` anchor point preserved

## Detailed Analysis

### install_if_missing function correctness
- `${1:?...}` correctly fails if no argument given
- `${2:-$what_to_install}` sensible default
- `command -v` properly used with quoting
- Package manager detection order (dnf, apt, apt-get, brew) is reasonable for a Fedora-focused script
- Post-install verification (`command -v` check after install) is a nice touch
- `exit 1` on failure is correct -- will abort the whole script

### Naming inconsistency (flagged as IMPORTANT)
The script is named `setup_on_fedora.sh` yet `install_if_missing` supports apt, apt-get, and brew.
The script hardcodes Fedora package names (`evemu` not `evemu-tools`).
On Ubuntu/Debian, `install_if_missing evemu evemu-event` will run `sudo apt install -y evemu`,
but the Debian/Ubuntu package is `evemu-tools`, not `evemu`. This will fail silently from the
apt perspective (no package found) and then the post-install check will catch it and exit 1.

This is acceptable given the script is named `_on_fedora`, but the `install_if_missing` function
supporting apt/brew creates a misleading impression that it works cross-distro. The VM_SETUP_CLAUDE_CODE.md
line 50 says "auto-detects dnf/apt/brew" which could mislead users on Debian/Ubuntu.

### SECURITY_REVIEW.md stale line numbers
Line numbers in the findings table (16, 21, 34, 38-39, 44-45) reference old setup.sh.
After adding ~33 lines for install_if_missing, actual line numbers shifted to ~54, 59, 72, 76-78, 82-83.
This is cosmetic and does not affect correctness or security.

### No strict mode activated
The `# __enable_bash_strict_mode__` comment exists but no `set -euo pipefail` is actually present.
This was pre-existing (same in original `setup.sh`). Not a regression.

### No tests
This is a bash setup script. No automated tests exist or are expected. The syntax check passes.
