local M = {}

function M.apply(name, background, p, terminal)
  vim.g.colors_name = nil
  vim.o.background = background
  vim.cmd.colorscheme("quiet")
  vim.g.colors_name = name

  local highlights = {
    Normal = { fg = p.fg, bg = p.bg },
    NormalNC = { link = "Normal" },
    NormalFloat = { fg = p.fg, bg = p.panel },
    FloatBorder = { fg = p.muted, bg = p.panel },
    FloatTitle = { fg = p.fg, bg = p.panel, bold = true },
    ColorColumn = { bg = p.line },
    CursorLine = { bg = p.line },
    CursorColumn = { bg = p.line },
    Cursor = { fg = p.cursor_text, bg = p.cursor },
    CursorInsert = { fg = p.bg, bg = p.insert_cursor },
    CursorIM = { link = "Cursor" },
    lCursor = { link = "Cursor" },
    TermCursor = { link = "Cursor" },
    LineNr = { fg = p.muted },
    CursorLineNr = { fg = p.fg, bg = p.line, bold = true },
    SignColumn = { fg = p.muted, bg = p.bg },
    EndOfBuffer = { fg = p.bg },
    NonText = { fg = p.border },
    Whitespace = { fg = p.border },
    SpecialKey = { fg = p.muted },
    Conceal = { fg = p.muted },
    FoldColumn = { fg = p.muted, bg = p.bg },
    Folded = { fg = p.muted, bg = p.panel },
    WinSeparator = { fg = p.border, bg = p.bg },
    VertSplit = { link = "WinSeparator" },
    Visual = { fg = p.fg, bg = p.selection },
    VisualNOS = { link = "Visual" },
    Search = { fg = p.fg, bg = p.search },
    IncSearch = { fg = p.bg, bg = p.yellow },
    CurSearch = { link = "IncSearch" },
    MatchParen = { fg = p.fg, bg = p.selection, bold = true },
    QuickFixLine = { fg = p.fg, bg = p.selection },
    StatusLine = { fg = p.fg, bg = p.panel },
    StatusLineNC = { fg = p.muted, bg = p.panel },
    TabLine = { fg = p.muted, bg = p.panel },
    TabLineFill = { bg = p.panel },
    TabLineSel = { fg = p.fg, bg = p.bg, bold = true },
    WinBar = { fg = p.fg, bg = p.bg, bold = true },
    WinBarNC = { fg = p.muted, bg = p.bg },
    Pmenu = { fg = p.fg, bg = p.panel },
    PmenuSel = { fg = p.fg, bg = p.selection },
    PmenuExtra = { fg = p.muted, bg = p.panel },
    PmenuExtraSel = { link = "PmenuSel" },
    PmenuKind = { fg = p.blue, bg = p.panel },
    PmenuKindSel = { link = "PmenuSel" },
    PmenuMatch = { fg = p.blue, bg = p.panel, bold = true },
    PmenuMatchSel = { fg = p.fg, bg = p.selection, bold = true },
    PmenuSbar = { bg = p.panel },
    PmenuThumb = { bg = p.border },
    WildMenu = { link = "PmenuSel" },
    Comment = { fg = p.muted, italic = true },
    Constant = { fg = p.purple },
    String = { fg = p.green },
    Identifier = { fg = p.fg },
    Function = { fg = p.blue },
    Statement = { fg = p.blue },
    PreProc = { fg = p.purple },
    Type = { fg = p.cyan },
    Special = { fg = p.yellow },
    Directory = { fg = p.blue },
    Title = { fg = p.fg, bold = true },
    Underlined = { fg = p.blue, underline = true },
    Todo = { fg = p.yellow, bg = p.panel, bold = true },
    Error = { fg = p.red, underline = true },
    ErrorMsg = { fg = p.red },
    WarningMsg = { fg = p.yellow },
    MoreMsg = { fg = p.green },
    Question = { fg = p.blue },
    ModeMsg = { fg = p.fg, bold = true },
    DiffAdd = { bg = p.diff_add },
    DiffChange = { bg = p.diff_change },
    DiffDelete = { fg = p.red, bg = p.diff_delete },
    DiffText = { bg = p.diff_text, bold = true },
    Added = { fg = p.green },
    Changed = { fg = p.blue },
    Removed = { fg = p.red },
    DiagnosticError = { fg = p.red },
    DiagnosticWarn = { fg = p.yellow },
    DiagnosticInfo = { fg = p.blue },
    DiagnosticHint = { fg = p.cyan },
    DiagnosticOk = { fg = p.green },
    SpellBad = { sp = p.red, undercurl = true },
    SpellCap = { sp = p.blue, undercurl = true },
    SpellRare = { sp = p.purple, undercurl = true },
    SpellLocal = { sp = p.cyan, undercurl = true },
    ["@markup.heading"] = { link = "Title" },
    ["@markup.strong"] = { bold = true },
    ["@markup.italic"] = { italic = true },
    ["@markup.strikethrough"] = { strikethrough = true },
    ["@markup.link"] = { fg = p.blue },
    ["@markup.link.label"] = { fg = p.blue },
    ["@markup.link.url"] = { fg = p.blue, underline = true },
    ["@markup.raw"] = { fg = p.yellow },
    ["@markup.quote"] = { fg = p.muted, italic = true },
    RenderMarkdownCode = { bg = p.panel },
    RenderMarkdownCodeInline = { fg = p.fg, bg = p.panel },
    RenderMarkdownBullet = { fg = p.muted },
    RenderMarkdownQuote = { fg = p.muted },
    RenderMarkdownDash = { fg = p.border },
    RenderMarkdownTableHead = { fg = p.muted },
    RenderMarkdownTableRow = { fg = p.muted },
  }

  for level = 1, 6 do
    highlights["@markup.heading." .. level] = { link = "Title" }
    highlights["RenderMarkdownH" .. level] = { link = "Title" }
    highlights["RenderMarkdownH" .. level .. "Bg"] = { bg = p.panel }
  end
  for group, definition in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, definition)
  end

  vim.g.terminal_ansi_colors = terminal
  for i, color in ipairs(terminal) do
    vim.g["terminal_color_" .. (i - 1)] = color
  end
end

return M
