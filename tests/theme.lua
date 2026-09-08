vim.opt.rtp:prepend(vim.fn.getcwd())
vim.o.termguicolors = true

local ghostty_path, wezterm_path
for _, argument in ipairs(arg) do
  local path = argument:match("^%-%-wezterm=(.+)$")
  if path then
    wezterm_path = path
  else
    assert(not ghostty_path, "Pass one Ghostty theme path and/or --wezterm=<config path>")
    ghostty_path = argument
  end
end

-- Applying the light theme must also work from the previous dark-only theme.
vim.cmd.colorscheme("habamax")
vim.cmd.colorscheme("paper")
assert(vim.o.background == "light")
assert(vim.g.colors_name == "paper")

local function highlight(name)
  return vim.api.nvim_get_hl(0, { name = name, link = false })
end

local function luminance(rgb)
  local channels = {
    math.floor(rgb / 65536),
    math.floor(rgb / 256) % 256,
    rgb % 256,
  }
  for i, value in ipairs(channels) do
    value = value / 255
    channels[i] = value <= 0.04045 and value / 12.92 or ((value + 0.055) / 1.055) ^ 2.4
  end
  return channels[1] * 0.2126 + channels[2] * 0.7152 + channels[3] * 0.0722
end

local function contrast(a, b)
  a, b = luminance(a), luminance(b)
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05)
end

local readable_groups = {
  "Normal", "NormalFloat", "Cursor", "CursorInsert", "lCursor", "CursorIM", "TermCursor",
  "Visual", "Search", "IncSearch",
  "Comment", "String", "Function", "Statement", "Type", "Special",
  "Pmenu", "PmenuSel", "PmenuExtra", "PmenuKind", "PmenuMatch",
  "StatusLine", "StatusLineNC", "DiagnosticError", "DiagnosticWarn",
  "DiagnosticInfo", "DiagnosticHint",
  "LineNr", "Folded", "FloatBorder", "WinBar", "WinBarNC",
  "RenderMarkdownCode", "RenderMarkdownCodeInline", "RenderMarkdownQuote",
  "@markup.link.url", "@markup.raw", "@markup.quote",
}

local function assert_readable()
  local normal = highlight("Normal")
  for _, name in ipairs(readable_groups) do
    local group = highlight(name)
    assert(not group.reverse, name .. " must use explicit foreground/background colors")
    local ratio = contrast(group.fg or normal.fg, group.bg or normal.bg)
    assert(ratio >= 4.5, ("%s: %s contrast is only %.2f:1"):format(vim.g.colors_name, name, ratio))
  end
end

local normal = highlight("Normal")
assert(normal.bg == 0xfaf9f6 and normal.fg == 0x3f3a34)
assert_readable()
local cursor = highlight("Cursor")
local cursor_contrast = (luminance(normal.bg) + 0.05) / (luminance(cursor.bg) + 0.05)
assert(cursor.bg == 0xd3cec4 and cursor_contrast >= 1.4, "keep the light block distinct from the paper")
assert(cursor.fg == normal.fg, "the character under the block must retain its dark text color")
local insert_cursor = highlight("CursorInsert")
local insert_contrast = (luminance(normal.bg) + 0.05) / (luminance(insert_cursor.bg) + 0.05)
assert(insert_cursor.bg == 0x68645e and insert_contrast >= 4.5, "keep the insert bar easy to locate")
assert(highlight("SpellBad").undercurl, "keep spelling feedback")
assert(highlight("Title").bold, "preserve heading emphasis")
for level = 1, 6 do
  assert(highlight("RenderMarkdownH" .. level).fg == normal.fg)
  assert(highlight("RenderMarkdownH" .. level .. "Bg").bg == 0xf0eee8)
end
for i = 0, 15 do
  assert(vim.g["terminal_color_" .. i] == vim.g.terminal_ansi_colors[i + 1])
end

if ghostty_path then
  local colors, palette = {}, {}
  for _, line in ipairs(vim.fn.readfile(ghostty_path)) do
    local key, color = line:match("^([%w%-]+)%s*=%s*(#%x+)%s*$")
    if key then
      colors[key] = color
    end
    local index, entry = line:match("^palette%s*=%s*(%d+)=(#%x+)%s*$")
    if index then
      palette[tonumber(index)] = entry
    end
  end
  local expected = {
    background = normal.bg,
    foreground = normal.fg,
    ["cursor-color"] = highlight("Cursor").bg,
    ["cursor-text"] = highlight("Cursor").fg,
    ["selection-background"] = highlight("Visual").bg,
    ["selection-foreground"] = highlight("Visual").fg,
  }
  for key, value in pairs(expected) do
    assert(colors[key] == ("#%06x"):format(value), "Ghostty " .. key .. " differs from Neovim")
  end
  for i = 0, 15 do
    assert(palette[i] == vim.g["terminal_color_" .. i], "Ghostty palette entry " .. i .. " differs")
  end
