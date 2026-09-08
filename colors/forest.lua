-- Everforest-inspired colors matching ~/.config/wezterm/wezterm.lua.
-- Kept local so Neovim also works without WezTerm or extra theme plugins.
local p = {
  bg = "#2d353b",
  fg = "#d3c6aa",
  cursor = "#a7c080",
  cursor_text = "#2d353b",
  insert_cursor = "#d3c6aa",
  muted = "#9da9a0",
  panel = "#272e33",
  line = "#343f44",
  border = "#4f585e",
  selection = "#425047",
  search = "#4f5144",
  red = "#e67e80",
  green = "#a7c080",
  yellow = "#dbbc7f",
  blue = "#7fbbb3",
  purple = "#d699b6",
  cyan = "#83c092",
  diff_add = "#343e35",
  diff_change = "#303b44",
  diff_delete = "#382d32",
  diff_text = "#425047",
}

require("config.theme").apply("forest", "dark", p, {
  "#475258", p.red, p.green, p.yellow, p.blue, p.purple, p.cyan, p.fg,
  p.muted, p.red, p.green, p.yellow, p.blue, p.purple, p.cyan, "#e6ddcb",
})
