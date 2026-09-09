vim.opt.rtp:prepend(vim.fn.getcwd())
local ts = require("config.treesitter")
local messages, starts = {}, {}
local original_runtime_file = vim.api.nvim_get_runtime_file
local original_add = vim.treesitter.language.add
local original_start = vim.treesitter.start
local original_notify_once = vim.notify_once
local available = false
local load_error

for _, lang in ipairs({ "python", "go", "gomod", "gosum", "gowork", "markdown", "markdown_inline" }) do
  assert(vim.list_contains(ts.languages, lang), lang .. " must be explicitly provisioned")
end
assert(vim.treesitter.language.get_lang("golang") == "go", "Go fences must accept the golang alias")

vim.api.nvim_get_runtime_file = function()
  return available and { "/test/parser.so" } or {}
end
vim.treesitter.language.add = function()
  if load_error then
    error(load_error)
  end
  return true
end
vim.treesitter.start = function(buf, lang)
  starts[#starts + 1] = { buf = buf, lang = lang }
end
vim.notify_once = function(message, level)
  messages[#messages + 1] = { message = message, level = level }
end

vim.bo.filetype = "text"
ts.start(0)
vim.wait(20)
assert(#messages == 0, "unsupported filetypes should remain quiet")

vim.bo.filetype = "python"
ts.start(0)
vim.wait(20)
assert(#messages == 1 and messages[1].message:find("ConfigParsers"),
  "a missing configured parser must have an actionable warning")
assert(messages[1].level == vim.log.levels.WARN)
assert(#starts == 0, "never start without a parser")

available = true
load_error = "incompatible parser ABI"
ts.start(0)
vim.wait(20)
assert(messages[2].message:find(load_error, 1, true), "retain the original parser error")
assert(messages[2].level == vim.log.levels.ERROR, "load errors are not missing-parser warnings")

load_error = nil
ts.start(0)
assert(#starts == 1 and starts[1].lang == "python", "start an available parser")
for _, ft in ipairs({ "go", "gomod", "gosum", "gowork", "markdown" }) do
  vim.bo.filetype = ft
  ts.start(0)
  assert(starts[#starts].lang == ft, "start the parser for " .. ft)
end
vim.bo.filetype = "python"
vim.treesitter.start = function() error("invalid highlights query") end
ts.start(0)
vim.wait(20)
assert(messages[3].message:find("invalid highlights query", 1, true), "surface query failures")

vim.api.nvim_get_runtime_file = original_runtime_file
vim.treesitter.language.add = original_add
vim.treesitter.start = original_start
vim.notify_once = original_notify_once

local calls = {}
local succeeded = true
local install_succeeded = true
package.loaded["nvim-treesitter"] = {
  update = function()
    calls[#calls + 1] = "update"
    return { wait = function(_, timeout)
      assert(timeout == 300000)
      calls[#calls + 1] = "update finished"
      return succeeded
    end }
  end,
  install = function(languages)
    assert(vim.deep_equal(languages, ts.languages))
    calls[#calls + 1] = "install"
    return { wait = function(_, timeout)
      assert(timeout == 300000)
      calls[#calls + 1] = "install finished"
      return install_succeeded
    end }
  end,
}
ts.install()
assert(vim.deep_equal(calls, { "update", "update finished", "install", "install finished" }),
  "provisioning must wait for each operation")
succeeded = false
local ok, err = pcall(ts.install)
assert(not ok and err:find("Parser update failed"), "provisioning failures must propagate")
succeeded, install_succeeded = true, false
ok, err = pcall(ts.install)
assert(not ok and err:find("Parser installation failed"), "missing-parser installation failures must propagate")
print("Tree-sitter regression assertions passed")
