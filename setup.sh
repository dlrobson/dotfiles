#!/bin/sh

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
  # This script sets up symlinks to all the dotfiles
  # in the user's home directory. Set base to be the location of this
  # script, and it will set up all the symlinks
  base=$(dirname $(readlink -f $0))

  # If zgenom is not installed, install it
  if [ ! -d ~/.zgenom ]; then
    git clone https://github.com/jandamm/zgenom.git "${HOME}/.zgenom"
  fi

  # Set up all of the configs:
  cd ${base}/stow

  # This for loop iterates through all directories
  # contained in the stow directory. This makes
  # it easy to add configurations for new applications
  # without having to modify this script.
  for app in */; do
    stow -t ${HOME} $app
  done;
}

# Function to setup kmonad
kmonad_setup() {
  echo "Setting up kmonad..."
  # Add your kmonad setup code here
}

echo "Setting up dotfiles..."
install_dependencies
dotfile_setup

# Parse command line options
if [ $# -eq 0 ]; then
  install_dependencies
  dotfile_setup
else
  # Parse command line options
  while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
      -k|--kmonad)
        kmonad_setup
        shift
        ;;
      -i|--install-dependencies)
        install_dependencies
        shift
        ;;
      *)
        echo "Unknown option: $key"
        exit 1
        ;;
    esac

    shift
  done
fi
