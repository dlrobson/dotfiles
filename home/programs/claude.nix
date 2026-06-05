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

          tmpfile=$(mktemp)
          trap 'rm -f "$tmpfile"' EXIT
          claude plugin list --available --json 2>/dev/null > "$tmpfile"

          installedIds=$(jq -r '.installed[].id' "$tmpfile")
          availablePlugins=$(jq -r --arg m "$marketplaceName" \
            '.available[] | select(.marketplaceName == $m) | .pluginId' "$tmpfile")

          while IFS= read -r plugin; do
            if [ -z "$plugin" ]; then continue; fi
            if echo "$installedIds" | grep -qx "$plugin@$marketplaceName"; then
              echo "Already installed: $plugin"
            else
              echo "Installing: $plugin"
              claude plugin install "$plugin"
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
