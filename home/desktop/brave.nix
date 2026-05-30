{
  config,
  lib,
  pkgs,
  ...
}:

let
  isNixOS = builtins.pathExists "/etc/nixos";
in
{
  imports = [ ./nixgl-pkgs.nix ];

  programs.chromium = {
    package =
      if isNixOS then config.unstablePkgs.brave else config.lib.nixGL.wrap config.unstablePkgs.brave;

    extensions = [
      { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
      { id = "neebplgakaahbhdphmkckjjcegoiijjo"; } # Keepa
      { id = "idpbkophnbfijcnlffdmmppgnncgappc"; } # Rakuten
      { id = "nffaoalbilbmmfgbnbgppjihopabppdk"; } # Video Speed Controller
    ];
  };
}
