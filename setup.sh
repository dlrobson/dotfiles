#!/bin/sh
set -eu

# Constants
PROFILE_MINIMAL="minimal"
PROFILE_DESKTOP="desktop"

# Global variables
PROFILE="$PROFILE_MINIMAL"
DRY_RUN=""
REPO_ROOT=""

# Private helper functions
_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

_npins_path() {
    nix-instantiate --eval -E "(import $REPO_ROOT/npins).$1.outPath" | tr -d '"'
}

install_home_manager() {
    if _command_exists home-manager; then
        echo "home-manager is already installed."
        return 0
    fi

    echo "Installing home-manager..."

    if ! nix-env -iA home-manager -f "$(_npins_path home-manager)" -I "nixpkgs=$(_npins_path nixpkgs)"; then
        echo "Error: Failed to install home-manager"
        return 1
    fi

    if ! _command_exists home-manager; then
        echo "Error: home-manager installation failed"
        return 1
    fi

    return 0
}

deploy_home_manager() {
    local profile="$1"
    local dry_run_flag="$2"

    echo "Deploying home-manager configuration..."

    # Set message based on profile
    case "$profile" in
        "$PROFILE_MINIMAL")
            echo "Using minimal profile (CLI tools only)"
            ;;
        "$PROFILE_DESKTOP")
            echo "Using desktop profile (includes GUI applications)"
            ;;
    esac

    # Prepare home-manager command with optional dry-run flag
    local hm_cmd="home-manager switch -b backup -f $REPO_ROOT/profiles/$profile.nix -I home-manager=$(_npins_path home-manager) -I nixpkgs=$(_npins_path nixpkgs)"
    if [ -n "$dry_run_flag" ]; then
        hm_cmd="$hm_cmd -n"
        echo "Running in dry-run mode - no changes will be applied"
    fi

    if ! $hm_cmd; then
        echo "Error: Failed to apply home-manager configuration"
        return 1
    fi

    return 0
}

parse_arguments() {
    # Parse command line arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            "--$PROFILE_MINIMAL")
                echo "Using $PROFILE_MINIMAL profile (CLI tools only)"
                PROFILE="$PROFILE_MINIMAL"
                ;;
            "--$PROFILE_DESKTOP")
                echo "Using $PROFILE_DESKTOP profile (includes GUI applications)"
                PROFILE="$PROFILE_DESKTOP"
                ;;
            --dry-run)
                echo "Enabling dry-run mode"
                DRY_RUN=1
                ;;
            --help)
                echo "Usage: $0 [PROFILE] [OPTIONS]"
                echo
                echo "Profiles:"
                echo "  --$PROFILE_MINIMAL         Minimal configuration with CLI tools only (default)"
                echo "  --$PROFILE_DESKTOP         Desktop configuration with GUI applications"
                echo
                echo "Options:"
                echo "  --dry-run         Run in dry-run mode (no changes will be applied)"
                echo "  --help            Show this help message"
                exit 0
                ;;
            *)
                echo "Error: Unknown option $1"
                exit 1
                ;;
        esac
        shift
    done
}

main() {
    REPO_ROOT=$(dirname "$(readlink -f "$0")")

    # Parse arguments and set global variables
    parse_arguments "$@"

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

    if ! deploy_home_manager "$PROFILE" "$DRY_RUN"; then
        echo "Failed to deploy home-manager"
        exit 1
    fi

    echo "Home-manager setup and configuration complete! Please ensure either bash or fish is your default shell."
}

# Call main with all script arguments
main "$@"