end

vim.cmd.colorscheme("paper")
assert(highlight("Normal").bg == normal.bg, "theme reload must preserve the palette")
local paper_highlights = vim.api.nvim_get_hl(0, {})

vim.cmd.colorscheme("forest")
assert(vim.o.background == "dark" and vim.g.colors_name == "forest")
normal = highlight("Normal")
assert(normal.bg == 0x2d353b and normal.fg == 0xd3c6aa)
assert(contrast(normal.fg, normal.bg) >= 7, "prose should retain strong contrast without pure white")
assert_readable()
for _, name in ipairs({ "DiffAdd", "DiffChange", "DiffDelete", "DiffText" }) do
  local group = highlight(name)
  assert(contrast(group.fg or normal.fg, group.bg) >= 4.5, "readable " .. name)
end
cursor = highlight("Cursor")
assert(cursor.bg == 0xa7c080 and cursor.fg == normal.bg, "readable dark text inside the green block")
assert(contrast(cursor.bg, normal.bg) >= 4.5, "the block must remain easy to locate")
assert(highlight("CursorInsert").bg == normal.fg, "use a warm, visible insert bar")
assert(highlight("NormalNC").bg == normal.bg, "do not dim inactive prose windows")
assert(highlight("SpellBad").undercurl and not highlight("SpellBad").fg,
  "spelling feedback must not recolor the word")
assert(highlight("@markup.strong").bold and highlight("@markup.italic").italic)
for level = 1, 6 do
  local heading = highlight("RenderMarkdownH" .. level)
  assert(heading.fg == normal.fg and heading.bold)
  assert(highlight("RenderMarkdownH" .. level .. "Bg").bg == 0x272e33)
end
for i = 0, 15 do
  assert(vim.g["terminal_color_" .. i] == vim.g.terminal_ansi_colors[i + 1])
end

if wezterm_path then
  -- Evaluate just the supplied local config with stand-ins for WezTerm APIs.
  -- No WezTerm install or external config is needed for the default tests.
  local wezterm = {
    config_builder = function() return {} end,
    font_with_fallback = function(fonts) return fonts end,
    action = setmetatable({}, { __index = function()
      return function(value) return value end
    end }),
  }
  local load_config = assert(loadfile(wezterm_path, "t", {
    require = function(name)
      assert(name == "wezterm", "Unexpected dependency in WezTerm config: " .. name)
      return wezterm
    end,
  }))
  local colors = assert(load_config().colors, "WezTerm config must define its colors")
  local expected = {
    background = normal.bg,
    foreground = normal.fg,
    cursor_bg = cursor.bg,
    cursor_fg = cursor.fg,
    cursor_border = highlight("CursorInsert").bg,
    selection_bg = highlight("Visual").bg,
    selection_fg = highlight("Visual").fg,
    split = highlight("WinSeparator").fg,
  }
  for key, value in pairs(expected) do
    assert(colors[key] == ("#%06x"):format(value), "WezTerm " .. key .. " differs from Forest")
  end
  for i = 0, 7 do
    assert(colors.ansi[i + 1] == vim.g["terminal_color_" .. i], "WezTerm ANSI color " .. i .. " differs")
    assert(colors.brights[i + 1] == vim.g["terminal_color_" .. (i + 8)],
      "WezTerm bright color " .. i .. " differs")
  end
end

local forest_highlights = vim.api.nvim_get_hl(0, {})
vim.cmd.colorscheme("paper")
assert(vim.deep_equal(vim.api.nvim_get_hl(0, {}), paper_highlights),
  "switching to Paper must not retain Forest highlights")
vim.cmd.colorscheme("forest")
assert(vim.deep_equal(vim.api.nvim_get_hl(0, {}), forest_highlights),
  "switching to Forest must not retain Paper highlights")
vim.cmd.colorscheme("forest")
assert(vim.deep_equal(vim.api.nvim_get_hl(0, {}), forest_highlights),
  "reloading Forest must be idempotent")
print("Paper and Forest theme assertions passed")
