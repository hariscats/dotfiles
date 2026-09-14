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
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en"
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.conceallevel = 0
    for _, key in ipairs({ "j", "k" }) do
      vim.keymap.set("n", key, function()
        return vim.v.count == 0 and "g" .. key or key
      end, { buffer = true, expr = true })
    end
  end,
})
