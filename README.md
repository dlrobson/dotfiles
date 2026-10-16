# dlrobson's dotfiles

Home Manager configuration for my machines, managed with [Nix](https://nixos.org/).

It is used two ways:

- **As a library.** Other repos pin it with [npins](https://github.com/nix-community/npins)
  and import `${sources.dotfiles}/home` into their own Home Manager users. Options that
  vary per deployment (`pi.enable`, `paseo.enable`, `claude-window-trigger.schedule`, …)
  default to off/empty here, and the consuming repo sets real values.
- **Standalone.** `./setup.sh <profile>` deploys a profile directly. This is how the
  Ubuntu machine is configured.

## Standalone deploy

Prerequisites:

- [Nix](https://nixos.org/download.html)
- Fish (installed via Home Manager; set as your login shell afterwards)

```bash
./setup.sh desktop            # or: minimal
./setup.sh desktop --dry-run  # print what would change
./setup.sh --help
```

Then set Fish as your shell (once) and log back in:

```bash
chsh -s "$(command -v fish)"
```

| Profile | Contents |
|---|---|
| `minimal` | CLI tools, shell, git, tmux, Neovim, agent CLIs |
| `desktop` | `minimal` plus GUI apps (Ghostty, Chromium, VS Code), GNOME settings, and KMonad on non-NixOS hosts |

`setup.sh` is the only thing that switches the configuration — nothing applies changes
on its own.

## Development

`.envrc` puts a dev shell on `PATH` via `direnv`:

| Command | Does |
|---|---|
| `check` | lint: `nixfmt --check`, `statix`, `deadnix` |
| `format` | apply the same fixes |
| `run-tests` | build the `minimal`, `desktop`, and `coverage` profiles |
| `update-pins` | `npins upgrade && npins update` |

`coverage` is a test fixture, not a deployment target: it turns every per-deployment
option on with fake values so those code paths are built. **Adding a new
per-deployment option? Add it to `profiles/coverage.nix` too, or it goes untested.**

## KMonad (Ubuntu/Debian only)

KMonad remaps the ThinkPad keyboard (Caps and Space tap-hold bindings, plus a mod layer).
It is skipped on NixOS, where the consuming system config owns keyboard remapping
instead.

1. Deploy the `desktop` profile.
2. Run `./kmonad/kmonad-setup.sh` — needs root for the udev rule and the
   `input`/`uinput` group membership.
3. Manage it with:
   `systemctl --user {status,start,stop,enable,disable} kmonad-mapping.service`

## Layout

```text
home/
  default.nix        # profile selector and shared user options
  programs/          # CLI tools, shells, editor, agent harnesses (pi, paseo, claude)
  desktop/           # GUI apps, GNOME, non-NixOS (nixGL, KMonad) bits
modules/common/      # shared helpers (profile constants, private config, unstable pkgs)
kmonad/              # KMonad mapping + the Ubuntu setup script
profiles/            # deployable entrypoints, plus the coverage fixture
npins/               # pinned dependencies
shell.nix            # dev shell
setup.sh             # standalone deploy
```
