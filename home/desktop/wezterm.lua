local wezterm = require("wezterm")

local config = wezterm.config_builder()

-- Matches Ghostty's dark/light Catppuccin split (theme = "dark:Catppuccin
-- Frappe,light:Catppuccin Latte" in ghostty's config).
local function scheme_for_appearance(appearance)
	if appearance:find("Dark") then
		return "Catppuccin Frappe"
	else
		return "Catppuccin Latte"
	end
end

config.color_scheme = scheme_for_appearance(wezterm.gui.get_appearance())

-- `wezterm connect nixos-server` attaches to a persistent mux session on the
-- remote (survives disconnects/reboots of the local machine), instead of
-- `wezterm ssh` which is just a plain, non-multiplexed SSH connection.
--
-- Deliberately a unix domain with a proxy_command through the system `ssh`
-- binary, not a built-in `ssh_domains` entry: wezterm's own SSH client
-- (libssh-based) rejects pubkey auth that plain `ssh` accepts fine - a known
-- upstream limitation (wezterm/wezterm#5398), not something fixable from
-- config. `wezterm cli proxy` just streams the mux protocol over stdio, so
-- real `ssh` (with its full agent/cert/key support) does all the auth work.
--
-- Leaving ssh_domains unset doesn't mean "no ssh domains": wezterm defaults
-- it to wezterm.default_ssh_domains(), which auto-generates one per Host in
-- ~/.ssh/config - including "nixos-server", using the same broken libssh
-- client. That auto-generated domain shadows the unix domain below (same
-- name), silently undoing this workaround, so it must be disabled explicitly.
config.ssh_domains = {}

config.unix_domains = {
	{
		name = "nixos-server",
		proxy_command = { "ssh", "nixos-server", "--", "wezterm", "cli", "proxy" },
	},
}

-- Silently reattach any pre-existing nixos-server tabs/panes on every
-- launch (e.g. from a previous session that outlived a local disconnect) -
-- that's the actual point of a mux domain. domain:attach() (unlike the
-- AttachDomain key assignment below) does NOT spawn a pane when the domain
-- is empty, so this is a no-op rather than cluttering every startup with a
-- fresh remote tab when there's nothing to reattach to.
wezterm.on("gui-startup", function()
	local mux = wezterm.mux
	mux.get_domain("nixos-server"):attach()
end)

-- SplitPane can't jump straight from a local pane into a different mux
-- domain in one step - wezterm requires the pane being split to already
-- belong to that domain (confirmed by hitting its "pane_id 0 is not a
-- ClientPane" error). So entry into the domain has to happen first, via
-- AttachDomain, which imports nixos-server's tabs/panes into *this* window
-- (unlike `wezterm connect`, which always opens a separate top-level
-- window) - spawning a default pane as a new tab if none exist yet.
--
-- Bound to Ctrl+Shift+A, not the more obvious U: Ctrl+Shift+U is both
-- wezterm's own default CharSelect binding *and* IBus's system-wide Unicode
-- entry shortcut on Linux, so it never even reached wezterm's key handler.
config.keys = {
	{
		key = "a",
		mods = "CTRL|SHIFT",
		action = wezterm.action.AttachDomain("nixos-server"),
	},
	-- Once inside that domain's tab, these are plain splits with no domain
	-- override - they default to splitting within whatever domain the
	-- current pane already belongs to, so they correctly do a *remote*
	-- split there while still behaving as ordinary local splits everywhere
	-- else. Matches Ghostty's own default new_split:right/down keys.
	{
		key = "o",
		mods = "CTRL|SHIFT",
		action = wezterm.action.SplitPane({ direction = "Right" }),
	},
	{
		key = "e",
		mods = "CTRL|SHIFT",
		action = wezterm.action.SplitPane({ direction = "Down" }),
	},
}

return config
