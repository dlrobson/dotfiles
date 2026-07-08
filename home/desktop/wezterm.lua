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

-- Splits the current pane and attaches the new one directly to the
-- nixos-server mux domain, rather than `wezterm connect` popping a whole new
-- top-level window. Matches Ghostty's own default new_split:right/down keys
-- (Ctrl+Shift+O / Ctrl+Shift+E) rather than inventing new ones.
config.keys = {
	{
		key = "o",
		mods = "CTRL|SHIFT",
		action = wezterm.action.SplitPane({
			direction = "Right",
			command = { domain = { DomainName = "nixos-server" } },
		}),
	},
	{
		key = "e",
		mods = "CTRL|SHIFT",
		action = wezterm.action.SplitPane({
			direction = "Down",
			command = { domain = { DomainName = "nixos-server" } },
		}),
	},
}

return config
