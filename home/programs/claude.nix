{
  config,
  pkgs,
  lib,
  ...
}:

{
  home = {
    packages = [ config.unstablePkgs.claude-code ];

    sessionPath = [ "${config.home.homeDirectory}/.npm-global/bin" ];
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
  };
}
