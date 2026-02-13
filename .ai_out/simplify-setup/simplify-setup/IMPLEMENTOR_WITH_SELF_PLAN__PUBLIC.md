# simplify-setup: Implementation Summary

## What Was Done
- Renamed `setup.sh` to `setup_on_fedora.sh` (via git mv, preserving history)
- Fixed double shebang: removed `#!/bin/bash`, kept `#!/usr/bin/env bash`
- Added `install_if_missing` function that:
  - Accepts `what_to_install` and optional `what_to_check` (command name)
  - Detects package manager in order: dnf, apt, apt-get, brew
  - Installs the package if the command is not already available
  - Verifies installation succeeded; exits on failure
- Script now auto-installs `evemu` (checked via `evemu-event`) and `gnome-screenshot`
- All existing permissions logic (setuid, sudoers, input group, udev rules) preserved unchanged
- Updated `VM_SETUP_CLAUDE_CODE.md`: all references updated, Section 1 simplified (manual install instructions kept for Ubuntu/Debian only)
- Updated `README.md`: references updated to `setup_on_fedora.sh`
- Updated `SECURITY_REVIEW.md`: references updated to `setup_on_fedora.sh`

## Decisions
- Package manager detection order: dnf first (Fedora-focused), then apt, apt-get, brew
- The `install_if_missing` function is fully self-contained with no external dependencies
- Kept Ubuntu/Debian manual install instructions in VM_SETUP_CLAUDE_CODE.md as a reference since the script's package name (`evemu`) is Fedora-specific
