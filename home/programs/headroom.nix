{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.activation.headroom = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.uv}/bin/uv tool install "headroom-ai[proxy]" --quiet
  '';
}
