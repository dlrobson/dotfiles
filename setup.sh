#!/bin/sh

# Helper function to determine if a command exists
command_exists() {
	command -v "$@" > /dev/null 2>&1
}

# Installs dependencies
install_dependencies() {
  echo "Installing dependencies..."

  # The list of packages to install
  pkgs="stow git ca-certificates curl zsh tmux xsel"

  # Grab the user, and determine if they can run sudo commands
  user="$(id -un 2>/dev/null || true)"

	sh_c='sh -c'
	if [ "$user" != 'root' ]; then
		if command_exists sudo; then
			sh_c='sudo -E sh -c'
		elif command_exists su; then
			sh_c='su -c'
		else
      echo "Warning: This user does not have root access. This script will not be able to install packages."
			return
		fi
	fi

  # Install the packages. Only supports apt for now
  $sh_c 'apt-get update -qq >/dev/null'
  $sh_c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $pkgs >/dev/null"
}

dotfile_setup() {
  # If zgenom is not installed, install it
  if [ ! -d ~/.zgenom ]; then
    git clone https://github.com/jandamm/zgenom.git "${HOME}/.zgenom"
  fi
  
  # Determine the base directory and the directory containing stow packages
  stow_dir="$(dirname "$(readlink -f "$0")")/stow"

  # This for loop iterates through all directories
  # contained in the stow directory. This makes
  # it easy to add configurations for new applications
  # without having to modify this script.
  for app in "$stow_dir"/*/; do
    app_name=$(basename "$app")
    stow -t "${HOME}" -d "$stow_dir" "$app_name"
  done;
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

echo "Setting up dotfiles..."

# Function to display help message
show_help() {
  echo "Usage: $0 [options]"
  echo
  echo "Options:"
  echo "  -k, --kmonad                Setup the kmonad systemd service for custom keyboard mapping"
  echo "  -i, --install-dependencies  Install required dependencies"
  echo "  -d, --dotfile-setup-only    Set up dotfiles only"
  echo "  -h, --help                  Show this help message"
  echo
  echo "If no options are provided, the script will install dependencies and set up dotfiles by default."
}

# By default, only install dependencies and setup the dotfiles.
if [ $# -eq 0 ]; then
  install_dependencies
  dotfile_setup
else
  # Parse command line options
  while [ $# -gt 0 ]; do
    case $1 in
      -k|--kmonad)
        kmonad_setup
        shift
        ;;
      -i|--install-dependencies)
        install_dependencies
        shift
        ;;
      -d|--dotfile-setup-only)
        dotfile_setup
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
