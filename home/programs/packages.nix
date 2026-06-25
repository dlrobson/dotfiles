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
    packages = with pkgs; [
      bat
      fd
      fzf
      gh
      git-lfs
      htop
      jq
      less
      libnotify
      nixpkgs-fmt
      nixd
      nodejs_24
      ripgrep
    ];
  };
}
