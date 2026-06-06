# Ouster Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strip all ouster-specific config from the public `dotfiles` repo and create a new private `ouster-dotfiles` repo that imports the public repo as a pinned npins dependency.

**Architecture:** Public repo gets two new stable entry points (`profiles/minimal.nix`, `profiles/desktop.nix`) that replace the runtime profile system. Private repo pins the public repo via npins and composes machine-specific profiles on top.

**Tech Stack:** Nix, home-manager, npins, bash

---

## File Map

### Public repo (`~/dev/dotfiles`)

| Action | File | Change |
|--------|------|--------|
| Create | `profiles/minimal.nix` | New entry point for minimal profile |
| Create | `profiles/desktop.nix` | New entry point for desktop profile |
| Modify | `setup.sh` | Remove `--ouster`, point to `profiles/` |
| Modify | `shell.nix` | Remove ouster from run-tests, use profiles/ |
| Delete | `home.nix` | Replaced by profiles/ |
| Modify | `home/programs/packages.nix` | Remove work-vpn-client, slack, copilot-marketplace service |
| Modify | `home/programs/git.nix` | Remove ouster ignore file + git include |
| Modify | `home/default.nix` | Remove "ouster" from desktop enable check |
| Modify | `modules/common/constants.nix` | Remove ouster profile |

### Private repo (new, at `~/dev/ouster-dotfiles`)

| Action | File | Purpose |
|--------|------|---------|
| Create | `npins/` | Pins for nixpkgs, home-manager, dotfiles |
| Create | `profiles/nixos-server.nix` | Headless ouster machine profile |
| Create | `modules/git.nix` | Ouster git identity + ignore rules |
| Create | `modules/copilot-marketplace.nix` | Copilot CLI plugin management service |
| Create | `shell.nix` | Dev shell with home-manager |
| Create | `setup.sh` | Machine-name based deploy script |

---

## Part 1: Public Repo

### Task 1: Add `profiles/minimal.nix` and `profiles/desktop.nix`

**Files:**
- Create: `profiles/minimal.nix`
- Create: `profiles/desktop.nix`

These replace `home.nix` as entry points. Each reads `USER`/`HOME` from env and enables the appropriate profile via the existing `home-manager-configuration` option system.

- [ ] **Step 1: Create `profiles/minimal.nix`**

```nix
{
  config,
  pkgs,
  lib,
  ...
}:

let
  homeDirectory = builtins.getEnv "HOME";
  username = builtins.getEnv "USER";
in
{
  imports = [ ../home ];

  home-manager-configuration = {
    enable = true;
    profile = "minimal";
    inherit username homeDirectory;
  };

  nixpkgs.config.allowUnfree = true;
}
```

- [ ] **Step 2: Create `profiles/desktop.nix`**

```nix
{
  config,
  pkgs,
  lib,
  ...
}:

let
  homeDirectory = builtins.getEnv "HOME";
  username = builtins.getEnv "USER";
in
{
  imports = [ ../home ];

  home-manager-configuration = {
    enable = true;
    profile = "desktop";
    inherit username homeDirectory;
  };

  nixpkgs.config.allowUnfree = true;
}
```

- [ ] **Step 3: Verify both profiles build**

```bash
cd ~/dev/dotfiles
nix-shell shell.nix --run "USER=$(id -un) home-manager build -f profiles/minimal.nix"
nix-shell shell.nix --run "USER=$(id -un) home-manager build -f profiles/desktop.nix"
```

Expected: both complete without error.

- [ ] **Step 4: Commit**

```bash
git add profiles/
git commit -m "feat: add profiles/minimal.nix and profiles/desktop.nix entry points"
```

---

### Task 2: Update `setup.sh` and `shell.nix` to use profiles/

**Files:**
- Modify: `setup.sh`
- Modify: `shell.nix`
- Delete: `home.nix`

