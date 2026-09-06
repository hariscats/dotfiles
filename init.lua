assert(vim.fn.has("nvim-0.12") == 1, "This configuration requires Neovim 0.12 or newer")

-- Leader must be set before lazy.nvim loads any plugin.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

--------------------------------------------------------------------------
-- Options
--------------------------------------------------------------------------
local o = vim.o

o.number = true
o.relativenumber = true
o.mouse = "a"
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.softtabstop = 4
o.smartindent = true
o.termguicolors = true

-- Off for code (Neovim defaults it on); prose mode turns it back on together
-- with `linebreak`, so wrapping only ever happens at word boundaries.
o.wrap = false

o.ignorecase = true
o.smartcase = true
o.undofile = true
o.updatetime = 250
o.scrolloff = 5
o.splitright = true
o.splitbelow = true
o.confirm = true

-- Minimal chrome: one global statusline, no `~` filler past end-of-buffer,
-- a signcolumn that is always present so text never jitters.
o.laststatus = 3
o.signcolumn = "yes"
o.cursorline = true
-- Explicit colors in every mode; Ghostty controls the TUI bar's pixel thickness.
o.guicursor = "n-v-c-sm:block-Cursor/lCursor,i-ci-ve:ver40-CursorInsert,"
  .. "r-cr-o:hor30-CursorInsert,t:block-TermCursor,a:blinkon0"
o.winborder = "rounded"
vim.opt.fillchars = { eob = " ", vert = "│", horiz = "─", fold = " " }

-- Warm-white paper, with a matching Ghostty theme and no theme plugin.
vim.cmd.colorscheme("paper")

--------------------------------------------------------------------------
-- Diagnostics
--------------------------------------------------------------------------
vim.diagnostic.config({
  virtual_text = false, -- no inline error text; use `<leader>e` to read it
  underline = false,
  severity_sort = true,
  -- Deliberately plain glyphs: all four exist in IBM Plex Mono itself, so
  -- none of them fall back to an unrelated system font at a different weight
  -- or width. Severity reads from the color, not from the icon.
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "×",
      [vim.diagnostic.severity.WARN] = "!",
      [vim.diagnostic.severity.HINT] = "›",
      [vim.diagnostic.severity.INFO] = "»",
    },
  },
  float = { border = "rounded", source = true },
})

--------------------------------------------------------------------------
-- Keymaps
--------------------------------------------------------------------------
local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic" })

map("n", "<leader>z", function()
  require("prose").toggle()
end, { desc = "Toggle prose mode" })

map("n", "<leader>m", "<cmd>RenderMarkdown buf_toggle<CR>",
  { desc = "Toggle markdown rendering" })

-- Reversible prose settings and filetype-specific window guides.
require("prose").setup()

vim.api.nvim_create_user_command("ConfigParsers", function()
  require("config.treesitter").install()
end, { desc = "Install and update parsers, waiting for completion" })

--------------------------------------------------------------------------
-- Autocommands
--------------------------------------------------------------------------
local aug = vim.api.nvim_create_augroup("UserConfig", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
  group = aug,
  callback = function()
    vim.hl.on_yank({ higroup = "Visual", timeout = 150 })
  end,
})

--------------------------------------------------------------------------
-- Plugins (lazy.nvim)
--------------------------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath .. "/lua/lazy/init.lua") then
  assert(not vim.uv.fs_stat(lazypath),
    "Incomplete lazy.nvim installation at " .. lazypath .. "; move it aside before restarting")

  local lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json"
  local lock = vim.json.decode(table.concat(vim.fn.readfile(lockfile), "\n"))
  local commit = lock["lazy.nvim"] and lock["lazy.nvim"].commit
  assert(type(commit) == "string" and #commit == 40 and commit:match("^%x+$"),
    "lazy-lock.json must contain a full lazy.nvim commit")

  local clone = vim.system({
    "git", "clone", "--filter=blob:none", "--no-checkout",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  }, { text = true }):wait(120000)
  assert(clone.code == 0, "Failed to clone lazy.nvim:\n" .. (clone.stderr or ""))

  local checkout = vim.system({
    "git", "-C", lazypath, "checkout", "--detach", commit,
  }, { text = true }):wait(120000)
  assert(checkout.code == 0, "Failed to restore locked lazy.nvim:\n" .. (checkout.stderr or ""))
end
vim.opt.rtp:prepend(lazypath)

require("plugins")
