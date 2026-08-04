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

import { writeFileSync } from "node:fs";

const NOTIFY_SEND = "@notifySend@";
const TMUX = "@tmux@";

const TITLE = "opencode";
const MESSAGE = "opencode finished";

const ESC = "\x1b";
const BEL = "\x07";

/**
 * Ghostty renders OSC 777 as a desktop notification. Unlike notify-send this
 * needs no dbus session and no notification daemon, which is why it is the
 * primary path here.
 *
 * Claude Code hands the sequence back to the harness to emit; a plugin has to
 * write it to the controlling terminal itself. That is safe mid-render: OSC
 * 777 neither draws nor moves the cursor, so it cannot corrupt the TUI.
 *
 * Inside tmux the sequence would be consumed by tmux rather than forwarded to
 * Ghostty, so wrap it in tmux's passthrough (DCS tmux; ... ST) — which needs
 * `allow-passthrough on`, already set in tmux.nix:19. Passthrough requires
 * every ESC in the payload to be doubled.
 */
function terminalNotify() {
  const osc = `${ESC}]777;notify;${TITLE};${MESSAGE}${BEL}`;
  const sequence = process.env.TMUX
    ? `${ESC}Ptmux;${osc.replaceAll(ESC, ESC + ESC)}${ESC}\\`
    : osc;

  // /dev/tty is the controlling terminal regardless of how stdio is
  // redirected, so it is the right target when opencode is launched from a
  // shell. It fails with ENXIO when there is no controlling terminal at all
  // (a detached or systemd-run process), in which case stderr is worth a try
  // — but only if it is itself a terminal, otherwise the escape bytes would
  // land in a log file as garbage.
  try {
    writeFileSync("/dev/tty", sequence);
  } catch {
    if (process.stderr.isTTY) process.stderr.write(sequence);
  }
}

export const NotifyPlugin = async ({ $ }) => {
  return {
    event: async ({ event }) => {
      if (event.type !== "session.idle") return;

      // Every target is independent and best-effort: no controlling terminal
      // when run headless, no tmux outside tmux, no dbus without a running
      // notification daemon. None of them should ever take down the session.
      try {
        terminalNotify();
      } catch {}

      // Kept alongside OSC 777 for parity with the Claude hooks, and because
      // it is the path that works in a non-Ghostty terminal. It needs a
      // notification daemon on the session bus, so it is expected to fail
      // silently on a headless box.
      try {
        const dbus =
          process.env.DBUS_SESSION_BUS_ADDRESS ??
          `unix:path=/run/user/${process.getuid()}/bus`;
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
