{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.codex;
  jsonFormat = pkgs.formats.json { };

  # home-manager's release-26.05 `programs.codex` module predates plugin/
  # marketplace support (that lands in an unreleased home-manager version) —
  # this module ports just that piece from home-manager master
  # (modules/programs/codex/{default,lib}.nix as of 2026-07) so `codex.nix`
  # can register plugins/marketplaces the same way `claude.nix` does, without
  # moving this repo's home-manager pin off the stable release. Drop this file
  # and switch `codex.nix` back to upstream options once a home-manager
  # release ships with native `programs.codex.plugins`/`marketplaces`.
  configDir = ".codex";
  pluginsMarketplaceName = "home-manager";
  pluginsCacheDir = "${configDir}/plugins/cache";
  homeRelativePluginsCacheDir = pluginsCacheDir;

  sanitizePathComponent =
    value: builtins.unsafeDiscardStringContext (lib.strings.sanitizeDerivationName value);

  mkPluginName =
    plugin:
    let
      manifestPath = plugin + "/.codex-plugin/plugin.json";
      manifestName =
        if !lib.isDerivation plugin && builtins.pathExists manifestPath then
          (builtins.fromJSON (builtins.readFile manifestPath)).name
        else
          null;
      fallbackName =
        if lib.isDerivation plugin then
          plugin.pname or (lib.getName plugin)
        else
          baseNameOf (toString plugin);
    in
    builtins.unsafeDiscardStringContext (if manifestName != null then manifestName else fallbackName);

  mkPluginVersion =
    plugin:
    let
      manifestPath = plugin + "/.codex-plugin/plugin.json";
      manifestVersion =
        if !lib.isDerivation plugin && builtins.pathExists manifestPath then
          (builtins.fromJSON (builtins.readFile manifestPath)).version or null
        else
          null;
      fallbackVersion = plugin.version or "0.0.0";
    in
    builtins.unsafeDiscardStringContext (
      if manifestVersion != null then manifestVersion else fallbackVersion
    );

  mkPluginPathName = plugin: sanitizePathComponent (mkPluginName plugin);
  mkPluginPathVersion = plugin: sanitizePathComponent (mkPluginVersion plugin);

  mkPluginCachePath =
    plugin:
    "${pluginsCacheDir}/${pluginsMarketplaceName}/${mkPluginPathName plugin}/${mkPluginPathVersion plugin}";

  mkMarketplaceConfigEntry = _name: content: {
    source_type = "local";
    source = "${content}";
  };

  mkPersonalMarketplacePluginEntry = plugin: {
    name = mkPluginName plugin;
    source = {
      source = "local";
      path = "./${homeRelativePluginsCacheDir}/${pluginsMarketplaceName}/${mkPluginPathName plugin}/${mkPluginPathVersion plugin}";
    };
    policy = {
      installation = "AVAILABLE";
      authentication = "ON_INSTALL";
    };
    category = "Productivity";
  };

  mkPluginConfigEntry =
    plugin: lib.nameValuePair "${mkPluginName plugin}@${pluginsMarketplaceName}" { enabled = true; };

  mkPluginFileEntry =
    plugin:
    lib.nameValuePair (mkPluginCachePath plugin) {
      source = plugin;
      force = true;
    };
in
{
  options.programs.codex = {
    plugins = lib.mkOption {
      type = with lib.types; listOf (either package path);
      default = [ ];
      description = ''
        List of plugins to use when running Codex. Each entry is either a
        path to the plugin directory, or a package/fetcher output. Plugins
        are installed into Codex's plugin cache and enabled through
        {file}`CODEX_HOME/config.toml` under an auto-generated personal
        "home-manager" marketplace.

        Ported from home-manager master's `programs.codex.plugins`
        (unavailable on the release-26.05 this repo pins) — see
        `codex-plugins.nix`.
      '';
    };

    marketplaces = lib.mkOption {
      type = with lib.types; attrsOf (either package path);
      default = { };
      description = ''
        Custom marketplaces for Codex plugins, keyed by marketplace name.
        Each value is a path or package/fetcher output for the marketplace
        directory, configured through {file}`CODEX_HOME/config.toml`.

        Ported from home-manager master's `programs.codex.marketplaces`
        (unavailable on the release-26.05 this repo pins) — see
        `codex-plugins.nix`.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && (cfg.plugins != [ ] || cfg.marketplaces != { })) {
    assertions = [
      {
        assertion = lib.all (
          plugin:
          !(lib.hm.strings.isPathLike plugin && !lib.isDerivation plugin) || lib.pathIsDirectory plugin
        ) cfg.plugins;
        message = "`programs.codex.plugins` entries must be directories";
      }
      {
        assertion = lib.all (
          marketplace:
          !(lib.hm.strings.isPathLike marketplace && !lib.isDerivation marketplace)
          || lib.pathIsDirectory marketplace
        ) (lib.attrValues cfg.marketplaces);
        message = "`programs.codex.marketplaces` entries must be directories";
      }
    ];

    programs.codex.settings = {
      features.plugins = true;
      plugins = lib.listToAttrs (map mkPluginConfigEntry cfg.plugins);
      marketplaces = lib.mapAttrs mkMarketplaceConfigEntry cfg.marketplaces;
    };

    home = {
      # Codex converts the symlinked plugin cache directory into a real
      # directory on first run, which home-manager can't then overwrite —
      # clear it back out before each generation switch.
      activation.cleanCodexPluginCache = lib.mkIf (cfg.plugins != [ ]) (
        lib.hm.dag.entryBefore [ "linkGeneration" ] (
          lib.concatMapStringsSep "\n" (
            plugin:
            let
              cachePath = lib.escapeShellArg (mkPluginCachePath plugin);
            in
            ''
              path="$HOME"/${cachePath}
              if [ -d "$path" ] && [ ! -L "$path" ]; then
                rm -rf "$path"
              fi
            ''
          ) cfg.plugins
        )
      );

      file =
        lib.optionalAttrs (cfg.plugins != [ ]) {
          ".agents/plugins/marketplace.json" = {
            source = jsonFormat.generate "codex-home-manager-marketplace" {
              name = pluginsMarketplaceName;
              interface.displayName = "Home Manager";
              plugins = map mkPersonalMarketplacePluginEntry cfg.plugins;
            };
          };
        }
        // lib.listToAttrs (map mkPluginFileEntry cfg.plugins);
    };
  };
}
