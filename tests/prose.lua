local api = vim.api
local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root)
vim.opt.rtp:append(root .. "/after")
vim.cmd("filetype plugin indent on")
vim.o.hidden = true
vim.o.wrap = false
vim.o.number = true
vim.o.relativenumber = true
vim.o.cursorline = true
vim.o.signcolumn = "yes"
vim.o.shiftwidth = 4
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.expandtab = true

local prose = require("prose")
prose.setup()
local assertions = 0
local next_buffer = 0

local function equal(actual, expected, message)
  assert(vim.deep_equal(actual, expected),
    message .. "\nexpected: " .. vim.inspect(expected) .. "\nactual: " .. vim.inspect(actual))
  assertions = assertions + 1
end

local function settle()
  vim.wait(20)
end

local function buffer(ft)
  vim.cmd("enew!")
  next_buffer = next_buffer + 1
  api.nvim_buf_set_name(0, root .. "/tests/prose-case-" .. next_buffer)
  vim.bo.filetype = ft
  settle()
  return api.nvim_get_current_buf()
end

local function mapping(key)
  return vim.fn.maparg(key, "n", false, true)
end

for _, ft in ipairs({ "lua", "markdown" }) do
  buffer(ft)
  local lines = {}
  for i = 1, 30 do
    lines[i] = string.rep("word ", 70)
  end
  api.nvim_buf_set_lines(0, 0, -1, false, lines)
  for _, count in ipairs({ 1, 2, 10, 20 }) do
    for _, motion in ipairs({
      { key = "h", start = { 5, 25 }, expected = { 5, 25 - count } },
      { key = "l", start = { 5, 25 }, expected = { 5, 25 + count } },
      { key = "j", start = { 5, 25 }, expected = { 5 + count, 25 } },
      { key = "k", start = { 25, 25 }, expected = { 25 - count, 25 } },
    }) do
      api.nvim_win_set_cursor(0, motion.start)
      -- Do not use normal!: the assertions must exercise the actual mappings.
      vim.cmd.normal(tostring(count) .. motion.key)
      equal(api.nvim_win_get_cursor(0), motion.expected, ft .. ": counted " .. count .. motion.key)
    end
  end
  api.nvim_win_set_cursor(0, { 1, 0 })
  vim.cmd.normal("j")
  if ft == "markdown" then
    equal(api.nvim_win_get_cursor(0)[1], 1, "bare j stays on the wrapped paragraph")
    equal(api.nvim_win_get_cursor(0)[2] > 0, true, "bare j advances by a screen line")
  else
    equal(api.nvim_win_get_cursor(0), { 2, 0 }, "bare j moves one physical code line")
  end
  vim.cmd.normal("k")
  equal(api.nvim_win_get_cursor(0), { 1, 0 }, ft .. ": bare k reverses bare j")
end

local code = buffer("lua")
for _, key in ipairs({ "j", "k", "0", "$" }) do
  vim.keymap.set("n", key, "5j", { buffer = code })
end
buffer("lua")
api.nvim_set_current_buf(code)
settle()
for _, key in ipairs({ "j", "k", "0", "$" }) do
  equal(mapping(key).rhs, "5j", "ordinary buffer entry must preserve " .. key)
end

local callback = function() return "j" end
vim.keymap.set("n", "j", callback, { buffer = code, expr = true, silent = true })
prose.apply()
prose.clear()
equal(mapping("j").callback, callback, "restore a callback mapping")
equal(mapping("j").expr, 1, "restore expression behavior")
equal(mapping("j").silent, 1, "restore mapping options")
equal(mapping("k").rhs, "5j", "restore a string mapping")

prose.apply()
vim.keymap.set("n", "j", "7j", { buffer = code })
vim.keymap.del("n", "k", { buffer = code })
prose.clear()
equal(mapping("j").rhs, "7j", "preserve a replacement made while prose is active")
equal(mapping("k"), {}, "do not resurrect a deliberately removed mapping")

