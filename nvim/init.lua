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

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

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
      "catppuccin/nvim",
      name = "catppuccin",
      lazy = false,
      priority = 1000,
      opts = {
        flavour = "mocha",
        compile_path = vim.fn.stdpath("cache") .. "/catppuccin",
        auto_integrations = false,
        integrations = { render_markdown = true },
      },
      config = function(_, opts)
        require("catppuccin").setup(opts)
        vim.cmd.colorscheme("catppuccin-nvim")
      end,
    },
    {
      "MeanderingProgrammer/render-markdown.nvim",
      ft = "markdown",
      opts = {
        latex = { enabled = false },
        sign = { enabled = false },
      },
    },
  },
  rocks = { enabled = false },
  performance = {
    rtp = {
      disabled_plugins = { "gzip", "tarPlugin", "zipPlugin", "tutor" },
    },
  },
})
