{ pkgs, ... }:

# We sometimes may need to use NixGL on non-NixOS devices:
# https://github.com/nix-community/nixGL/issues/114#issuecomment-2741822320
let
  nixgl = (import ../../npins).nixGL;
in
{
  targets.genericLinux.nixGL = {
    packages = import nixgl { inherit pkgs; };
    defaultWrapper = "mesa";
  };
}
