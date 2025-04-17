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
  home.stateVersion = "24.11";
  programs.home-manager.enable = true;

  # Import KMonad configuration only when not in a container and not on NixOS
  imports = lib.optional ((!isContainer) && (!isNixOS)) ./kmonad/kmonad.nix;
  
  programs.bash = {
    enable = true;
    initExtra = ''
      # Source nix
      if [ -e $HOME/.nix-profile/etc/profile.d/nix.sh ]; then
        . $HOME/.nix-profile/etc/profile.d/nix.sh
      fi

      # Source fish (from here: https://nixos.wiki/wiki/Fish#Setting_fish_as_your_shell)
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };

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
}