buffer("lua")
vim.keymap.set("n", "j", "3j")
prose.apply()
prose.clear()
equal(mapping("j").rhs, "3j", "reveal the global mapping after prose")
equal(mapping("j").buffer, 0, "do not copy global mappings into the buffer")
vim.keymap.del("n", "j")

vim.wo.number = false
vim.wo.spell = true
vim.bo.spelllang = "en_gb"
vim.wo.colorcolumn = "100"
prose.apply()
prose.clear()
equal(vim.wo.number, false, "restore the original number setting")
equal(vim.wo.spell, true, "restore spell, not a global default")
equal(vim.bo.spelllang, "en_gb", "restore the original spell language")
equal(vim.wo.colorcolumn, "100", "restore a custom column guide")
prose.apply()
vim.wo.signcolumn = "yes:2"
vim.bo.spelllang = "en"
prose.clear()
equal(vim.wo.signcolumn, "yes:2", "preserve a window option changed by another owner")
equal(vim.bo.spelllang, "en", "preserve a changed spell language")
vim.wo.number = true
vim.wo.spell = false
vim.wo.signcolumn = "yes"
vim.wo.colorcolumn = ""

local markdown = buffer("markdown")
equal(vim.b.prose_mode, true, "Markdown opts in automatically")
equal(vim.bo.shiftwidth, 2, "Markdown retains its indent")
local first = api.nvim_get_current_win()
vim.cmd.vsplit()
local second = api.nvim_get_current_win()
prose.clear()
for _, win in ipairs({ first, second }) do
  equal(vim.wo[win].wrap, false, "restore wrapping in every split")
  equal(vim.wo[win].number, true, "restore numbers in every split")
  equal(vim.wo[win].spell, false, "restore spelling in every split")
end
api.nvim_set_current_win(first)
equal(mapping("j"), {}, "split switching must not restore prose mappings")
vim.cmd.only()

vim.cmd.ProseAuto()
vim.cmd("tab split")
prose.clear()
for _, win in ipairs(vim.fn.win_findbuf(markdown)) do
  equal(vim.wo[win].wrap, false, "restore inherited options across tabs")
  equal(vim.wo[win].number, true, "restore original values across tabs")
end
vim.cmd.tabonly()

buffer("lua")
local left = api.nvim_get_current_win()
vim.wo.number = false
vim.cmd.vsplit()
local right = api.nvim_get_current_win()
vim.wo.number = true
prose.apply()
prose.clear()
equal(vim.wo[left].number, false, "preserve each existing split's own baseline")
equal(vim.wo[right].number, true, "preserve the other split's own baseline")
vim.cmd.only()

buffer("markdown")
buffer("lua")
equal(vim.wo.wrap, false, "prose must not leak into a different code buffer")
equal(vim.wo.spell, false, "spelling must not leak into code")
equal(vim.wo.number, true, "line numbers return in code")
equal(mapping("j"), {}, "prose mappings remain buffer-local")

local revisited = buffer("markdown")
buffer("lua")
api.nvim_set_current_buf(revisited)
settle()
prose.clear()
equal(vim.wo.wrap, false, "restore the original baseline after revisiting Markdown")
equal(vim.wo.number, true, "revisiting Markdown must not capture prose as its baseline")

buffer("python")
equal(vim.bo.textwidth, 88, "Python text width")
equal(vim.wo.colorcolumn, "88", "Python column guide")
vim.bo.filetype = "lua"
settle()
equal(vim.bo.textwidth, 0, "undo Python text width on filetype change")
equal(vim.b.ft_colorcolumn, nil, "undo Python guide metadata")
equal(vim.wo.colorcolumn, "", "undo Python's window guide")

buffer("python")
buffer("lua")
equal(vim.wo.colorcolumn, "", "Python's guide must not leak across buffers")

local python = buffer("python")
buffer("lua")
api.nvim_set_current_buf(python)
buffer("lua")
equal(vim.wo.colorcolumn, "", "a revisited Python guide must not become the window default")

