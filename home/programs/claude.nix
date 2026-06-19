{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.claude-window-trigger;
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
    home = {
      packages = [
        config.unstablePkgs.claude-code
        pkgs.uv
      ];

      sessionPath = [
        "${config.home.homeDirectory}/.npm-global/bin"
        "${config.home.homeDirectory}/.local/bin"
      ];
    };

    systemd.user = {
      services.claude-marketplace = {
        Unit.Description = "Install and update Claude Code marketplace plugins";
        Service = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "claude-marketplace" ''
            export PATH="${config.unstablePkgs.claude-code}/bin:${pkgs.git}/bin:${pkgs.jq}/bin:${pkgs.openssh}/bin:$PATH"

            marketplaceName="dlrobson-plugins"
            claude plugin marketplace add "dlrobson/plugin-marketplace"
            claude plugin marketplace update "$marketplaceName" || true

            marketplaceDir=$(claude plugin marketplace list --json \
              | jq -r --arg m "$marketplaceName" '.[] | select(.name == $m) | .installLocation')
            availablePlugins=$(jq -r '.plugins[].name' "$marketplaceDir/.claude-plugin/marketplace.json")
            installedIds=$(claude plugin list --json | jq -r '.[].id')

            while IFS= read -r plugin; do
              if [ -z "$plugin" ]; then continue; fi
              if echo "$installedIds" | grep -qx "$plugin@$marketplaceName"; then
                echo "Already installed: $plugin"
              else
                echo "Installing: $plugin"
                claude plugin install "$plugin@$marketplaceName"
              fi
            done <<< "$availablePlugins"

            while IFS= read -r installedId; do
              if [ -z "$installedId" ]; then continue; fi
              pluginName=$(echo "$installedId" | sed "s/@$marketplaceName$//")
              if [ "$pluginName" = "$installedId" ]; then continue; fi
              if ! echo "$availablePlugins" | grep -qx "$pluginName"; then
                echo "Removing stale plugin: $installedId"
                claude plugin remove "$installedId"
              else
                echo "Updating: $installedId"
                claude plugin update "$installedId" || true
              fi
            done <<< "$installedIds"
          '';
        };
      };

      timers.claude-marketplace = {
        Unit.Description = "Periodically update Claude Code marketplace plugins";
        Timer = {
          OnBootSec = "2min";
          OnCalendar = "daily";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };

      services.claude-window-trigger = lib.mkIf cfg.enable {
        Unit.Description = "Trigger Claude Code usage window";
        Service = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "claude-window-trigger" ''
            export PATH="${config.unstablePkgs.claude-code}/bin:$PATH"
            claude -p "hi" --output-format text
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
