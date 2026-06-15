{ config, pkgs, ... }:

{
  home.packages = with pkgs; [ fzf xclip ]; # required by fzf-tmux-url plugin

  programs.tmux = {
    enable = true;
    mouse = true;
    historyLimit = 100000;
    terminal = "screen-256color";
    extraConfig = ''
      set -g focus-events on
      set -g automatic-rename off

      # Open new panes/windows in the current pane's working directory
      bind '"' split-window -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"
    '';

    plugins = with pkgs.tmuxPlugins; [
      cpu
      battery
      {
        plugin = fzf-tmux-url;
        extraConfig = "set -g @fzf-url-copy-cmd 'xclip -selection clipboard'";
      }
      {
        plugin = yank;
        extraConfig = "set -g @yank_selection_mouse 'clipboard'";
      }
      {
        plugin = resurrect;
        extraConfig = "set -g @resurrect-capture-pane-contents 'on'";
      }
      {
        plugin = continuum;
        extraConfig = "set -g @continuum-restore 'on'";
      }
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor "mocha"
          set -g @catppuccin_window_status_style "rounded"
          set -g @catppuccin_window_text " #W"
          set -g @catppuccin_window_current_text " #W"

          set -g status-right-length 100
          set -g status-left-length 100
          set -g status-left ""
          set -g status-right "#{E:@catppuccin_status_application}"
          set -agF status-right "#{E:@catppuccin_status_cpu}"
          set -ag status-right "#{E:@catppuccin_status_session}"
          set -ag status-right "#{E:@catppuccin_status_uptime}"
          set -agF status-right "#{E:@catppuccin_status_battery}"
        '';
      }
    ];
  };
}
