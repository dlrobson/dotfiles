#!/bin/sh
set -eu

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

install_packages() {
    packages="$1"

    if command_exists apt; then
        echo "Installing packages: $packages"
        DEBIAN_FRONTEND=noninteractive sudo -E apt-get -qq update
        DEBIAN_FRONTEND=noninteractive sudo -E apt -y install $packages
        return 0
    fi

    echo "No supported package manager found. Please install packages manually."
    return 1
}

is_systemd_available() {
    # Check if systemd is available and running
    [ -d "/run/systemd/system" ] && command_exists systemctl
}

install_nix_single_user() {
    echo "Installing Nix (single-user mode)..."
    
    # Create and configure /nix directory
    sudo mkdir -p /nix && sudo chown "$(whoami)" /nix

    # Install Nix in single-user mode
    curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

    # Source nix profile
    if [ ! -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        echo "Error: Nix profile script not found"
        exit 1
    fi

    # Load Nix environment
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
}

install_nix_multi_user() {
    echo "Installing Nix (multi-user mode)..."
    
    # Install Nix in multi-user mode
    curl -L https://nixos.org/nix/install | sh -s -- --daemon

    # Source nix profile
    if [ ! -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        echo "Error: Nix profile script not found"
        exit 1
    fi

    # Load Nix environment
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
}

install_nix() {
    if command_exists nix; then
        echo "Nix is already installed."
        return 0
    fi

    if is_systemd_available; then
        echo "Systemd is available. Installing Nix in multi-user mode..."
        echo "ERROR: Nix installation is untested in multi-user mode."
        echo "Defaulting to single-user mode."
        install_nix_single_user
        # install_nix_multi_user
    else
        install_nix_single_user
    fi

    # Validate installation
    if ! command_exists nix; then
        echo "Error: Nix installation failed"
        exit 1
    fi
}

install_home_manager() {
    echo "Installing home-manager..."
    nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
    nix-channel --update

    # Install home-manager
    nix-shell '<home-manager>' -A install

    # Validate installation
    if ! command_exists home-manager; then
        echo "Error: home-manager installation failed"
        exit 1
    fi
}

install_required_packages() {
    REQUIRED_COMMANDS=""
    REQUIRED_PACKAGES=""

    # Add nix dependencies if needed
    if ! command_exists nix; then
        REQUIRED_COMMANDS="$REQUIRED_COMMANDS curl xz"
        REQUIRED_PACKAGES="$REQUIRED_PACKAGES curl xz-utils"
    fi

    # Install dependencies if needed
    missing_commands=""
    for cmd in $REQUIRED_COMMANDS; do
        if ! command_exists "$cmd"; then
            missing_commands="$missing_commands $cmd"
        fi
    done

    if [ -n "$missing_commands" ]; then
        echo "Missing commands: $missing_commands"
        if ! install_packages "$REQUIRED_PACKAGES"; then
            echo "Failed to install required packages: $REQUIRED_PACKAGES"
            exit 1
        fi
    fi
}

main() {
    install_required_packages
    install_nix
    install_home_manager
}

# Run the script
main "$@"
