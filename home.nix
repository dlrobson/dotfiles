{
  config,
  pkgs,
  lib,
  profile ? "minimal",
  ...
}:

let
  homeDirectory = builtins.getEnv "HOME";
  username = builtins.getEnv "USER";
in
{
  imports = [ ./home ];

  home-manager-configuration = {
    enable = true;
    inherit profile username homeDirectory;
  };

  nixpkgs.config.allowUnfree = true;
}
