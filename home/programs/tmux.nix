{ pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    mouse = true;
    historyLimit = 100000;
    # tmux's own terminfo entry (not xterm-256color) - correctly declares key
    # capabilities so special keys like Home/End pass through to programs
    # running inside tmux (e.g. Neovim). RGB/extended-keys below are separate:
    # they describe the *outer* terminal (Ghostty), not this.
    terminal = "tmux-256color";
    extraConfig = ''
      set -g focus-events on
      set -g automatic-rename off

      # Let Claude Code's desktop notifications and terminal progress bar
      # pass through tmux to Ghostty (otherwise tmux swallows them).
      set -g allow-passthrough on
      # Distinguish Shift+Enter from plain Enter so Claude Code's newline
      # shortcut works inside tmux; pair with a truecolor advert for the
      # Catppuccin theme to render with full 24-bit color.
      set -s extended-keys on
      set -as terminal-features 'xterm*:extkeys:RGB'

      # Open new panes/windows in the current pane's working directory
      bind '"' split-window -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"
    '';

    plugins = with pkgs.tmuxPlugins; [
      cpu
      battery
      {
        plugin = yank;
        extraConfig = "set -g @yank_selection_mouse 'clipboard'";
      }
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
          # Match the saved command by substring (~) — it's saved as an
          # absolute wrapper path (/.../bin/claude ...), so resurrect's default
          # anchored (^claude) match never fires. NOTE: do not use resurrect's
          # `match->restore` inline strategy here; the `->` is parsed as a shell
          # redirect inside resurrect's unquoted `eval set`, which corrupts the
          # restore list and silently drops the pane.
          set -g @resurrect-processes '~claude'
        '';
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
          set -g @catppuccin_window_text " #W#{@claude_done}"
          set -g @catppuccin_window_current_text " #W#{@claude_done}"
          set-hook -g session-window-changed "run-shell 'tmux set-window-option -t #{window_id} -u @claude_done'"

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
