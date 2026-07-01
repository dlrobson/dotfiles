{ config, pkgs, ... }:

{
  imports = [
    ./bash.nix
    ./claude.nix
    ./direnv.nix
    ./et.nix
    ./fish.nix
    ./git.nix
    ./packages.nix
    ./rbw.nix
    ./ssh.nix
    ./tmux.nix
    ./vim.nix
  ];
}
