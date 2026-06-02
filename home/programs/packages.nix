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

    activation = lib.optionalAttrs (cfg.profile == "ouster") {
      installCopilotPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        export PATH="${githubCopilotCli}/bin:${pkgs.git}/bin:$PATH"

        stateFile="${config.home.homeDirectory}/.local/share/copilot-cli/managed-plugins"
        desired="awesome-copilot-refactor@dlrobson-plugins frontend-design@dlrobson-plugins handbook-glab@dlrobson-plugins learning-output-style@dlrobson-plugins plugin-dev@dlrobson-plugins pr-review-toolkit@dlrobson-plugins superpowers@dlrobson-plugins"

        # Uninstall any previously-managed plugins that are no longer desired
        if [ -f "$stateFile" ]; then
          while IFS= read -r old; do
            if [[ " $desired " != *" $old "* ]]; then
              $DRY_RUN_CMD copilot plugin uninstall "''${old%%@*}" || true
            fi
          done < "$stateFile"
        fi

        $DRY_RUN_CMD copilot plugin marketplace add dlrobson/plugin-marketplace || true

        for plugin in $desired; do
          $DRY_RUN_CMD copilot plugin install "$plugin" || true
        done

        # Persist the new desired state for future reconciliation
        if [ -z "$DRY_RUN_CMD" ]; then
          mkdir -p "$(dirname "$stateFile")"
          printf '%s\n' $desired > "$stateFile"
        fi
      '';
    };
  };
}
