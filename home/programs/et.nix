{ pkgs, ... }:

{
  home.packages = [ pkgs.eternal-terminal ];

  systemd.user.services.etserver = {
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
}
