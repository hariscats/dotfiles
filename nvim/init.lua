-- Leader must be set before lazy.nvim and any <leader> mappings
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.undofile = true
vim.opt.confirm = true
vim.opt.scrolloff = 5
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.wrap = false

-- Reading code
vim.opt.cursorline = true
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
vim.opt.foldmethod = "indent"
vim.opt.foldlevel = 99
vim.opt.foldtext = ""
vim.opt.splitright = true
vim.opt.splitbelow = true

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- System clipboard: Windows uses win32yank, macOS uses pbcopy/pbpaste.
-- Plain y/p stay internal; <leader> variants talk to the OS clipboard.
vim.keymap.set({ "n", "x" }, "<leader>y", '"+y', { desc = "Yank to system clipboard" })
vim.keymap.set("n", "<leader>Y", '"+Y', { desc = "Yank to end of line to system clipboard" })
vim.keymap.set({ "n", "x" }, "<leader>p", '"+p', { desc = "Paste from system clipboard" })
vim.keymap.set({ "n", "x" }, "<leader>P", '"+P', { desc = "Paste before from system clipboard" })
vim.keymap.set("n", "<leader>ya", "<cmd>%y+<CR>", { desc = "Copy whole file to system clipboard" })

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("Notes", { clear = true }),
  pattern = "markdown",
  callback = function(args)
    -- Neovim 0.12+ already starts this in its bundled ftplugin.
    if not vim.treesitter.highlighter.active[args.buf] then
      vim.treesitter.start(args.buf)
    end
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en"
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
    vim.opt_local.conceallevel = 0
    -- Fold by heading; open files fully expanded
    vim.opt_local.foldmethod = "expr"
    vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    vim.opt_local.foldlevel = 99
    -- gf opens linked notes without typing .md; :find searches subfolders
    vim.opt_local.suffixesadd = ".md"
    vim.opt_local.path:append("**")
    for _, key in ipairs({ "j", "k" }) do
      vim.keymap.set("n", key, function()
        return vim.v.count == 0 and "g" .. key or key
      end, { buffer = true, expr = true })
    end
  end,
})

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to clone lazy.nvim:\n" .. out, vim.log.levels.ERROR)
    return
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    {
      "sainnhe/everforest",
      lazy = false,
      priority = 1000,
      config = function()
        vim.o.background = "dark"
        vim.g.everforest_background = "medium"
        vim.g.everforest_better_performance = 1
        vim.cmd.colorscheme("everforest")
      end,
    },
  },
  rocks = { enabled = false },
  performance = {
    rtp = {
      disabled_plugins = { "gzip", "tarPlugin", "zipPlugin", "tutor" },
    },
  },
})
