{
  config,
  lib,
  ...
}:
let
  sources = import ../../npins;
  pluginMarketplace = sources.plugin-marketplace;
  pluginsDir = "${pluginMarketplace}/plugins";
  # Only plugins that carry a `.codex-plugin/plugin.json` manifest are
  # Codex-compatible today (currently just `agenix`, for its skill) — `nix`'s
  # value is its MCP server config, wired below instead, and `direnv`'s hook
  # relies on Claude-only env vars/events with no Codex equivalent.
  codexPluginNames =
    builtins.filter (name: builtins.pathExists (pluginsDir + "/${name}/.codex-plugin/plugin.json"))
      (builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir pluginsDir)));
in
{
  options.codex-trusted-projects = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Absolute paths to mark as trusted Codex projects. Codex's `projects`
      trust map only matches a cwd or git-repo-root path exactly — no
      prefix/glob matching — so every repo root that should skip the
      interactive trust prompt needs its own entry here. Machine-specific,
      so set per-deployment (e.g. in the consuming flake/config that imports
      this repo's `home/` module) rather than hardcoded in this file.
    '';
  };

  config.programs.codex = {
    enable = lib.mkDefault false;
    package = config.unstablePkgs.codex;
    # Same global rules as Claude Code — single source of truth.
    context = config.programs.claude-code.context;
    plugins = map (name: pluginsDir + "/${name}") codexPluginNames;
    settings = {
      mcp_servers = builtins.fromJSON (builtins.readFile "${pluginsDir}/nix/.mcp.json");
      projects = lib.genAttrs config.codex-trusted-projects (_: {
        trust_level = "trusted";
      });
    };
  };
}
