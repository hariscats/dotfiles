-- Markdown: wrap, spell, and conceal all come from prose mode (lua/prose.lua),
-- and rendering from render-markdown.nvim. Only the markup-specific indent
-- belongs here -- lists nest at two spaces, not the global four.
local b = vim.bo

b.shiftwidth = 2
b.tabstop = 2
b.softtabstop = 2

local undo = "setlocal shiftwidth< tabstop< softtabstop<"
vim.b.undo_ftplugin = (vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | ") or "") .. undo
