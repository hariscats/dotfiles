-- Tokyo Night Moon colors matching ~/.config/wezterm/wezterm.lua.
-- Kept local so Neovim also works without WezTerm or extra theme plugins.
local p = {
  bg = "#222436",
  fg = "#c8d3f5",
  cursor = "#c8d3f5",
  cursor_text = "#222436",
  insert_cursor = "#82aaff",
  muted = "#828bb8",
  panel = "#1e2030",
  line = "#2f334d",
  border = "#636da6",
  selection = "#2f334d",
  search = "#34548a",
  red = "#ff757f",
  green = "#c3e88d",
  yellow = "#ffc777",
  blue = "#82aaff",
  purple = "#c099ff",
  cyan = "#86e1fc",
  diff_add = "#29334a",
  diff_change = "#272d46",
  diff_delete = "#372638",
  diff_text = "#394b70",
}

require("config.theme").apply("tokyonight-moon", "dark", p, {
  "#1b1d2b", p.red, p.green, p.yellow,
  "#2f436e", p.purple, p.cyan, p.muted,
  "#444a73", p.red, p.green, p.yellow,
  p.blue, p.purple, p.cyan, p.fg,
})
