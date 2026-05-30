{ config, pkgs, ... }:

{
  programs.vim = {
    enable = true;
    extraConfig = ''
      " Sets it so that the backspace and arrow keys work properly
      set nocompatible
      set backspace=2
    '';
  };
}
