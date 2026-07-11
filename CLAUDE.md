# CLAUDE.md

## Repo usage
This repo is consumed as a library, not just built standalone. Other repos pin this repo
via npins and `imports = [ "${sources.dotfiles}/home" ]` into their own home-manager user
configs. Because of that:
- Options meant to vary per deployment (e.g. `codex-trusted-projects`,
  `claude-window-trigger.schedule`, `et-server.enable`) default to off/empty here — the
  consuming repo sets real values, not this one.
- `run-tests` only builds `profiles/{minimal,desktop}.nix` standalone; it won't catch
  issues that only surface when a consumer overrides these options.

## Config changes
- All config changes go through home-manager nix files (`home/programs/*.nix`) — never imperative commands like `git config --local` or `git config --global` (`~/.config/git` is read-only anyway).
- Don't invent home-manager option names. Verify first with the nixos MCP tool (`source: home-manager`, action `search`/`browse`).
- Raw git config keys with no dedicated home-manager option go under `programs.git.settings.<section>.<key>` (freeform), e.g. `diff.tool`, `difftool.prompt`.
- Don't run `home-manager switch` — the user applies changes themselves.

## Validation
- `check` — lint (nixfmt --check, statix, deadnix)
- `run-tests` — builds both profiles (minimal, desktop) via `home-manager build`

These are provided on `PATH` by the `.envrc` (`use nix`) direnv environment — call them directly, no `nix-shell --run` wrapper needed.
- To confirm generated output, inspect the built store path, e.g. `<result>/home-files/.config/git/config` (pattern generalizes to any dotfile, e.g. `.config/fish/config.fish`)
