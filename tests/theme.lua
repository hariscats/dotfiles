vim.opt.rtp:prepend(vim.fn.getcwd())
vim.o.termguicolors = true

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

local normal = highlight("Normal")
assert(normal.bg == 0xfaf9f6 and normal.fg == 0x3f3a34)
for _, name in ipairs({
  "Normal", "NormalFloat", "Cursor", "CursorInsert", "lCursor", "CursorIM", "TermCursor",
  "Visual", "Search", "IncSearch",
  "Comment", "String", "Function", "Statement", "Type", "Special",
  "Pmenu", "PmenuSel", "PmenuExtra", "PmenuKind", "PmenuMatch",
  "StatusLine", "StatusLineNC", "DiagnosticError", "DiagnosticWarn",
  "DiagnosticInfo", "DiagnosticHint",
}) do
  local group = highlight(name)
  assert(not group.reverse, name .. " must use explicit foreground/background colors")
  local fg = luminance(group.fg or normal.fg)
  local bg = luminance(group.bg or normal.bg)
  local ratio = (math.max(fg, bg) + 0.05) / (math.min(fg, bg) + 0.05)
  assert(ratio >= 4.5, ("%s contrast is only %.2f:1"):format(name, ratio))
end

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

if arg[1] then
  local colors, palette = {}, {}
  for _, line in ipairs(vim.fn.readfile(arg[1])) do
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
print("Paper theme assertions passed")
