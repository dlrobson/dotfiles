{ config, pkgs, lib, ... }:

let
  # Detect if running in a container
  isContainer = builtins.pathExists "/.dockerenv" || lib.pathExists "/run/.containerenv";
  
  # Detect if running on NixOS
  isNixOS = builtins.pathExists "/etc/nixos";
in
{
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";

  programs.fish = {
    enable = true;
    plugins = [
      {
        name = "plugin-git";
        src = pkgs.fishPlugins.plugin-git.src;
      }
    ];
    
    functions = {
      clean_branches = ''
        git fetch --all --prune && git branch -D (git branch -vv | string match -r ': gone]' | string match -rv '\*' | awk '{ print $1; }')
      '';
    };
  };

  programs.git = {
    enable = true;
    userName = "Daniel Robson";
    userEmail = "danr.236@gmail.com";
    
    includes = [
      {
        condition = "hasconfig:remote.*.url:git@gitlab.com:ouster/*/**";
        contents = {
          user.email = "daniel.robson@ouster.io";
        };
      }
    ];

    extraConfig = {
      pull.rebase = true;
      core.editor = "vi";
      init.defaultBranch = "main";
    };
  };

  programs.vim = {
    enable = true;
    extraConfig = ''
      " Sets it so that the backspace and arrow keys work properly
      set nocompatible
      set backspace=2
    '';
  };

  programs.tmux = {
    enable = true;
    mouse = true;
    historyLimit = 100000;
    terminal = "screen-256color";

    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = yank;
        extraConfig = "set -g @yank_selection_mouse 'clipboard'";
      }
      {
        plugin = continuum;
        extraConfig = "set -g @continuum-restore 'on'";
      }
      {
        plugin = resurrect;
        extraConfig = "set -g @resurrect-capture-pane-contents 'on'";
      }
      {
        plugin = gruvbox;
        extraConfig = "set -g @tmux-gruvbox 'dark'";
      }
    ];
  };

  programs.bash = {
    enable = true;
    initExtra = ''
      [ -x /bin/fish ] && SHELL=/bin/fish exec fish
    '';
  };

  # Import KMonad configuration only when not in a container and not on NixOS
  imports = lib.optional ((!isContainer) && (!isNixOS)) ./kmonad/kmonad.nix;
  
  programs.home-manager.enable = true;
  home.stateVersion = "24.11";
}
