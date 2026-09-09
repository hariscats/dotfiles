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

local function assert_captures(lang, cases, offset)
  local buf = api.nvim_get_current_buf()
  assert(vim.treesitter.highlighter.active[buf], "Tree-sitter must start automatically")
  local trees = vim.treesitter.get_parser(buf):parse(true)
  assert(not trees[1]:root():has_error(), "syntax fixtures must parse without errors")
  for _, case in ipairs(cases) do
    local row = case[1] - 1 + (offset or 0)
    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    local col = assert(line:find(case[2], 1, true), "missing fixture text: " .. case[2]) - 1
    local captures = vim.treesitter.get_captures_at_pos(buf, row, col)
    assert(vim.iter(captures):any(function(item)
      return item.lang == lang and item.capture == case[3]
    end), ("%s %q must have @%s: %s"):format(lang, case[2], case[3], vim.inspect(captures)))
  end
end

local python_lines = {
  "# A typed greeting.",
  "def greet(name: str, count: int = 2) -> str:",
  "    enabled = True",
  '    message = f"Hello {name}"',
  "    return message.upper() * count",
}
local python_captures = {
  { 1, "#", "comment" },
  { 2, "def", "keyword.function" },
  { 2, "greet", "function" },
  { 2, "name", "variable.parameter" },
  { 2, "str", "type.builtin" },
  { 2, "2", "number" },
  { 3, "True", "boolean" },
  { 4, "Hello", "string" },
  { 4, "name", "variable" },
  { 5, "return", "keyword.return" },
  { 5, "upper", "function.method.call" },
}
local go_lines = {
  "package main",
  "",
  "type User struct {",
  "    Name string",
  "}",
  "",
  "func greet(user User, count int) string {",
  "    // Keep the greeting short.",
  "    if count > 0 {",
  "        return user.Name",
  "    }",
  '    return "hello"',
  "}",
  "",
  "func main() {",
  '    println(greet(User{Name: "World"}, 2))',
  "}",
}
local go_captures = {
  { 1, "package", "keyword.import" },
  { 3, "User", "type.definition" },
  { 4, "Name", "variable.member" },
  { 4, "string", "type.builtin" },
  { 7, "func", "keyword.function" },
  { 7, "greet", "function" },
  { 7, "user", "variable.parameter" },
  { 7, "User", "type" },
  { 8, "//", "comment" },
  { 9, "if", "keyword.conditional" },
  { 9, "0", "number" },
  { 10, "user", "variable" },
  { 10, "Name", "property" },
  { 12, "hello", "string" },
  { 16, "println", "function.builtin" },
  { 16, "greet", "function.call" },
}

edit(".md")
assert(not require("lazy.core.config").plugins["nvim-lspconfig"]._.loaded,
  "reading Markdown must not load Python LSP setup")
assert(not package.loaded.cmp and not package.loaded.luasnip,
  "reading Markdown must not eagerly load completion or snippets")

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
api.nvim_buf_set_lines(python, 0, -1, false, python_lines)
assert_captures("python", python_captures)

edit(".go")
assert(vim.bo.filetype == "go")
api.nvim_buf_set_lines(0, 0, -1, false, go_lines)
assert_captures("go", go_captures)

for _, case in ipairs({
  { "go.mod", "gomod", { "module example.com/minimal", "", "go 1.22" } },
  { "go.sum", "gosum", { "example.com/dependency v1.0.0 h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" } },
  { "go.work", "gowork", { "go 1.22", "", "use ." } },
}) do
  vim.cmd("enew!")
  vim.cmd.edit(vim.fn.fnameescape(vim.fs.joinpath(vim.fn.tempname(), case[1])))
  assert(vim.bo.filetype == case[2], case[1] .. " must use its Go filetype")
  api.nvim_buf_set_lines(0, 0, -1, false, case[3])
  assert(vim.treesitter.highlighter.active[api.nvim_get_current_buf()])
  local parser = vim.treesitter.get_parser()
  assert(parser:lang() == case[2] and not parser:parse(true)[1]:root():has_error())
  assert(#vim.treesitter.get_captures_at_pos(0, 0, 0) > 0, case[1] .. " must have syntax captures")
end

local markdown_lines = {
  "# Heading", "", "> [!NOTE]", "> Body with **bold**, *italic*, and `inline code`.",
  "", "[link](https://example.com)", "", "```python",
}
local python_offset = #markdown_lines
vim.list_extend(markdown_lines, python_lines)
vim.list_extend(markdown_lines, { "```", "", "```go" })
local go_offset = #markdown_lines
vim.list_extend(markdown_lines, go_lines)
vim.list_extend(markdown_lines, { "```", "", "```golang" })
local golang_offset = #markdown_lines
vim.list_extend(markdown_lines, { "package main", "var answer = 42", "```" })
edit(".md")
api.nvim_buf_set_lines(0, 0, -1, false, markdown_lines)
vim.wait(200)
assert(vim.g.colors_name == "tokyonight-moon" and vim.o.background == "dark")
local function assert_tokyonight_moon_highlights()
  local function hl(name)
    return api.nvim_get_hl(0, { name = name, link = false })
  end
  assert(hl("Normal").bg == 0x222436 and hl("Normal").fg == 0xc8d3f5)
  assert(hl("NormalFloat").bg == 0x1e2030 and hl("Pmenu").bg == 0x1e2030)
  assert(hl("Cursor").bg == 0xc8d3f5 and hl("Cursor").fg == 0x222436)
  assert(hl("CursorInsert").bg == 0x82aaff)
  assert(hl("@variable").fg == 0xc8d3f5 and hl("@variable.parameter").fg == 0xffc777)
  assert(hl("@keyword").fg == 0xc099ff and hl("@function").fg == 0x82aaff)
  assert(hl("@type").fg == 0x86e1fc and hl("@string").fg == 0xc3e88d)
  assert(hl("RenderMarkdownCodeInline").fg == 0xffc777 and not hl("RenderMarkdownCode").fg)
  for level, color in ipairs({ 0xffc777, 0xc3e88d, 0x82aaff, 0xc099ff, 0x86e1fc, 0xff757f }) do
    assert(hl("RenderMarkdownH" .. level).fg == color)
    local panel = hl("RenderMarkdownH" .. level .. "Bg")
    assert(panel.bg == 0x1e2030 and panel.fg == color)
  end
end
assert_tokyonight_moon_highlights()
assert(vim.b.prose_mode and vim.wo.wrap)
assert_captures("markdown", { { 1, "Heading", "markup.heading.1" } })
assert_captures("markdown_inline", {
  { 4, "bold", "markup.strong" },
  { 4, "italic", "markup.italic" },
  { 4, "inline code", "markup.raw" },
  { 6, "link", "markup.link.label" },
})
assert_captures("python", python_captures, python_offset)
assert_captures("go", go_captures, go_offset)
assert_captures("go", { { 2, "42", "number" } }, golang_offset)
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
vim.cmd.colorscheme("paper")
vim.cmd.colorscheme("tokyonight-moon")
vim.wait(200)
assert_tokyonight_moon_highlights()
assert(#errors == 0, table.concat(errors, "\n"))
vim.notify = original_notify
for _, client in ipairs(vim.lsp.get_clients()) do
  client:stop()
end
vim.wait(2000, function() return #vim.lsp.get_clients() == 0 end)
vim.g.config_integration_ok = true
print("Plugin integration assertions passed")
