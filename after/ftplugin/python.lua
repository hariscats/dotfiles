-- Python: PEP 8 four-space indent, and ruff's default 88-column limit.
local b = vim.bo

b.expandtab = true
b.shiftwidth = 4
b.tabstop = 4
b.softtabstop = 4
b.textwidth = 88

-- The window overlay in prose.lua also owns filetype-specific guides.
vim.b.ft_colorcolumn = "88"

local undo = "setlocal expandtab< shiftwidth< tabstop< softtabstop< textwidth<"
  .. " | unlet! b:ft_colorcolumn"
vim.b.undo_ftplugin = (vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | ") or "") .. undo

-- Indentation is provided by Neovim's bundled Python indent script.
