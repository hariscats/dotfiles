local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.color_scheme = "Catppuccin Mocha"
config.default_prog = { [[C:\Program Files\PowerShell\7\pwsh.exe]], "-NoLogo" }

return config
