{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      bat
      fd
      fzf
      gh
      git-lfs
      htop
      jq
      less
      nixd
      nodejs_24
      ripgrep
    ];
  };
}
