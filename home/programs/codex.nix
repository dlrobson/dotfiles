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
  programs.codex = {
    enable = true;
    package = config.unstablePkgs.codex;
    # Same global rules as Claude Code — single source of truth.
    context = config.programs.claude-code.context;
    plugins = map (name: pluginsDir + "/${name}") codexPluginNames;
    settings.mcp_servers = builtins.fromJSON (builtins.readFile "${pluginsDir}/nix/.mcp.json");
  };
}
