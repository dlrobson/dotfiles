{ lib, ... }:
let
  sources = import ../../npins;
  pluginMarketplace = sources.plugin-marketplace;
  localMarketplaceManifest = builtins.fromJSON (
    builtins.readFile "${pluginMarketplace}/.claude-plugin/marketplace.json"
  );
in
{
  # Single declaration site for the plugins shared between Claude Code and
  # opencode. Previously these lived in `programs.claude-code.settings`, with
  # `opencode.nix` reading them back out — which made Claude's harness config
  # double as the cross-agent registry, so disabling a plugin for a
  # Claude-specific reason silently changed what opencode installed.
  #
  # Codex deliberately does not read this: it only supports plugins carrying a
  # `.codex-plugin/plugin.json` manifest (today just `agenix`), so it keeps its
  # own narrower scan in `codex.nix`.
  options.agentPlugins = {
    marketplaces = lib.mkOption {
      type = with lib.types; attrsOf (either package path);
      default = { };
      description = ''
        Plugin marketplaces, keyed by marketplace id. Each value is a
        directory containing a `.claude-plugin/marketplace.json`.
      '';
    };

    enabled = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Enabled plugins as `plugin-id@marketplace-id`, referencing a
        marketplace declared above.
      '';
    };
  };

  config.agentPlugins = {
    marketplaces = {
      # Named away from "claude-plugins-official": Claude Code hardcodes
      # an exact-match set of reserved marketplace names (including
      # "claude-plugins-official" and, as of 2.1.209, "anthropic-plugins")
      # and refuses to load any of them from a source it can't verify as
      # the anthropics GitHub org - which a vendored nix-store directory
      # source never satisfies, even when the content genuinely is
      # anthropics/claude-plugins-official. Any name outside that fixed
      # set (exact string match, not a substring/pattern check) works.
      # https://github.com/anthropics/claude-code/issues/18329
      claude-plugins-official-mirror = sources.claude-plugins-official;
      inherit (sources) claude-code-lsps;
      ast-grep-marketplace = sources.ast-grep-skill;
      dlrobson-plugins = pluginMarketplace;
      inherit (sources) engram;
      # `claude-plugins-official` lists superpowers as a remote `url` source
      # rather than vendoring it, so consuming it from there means Claude
      # Code fetches the repo at runtime — and leaves nothing on disk for
      # `opencode.nix` to install skills from. Pinning it via npins instead
      # keeps the fetch declarative and lets both agents share one version.
      # The repo is itself a marketplace (`.claude-plugin/marketplace.json`,
      # name "superpowers-dev", plugin source "./"), hence the id below.
      superpowers-dev = sources.superpowers;
    };

    enabled = [
      "claude-md-management@claude-plugins-official-mirror"
      "claude-code-setup@claude-plugins-official-mirror"
      "superpowers@superpowers-dev"
      "plugin-dev@claude-plugins-official-mirror"
      "pr-review-toolkit@claude-plugins-official-mirror"
      "rust-analyzer@claude-code-lsps"
      "nixd@claude-code-lsps"
      "vtsls@claude-code-lsps"
      "ast-grep@ast-grep-marketplace"
      "engram@engram"
    ]
    # Enable every plugin listed in the local marketplace's manifest
    # automatically, so new plugins added to that repo don't need listing here
    # by hand.
    ++ map (plugin: "${plugin.name}@dlrobson-plugins") localMarketplaceManifest.plugins;
  };
}
