{
  config,
  lib,
  pkgs,
  ...
}:
let
  sources = import ../../npins;
  pluginsDir = "${sources.plugin-marketplace}/plugins";

  claudeCfg = config.programs.claude-code;

  subDirs =
    dir: builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir));

  # opencode consumes bare skill directories rather than plugin manifests, so
  # any `SKILL.md` tree Claude Code already uses works here unchanged — the
  # frontmatter contract is the same. Rather than maintain a second list of
  # what to install, derive it from the plugins `claude.nix` already enables,
  # so the two agents can't silently drift apart.
  enabledPlugins = lib.attrNames (lib.filterAttrs (_: v: v) claudeCfg.settings.enabledPlugins);

  # Marketplaces don't agree on where a plugin lives: `dlrobson-plugins` and
  # `claude-plugins-official-mirror` nest under `plugins/`, `ast-grep-marketplace`
  # puts it at the top level, and `engram` *is* the plugin. Probe the three
  # layouts for one that has a `skills/` directory; a marketplace whose plugins
  # ship no skills (e.g. `claude-code-lsps`, superseded here by `lsp = true`)
  # simply contributes nothing.
  skillsDirOf =
    name: marketplace:
    let
      src = claudeCfg.marketplaces.${marketplace};
      candidates = map (dir: "${dir}/skills") [
        "${src}/plugins/${name}"
        "${src}/${name}"
        "${src}"
      ];
    in
    lib.findFirst builtins.pathExists null candidates;

  # Skill directory names are unique across the enabled set today. If two
  # plugins ever ship the same skill name, `listToAttrs` keeps the last — which
  # would silently shadow one, so `run-tests` output is worth a glance when
  # enabling a new marketplace.
  marketplaceSkills = lib.listToAttrs (
    lib.concatMap (
      ref:
      let
        parts = lib.splitString "@" ref;
        skillsDir = skillsDirOf (builtins.head parts) (lib.last parts);
      in
      lib.optionals (skillsDir != null) (
        map (skill: lib.nameValuePair skill "${skillsDir}/${skill}") (
          # A `skills/` tree can hold non-skill directories of shared assets
          # (engram's `_shared`), which opencode would reject for having no
          # frontmatter — a `SKILL.md` is what makes a directory a skill.
          lib.filter (skill: builtins.pathExists "${skillsDir}/${skill}/SKILL.md") (subDirs skillsDir)
        )
      )
    ) enabledPlugins
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
      # Ported from `claude.nix`'s `settings.permissions`, with one structural
      # difference: there is no bubblewrap equivalent here. Claude Code can
      # afford to auto-run everything because the sandbox is the safety
      # boundary; opencode has only these pattern rules, so they *are* the
      # boundary. Rules are evaluated last-match-wins, hence the `"*"`
      # catch-all first and the specific overrides after it.
      permission = {
        bash = {
          "*" = "allow";
          # Backstops the "never run sudo" rule in the shared `context` above
          # (prose the model could ignore) with harness-level enforcement,
          # mirroring the `Bash(sudo *)` deny in `claude.nix`.
          "sudo *" = "deny";
          "git push *" = "ask";
          "git reset *" = "ask";
        };
        edit = "allow";
        webfetch = "allow";
        # Reaching outside the project is the one thing the missing sandbox
        # made cheap to do by accident, so keep a prompt on it.
        external_directory = "ask";
      };
    };
  };
}
