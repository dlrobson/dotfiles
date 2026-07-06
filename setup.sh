#!/bin/sh
set -eu

# Global variables
PROFILE=""
DRY_RUN=""
REPO_ROOT="${REPO_ROOT:-}"

_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

_npins_path() {
    nix-instantiate --eval -E "(import $REPO_ROOT/npins).$1.outPath" | tr -d '"'
}

_build_home_manager() {
    local hm_out
    if ! hm_out=$(nix-build "$(_npins_path home-manager)" -A home-manager -I "nixpkgs=$(_npins_path nixpkgs)" --no-out-link); then
        echo "Error: Failed to build home-manager" >&2
        return 1
    fi

    echo "$hm_out/bin/home-manager"
}

fix_sandbox_permissions() {
    fixed=0
    for sandbox in $(find $(nix-store -q --requisites ~/.nix-profile 2>/dev/null) -name "chrome-sandbox" 2>/dev/null); do
        if ! stat -c "%U %a" "$sandbox" 2>/dev/null | grep -q "^root 4755$"; then
            sudo chown root:root "$sandbox" && sudo chmod 4755 "$sandbox"
            echo "Fixed sandbox: $sandbox"
            fixed=$((fixed + 1))
        fi
    done

    if [ "$fixed" -gt 0 ]; then
        echo "Fixed $fixed chrome-sandbox file(s)."
    fi
}

deploy() {
    local profile="$1"
    local dry_run_flag="$2"
    local profile_file="$REPO_ROOT/profiles/${profile}.nix"
    local hm_bin

    if [ ! -f "$profile_file" ]; then
        echo "Error: unknown profile: $profile"
        echo "Available profiles:"
        for f in "$REPO_ROOT/profiles/"*.nix; do
            echo "  $(basename "$f" .nix)"
        done
        return 1
    fi

    echo "Building home-manager..."
    if ! hm_bin="$(_build_home_manager)"; then
        return 1
    fi

    echo "Deploying configuration for: $profile"

    local hm_cmd="$hm_bin switch -b backup -f $profile_file -I home-manager=$(_npins_path home-manager) -I nixpkgs=$(_npins_path nixpkgs)"
    if [ -n "$dry_run_flag" ]; then
        hm_cmd="$hm_cmd -n"
        echo "Running in dry-run mode - no changes will be applied"
    fi

    if ! $hm_cmd; then
        echo "Error: Failed to apply configuration"
        return 1
    fi

    return 0
}

parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run)
                DRY_RUN=1
                ;;
            --help)
                echo "Usage: $0 <profile> [OPTIONS]"
                echo
                echo "Profiles:"
                for f in "$REPO_ROOT/profiles/"*.nix; do
                    echo "  $(basename "$f" .nix)"
                done
                echo
                echo "Options:"
                echo "  --dry-run   Run in dry-run mode (no changes applied)"
                echo "  --help      Show this help message"
                exit 0
                ;;
            -*)
                echo "Error: Unknown option $1"
                exit 1
                ;;
            *)
                if [ -n "$PROFILE" ]; then
                    echo "Error: multiple profiles specified"
                    exit 1
                fi
                PROFILE="$1"
                ;;
        esac
        shift
    done

    if [ -z "$PROFILE" ]; then
        echo "Error: profile name required"
        echo "Run '$0 --help' for usage"
        exit 1
    fi
}

main() {
    REPO_ROOT="${REPO_ROOT:-$(dirname "$(readlink -f "$0")")}"
    parse_arguments "$@"

    if ! _command_exists nix; then
        echo "Error: Nix is required but not installed."
        echo "Please install Nix first: https://nixos.org/download.html"
        exit 1
    fi

    if ! deploy "$PROFILE" "$DRY_RUN"; then
        echo "Failed to deploy configuration"
        exit 1
    fi

    if [ -z "$DRY_RUN" ]; then
        fix_sandbox_permissions
    fi

    echo "Configuration for '$PROFILE' deployed. Ensure fish or bash is your default shell."
}

main "$@"
