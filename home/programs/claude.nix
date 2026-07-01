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
  anthropicsClaude = sources.claude-code;
  localPlugins = map (name: "${pluginMarketplace}/plugins/${name}") (
    builtins.attrNames (builtins.readDir "${pluginMarketplace}/plugins")
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
        attribution = {
          commit = "";
          pr = "";
        };
      };
      plugins = [
        "${sources.superpowers}"
        "${anthropicsClaude}/plugins/pr-review-toolkit"
        # Official ast-grep skill: structural (AST-based) code search and
        # rewrites. The binary is added to home.packages below; the skill is
        # inert without it. Repo is itself a marketplace; the plugin lives in
        # the `ast-grep/` subdir.
        "${sources.ast-grep-skill}/ast-grep"
        "${sources.claude-code-lsps}/rust-analyzer"
        "${sources.claude-code-lsps}/nixd"
        "${sources.claude-code-lsps}/vtsls"
      ]
      ++ localPlugins;
    };

    home = {
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