- [ ] **Step 1: Update `deploy_home_manager` in `setup.sh` to use profiles/**

In `setup.sh`, change `deploy_home_manager` so it points to the profile file instead of `home.nix`, and drops the `ROBSON_HOME_PROFILE` env var:

```bash
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
```

- [ ] **Step 2: Remove `PROFILE_OUSTER` and `--ouster` from `setup.sh`**

Replace the constants block and `parse_arguments`:

```bash
# Constants
PROFILE_MINIMAL="minimal"
PROFILE_DESKTOP="desktop"
```

Replace `parse_arguments` (remove the `--ouster` case and update `--help`):

```bash
parse_arguments() {
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
```

- [ ] **Step 3: Update `run-tests` in `shell.nix` to use profiles/**

Replace the `run-tests` block:

```nix
  run-tests = pkgs.writeShellApplication {
    name = "run-tests";
    runtimeInputs = [ pkgs.home-manager ];
    text = ''
      for profile in minimal desktop; do
        echo "Testing home-manager profile: $profile"
        USER=$(id -un) home-manager build -f profiles/$profile.nix
      done
    '';
  };
```

- [ ] **Step 4: Delete `home.nix`**

```bash
git rm home.nix
```

- [ ] **Step 5: Verify setup.sh help and shell.nix tests still work**

```bash
./setup.sh --help
nix-shell shell.nix --run "run-tests"
```

Expected: `--help` shows only minimal/desktop. `run-tests` builds both profiles successfully.

- [ ] **Step 6: Commit**

```bash
git add setup.sh shell.nix
git commit -m "refactor: use profiles/ entry points in setup.sh and shell.nix; remove home.nix"
```

---

### Task 3: Strip ouster from `home/programs/packages.nix`

**Files:**
- Modify: `home/programs/packages.nix`

Remove: ouster-only packages (`work-vpn-client`, `slack`), the `githubCopilotCli` let binding, the `copilot-marketplace` systemd service/timer block. Simplify `code-cursor` to desktop-only.

- [ ] **Step 1: Rewrite `home/programs/packages.nix`**

```nix
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.home-manager-configuration;
in
{
  home = {
    packages =
      with pkgs;
      [
        git-lfs
        htop
        jq
        less
        libnotify
        nixpkgs-fmt
        nodejs_24
        ripgrep
        config.unstablePkgs.glab
      ]
      ++ lib.optionals (cfg.profile == "desktop") [
        config.unstablePkgs.code-cursor
      ];
  };
}
```

- [ ] **Step 2: Verify build still works**

```bash
nix-shell shell.nix --run "run-tests"
```

Expected: both profiles build without error.

- [ ] **Step 3: Commit**

```bash
git add home/programs/packages.nix
git commit -m "refactor: remove ouster packages and copilot-marketplace service"
```

---

### Task 4: Strip ouster from `home/programs/git.nix`

**Files:**
- Modify: `home/programs/git.nix`

Remove: `ousterIgnores` let binding, `home.file.".config/git/ignore-ouster"`, the ouster conditional git include. Rename `baseIgnores` to `ignores` for clarity.

- [ ] **Step 1: Rewrite `home/programs/git.nix`**

```nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  ignores = [
    ".direnv"
    ".claude/settings.local.json"
  ];
in
{
  imports = [
    ../../modules/common/private.nix
    ../../modules/common/unstable-pkgs.nix
  ];

  programs.difftastic = {
    enable = true;
    package = config.unstablePkgs.difftastic;
    git.enable = true;
  };

  programs.git = {
    enable = true;
    package = config.unstablePkgs.git;
    inherit ignores;

    settings = {
      core.editor = "vi";
      fetch.prune = true;
      init.defaultBranch = "main";
      pull.rebase = true;
      user = {
        email = "danr.236@gmail.com";
        name = "Daniel Robson";
      };
    };

    includes = lib.optionals config.private.available [
      {
        contents.core.hooksPath = "${config.private.dir}/.githooks";
      }
    ];
  };
}
```

- [ ] **Step 2: Verify build**

```bash
nix-shell shell.nix --run "run-tests"
```

- [ ] **Step 3: Commit**

```bash
git add home/programs/git.nix
git commit -m "refactor: remove ouster git identity and ignore rules"
```

---

### Task 5: Strip ouster from `constants.nix` and `home/default.nix`

**Files:**
- Modify: `modules/common/constants.nix`
- Modify: `home/default.nix`

- [ ] **Step 1: Rewrite `modules/common/constants.nix`**

```nix
{ lib, ... }:

{
  profiles = {
    options = [
      "minimal"
      "desktop"
    ];

    descriptions = {
      minimal = "CLI tools only";
      desktop = "includes GUI applications";
    };

    default = "minimal";
  };
}
```

- [ ] **Step 2: Update `home/default.nix` — remove ouster from desktop enable check**

Change line 55-58 from:
```nix
    home-manager-desktop-configuration.enable = builtins.elem cfg.profile [
      "desktop"
      "ouster"
    ];
```
To:
```nix
    home-manager-desktop-configuration.enable = cfg.profile == "desktop";
```

- [ ] **Step 3: Verify build and run linter**

```bash
nix-shell shell.nix --run "check"
nix-shell shell.nix --run "run-tests"
```

Expected: linter clean, both profiles build.

- [ ] **Step 4: Commit**

```bash
git add modules/common/constants.nix home/default.nix
git commit -m "refactor: remove ouster profile from public repo"
```

- [ ] **Step 5: Push**

```bash
git push
```

---

## Part 2: Private Repo

All remaining steps create a new repo at `~/dev/ouster-dotfiles`.

---

### Task 6: Initialize private repo with npins

**Files:**
- Create: `~/dev/ouster-dotfiles/` (new git repo)
- Create: `npins/sources.json`

- [ ] **Step 1: Create the repo and initialize npins**

```bash
mkdir ~/dev/ouster-dotfiles
cd ~/dev/ouster-dotfiles
git init
nix-shell -p npins --run "npins init --bare"
```

- [ ] **Step 2: Pin nixpkgs, home-manager, and dotfiles**

```bash
nix-shell -p npins --run "npins add github NixOS nixpkgs --branch release-25.11"
nix-shell -p npins --run "npins add github nix-community home-manager --branch release-25.11"
nix-shell -p npins --run "npins add github dlrobson dotfiles --branch master"
```

- [ ] **Step 3: Verify pins**

```bash
nix-shell -p npins --run "npins show"
```

Expected: three entries — nixpkgs, home-manager, dotfiles — each with a pinned revision.

- [ ] **Step 4: Add `.gitignore`**

```bash
echo "result" > .gitignore
```

- [ ] **Step 5: Commit**

```bash
git add npins/ .gitignore
git commit -m "chore: initialize repo with npins"
```

---

### Task 7: Create `modules/git.nix`

**Files:**
- Create: `modules/git.nix`

Ouster git identity and ignore rules, extracted from the public repo's `home/programs/git.nix`.

- [ ] **Step 1: Create `modules/` and write `modules/git.nix`**

```nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  ousterIgnores = [
    ".direnv"
    ".claude/settings.local.json"
    "CLAUDE.md"
    ".envrc"
    "shell.nix"
    "docs/superpowers"
  ];
in
{
  home.file.".config/git/ignore-ouster".text = lib.concatStringsSep "\n" ousterIgnores;

  programs.git.includes = [
    {
      condition = "hasconfig:remote.*.url:git@gitlab.com:work/*/**";
      contents = {
        user.email = "REDACTED";
        core.excludesFile = "~/.config/git/ignore-ouster";
      };
    }
  ];
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/git.nix
git commit -m "feat: add ouster git identity module"
```

---

### Task 8: Create `modules/copilot-marketplace.nix`

**Files:**
- Create: `modules/copilot-marketplace.nix`

Systemd service/timer for managing Copilot CLI plugins, moved from the public `home/programs/packages.nix`.

- [ ] **Step 1: Create `modules/copilot-marketplace.nix`**

```nix
{
  config,
  pkgs,
  lib,
  ...
}:

