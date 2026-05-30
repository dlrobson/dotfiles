{ config, ... }:

{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    stdlib = ''
      PATH_add ${config.home.homeDirectory}/.npm-global/bin
    '';
  };
}
