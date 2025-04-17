#!/bin/bash
set -eu

# Helper function to determine if a command exists
command_exists() {
  command -v "$@" > /dev/null 2>&1
}

# Helper function to get the sudo command
get_sudo() {
  local user="$(id -un 2>/dev/null || true)"
  
  if [ "$user" != "root" ]; then
    if command_exists sudo; then
      echo "sudo -E"
    elif command_exists su; then
      echo "su -c"
    else
      echo "ERROR: This script requires root privileges to set up udev rules and user groups."
      exit 1
    fi
  fi
}

# Check for KMonad installation
if ! command_exists kmonad; then
  echo "ERROR: KMonad is not installed. Please run home-manager switch first."
  exit 1
fi

echo "Setting up KMonad system requirements..."

# Get sudo command
SUDO=$(get_sudo)

# Create uinput group if it doesn't exist
if ! getent group uinput > /dev/null; then
  echo "Creating uinput group..."
  $SUDO groupadd uinput
fi

# Add the current user to input and uinput groups
echo "Adding user to input and uinput groups..."
$SUDO usermod -aG input "$(whoami)"
$SUDO usermod -aG uinput "$(whoami)"

# Create udev rule for uinput if it doesn't exist
if [ ! -f /etc/udev/rules.d/90-kmonad.rules ]; then
  echo "Creating udev rule for uinput..."
  echo 'KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"' | \
    $SUDO tee /etc/udev/rules.d/90-kmonad.rules > /dev/null
fi

# Load uinput kernel module
if ! lsmod | grep -q uinput; then
  echo "Loading uinput kernel module..."
  $SUDO modprobe uinput
fi

# Add uinput module to /etc/modules for persistence
if ! grep -q uinput /etc/modules 2>/dev/null; then
  echo "Adding uinput to /etc/modules for persistence..."
  echo "uinput" | $SUDO tee -a /etc/modules > /dev/null
fi

# Reload udev rules
echo "Reloading udev rules..."
$SUDO udevadm control --reload-rules
$SUDO udevadm trigger

# Enable and start the KMonad service
echo "Enabling and starting KMonad service..."
systemctl --user enable kmonad-mapping.service
systemctl --user start kmonad-mapping.service

echo "KMonad setup complete!"
echo ""
echo "NOTE: You may need to log out and log back in for group changes to take effect."
echo "To check the status of the service, run: systemctl --user status kmonad-mapping.service"
echo "To stop the service, run: systemctl --user stop kmonad-mapping.service"
echo "To disable the service, run: systemctl --user disable kmonad-mapping.service"