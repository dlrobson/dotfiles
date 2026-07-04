{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.claude-window-trigger;
  sources = import ../../npins;
  pluginMarketplace = sources.plugin-marketplace;
  claudePluginsOfficial = sources.claude-plugins-official;
  # Enable every plugin listed in the marketplace's manifest automatically,
  # so new plugins added to the repo don't need to be listed here by hand.
  localMarketplaceManifest = builtins.fromJSON (
    builtins.readFile "${pluginMarketplace}/.claude-plugin/marketplace.json"
  );
  localEnabledPlugins = lib.listToAttrs (
    map (
      plugin: lib.nameValuePair "${plugin.name}@dlrobson-plugins" true
    ) localMarketplaceManifest.plugins
  );
in
{
  options.claude-window-trigger = {
    enable = lib.mkEnableOption "Claude Code usage window triggers";
    schedule = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "OnCalendar entries for the window trigger timer.";
    };
  };

  config = {
    programs.claude-code = {
      enable = true;
      package = config.unstablePkgs.claude-code;
      context = ''
        # Global Claude Code Rules

        ## Git workflow
        When pushing a new branch upstream for the first time, return the PR creation URL (from `gh pr create`).
      '';
      settings = {
        # Flicker-free alt-screen renderer with virtualized scrollback
        # (equivalent to CLAUDE_CODE_NO_FLICKER=1; toggle live via /tui).
        tui = "fullscreen";
        # Retain sessions/tasks/backups for 60 days (default is shorter), so
        # older sessions remain scrollable and backups recoverable.
        # Note: the nixpkgs claude-code wrapper already sets DISABLE_AUTOUPDATER=1,
        # so no env entry is needed to stop the bundled updater.
        cleanupPeriodDays = 60;
        autoMemoryEnabled = true;
        autoDreamEnabled = true;
        remoteControlAtStartup = true;
        agentPushNotifEnabled = true;
        skipAutoPermissionPrompt = true;
        model = "claude-sonnet-5";
        effortLevel = "medium";
        # Default 1% budget truncates a handful of skill descriptions (full
        # listing is ~1.7% of context); actual cost is negligible either way
        # (~3.3k tokens total), so raise the cap to stop the startup warning.
        skillListingBudgetFraction = 0.02;
        attribution = {
          commit = "";
          pr = "";
          sessionUrl = false;
        };
        # Plugins resolved from the marketplaces registered below, keyed as
        # `plugin-id@marketplace-id`.
        enabledPlugins = {
          "claude-md-management@claude-plugins-official" = true;
          "claude-code-setup@claude-plugins-official" = true;
          "superpowers@claude-plugins-official" = true;
          "pr-review-toolkit@claude-plugins-official" = true;
          "rust-analyzer@claude-code-lsps" = true;
          "nixd@claude-code-lsps" = true;
          "vtsls@claude-code-lsps" = true;
          "ast-grep@ast-grep-marketplace" = true;
        }
        // localEnabledPlugins;
      };
      marketplaces = {
        claude-plugins-official = claudePluginsOfficial;
        inherit (sources) claude-code-lsps;
        ast-grep-marketplace = sources.ast-grep-skill;
        dlrobson-plugins = pluginMarketplace;
      };
    };

    home = {
      # known_marketplaces.json is fully derived from `marketplaces` above, so
      # always overwrite it rather than backing up (avoids "would be
      # clobbered" failures when a stale .backup already exists).
      file."${config.programs.claude-code.configDir}/plugins/known_marketplaces.json".force = true;

      # Runtime deps for the `nix` plugin's mcp-nixos server, which launches
      # via `UV_PYTHON=$(which python3) uvx mcp-nixos`
      # (see plugin-marketplace/plugins/nix/.mcp.json). uvx runs the server;
      # python3 is the interpreter uv builds its environment against.
      packages = [
        pkgs.uv
        pkgs.python3
        # Binary for the ast-grep-skill plugin (pinned above). Unstable to
        # stay aligned with the skill, which tracks the upstream repo's main.
        config.unstablePkgs.ast-grep
      ];

      sessionPath = [
        "${config.home.homeDirectory}/.npm-global/bin"
        "${config.home.homeDirectory}/.local/bin"
      ];
    };

    systemd.user = {
      services.claude-window-trigger = lib.mkIf cfg.enable {
        Unit.Description = "Trigger Claude Code usage window";
        Service = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "claude-window-trigger" ''
            export PATH="${config.unstablePkgs.claude-code}/bin:$PATH"
            claude -p "hi" --output-format text --system-prompt "" --model claude-haiku-4-5-20251001
          '';
        };
      };

      timers.claude-window-trigger = lib.mkIf cfg.enable {
        Unit.Description = "Claude Code usage window trigger timer";
        Timer = {
          OnCalendar = cfg.schedule;
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
