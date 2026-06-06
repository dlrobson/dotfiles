{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.home-manager-configuration;
in
{
  home = {
    packages =
      with pkgs;
      [
        git-lfs
        htop
        jq
        less
        libnotify
        nixpkgs-fmt
        nodejs_24
        ripgrep
        config.unstablePkgs.glab
      ]
      ++ lib.optionals (cfg.profile == "desktop") [
        config.unstablePkgs.code-cursor
      ];
  };
}
