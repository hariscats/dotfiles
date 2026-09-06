-- Prose mode is turned on for gitcommit by lua/prose.lua; this only supplies
-- the git-specific column guides (subject limit, body wrap).
vim.b.prose_colorcolumn = "51,73"
vim.bo.textwidth = 72

local undo = "setlocal textwidth< | unlet! b:prose_colorcolumn"
vim.b.undo_ftplugin = (vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | ") or "") .. undo
