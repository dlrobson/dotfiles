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

      # Neovim's OSC52 clipboard provider wraps its sequence in a DCS
      # passthrough envelope (see the clipboard block in neovim.nix) because
      # tmux's own OSC52 relay drops it; without this, "+y does nothing under
      # tmux. Also lets apps' terminal notifications and progress bars reach
      # Ghostty instead of being swallowed.
      set -g allow-passthrough on
      # Accept OSC 52 clipboard writes from apps inside tmux (Pi, Claude Code)
      # and relay them to the outer terminal. The default, `external`, only
      # relays tmux's own copies and ignores sequences from running programs.
      set -g set-clipboard on
      # Distinguish Shift+Enter from plain Enter so Claude Code's newline
      # shortcut works inside tmux; pair with a truecolor advert for the
      # Catppuccin theme to render with full 24-bit color.
      set -s extended-keys on
      # Pi (and modern apps) parse CSI-u for modified keys; tmux defaults to the
      # older xterm modifyOtherKeys format. Both Pi and Claude Code handle CSI-u.
      set -s extended-keys-format csi-u
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
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor "mocha"
          set -g @catppuccin_window_status_style "rounded"

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
