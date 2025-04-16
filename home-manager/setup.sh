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
            return 1
        fi
    fi

    return 0
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
        return 1
    fi

    # Load Nix environment
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"

    return 0
}

install_nix_multi_user() {
    echo "Installing Nix (multi-user mode)..."
    
    # Install Nix in multi-user mode
    curl -L https://nixos.org/nix/install | sh -s -- --daemon

    # Source nix profile
    if [ ! -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        echo "Error: Nix profile script not found"
        return 1
    fi

    # Load Nix environment
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    return 0
}

install_nix() {
    if command_exists nix; then
        echo "Nix is already installed."
        return 0
    fi

    if is_systemd_available; then
        echo "Systemd is available. Installing Nix in multi-user mode..."
        echo "ERROR: Nix installation is untested in multi-user mode. Cannot continue."
        return 1
    else
        if ! install_nix_single_user; then
            echo "Error: Failed to install Nix in single-user mode"
            return 1
        fi
    fi

    # Validate installation
    if ! command_exists nix; then
        echo "Error: Nix installation failed"
        return 1
    fi

    return 0
}

install_home_manager() {
    echo "Installing home-manager..."
    if ! nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager; then
        echo "Error: Failed to add home-manager channel"
        return 1
    fi

    if ! nix-channel --update; then
        echo "Error: Failed to update channels"
        return 1
    fi

    # Install home-manager
    if ! nix-shell '<home-manager>' -A install; then
        echo "Error: Failed to install home-manager"
        return 1
    fi

    # Validate installation
    if ! command_exists home-manager; then
        echo "Error: home-manager installation failed"
        return 1
    fi

    return 0
}

configure_home_manager() {
    echo "Configuring home-manager..."
    SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
    
    # Deploy home-manager configuration. Replace conflicting files with .backup
    if ! home-manager switch -b backup -f "$SCRIPT_DIR/home.nix"; then
        echo "Error: Failed to apply home-manager configuration"
        return 1
    fi
    
    return 0
}

main() {
    if ! install_required_packages; then
        echo "Failed to install required packages"
        exit 1
    fi

    if ! install_nix; then
        echo "Failed to install Nix"
        exit 1
    fi

    if ! install_home_manager; then
        echo "Failed to install home-manager"
        exit 1
    fi

    if ! configure_home_manager; then
        echo "Failed to configure home-manager"
        exit 1
    fi
    
    echo "Home-manager setup and configuration complete!"
}

main
