local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Everforest Dark (medium) — matches Neovim's everforest theme
config.colors = {
  foreground = "#d3c6aa",
  background = "#2d353b",
  cursor_bg = "#d3c6aa",
  cursor_fg = "#2d353b",
  cursor_border = "#d3c6aa",
  selection_fg = "#d3c6aa",
  selection_bg = "#475258",
  ansi = { "#475258", "#e67e80", "#a7c080", "#dbbc7f", "#7fbbb3", "#d699b6", "#83c092", "#d3c6aa" },
  brights = { "#859289", "#e67e80", "#a7c080", "#dbbc7f", "#7fbbb3", "#d699b6", "#83c092", "#d3c6aa" },
}

-- Readability: extra line spacing; macOS renders smaller at the same size
config.line_height = 1.1
config.font_size = wezterm.target_triple:find("darwin") and 14 or 12

-- Zoom text (Ctrl/Cmd +/-) without resizing the window
config.adjust_window_size_when_changing_font_size = false

-- Minimal and quiet
config.window_padding = { left = 8, right = 8, top = 6, bottom = 6 }
config.hide_tab_bar_if_only_one_tab = true
config.audible_bell = "Disabled"
config.scrollback_lines = 10000

-- Ctrl+Alt+N: open Neovim in the notes folder in a new tab
config.keys = {
  {
    key = "n",
    mods = "CTRL|ALT",
    action = wezterm.action.SpawnCommandInNewTab({
      args = { "nvim", "." },
      cwd = wezterm.home_dir .. "/notes/",
    }),
  },
}

-- macOS and Linux use the login shell by default.
if wezterm.target_triple:find("windows") then
  config.default_prog = { "pwsh.exe", "-NoLogo" }
end

return config
