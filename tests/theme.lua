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
  "Constant", "Boolean", "Character", "Operator", "Delimiter",
  "Pmenu", "PmenuSel", "PmenuExtra", "PmenuKind", "PmenuMatch",
  "StatusLine", "StatusLineNC", "DiagnosticError", "DiagnosticWarn",
  "DiagnosticInfo", "DiagnosticHint",
  "LineNr", "Folded", "FloatBorder", "WinBar", "WinBarNC",
  "RenderMarkdownCode", "RenderMarkdownCodeInline", "RenderMarkdownQuote", "RenderMarkdownBullet",
  "RenderMarkdownLink", "RenderMarkdownChecked", "RenderMarkdownUnchecked", "RenderMarkdownTodo",
  "RenderMarkdownTableHead",
  "@variable", "@variable.builtin", "@variable.parameter", "@variable.member", "@property",
  "@function", "@function.builtin", "@constructor", "@keyword", "@type", "@type.builtin",
  "@number", "@boolean", "@constant.builtin", "@string", "@string.escape", "@attribute",
  "@punctuation.delimiter", "@punctuation.bracket",
  "@lsp.type.variable", "@lsp.type.parameter", "@lsp.type.property", "@lsp.type.decorator",
  "@markup.link.url", "@markup.raw", "@markup.raw.block", "@markup.list", "@markup.quote",
  "@markup.strong", "@markup.italic", "@markup.heading",
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

local function assert_syntax_colors()
  local normal = highlight("Normal")
  for _, name in ipairs({ "@variable", "@lsp.type.variable", "@markup.raw.block" }) do
    assert(highlight(name).fg == normal.fg, name .. " must not inherit the bundled theme's gray")
  end
  local links = {
    ["@keyword"] = "Statement",
    ["@function.builtin"] = "Function",
    ["@type.builtin"] = "Type",
    ["@constructor"] = "Type",
    ["@number"] = "Constant",
    ["@constant.builtin"] = "Boolean",
    ["@property"] = "@variable.member",
    ["@punctuation.delimiter"] = "Delimiter",
    ["@punctuation.bracket"] = "Delimiter",
    ["@lsp.type.parameter"] = "@variable.parameter",
    ["@lsp.type.property"] = "@variable.member",
    ["@lsp.type.decorator"] = "@attribute",
    RenderMarkdownCodeInline = "@markup.raw",
    RenderMarkdownBullet = "@markup.list",
  }
  for name, target in pairs(links) do
    assert(highlight(name).fg == highlight(target).fg, name .. " must match " .. target)
  end
  assert(highlight("Statement").fg ~= highlight("Function").fg, "keywords must stand apart from functions")
  assert(highlight("Constant").fg ~= highlight("String").fg, "numbers must stand apart from strings")
  assert(highlight("@variable.parameter").fg ~= normal.fg, "parameters must stand apart from variables")
  assert(not highlight("RenderMarkdownCode").fg, "code-block shading must not override injected syntax colors")
end

local function assert_markdown_colors()
  local headings = { "Constant", "String", "Function", "Statement", "Type", "DiagnosticError" }
  local distinct = {}
  for level, source in ipairs(headings) do
    local expected = highlight(source).fg
    local heading = highlight("RenderMarkdownH" .. level)
    local panel = highlight("RenderMarkdownH" .. level .. "Bg")
    assert(heading.fg == expected and heading.bold, "each heading level needs its own accent")
    assert(highlight("@markup.heading." .. level).fg == expected, "source and rendered headings must match")
    assert(panel.fg == expected, "heading text must stay colored when its icon is hidden")
    assert(contrast(expected, panel.bg) >= 4.5, "heading accents must remain readable")
    assert(not distinct[expected], "heading levels must not share one color")
    distinct[expected] = true
  end
  assert(highlight("@markup.strong").fg == highlight("Constant").fg)
  assert(highlight("@markup.italic").fg == highlight("Statement").fg)
  assert(highlight("RenderMarkdownLink").fg == highlight("@markup.link.label").fg)
  assert(highlight("RenderMarkdownQuote").fg == highlight("@markup.quote").fg)
  assert(highlight("RenderMarkdownChecked").fg == highlight("String").fg)
  assert(highlight("RenderMarkdownUnchecked").fg == highlight("Constant").fg)
