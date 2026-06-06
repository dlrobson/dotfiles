# Ouster Split Design

**Date:** 2026-06-05
**Status:** Approved

## Problem

The public `dotfiles` repo contains work-specific configuration (ouster packages, git identity, copilot-marketplace service). This needs to be a private concern.

## Goal

Make `dotfiles` a standalone public library. Move all ouster-specific configuration to a new private `ouster-dotfiles` repo. The private repo is the single entry point for ouster machines.

---

## Public Repo Changes (`dotfiles`)

### What gets removed
- `PROFILE_OUSTER` constant from `modules/common/constants.nix`
- `--ouster` flag and `PROFILE_OUSTER` variable from `setup.sh`
- All `cfg.profile == "ouster"` conditionals from `home/programs/packages.nix` (work-vpn-client, slack, copilot-marketplace service/timer)
- Ouster git config (conditional email + ignore-ouster file) from `home/programs/git.nix`
- `"ouster"` from the `run-tests` loop in `shell.nix`

### What gets added
Two new top-level entry point files:

**`profiles/minimal.nix`** — home-manager module that sets `username`/`homeDirectory` from env and enables the minimal profile via the existing `home/` module system.

**`profiles/desktop.nix`** — same but enables the desktop profile.

### What stays the same
The entire `home/` and `modules/` directory structure is unchanged. `profiles/` are thin wrappers that expose stable entry points for external consumers.

---

## Private Repo Structure (`ouster-dotfiles`)

```
ouster-dotfiles/
├── npins/
│   └── sources.json        (pins: nixpkgs, home-manager, dotfiles)
├── profiles/
│   ├── nixos-server.nix    (imports dotfiles/profiles/minimal.nix + ouster CLI modules)
│   └── <machine>.nix       (one file per machine)
├── modules/
│   ├── git.nix             (ouster git conditional config: email, ignore rules)
│   └── copilot-marketplace.nix  (systemd service/timer, moved from public repo)
├── shell.nix               (dev shell with home-manager from npins)
└── setup.sh
```

### Machine profiles
Each `profiles/<machine>.nix` is a self-contained home-manager module:
- Sets `home.username` / `home.homeDirectory` from env
- Imports the appropriate public profile (`dotfiles/profiles/minimal.nix` or `desktop.nix`) via the npins-pinned path
- Imports whichever ouster modules it needs

Machines that need a GUI import `desktop.nix`; headless machines import `minimal.nix`. There is no separate headless/desktop abstraction — the machine file makes that decision directly.

### setup.sh
Takes a single positional argument: the machine name.

```sh
./setup.sh nixos-server
```

Behaviour:
1. Checks that `profiles/<name>.nix` exists; if not, prints `"unknown machine: <name>"` and lists the available profile files from `profiles/`, then exits 1
2. Installs home-manager from the npins-pinned path (same `nix-env -iA` approach as public repo)
3. Runs `home-manager switch -b backup -f $REPO_ROOT/profiles/<name>.nix -I home-manager=… -I nixpkgs=…`

### npins
The private repo pins three sources:
- `nixpkgs` (release-25.11)
- `home-manager` (release-25.11)
- `dotfiles` (pinned to a specific commit of the public repo)

Updating the public dotfiles pin: `npins update dotfiles` in the private repo.

---

## Composition Example

```
home-manager switch -f profiles/nixos-server.nix
    └── profiles/nixos-server.nix
            ├── imports dotfiles/profiles/minimal.nix  (public)
            │       └── imports home/  (all CLI programs, fish, git, vim, tmux…)
            └── imports modules/git.nix                (ouster email, ignore rules)
```

---

## CI

- **Public repo**: existing CI tests `minimal` and `desktop` profiles only (ouster removed from `run-tests`)
- **Private repo**: CI can be added later; not in scope for this change

---

## Out of Scope

- Any ouster-specific secrets management
- Private repo CI
- Changes to the `modules/common/` internals