buffer("markdown")
vim.bo.filetype = "python"
settle()
equal(vim.b.prose_mode, false, "automatic prose follows filetype changes")
equal(vim.wo.wrap, false, "stop wrapping after Markdown becomes Python")
equal(vim.wo.colorcolumn, "88", "apply the incoming Python guide")
equal(mapping("j"), {}, "release prose mappings after a filetype change")
prose.apply()
prose.clear()
equal(vim.wo.colorcolumn, "88", "a prose toggle must preserve the Python guide")

buffer("gitcommit")
equal(vim.wo.colorcolumn, "51,73", "Git commit guides")
vim.bo.filetype = "text"
settle()
equal(vim.b.prose_colorcolumn, nil, "undo Git guide metadata")
equal(vim.bo.textwidth, 0, "undo Git text width")
equal(vim.wo.colorcolumn, "", "remove Git-only guides from other prose")

buffer("markdown")
prose.clear()
vim.bo.filetype = "text"
settle()
equal(vim.b.prose_mode, false, "an explicit off choice survives filetype changes")
vim.cmd.ProseAuto()
equal(vim.b.prose_mode, true, "ProseAuto removes the explicit override")

buffer("lua")
prose.apply()
vim.bo.filetype = "python"
settle()
equal(vim.b.prose_mode, true, "an explicit on choice survives filetype changes")
prose.clear()
equal(vim.wo.colorcolumn, "88", "restore the new filetype guide after an explicit toggle")

buffer("lua")
vim.keymap.set("n", "j", "4j", { buffer = 0 })
prose.apply()
api.nvim_buf_set_name(0, root .. "/tests/prose-renamed")
prose.clear()
equal(mapping("j").rhs, "4j", "renaming a buffer must preserve mapping ownership")

local ordinary = buffer("lua")
local current = api.nvim_get_current_win()
vim.cmd.vsplit()
local other = api.nvim_get_current_win()
buffer("markdown")
api.nvim_set_current_win(current)
api.nvim_win_set_buf(other, ordinary)
settle()
equal(vim.wo[other].wrap, false, "normalize a buffer changed in a noncurrent window")
equal(vim.wo[current].wrap, false, "do not change the current window's presentation")
vim.cmd.only()

buffer("lua")
prose.apply()
local floating = api.nvim_open_win(api.nvim_get_current_buf(), false, {
  relative = "editor", row = 1, col = 1, width = 20, height = 3, style = "minimal",
})
vim.wo[floating].wrap = false
prose.refresh()
equal(vim.wo[floating].wrap, false, "floating previews own their presentation")
prose.clear()
equal(vim.wo[floating].number, false, "do not restore split defaults into a floating preview")
api.nvim_win_close(floating, true)

local reopened = buffer("markdown")
api.nvim_buf_set_name(reopened, root .. "/tests/prose-reopened.md")
vim.cmd.bdelete()
api.nvim_set_current_buf(reopened)
settle()
equal(vim.wo.wrap, true, "reopened Markdown retains prose mode")
equal(mapping("j").rhs, "v:count == 0 ? 'gj' : 'j'", "reopened Markdown retains prose mappings")
prose.clear()
equal(vim.wo.wrap, false, "reopened Markdown still restores the original baseline")
equal(mapping("j"), {}, "reopened Markdown releases its mappings")

buffer("lua")
vim.bo.buftype = "nofile"
vim.wo.wrap = true
vim.keymap.set("n", "j", "2j", { buffer = 0 })
prose.refresh()
equal(vim.wo.wrap, true, "leave special-buffer presentation alone")
equal(mapping("j").rhs, "2j", "leave special-buffer mappings alone")

prose.setup()
equal(#api.nvim_get_autocmds({ group = "ProseMode", event = "WinEnter" }), 1,
  "setup remains idempotent")
print(("Prose regression assertions passed: %d"):format(assertions))
