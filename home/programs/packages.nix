{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.home-manager-configuration;
  githubCopilotCli = config.unstablePkgs.github-copilot-cli.overrideAttrs (_: {
    # The upstream install check runs `copilot --version`, which tries to
    # unpack to /var/empty in sandboxed builds and fails with EACCES.
    doInstallCheck = false;
  });
in
{
  home = {
    packages =
      with pkgs;
      [
        git-lfs
        htop
        less
        libnotify
        nixpkgs-fmt
        nodejs_24
        ripgrep
        config.unstablePkgs.glab
        githubCopilotCli
      ]
      ++ lib.optionals (cfg.profile == "ouster") [
        config.unstablePkgs.work-vpn-client
        config.unstablePkgs.slack
      ]
      ++ lib.optionals (cfg.profile == "desktop" || cfg.profile == "ouster") [
        config.unstablePkgs.code-cursor
      ];
  };

  systemd.user = lib.mkIf (cfg.profile == "ouster") {
    services.copilot-marketplace = {
      Unit.Description = "Install and update Copilot CLI marketplace plugins";
      Service = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "copilot-marketplace" ''
          export PATH="${githubCopilotCli}/bin:${pkgs.git}/bin:$PATH"

          stateFile="$HOME/.local/share/copilot-cli/managed-plugins"
          desired="awesome-copilot-refactor@dlrobson-plugins frontend-design@dlrobson-plugins handbook-glab@dlrobson-plugins learning-output-style@dlrobson-plugins plugin-dev@dlrobson-plugins pr-review-toolkit@dlrobson-plugins superpowers@dlrobson-plugins"

          if [ -f "$stateFile" ]; then
            while IFS= read -r old; do
              if [[ " $desired " != *" $old "* ]]; then
                copilot plugin uninstall "''${old%%@*}" || true
              fi
            done < "$stateFile"
          fi

          copilot plugin marketplace add dlrobson/plugin-marketplace || true

          for plugin in $desired; do
            copilot plugin install "$plugin" || true
          done

          mkdir -p "$(dirname "$stateFile")"
          printf '%s\n' $desired > "$stateFile"
        '';
      };
    };

    timers.copilot-marketplace = {
      Unit.Description = "Periodically update Copilot CLI marketplace plugins";
      Timer = {
        OnBootSec = "2min";
        OnCalendar = "daily";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
