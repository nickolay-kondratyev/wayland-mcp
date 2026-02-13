#!/usr/bin/env bash
# Diagnostic script for wayland-mcp.
# Performs read-only checks and reports PASS/FAIL with remediation hints.
# Safe to run at any time — does NOT modify anything.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pass_count=0
fail_count=0
warn_count=0

pass()  { echo "  PASS: $1"; ((pass_count++)); }
fail()  { echo "  FAIL: $1"; echo "    -> Fix: $2"; ((fail_count++)); }
warn()  { echo "  WARN: $1"; echo "    -> $2"; ((warn_count++)); }
section() { echo ""; echo "=== $1 ==="; }

# ---------------------------------------------------------------------------
section "1. Environment"
# ---------------------------------------------------------------------------

# 1a. KVM check
virt_type="$(systemd-detect-virt 2>/dev/null || echo 'unknown')"
if [[ "${virt_type}" == "kvm" ]]; then
  pass "Running inside KVM (detected=[${virt_type}])"
else
  warn "Not running inside KVM (detected=[${virt_type}])" \
       "This script expects a KVM VM. If you are on bare metal, input permissions may be a security risk."
fi

# 1b. Wayland session
if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
  pass "Wayland session active (XDG_SESSION_TYPE=[${XDG_SESSION_TYPE}])"
else
  fail "Not a Wayland session (XDG_SESSION_TYPE=[${XDG_SESSION_TYPE:-<unset>}])" \
       "Log in to a Wayland session (e.g. GNOME on Wayland). X11 is not supported."
fi

# 1c. WAYLAND_DISPLAY
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
  pass "WAYLAND_DISPLAY is set (WAYLAND_DISPLAY=[${WAYLAND_DISPLAY}])"
else
  fail "WAYLAND_DISPLAY is not set" \
       "Ensure you are in a Wayland session. Check 'echo \$WAYLAND_DISPLAY' in your terminal."
fi

# 1d. XDG_RUNTIME_DIR and Wayland socket
if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
  wayland_socket="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY:-wayland-0}"
  if [[ -e "${wayland_socket}" ]]; then
    pass "Wayland socket exists at [${wayland_socket}]"
  else
    fail "Wayland socket not found at [${wayland_socket}]" \
         "Verify WAYLAND_DISPLAY and XDG_RUNTIME_DIR are correct for your session."
  fi
else
  fail "XDG_RUNTIME_DIR is not set" \
       "This should be set automatically by your login session (e.g. /run/user/\$(id -u))."
fi

# ---------------------------------------------------------------------------
section "2. Input Devices"
# ---------------------------------------------------------------------------

# 2a. /dev/input/event* exist
event_devices=(/dev/input/event*)
if [[ -e "${event_devices[0]}" ]]; then
  pass "Input event devices found (count=[${#event_devices[@]}])"
else
  fail "No /dev/input/event* devices found" \
       "Ensure input devices are available. In a VM, check that virtio-input or evdev passthrough is configured."
fi

# 2b. Writable check
non_writable=0
for dev in /dev/input/event*; do
  if [[ -e "${dev}" ]] && [[ ! -w "${dev}" ]]; then
    ((non_writable++))
  fi
done
if [[ ${non_writable} -eq 0 ]]; then
  pass "All input devices are writable by current user"
else
  fail "${non_writable} input device(s) are not writable" \
       "Re-run ./setup_on_fedora_run_in_vm.sh or manually: sudo chmod 666 /dev/input/event*"
fi

# 2c. User in input group
if id -nG | grep -qw input; then
  pass "User [${USER}] is in the 'input' group"
else
  fail "User [${USER}] is NOT in the 'input' group" \
       "Run: sudo usermod -aG input ${USER} (then log out and back in)"
fi

# 2d. Udev rule
udev_rule_file="/etc/udev/rules.d/99-input.rules"
if [[ -f "${udev_rule_file}" ]]; then
  pass "Udev rule exists at [${udev_rule_file}]"
else
  warn "Udev rule [${udev_rule_file}] not found" \
       "Re-run ./setup_on_fedora_run_in_vm.sh to create the persistent udev rule."
fi

# ---------------------------------------------------------------------------
section "3. evemu-event"
# ---------------------------------------------------------------------------

if command -v evemu-event > /dev/null 2>&1; then
  pass "evemu-event is installed (path=[$(command -v evemu-event)])"

  # Setuid check
  evemu_path="$(command -v evemu-event)"
  if [[ -u "${evemu_path}" ]]; then
    pass "evemu-event has setuid bit set"
  else
    warn "evemu-event does NOT have setuid bit" \
         "Run: sudo chmod u+s ${evemu_path}"
  fi
else
  fail "evemu-event is not installed" \
       "Run: sudo dnf install -y evemu (Fedora) or sudo apt install -y evemu-tools (Debian/Ubuntu)"
fi

# ---------------------------------------------------------------------------
section "4. Screenshot Tools"
# ---------------------------------------------------------------------------

screenshot_tools=(gnome-screenshot grim ksnip spectacle)
found_tool=""
for tool in "${screenshot_tools[@]}"; do
  if command -v "${tool}" > /dev/null 2>&1; then
    found_tool="${tool}"
    break
  fi
done
if [[ -n "${found_tool}" ]]; then
  pass "Screenshot tool available: [${found_tool}]"
else
  fail "No supported screenshot tool found (checked: ${screenshot_tools[*]})" \
       "Run: sudo dnf install -y gnome-screenshot (Fedora) or install grim/ksnip/spectacle."
fi

# ---------------------------------------------------------------------------
section "5. Python Virtual Environment"
# ---------------------------------------------------------------------------

