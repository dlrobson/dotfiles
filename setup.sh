#!/bin/sh
set -eu

# Private helper functions
_command_exists() {
    command -v "$1" >/dev/null 2>&1
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
    if ! home-manager switch -b backup -f "$SCRIPT_DIR/home.nix"; then
        echo "Error: Failed to apply home-manager configuration"
        return 1
    fi
    
    return 0
}

check_default_shell() {
    if ! _command_exists fish; then
        echo "Note: Fish shell is not installed. This configuration includes Fish shell settings."
        echo "Consider installing Fish and setting it as your default shell:"
        echo "    chsh -s \$(which fish)"
        return 0
    fi
    
    current_shell=$(getent passwd "$USER" | cut -d: -f7)
    fish_path="$(which fish)"
    
    if [ "$current_shell" != "$fish_path" ]; then
        echo "Note: Fish is installed but not set as your default shell."
        echo "To make fish your default shell, run:"
        echo "    chsh -s $fish_path"
    fi
    
    return 0
}

main() {
    # Early check for Nix
    if ! _command_exists nix; then
        echo "Error: Nix is required but not installed."
        echo "Please install Nix first: https://nixos.org/download.html"
        echo "After installing Nix, run this script again."
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
    
    check_default_shell
    
    echo "Home-manager setup and configuration complete!"
}

main
