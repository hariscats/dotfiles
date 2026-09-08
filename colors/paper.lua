-- A warm-white writing theme, built on Neovim's bundled quiet colorscheme.
local p = {
  bg = "#faf9f6",
  fg = "#3f3a34",
  cursor = "#d3cec4",
  cursor_text = "#3f3a34",
  insert_cursor = "#68645e",
  muted = "#726b62",
  panel = "#f0eee8",
  line = "#f3f1ec",
  border = "#d3cec4",
  selection = "#dce5e9",
  search = "#eee0b7",
  red = "#a0443b",
  green = "#4f6746",
  yellow = "#846025",
  blue = "#3b6078",
  purple = "#775677",
  cyan = "#3f6b68",
  diff_add = "#e5ecdf",
  diff_change = "#e3eaf0",
  diff_delete = "#f3e3df",
  diff_text = "#cedce5",
}

-- Keep this palette in sync with ~/.config/ghostty/themes/paper.
require("config.theme").apply("paper", "light", p, {
  p.fg, p.red, p.green, p.yellow, p.blue, p.purple, p.cyan, "#dedad2",
  p.muted, "#b14b41", "#596e4b", "#8c682c", "#426b83", "#866086", "#477672", p.bg,
})
