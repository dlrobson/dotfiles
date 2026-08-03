{
  config,
  lib,
  pkgs,
  ...
}:
let
  sources = import ../../npins;
  pluginsDir = "${sources.plugin-marketplace}/plugins";

  subDirs =
    dir: builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir));

  # opencode consumes bare skill directories rather than plugin manifests, so
  # every `plugins/*/skills/*` in the marketplace is usable as-is (the
  # SKILL.md frontmatter contract is the same one Claude Code uses). Discovered
  # rather than listed so new marketplace skills need no edit here.
  marketplaceSkills = lib.listToAttrs (
    lib.concatMap (
      plugin:
      let
        skillsDir = "${pluginsDir}/${plugin}/skills";
      in
      lib.optionals (builtins.pathExists skillsDir) (
        map (skill: lib.nameValuePair skill "${skillsDir}/${skill}") (subDirs skillsDir)
      )
    ) (subDirs pluginsDir)
  );

  # Same `.mcp.json` that `claude.nix` (via the `nix` plugin) and `codex.nix`
  # read — one source of truth for the mcp-nixos server. opencode's schema
  # differs from Claude's, so translate rather than splat: it wants a `type`
  # discriminator and a single flat argv instead of `command` + `args`.
  # home-manager's opencode module has this exact translation internally, but
  # only reachable through `programs.mcp.servers`, which this repo doesn't use
  # (moving all three agents onto it would be a separate change).
  toOpencodeMcp = _name: server: {
    type = "local";
    command = [ server.command ] ++ (server.args or [ ]);
    enabled = true;
  };
in
{
  config.programs.opencode = {
    # Unconditional, unlike `programs.codex.enable`: Codex is opt-in because
    # its `projects` trust map is inherently per-deployment, whereas opencode
    # has no equivalent machine-specific state.
    enable = true;
    package = config.unstablePkgs.opencode;

    # Same global rules as Claude Code and Codex — single source of truth.
    # The module writes this to `~/.config/opencode/AGENTS.md`.
    context = config.programs.claude-code.context;

    # Runtime deps for the mcp-nixos server below, which launches via
    # `UV_PYTHON=$(which python3) uvx mcp-nixos`. Wrapped onto opencode's own
    # PATH so the module stands alone, even though `claude.nix` also installs
    # them globally for the same reason.
    extraPackages = [
      pkgs.uv
      pkgs.python3
    ];

    skills = marketplaceSkills;

    settings = {
      # Anthropic prohibits third-party harnesses from using Claude Pro/Max
      # OAuth (https://code.claude.com/docs/en/legal-and-compliance), so
      # opencode can't spend the subscription — point it at opencode Zen's
      # free tier instead. The API key is entered interactively via `/connect`
      # and stored in ~/.local/share/opencode/auth.json, so there's nothing to
      # manage here. Note Zen's free models may retain data for training;
      # don't point opencode at anything sensitive.
      model = "opencode/deepseek-v4-flash-free";
      # Built in, so no equivalent of the `claude-code-lsps` marketplace
      # plugins is needed.
      lsp = true;
      mcp = lib.mapAttrs toOpencodeMcp (
        builtins.fromJSON (builtins.readFile "${pluginsDir}/nix/.mcp.json")
      );
      # No `permission` block yet: opencode's rules are pattern matches, not an
      # OS sandbox like `claude.nix`'s bubblewrap config, so nothing carries
      # over directly. Its defaults (prompt on edit/bash) apply until the
      # allowlist is ported deliberately.
    };
  };
}
