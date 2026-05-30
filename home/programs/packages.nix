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
      ++ lib.optionals (cfg.profile == "desktop") [
        moonlight-qt
        config.unstablePkgs.code-cursor
      ];

  };
}