let
  githubCopilotCli = config.unstablePkgs.github-copilot-cli.overrideAttrs (_: {
    doInstallCheck = false;
  });
in
{
  home.packages = [ githubCopilotCli ];

  systemd.user = {
    services.copilot-marketplace = {
      Unit.Description = "Install and update Copilot CLI marketplace plugins";
      Service = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "copilot-marketplace" ''
          export PATH="${githubCopilotCli}/bin:${pkgs.git}/bin:$PATH"

          stateFile="$HOME/.local/share/copilot-cli/managed-plugins"
          desired="awesome-copilot-refactor@dlrobson-plugins frontend-design@dlrobson-plugins handbook-glab@dlrobson-plugins learning-output-style@dlrobson-plugins plugin-dev@dlrobson-plugins pr-review-toolkit@dlrobson-plugins superpowers@dlrobson-plugins"

          if [ -f "$stateFile" ]; then
            while IFS= read -r old; do
              if [[ " $desired " != *" $old "* ]]; then
                copilot plugin uninstall "''${old%%@*}" || true
              fi
            done < "$stateFile"
          fi

          copilot plugin marketplace add dlrobson/plugin-marketplace || true

          for plugin in $desired; do
            copilot plugin install "$plugin" || true
          done

          mkdir -p "$(dirname "$stateFile")"
          printf '%s\n' $desired > "$stateFile"
        '';
      };
    };

    timers.copilot-marketplace = {
      Unit.Description = "Periodically update Copilot CLI marketplace plugins";
      Timer = {
        OnBootSec = "2min";
        OnCalendar = "daily";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/copilot-marketplace.nix
git commit -m "feat: add copilot-marketplace systemd service module"
```

---

### Task 9: Create `shell.nix`

**Files:**
- Create: `shell.nix`

Dev shell with home-manager, nixfmt, statix, npins. `run-tests` builds every profile in `profiles/`.

- [ ] **Step 1: Create `shell.nix`**

```nix
let
  sources = import ./npins;
  pkgs = import sources.nixpkgs { };

  check = pkgs.writeShellApplication {
    name = "check";
    text = ''
      find . -name "*.nix" -type f -print0 | xargs -0 nixfmt --check
      statix check --ignore "npins/default.nix"
    '';
  };

  run-tests = pkgs.writeShellApplication {
    name = "run-tests";
    runtimeInputs = [ pkgs.home-manager ];
    text = ''
      for profile in profiles/*.nix; do
        machine=$(basename "$profile" .nix)
        echo "Testing machine: $machine"
        USER=$(id -un) home-manager build -f "$profile"
      done
    '';
  };
in
pkgs.mkShell {
  buildInputs = [
    pkgs.nixfmt
    pkgs.statix
    pkgs.home-manager
    pkgs.npins
    check
    run-tests
  ];
}
```

- [ ] **Step 2: Commit**

```bash
git add shell.nix
git commit -m "feat: add shell.nix with run-tests for all machine profiles"
```

---

### Task 10: Create `profiles/nixos-server.nix`

**Files:**
- Create: `profiles/nixos-server.nix`

Headless ouster machine — imports the public `minimal` profile (which already reads `USER`/`HOME` from env) and the ouster git module. No need to re-declare username/homeDirectory.

- [ ] **Step 1: Create `profiles/` and write `profiles/nixos-server.nix`**

```nix
{
  config,
  pkgs,
  lib,
  ...
}:

let
  sources = import ../npins;
in
{
  imports = [
    "${sources.dotfiles}/profiles/minimal.nix"
    ../modules/git.nix
  ];
}
```

- [ ] **Step 2: Verify the profile builds**

```bash
nix-shell shell.nix --run "run-tests"
```

Expected: nixos-server builds without error.

- [ ] **Step 3: Commit**

```bash
git add profiles/nixos-server.nix
git commit -m "feat: add nixos-server machine profile"
```

---

### Task 11: Create `setup.sh`

**Files:**
- Create: `setup.sh`

Takes a machine name, validates `profiles/<name>.nix` exists, installs home-manager from npins, deploys.

- [ ] **Step 1: Create `setup.sh`**

```bash
#!/bin/sh
set -eu

# Global variables
MACHINE_NAME=""
DRY_RUN=""
REPO_ROOT=""

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

deploy() {
    local machine_name="$1"
    local dry_run_flag="$2"
    local profile_file="$REPO_ROOT/profiles/${machine_name}.nix"

    if [ ! -f "$profile_file" ]; then
        echo "Error: unknown machine: $machine_name"
        echo "Available machines:"
        for f in "$REPO_ROOT/profiles/"*.nix; do
            echo "  $(basename "$f" .nix)"
        done
        return 1
    fi

    echo "Deploying configuration for: $machine_name"

    local hm_cmd="home-manager switch -b backup -f $profile_file -I home-manager=$(_npins_path home-manager) -I nixpkgs=$(_npins_path nixpkgs)"
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
                echo "Usage: $0 <machine> [OPTIONS]"
                echo
                echo "Machines:"
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
                if [ -n "$MACHINE_NAME" ]; then
                    echo "Error: multiple machine names specified"
                    exit 1
                fi
                MACHINE_NAME="$1"
                ;;
        esac
        shift
    done

    if [ -z "$MACHINE_NAME" ]; then
        echo "Error: machine name required"
        echo "Run '$0 --help' for usage"
        exit 1
    fi
}

main() {
    REPO_ROOT=$(dirname "$(readlink -f "$0")")
    parse_arguments "$@"

    if ! _command_exists nix; then
        echo "Error: Nix is required but not installed."
        echo "Please install Nix first: https://nixos.org/download.html"
        exit 1
    fi

    if ! install_home_manager; then
        echo "Failed to install home-manager"
        exit 1
    fi

    if ! deploy "$MACHINE_NAME" "$DRY_RUN"; then
        echo "Failed to deploy configuration"
        exit 1
    fi

    echo "Configuration for '$MACHINE_NAME' deployed. Ensure fish or bash is your default shell."
}

main "$@"
```

- [ ] **Step 2: Make executable and verify help**

```bash
chmod +x setup.sh
./setup.sh --help
```

Expected: shows `nixos-server` in the machines list.

- [ ] **Step 3: Verify unknown machine error**

```bash
./setup.sh nonexistent 2>&1 || true
```

Expected: `"Error: unknown machine: nonexistent"` followed by the available machines list.

- [ ] **Step 4: Commit**

```bash
git add setup.sh
git commit -m "feat: add setup.sh with machine-name based deployment"
```

- [ ] **Step 5: Create the GitHub repo and push**

Create the private GitHub repo at `github.com/dlrobson/ouster-dotfiles` (via GitHub UI or `gh repo create dlrobson/ouster-dotfiles --private`), then:

```bash
git remote add origin git@github.com:dlrobson/ouster-dotfiles.git
git push -u origin master
```

---

## Verification

- [ ] Public repo: `nix-shell shell.nix --run "check && run-tests"` — clean linter, both profiles build
- [ ] Public repo: `./setup.sh --help` — shows only minimal/desktop
- [ ] Public repo: no files reference "ouster" (`grep -r ouster . --include="*.nix" --include="*.sh"` returns nothing outside `docs/`)
- [ ] Private repo: `nix-shell shell.nix --run "run-tests"` — nixos-server builds
- [ ] Private repo: `./setup.sh nixos-server --dry-run` — dry-run completes without error
- [ ] Private repo: `./setup.sh badname` — exits 1 with helpful error message
