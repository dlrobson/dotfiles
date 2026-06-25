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
        autoMemoryEnabled = true;
        autoDreamEnabled = true;
        remoteControlAtStartup = true;
        agentPushNotifEnabled = true;
        skipAutoPermissionPrompt = true;
        attribution = {
          commit = "";
          pr = "";
        };
      };
      plugins = [
        "${sources.superpowers}"
        "${anthropicsClaude}/plugins/learning-output-style"
        "${anthropicsClaude}/plugins/pr-review-toolkit"
      ]
      ++ localPlugins;
    };

    home = {

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