end

local normal = highlight("Normal")
assert(normal.bg == 0xfaf9f6 and normal.fg == 0x3f3a34)
assert_readable()
assert_syntax_colors()
assert_markdown_colors()
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

vim.cmd.colorscheme("tokyonight-moon")
assert(vim.o.background == "dark" and vim.g.colors_name == "tokyonight-moon")
normal = highlight("Normal")
assert(normal.bg == 0x222436 and normal.fg == 0xc8d3f5)
assert(contrast(normal.fg, normal.bg) >= 10, "Tokyo Night Moon prose should retain strong contrast")
assert_readable()
assert_syntax_colors()
assert_markdown_colors()
for _, name in ipairs({ "DiffAdd", "DiffChange", "DiffDelete", "DiffText" }) do
  local group = highlight(name)
  assert(contrast(group.fg or normal.fg, group.bg) >= 4.5, "readable " .. name)
end
cursor = highlight("Cursor")
assert(cursor.bg == normal.fg and cursor.fg == normal.bg, "readable dark text inside the light block")
assert(contrast(cursor.bg, normal.bg) >= 4.5, "the block must remain easy to locate")
assert(highlight("CursorInsert").bg == 0x82aaff, "use a visible blue insert bar")
assert(highlight("NormalNC").bg == normal.bg, "do not dim inactive prose windows")
assert(highlight("SpellBad").undercurl and not highlight("SpellBad").fg,
  "spelling feedback must not recolor the word")
assert(highlight("@markup.strong").bold and highlight("@markup.italic").italic)
for level = 1, 6 do
  assert(highlight("RenderMarkdownH" .. level .. "Bg").bg == 0x1e2030)
end
assert(vim.g.terminal_color_4 == "#2f436e",
  "PowerShell directory backgrounds need a dark ANSI blue")
for i = 0, 15 do
  assert(vim.g["terminal_color_" .. i] == vim.g.terminal_ansi_colors[i + 1])
end

if wezterm_path then
  -- Evaluate just the supplied local config with stand-ins for WezTerm APIs.
  -- No WezTerm install or external config is needed for the default tests.
  local wezterm = {
    config_builder = function() return {} end,
    target_triple = "x86_64-unknown-linux-gnu",
    font = function(name) return name end,
    action_callback = function(callback) return callback end,
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
    assert(colors[key] == ("#%06x"):format(value), "WezTerm " .. key .. " differs from Tokyo Night Moon")
  end
  for i = 0, 7 do
    assert(colors.ansi[i + 1] == vim.g["terminal_color_" .. i], "WezTerm ANSI color " .. i .. " differs")
    assert(colors.brights[i + 1] == vim.g["terminal_color_" .. (i + 8)],
      "WezTerm bright color " .. i .. " differs")
  end
end

local moon_highlights = vim.api.nvim_get_hl(0, {})
vim.cmd.colorscheme("paper")
assert(vim.deep_equal(vim.api.nvim_get_hl(0, {}), paper_highlights),
  "switching to Paper must not retain Tokyo Night Moon highlights")
vim.cmd.colorscheme("tokyonight-moon")
assert(vim.deep_equal(vim.api.nvim_get_hl(0, {}), moon_highlights),
  "switching to Tokyo Night Moon must not retain Paper highlights")
vim.cmd.colorscheme("tokyonight-moon")
assert(vim.deep_equal(vim.api.nvim_get_hl(0, {}), moon_highlights),
  "reloading Tokyo Night Moon must be idempotent")
vim.cmd.colorscheme("forest")
assert(highlight("Normal").bg == 0x2d353b and highlight("Normal").fg == 0xd3c6aa,
  "the Forest alternative must remain available")
assert_readable()
assert_syntax_colors()
assert_markdown_colors()
vim.cmd.colorscheme("tokyonight-moon")
assert(vim.deep_equal(vim.api.nvim_get_hl(0, {}), moon_highlights),
  "returning from Forest must restore Tokyo Night Moon exactly")
print("Paper, Forest, and Tokyo Night Moon theme assertions passed")
