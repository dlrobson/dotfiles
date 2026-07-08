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
config.ssh_domains = {
	{
		name = "nixos-server",
		remote_address = "nixos-server",
		multiplexing = "WezTerm",
	},
}

return config
