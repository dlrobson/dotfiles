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

return config
