{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ../../modules/common/unstable-pkgs.nix ];

  programs.rbw = {
    enable = true;
    package = config.unstablePkgs.rbw;
    settings = {
      email = "danr.236@gmail.com";
      pinentry = pkgs.pinentry-gnome3;
    };
  };
}
