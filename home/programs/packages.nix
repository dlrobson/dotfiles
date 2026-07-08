{ pkgs, config, ... }:
let
  isNixOS = builtins.pathExists "/etc/nixos";
in
{
  home = {
    packages =
      (with pkgs; [
        bat
        fd
        fzf
        gh
        git-lfs
        htop
        jq
        less
        libnotify
        nixd
        nodejs_24
        ripgrep
      ])
      ++ [
        # Also needed on headless/minimal hosts (not just desktop.nix's
        # Ghostty-alternative GUI trial): WezTerm's SSH multiplexing
        # requires the exact same wezterm version to be present and on
        # PATH on the remote host too, so the SSH backend can launch it
        # there as the mux server.
        (if isNixOS then config.unstablePkgs.wezterm else config.lib.nixGL.wrap config.unstablePkgs.wezterm)
      ];
  };
}
