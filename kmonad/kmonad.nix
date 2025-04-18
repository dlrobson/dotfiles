{ config, pkgs, lib, ... }:

{
  # Install KMonad package
  home.packages = with pkgs; [
    kmonad
  ];

  # Add your KMonad configuration file
  home.file = {
    ".config/thinkpad.kbd".source = ./thinkpad.kbd;
  };

  # Set up the systemd user service (disabled by default)
  systemd.user.services.kmonad-mapping = {
    Unit = {
      Description = "Start KMonad with custom mapping";
    };
    Service = {
      ExecStart = "${pkgs.kmonad}/bin/kmonad %h/.config/thinkpad.kbd";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}