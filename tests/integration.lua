local api = vim.api
vim.g.config_integration_ok = false
local errors = {}
local original_notify = vim.notify
vim.notify = function(message, level, opts)
  if level == vim.log.levels.ERROR then
    errors[#errors + 1] = message
  end
  return original_notify(message, level, opts)
end

local function edit(extension)
  vim.cmd("enew!")
  vim.cmd.edit(vim.fn.fnameescape(vim.fn.tempname() .. extension))
end

edit(".py")
local python = api.nvim_get_current_buf()
api.nvim_buf_set_lines(python, 0, -1, false, { "answer=  42" })
local attached = vim.wait(10000, function()
  local clients = vim.lsp.get_clients({ bufnr = python })
  return #clients == 2 and vim.iter(clients):all(function(client)
    return client.initialized
  end)
end)
assert(attached, "Ruff and Basedpyright must both attach: " .. vim.inspect({
  filetype = vim.bo.filetype,
  lazy_command = vim.fn.exists(":Lazy"),
  clients = vim.tbl_map(function(client) return client.name end, vim.lsp.get_clients()),
  messages = api.nvim_exec2("messages", { output = true }).output,
}))

local original_format = vim.lsp.buf.format
local format_options
vim.lsp.buf.format = function(opts)
  format_options = opts
  return original_format(opts)
end
local format = vim.fn.maparg("<leader>f", "n", false, true).callback
assert(format, "Python formatting mapping is missing")
format()
vim.lsp.buf.format = original_format
assert(format_options.name == "ruff" and format_options.async == false
  and format_options.timeout_ms == 2000 and format_options.bufnr == python)
assert(api.nvim_buf_get_lines(python, 0, 1, false)[1] == "answer = 42",
  "Ruff formatting must finish before returning")

edit(".md")
api.nvim_buf_set_lines(0, 0, -1, false, {
  "# Heading", "", "> [!NOTE]", "> Body", "", "```python", "answer = 42", "```",
})
vim.wait(200)
assert(vim.b.prose_mode and vim.wo.wrap)
assert(vim.treesitter.highlighter.active[api.nvim_get_current_buf()])
vim.treesitter.get_parser():parse(true)
local movement_lines = {}
for i = 1, 30 do
  movement_lines[i] = string.rep("word ", 70)
end
api.nvim_buf_set_lines(0, 0, -1, false, movement_lines)
for _, keys in ipairs({ "10j", "10k", "10h", "10l" }) do
  local start = { 15, 25 }
  api.nvim_win_set_cursor(0, start)
  vim.cmd("normal! " .. keys)
  local expected = api.nvim_win_get_cursor(0)
  api.nvim_win_set_cursor(0, start)
  vim.cmd.normal(keys)
  assert(vim.deep_equal(api.nvim_win_get_cursor(0), expected),
    "counted " .. keys .. " must retain native behavior with plugins loaded")
end
assert(vim.o.guicursor:find("n%-v%-c%-sm:block%-Cursor/lCursor"))
assert(vim.o.guicursor:find("i%-ci%-ve:ver40%-CursorInsert"))
assert(vim.o.guicursor:find("a:blinkon0"))
local first = api.nvim_get_current_win()
vim.cmd.vsplit()
require("prose").clear()
assert(not vim.wo[first].wrap and not vim.wo.wrap, "real plugins must preserve split consistency")

api.nvim_exec_autocmds("InsertEnter", { modeline = false })
local cmp = require("cmp")
for _, key in ipairs({ "<CR>", "<C-Y>", "<C-E>", "<C-P>", "<C-N>", "<C-Space>", "<Up>", "<Down>" }) do
  assert(cmp.get_config().mapping[key], "missing explicit completion mapping " .. key)
end
assert(package.loaded["nvim-autopairs"], "autopairs must still load")
assert(#errors == 0, table.concat(errors, "\n"))
vim.notify = original_notify
for _, client in ipairs(vim.lsp.get_clients()) do
  client:stop(true)
end
vim.g.config_integration_ok = true
print("Plugin integration assertions passed")
