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
    nix-instantiate --eval --raw -E "\"\${(import $REPO_ROOT/pins.nix).$1}\""
}

# Pins other than `nixpkgs` are fixed-output derivations (see `pins.nix`), which
# evaluating a path does not build; realise one so a garbage-collected path is
# substituted or re-fetched.
_realise_pin() {
    nix-build -E "(import $REPO_ROOT/pins.nix).$1" --no-out-link >/dev/null
}

# `coverage` is a test fixture, not a deployment target.
_list_profiles() {
    for f in "$REPO_ROOT/profiles/"*.nix; do
        name="$(basename "$f" .nix)"
        [ "$name" = coverage ] || echo "  $name"
    done
}

_build_home_manager() {
    local hm_out
    _realise_pin home-manager
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

check_userns_restriction() {
    local sysctl_path="/proc/sys/kernel/apparmor_restrict_unprivileged_userns"
    local value

    [ -f "$sysctl_path" ] || return 0
    value="$(cat "$sysctl_path" 2>/dev/null || true)"
    [ "$value" = "1" ] || return 0

    cat <<'EOF'

WARNING: Unprivileged user namespaces are restricted on this machine
(kernel.apparmor_restrict_unprivileged_userns=1). This breaks any
unprivileged sandboxing tool built on bwrap/unshare - e.g. some
browser/Flatpak/Snap sandboxes - with errors like:
    bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted

To fix it:
    sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0

Make it persist across reboots:
    echo 'kernel.apparmor_restrict_unprivileged_userns=0' | sudo tee /etc/sysctl.d/99-userns.conf

Implications: any unprivileged local process can create user/network/mount
namespaces. This is the attack surface Ubuntu's restriction (added ~23.10)
was added to close, since unprivileged user namespaces have been a
recurring privilege-escalation vector. Reasonable on a single-user machine
that doesn't run untrusted code; revert anytime by setting the same value
back to 1.

EOF
}

deploy() {
    local profile="$1"
    local dry_run_flag="$2"
    local profile_file="$REPO_ROOT/profiles/${profile}.nix"
    local hm_bin

    if [ "$profile" = coverage ] || [ ! -f "$profile_file" ]; then
        echo "Error: unknown profile: $profile"
        echo "Available profiles:"
        _list_profiles
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
                _list_profiles
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

    check_userns_restriction

    echo "Configuration for '$PROFILE' deployed. Ensure fish or bash is your default shell."
}

main "$@"
