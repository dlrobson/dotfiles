{ pkgs, config, ... }:
let
  isNixOS = builtins.pathExists "/etc/nixos";
  isDesktop = config.home-manager-desktop-configuration.enable;
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
        # there as the mux server. Only nixGL-wrap on non-NixOS *desktop*
        # machines - that's for wezterm-gui's OpenGL rendering, which a
        # headless mux-server host never needs.
        (
          if isDesktop && !isNixOS then
            config.lib.nixGL.wrap config.unstablePkgs.wezterm
          else
            config.unstablePkgs.wezterm
        )
      ];
  };
}
