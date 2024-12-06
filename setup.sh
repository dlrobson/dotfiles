#!/bin/bash
set -x

# Helper function to determine if a command exists
command_exists() {
	command -v "$@" > /dev/null 2>&1
}

# Helper function to get the sudo command
get_sudo_su() {
  local user="$(id -un 2>/dev/null || true)"
  local sh_c="sh -c"

  if [ "$user" != "root" ]; then
    if command_exists sudo; then
      sh_c="sudo -E sh -c"
    elif command_exists su; then
      sh_c="su -c"
    else
      echo "Warning: This user does not have root access. This script will not be able to install packages."
      return 1
    fi
  fi

  echo "$sh_c"
}

DEFAULT_PACKAGES="stow git ca-certificates curl zsh tmux xsel"

# Installs dependencies
install_dependencies() {
  echo "Installing dependencies..."

  # The list of packages to install
  local pkgs="$@"

  # Get the sudo command
  local sh_c
  sh_c="$(get_sudo_su)"
  if [ $? -ne 0 ]; then
    return 1
  fi

  # Install the packages. Only supports apt for now
  $sh_c "apt-get update -qq >/dev/null"
  $sh_c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $pkgs >/dev/null"
}

dotfile_setup() {
  local dotfiles_path="$1"

  # If zgenom is not installed, install it
  if [ ! -d ~/.zgenom ]; then
    git clone https://github.com/jandamm/zgenom.git "${HOME}/.zgenom"
  fi
  
  # Determine the base directory and the directory containing stow packages
  local stow_dir="$dotfiles_path/stow"

  # This for loop iterates through all directories
  # contained in the stow directory. This makes
  # it easy to add configurations for new applications
  # without having to modify this script.
  for app in "$stow_dir"/*/; do
    local app_name=$(basename "$app")
    stow -t "${HOME}" -d "$stow_dir" "$app_name"
  done;


    # This sources the zshrc file and then exits
    echo exit | script -qec zsh /dev/null && \
    # Start a new tmux session in detached mode, source the tmux configuration
    # file, and then kill the server. 
    # `tmux new-session -d -s tmp` starts a new tmux session in detached mode
    # (i.e., not visible to the user) with the name 'tmp'.
    # `"tmux source-file ~/.tmux.conf; tmux kill-server"` is the command that is
    # run in the new tmux session.
    # `tmux source-file ~/.tmux.conf` sources (loads) the tmux configuration file.
    # `tmux kill-server` then kills the tmux server, ending the session.
    # This sequence is used to ensure that the tmux configuration file is correctly
    # loaded in a tmux session environment.
    tmux new-session -d -s tmp "tmux source-file ~/.tmux.conf; tmux kill-server"
}

# Function to setup kmonad
kmonad_setup() {
  echo "Setting up the kmonad service. This assumes the setup.sh script was run already."

  # Checks for the kmonad command to exist. If not, error:
  if ! command_exists kmonad; then
    echo "`kmonad` is not installed. Please install it and make it accessible on your PATH."
  fi

  set -x

  # Reload systemd to recognize the new service
  systemctl --user daemon-reload

  # Enable the service to start on login
  systemctl --user enable kmonad-mapping.service

  # Start the service immediately
  systemctl --user start kmonad-mapping.service

  set +x

  echo "Kmonad service has been set up."
  echo "To verify the status of the service, use: systemctl --user status kmonad-mapping.service"
  echo "To disable the service, use: systemctl --user disable kmonad-mapping.service"
}

# Function to install kmonad
kmonad_installation() {
  # Check if kmonad is already installed
  if command_exists kmonad; then
    echo "Kmonad is already installed."
    return 0
  fi

  echo "Installing kmonad..."

  # Get the sudo command
  local sh_c
  sh_c="$(get_sudo_su)"
  if [ $? -ne 0 ]; then
    return 1
  fi

  # Create the directory if it doesn't exist
  mkdir -p ~/.local/bin

  # Download kmonad binary
  wget -O ~/.local/bin/kmonad https://github.com/kmonad/kmonad/releases/download/0.4.2/kmonad

  # Make the binary executable
  chmod +x ~/.local/bin/kmonad

  # Create the uinput group if it doesn't exist
  $sh_c "groupadd uinput"

  # Add the current user to the input and uinput groups
  $sh_c "usermod -aG input $(whoami)"
  $sh_c "usermod -aG uinput $(whoami)"

  # Create the udev rules file
  $sh_c "echo \"KERNEL==\\\"uinput\\\", MODE=\\\"0660\\\", GROUP=\\\"uinput\\\", OPTIONS+=\\\"static_node=uinput\\\"\" |  tee /etc/udev/rules.d/90-kmonad.rules"

  # Load the uinput kernel module
  $sh_c "modprobe uinput"

  echo "Kmonad installation complete."
}

# Function to display help message
show_help() {
  echo "Usage: $0 [options]"
  echo
  echo "Options:"
  echo "  -k, --kmonad                Setup the kmonad systemd service for custom keyboard mapping"
  echo "  -h, --help                  Show this help message"
  echo
  echo "If no options are provided, the script will install dependencies and set up dotfiles by default."
}

main() {
  echo "Setting up dotfiles..."
  # Capture this before we shift the arguments
  local dotfiles_path="$(dirname "$(readlink -f "$0")")"

  # By default, only install dependencies and setup the dotfiles.
  if [ $# -eq 0 ]; then
    install_dependencies $DEFAULT_PACKAGES
    dotfile_setup "$dotfiles_path"
  else
    # Parse command line options
    while [ $# -gt 0 ]; do
      case $1 in
        -k|--kmonad)
          kmonad_setup
          shift
          ;;
        -h|--help)
          show_help
          exit 0
          ;;
        *)
          echo "Unknown option: $key"
          exit 1
          ;;
      esac
    done
  fi
}

main "$@"