if [[ -n "${MY_VENV_PYTHON_BIN:-}" ]]; then
  if [[ -x "${MY_VENV_PYTHON_BIN}" ]]; then
    pass "MY_VENV_PYTHON_BIN=[${MY_VENV_PYTHON_BIN}] exists and is executable"
  else
    fail "MY_VENV_PYTHON_BIN=[${MY_VENV_PYTHON_BIN}] is not executable" \
         "Check the path and ensure the venv was created correctly."
  fi
else
  fail "MY_VENV_PYTHON_BIN is not set" \
       "Export MY_VENV_PYTHON_BIN pointing to your venv python binary (e.g. /home/user/MY_PYTHON_VENV/bin/python3)."
fi

if [[ -n "${MY_VENV_PIP:-}" ]]; then
  if [[ -x "${MY_VENV_PIP}" ]]; then
    pass "MY_VENV_PIP=[${MY_VENV_PIP}] exists and is executable"
  else
    fail "MY_VENV_PIP=[${MY_VENV_PIP}] is not executable" \
         "Check the path and ensure the venv was created correctly."
  fi
else
  fail "MY_VENV_PIP is not set" \
       "Export MY_VENV_PIP pointing to your venv pip binary (e.g. /home/user/MY_PYTHON_VENV/bin/pip)."
fi

# ---------------------------------------------------------------------------
section "6. wayland-mcp Installation"
# ---------------------------------------------------------------------------

if [[ -n "${MY_VENV_PYTHON_BIN:-}" ]] && [[ -x "${MY_VENV_PYTHON_BIN:-}" ]]; then
  if "${MY_VENV_PYTHON_BIN}" -c "import wayland_mcp" 2>/dev/null; then
    pass "wayland_mcp is importable in venv"
  else
    fail "wayland_mcp is NOT importable in venv" \
         "Run: ${MY_VENV_PIP:-pip} install -e ${SCRIPT_DIR}"
  fi

  # Mouse device check
  mouse_output="$("${MY_VENV_PYTHON_BIN}" -c "
from wayland_mcp.mouse_utils import MouseController
m = MouseController()
print(m.device)
" 2>&1)" && mouse_ok=true || mouse_ok=false

  if [[ "${mouse_ok}" == "true" ]]; then
    pass "MouseController initialized (device=[${mouse_output}])"
  else
    fail "MouseController failed to initialize" \
         "Check input device permissions (see section 2 above). Error: ${mouse_output}"
  fi

  # Keyboard device check
  kb_output="$("${MY_VENV_PYTHON_BIN}" -c "
from wayland_mcp.keyboard_utils import KeyboardController
k = KeyboardController()
print(k.device)
" 2>&1)" && kb_ok=true || kb_ok=false

  if [[ "${kb_ok}" == "true" ]]; then
    pass "KeyboardController initialized (device=[${kb_output}])"
  else
    fail "KeyboardController failed to initialize" \
         "Check input device permissions (see section 2 above). Error: ${kb_output}"
  fi
else
  warn "Skipping wayland-mcp checks (MY_VENV_PYTHON_BIN not available)" \
       "Set MY_VENV_PYTHON_BIN to enable these checks."
fi

# ---------------------------------------------------------------------------
section "7. MCP Config"
# ---------------------------------------------------------------------------

mcp_json="${SCRIPT_DIR}/.claude/mcp.json"
if [[ -f "${mcp_json}" ]]; then
  pass "MCP config exists at [${mcp_json}]"

  # Check that WAYLAND_DISPLAY in config matches current session
  if command -v python3 > /dev/null 2>&1 || [[ -n "${MY_VENV_PYTHON_BIN:-}" ]]; then
    python_bin="${MY_VENV_PYTHON_BIN:-python3}"
    config_wayland_display="$("${python_bin}" -c "
import json, sys
with open('${mcp_json}') as f:
    cfg = json.load(f)
env = cfg.get('mcpServers', {}).get('wayland-mcp', {}).get('env', {})
print(env.get('WAYLAND_DISPLAY', ''))
" 2>/dev/null || echo '')"

    actual_wayland_display="${WAYLAND_DISPLAY:-}"
    if [[ -n "${config_wayland_display}" ]] && [[ "${config_wayland_display}" == "${actual_wayland_display}" ]]; then
      pass "MCP config WAYLAND_DISPLAY=[${config_wayland_display}] matches current session"
    elif [[ -n "${config_wayland_display}" ]] && [[ -n "${actual_wayland_display}" ]]; then
      fail "MCP config WAYLAND_DISPLAY=[${config_wayland_display}] does NOT match current session=[${actual_wayland_display}]" \
           "Re-run ./setup_mcp_config.sh or edit ${mcp_json} to set WAYLAND_DISPLAY to [${actual_wayland_display}]."
    elif [[ -z "${actual_wayland_display}" ]]; then
      warn "Cannot verify WAYLAND_DISPLAY match (current session value is unset)" \
           "Ensure you are in a Wayland session."
    fi
  fi
else
  fail "MCP config not found at [${mcp_json}]" \
       "Run: ./setup_mcp_config.sh (or ./setup_on_fedora_run_in_vm.sh which calls it)."
fi

# ---------------------------------------------------------------------------
section "Summary"
# ---------------------------------------------------------------------------

echo ""
echo "  Results: ${pass_count} passed, ${fail_count} failed, ${warn_count} warnings"
echo ""

if [[ ${fail_count} -eq 0 ]]; then
  echo "  All checks passed! wayland-mcp should be ready to use."
  echo "  Start Claude Code with: cd ${SCRIPT_DIR} && claude"
else
  echo "  There are ${fail_count} failure(s) to address. See FAIL items above for fix instructions."
fi
