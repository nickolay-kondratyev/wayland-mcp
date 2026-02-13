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

  # Setup script for evemu-event mouse control permissions
  # Works immediately without reboot or logout

  echo "Setting up wayland-mcp dependencies and permissions..."

  # 1. Install required packages
  install_if_missing evemu evemu-event
  install_if_missing gnome-screenshot gnome-screenshot

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
}

main "${@}"
