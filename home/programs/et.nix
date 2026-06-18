{
  config,
  pkgs,
  lib,
  ...
}:

{
  options.et-server.enable = lib.mkEnableOption "Eternal Terminal server user service";

  config = {
    home.packages = [ pkgs.eternal-terminal ];

    systemd.user.services.etserver = lib.mkIf config.et-server.enable {
      Unit = {
        Description = "Eternal Terminal Server";
        After = [ "network.target" ];
      };
      Service = {
        ExecStart = "${pkgs.eternal-terminal}/bin/etserver --logtostderr";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
