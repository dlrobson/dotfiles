{
  config,
  pkgs,
  lib,
  ...
}:

let
  homeDirectory = builtins.getEnv "HOME";
  username = builtins.getEnv "USER";
in
{
  imports = [ ../home ];

  home-manager-configuration = {
    enable = true;
    profile = "desktop";
    inherit username homeDirectory;
  };

  nixpkgs.config.allowUnfree = true;
}
