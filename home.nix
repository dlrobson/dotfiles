{
  config,
  pkgs,
  lib,
  ...
}:

let
  homeDirectory = builtins.getEnv "HOME";
  username = builtins.getEnv "USER";
  profile =
    let
      envProfile = builtins.getEnv "ROBSON_HOME_PROFILE";
    in
    if envProfile != "" then envProfile else "minimal";
in
{
  imports = [ ./home ];

  home-manager-configuration = {
    enable = true;
    inherit profile username homeDirectory;
  };

  nixpkgs.config.allowUnfree = true;
}
