#!/bin/sh
set -eu

# Private helper functions
_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

_install_packages() {
    packages="$1"

    if _command_exists apt; then
        echo "Installing packages: $packages"
        DEBIAN_FRONTEND=noninteractive sudo -E apt-get -qq update
        DEBIAN_FRONTEND=noninteractive sudo -E apt -y install $packages
        return 0
    fi

    echo "No supported package manager found. Please install packages manually."
    return 1
}

_is_in_container() {
    # Check for .dockerenv file
    [ -f "/.dockerenv" ] && return 0
    # Check for docker in cgroup
    grep -q docker /proc/1/cgroup 2>/dev/null && return 0
    return 1
}

_install_nix_single_user() {
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

_install_nix_multi_user() {
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

# Public functions called by main
install_required_packages() {
    REQUIRED_COMMANDS=""
    REQUIRED_PACKAGES=""

    # Add nix dependencies if needed
    if ! _command_exists nix; then
        REQUIRED_COMMANDS="$REQUIRED_COMMANDS curl xz"
        REQUIRED_PACKAGES="$REQUIRED_PACKAGES curl xz-utils"
    fi

    # Install dependencies if needed
    missing_commands=""
    for cmd in $REQUIRED_COMMANDS; do
        if ! _command_exists "$cmd"; then
            missing_commands="$missing_commands $cmd"
        fi
    done

    if [ -n "$missing_commands" ]; then
        echo "Missing commands: $missing_commands"
        if ! _install_packages "$REQUIRED_PACKAGES"; then
            echo "Failed to install required packages: $REQUIRED_PACKAGES"
            return 1
        fi
    fi

    return 0
}

install_nix() {
    if _command_exists nix; then
        echo "Nix is already installed."
        return 0
    fi

    if _is_in_container; then
        echo "Container environment detected. Installing Nix in single-user mode..."
        if ! _install_nix_single_user; then
            echo "Error: Failed to install Nix in single-user mode"
            return 1
        fi
    else
        echo "Non-container environment detected. Installing Nix in multi-user mode..."
        if ! _install_nix_multi_user; then
            echo "Error: Failed to install Nix in multi-user mode"
            return 1
        fi
    fi

    # Validate installation
    if ! _command_exists nix; then
        echo "Error: Nix installation failed"
        return 1
    fi

    return 0
}

install_home_manager() {
    if _command_exists home-manager; then
        echo "home-manager is already installed."
        return 0
    fi

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
    if ! _command_exists home-manager; then
        echo "Error: home-manager installation failed"
        return 1
    fi

    return 0
}

deploy_home_manager() {
    echo "Deploying home-manager configuration..."
    SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
    
    # Deploy home-manager configuration. Replace conflicting files with .backup
    if ! home-manager switch -f "$SCRIPT_DIR/home.nix"; then
    # if ! home-manager switch -b backup -f "$SCRIPT_DIR/home.nix"; then
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

    if ! deploy_home_manager; then
        echo "Failed to deploy home-manager"
        exit 1
    fi
    
    echo "Home-manager setup and configuration complete!"
}

main
