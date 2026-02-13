# Exploration: simplify-setup

## Current State
- `setup.sh` exists at repo root - hardcodes `sudo apt install -y evemu-tools` (Debian/Ubuntu only)
- `VM_SETUP_CLAUDE_CODE.md` references `setup.sh` and has manual Fedora/Ubuntu install instructions
- `README.md` also references `./setup.sh`

## Key Findings
1. **Package name differs by distro**: Fedora uses `evemu`, Debian/Ubuntu uses `evemu-tools`
2. Current `setup.sh` only handles apt (Debian/Ubuntu) - fails on Fedora
3. The script does 7 things: install evemu-tools, setuid, sudoers, verify, add to input group, chmod devices, udev rule
4. `VM_SETUP_CLAUDE_CODE.md` Section 1 has manual `dnf install evemu gnome-screenshot` step that could be automated

## Plan
1. Rename `setup.sh` → `setup_on_fedora.sh`
2. Add `install_if_missing` function pattern (standalone, no external deps) that detects dnf/apt
3. Auto-install `evemu`/`evemu-tools` AND `gnome-screenshot`
4. Update `VM_SETUP_CLAUDE_CODE.md` to reference new script name and reflect automation
5. Update `README.md` to reference new script name
