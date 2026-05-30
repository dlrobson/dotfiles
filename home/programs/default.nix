{ config, pkgs, ... }:

{
  imports = [
    ./bash.nix
    ./claude.nix
    ./direnv.nix
    ./fish.nix
    ./git.nix
    ./packages.nix
    ./rbw.nix
    ./ssh.nix
    ./tmux.nix
    ./vim.nix
  ];
}
