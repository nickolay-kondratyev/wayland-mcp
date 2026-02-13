#!/usr/bin/env bash
# __enable_bash_strict_mode__

# Installs a package if the corresponding command is not already available.
# Usage: install_if_missing <package_name> [<command_to_check>]
#   - package_name:    Name to pass to the package manager (e.g. "evemu").
#   - command_to_check: Command to verify availability (defaults to package_name).
install_if_missing() {
  local what_to_install="${1:?what to install is required.}"
  local what_to_check="${2:-$what_to_install}"

  if command -v "${what_to_check}" > /dev/null 2>&1; then
    echo "${what_to_check} is already installed."
    return 0
  fi

  echo "Installing ${what_to_install} (checked via '${what_to_check}')..."

  if command -v dnf > /dev/null 2>&1; then
    sudo dnf install -y "${what_to_install}"
  elif command -v apt > /dev/null 2>&1; then
    sudo apt install -y "${what_to_install}"
  elif command -v apt-get > /dev/null 2>&1; then
    sudo apt-get install -y "${what_to_install}"
  elif command -v brew > /dev/null 2>&1; then
    brew install "${what_to_install}"
  else
    echo "ERROR: No supported package manager found (tried dnf, apt, apt-get, brew)."
    exit 1
  fi

  if ! command -v "${what_to_check}" > /dev/null 2>&1; then
    echo "ERROR: ${what_to_check} still not found after installing ${what_to_install}."
    exit 1
  fi

  echo "${what_to_install} installed successfully."
}

main() {
  if [[ "$(systemd-detect-virt)" != "kvm" ]]; then
    echo "This setup script is intended to be run inside a KVM virtual machine. Detected environment: $(systemd-detect-virt). As it is NOT meant to run on HOST machine. It should only run within a VM"
    echo "Please run this script inside a KVM VM for proper setup."
    exit 1
  fi
  
  if type linux.is_main_dev_machine &> /dev/null; then
    if linux.is_main_dev_machine; then
      echo "We on on the main dev machine, which is unexpected for this script. This script is intended to be run inside a KVM virtual machine, not on the host. Detected environment: $(systemd-detect-virt). Please run this script inside a KVM VM for proper setup."
      exit 1
    fi
  else
    echo "ERROR: linux.is_main_dev_machine function not found. This function is required to verify that the script is running on the expected environment. Please ensure you have the necessary environment setup and try again."
    exit 1
  fi

  if [[ -z "${MY_VENV_PYTHON_BIN:-}" ]]; then
    echo "ERROR: MY_VENV_PYTHON_BIN is not set. Expected path to venv python binary (e.g. /home/user/MY_PYTHON_VENV/bin/python3)."
    exit 1
  fi

  if [[ ! -x "${MY_VENV_PYTHON_BIN}" ]]; then
    echo "ERROR: MY_VENV_PYTHON_BIN=[${MY_VENV_PYTHON_BIN}] is not an executable file."
    exit 1
  fi

  if [[ -z "${MY_VENV_PIP:-}" ]]; then
    echo "ERROR: MY_VENV_PIP is not set. Expected path to venv pip binary (e.g. /home/user/MY_PYTHON_VENV/bin/pip)."
    exit 1
  fi

  if [[ ! -x "${MY_VENV_PIP}" ]]; then
    echo "ERROR: MY_VENV_PIP=[${MY_VENV_PIP}] is not an executable file."
    exit 1
  fi

  # Setup script for evemu-event mouse control permissions
  # Works immediately without reboot or logout

  echo "Setting up wayland-mcp dependencies and permissions..."

  # 1. Install required packages
  install_if_missing evemu evemu-event

  # Install a screenshot tool if none of the supported ones are available.
  local screenshot_tools=(gnome-screenshot grim ksnip spectacle)
  local has_screenshot_tool=false
  for tool in "${screenshot_tools[@]}"; do
    if command -v "${tool}" > /dev/null 2>&1; then
      echo "Screenshot tool already available: ${tool}"
      has_screenshot_tool=true
      break
    fi
  done
  if [[ "${has_screenshot_tool}" == "false" ]]; then
    install_if_missing gnome-screenshot gnome-screenshot
  fi

  # 2. Immediate solution (current session) for evemu-event
  echo "Setting setuid bit for evemu-event (current session)..."
  if [ -f /usr/bin/evemu-event ]; then
    sudo chmod u+s /usr/bin/evemu-event
  fi

  # 3. Permanent solution (future sessions) for evemu-event
  echo "Configuring sudoers rule for evemu-event..."
  echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/evemu-event" | sudo tee /etc/sudoers.d/evemu-event >/dev/null
  sudo chmod 440 /etc/sudoers.d/evemu-event

  # 4. Verify setup
  echo -e "\nVerification:"
  ls -la /usr/bin/evemu-event | grep -q 'rws' && echo "evemu-event Setuid OK" || echo "evemu-event Setuid FAILED"
  sudo -l | grep -q 'NOPASSWD.*evemu-event' && echo "evemu-event Sudoers OK" || echo "evemu-event Sudoers FAILED"

  echo -e "\nSetup complete! You can now use evemu-event without sudo."
  echo "Both current and future sessions are configured."

  # 5. Add user to input group for persistent access
  echo "Adding $USER to input group..."
  sudo usermod -aG input $USER

  # 6. Immediate keyboard device access
  echo "Temporarily making input devices writable..."
  for dev in /dev/input/event*; do
      sudo chmod 666 $dev 2>/dev/null
  done

  # 7. Persistent udev rule for keyboard access
  echo "Creating udev rule for keyboard access..."
  UDEV_RULE="KERNEL==\"event*\", GROUP=\"input\", MODE=\"0666\""
  echo $UDEV_RULE | sudo tee /etc/udev/rules.d/99-input.rules >/dev/null
  sudo udevadm control --reload-rules
  sudo udevadm trigger

  echo -e "\nKeyboard setup complete!"

  # 8. Install wayland-mcp into the virtual environment
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "Installing wayland-mcp into venv using MY_VENV_PIP=[${MY_VENV_PIP}]..."
  mkdir -p "${script_dir}/.tmp/"
  "${MY_VENV_PIP}" install -e "${script_dir}" > "${script_dir}/.tmp/pip_install.log" 2>&1
  if [[ $? -ne 0 ]]; then
    echo "ERROR: pip install failed. See .tmp/pip_install.log for details."
    exit 1
  fi
  echo "wayland-mcp installed successfully into venv."

  # 9. Verify wayland-mcp is importable
  echo "Verifying wayland-mcp installation..."
  "${MY_VENV_PYTHON_BIN}" -c "from wayland_mcp.mouse_utils import MouseController; m = MouseController(); print(f'Mouse device: {m.device}')" && echo "Mouse verification OK" || echo "Mouse verification FAILED (may need input devices available)"
  "${MY_VENV_PYTHON_BIN}" -c "from wayland_mcp.keyboard_utils import KeyboardController; k = KeyboardController(); print(f'Keyboard device: {k.device}')" && echo "Keyboard verification OK" || echo "Keyboard verification FAILED (may need input devices available)"

  # 10. Generate .claude/mcp.json in this directory
  echo ""
  echo "Generating .claude/mcp.json..."
  "${script_dir}/setup_mcp_config.sh"

  echo ""
  echo "Setup complete!"
  echo ""
  echo "To use wayland-mcp, start Claude Code from this directory:"
  echo "  cd ${script_dir} && claude"
}

main "${@}"
