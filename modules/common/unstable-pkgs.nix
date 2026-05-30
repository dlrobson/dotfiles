{
  config,
  lib,
  pkgs,
  ...
}:

let
  unstable = import (import ../../npins).nixpkgs-unstable {
    config = {
      allowUnfree = true;
    };
    inherit (pkgs.stdenv.hostPlatform) system;
  };
in
{
  options = {
    unstablePkgs = lib.mkOption {
      type = lib.types.attrs;
      description = "Unstable nixpkgs packages";
      default = { };
    };
  };

  config = {
    unstablePkgs = unstable;
  };
}
