/**
 * Desktop and tmux notifications when opencode goes idle.
 *
 * The opencode counterpart to the Stop/Notification hooks in `claude.nix`.
 * Kept as a local plugin file (auto-loaded from ~/.config/opencode/plugins/)
 * rather than an npm entry in `settings.plugin`, so it stays pinned to the
 * generation rather than being fetched by Bun at startup.
 *
 * Binary paths are substituted in by Nix; see `opencode.nix`.
 */

const NOTIFY_SEND = "@notifySend@";
const TMUX = "@tmux@";

const TITLE = "opencode";
const MESSAGE = "opencode finished";

export const NotifyPlugin = async ({ $ }) => {
  return {
    event: async ({ event }) => {
      if (event.type !== "session.idle") return;

      // opencode may be launched from a context that never exported the bus
      // address (a bare tty, a systemd unit), so fall back to the well-known
      // per-uid path the way the Claude Code hook does.
      const dbus =
        process.env.DBUS_SESSION_BUS_ADDRESS ??
        `unix:path=/run/user/${process.getuid()}/bus`;

      // Notification failures must never take down the session, and each
      // target is independent: no tmux outside tmux, no dbus on a headless
      // box. Try both, swallow both.
      try {
        await $`${NOTIFY_SEND} ${TITLE} ${MESSAGE}`
          .env({ ...process.env, DBUS_SESSION_BUS_ADDRESS: dbus })
          .quiet();
      } catch {}

      const pane = process.env.TMUX_PANE;
      if (pane) {
        try {
          // Same @claude_done variable the tmux config already renders in the
          // window title and clears on window change (tmux.nix:61-63). The
          // name is Claude-specific but the mechanism is not, and a second
          // indicator would mean a second slot in the status line.
          await $`${TMUX} set-window-option -t ${pane} @claude_done " !"`.quiet();
        } catch {}
      }
    },
  };
};
