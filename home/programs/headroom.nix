{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.sessionPath = [ "${config.home.homeDirectory}/.npm-global/bin" ];

  home.activation.headroom = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export npm_config_prefix="${config.home.homeDirectory}/.npm-global"
    ${pkgs.nodejs_24}/bin/npm install -g headroom-ai
  '';
}
