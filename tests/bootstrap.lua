local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json"
local original_stat = vim.uv.fs_stat
local original_system = vim.system
local original_readfile = vim.fn.readfile
local lock = vim.json.decode(table.concat(original_readfile(lockfile), "\n"))
local commit = lock["lazy.nvim"].commit
local calls, loaded, scenario

package.preload.plugins = function()
  loaded = true
end
vim.uv.fs_stat = function(path, ...)
  if path == lazypath .. "/lua/lazy/init.lua" then
    return scenario == "installed" and { type = "file" } or nil
  elseif path == lazypath then
    return scenario == "incomplete" and { type = "directory" } or nil
  end
  return original_stat(path, ...)
end
vim.fn.readfile = function(path, ...)
  if path == lockfile and scenario == "invalid-lock" then
    return { '{"lazy.nvim":{"commit":"main"}}' }
  end
  return original_readfile(path, ...)
end
vim.system = function(argv)
  calls[#calls + 1] = argv
  return {
    wait = function(_, timeout)
      assert(timeout == 120000)
      local failed = (scenario == "clone-failure" and argv[2] == "clone")
        or (scenario == "checkout-failure" and argv[4] == "checkout")
      return { code = failed and 1 or 0, stderr = failed and "simulated git failure" or "" }
    end,
  }
end

local function run(name)
  scenario, calls, loaded = name, {}, false
  package.loaded.plugins = nil
  return pcall(dofile, root .. "/init.lua")
end

assert(run("fresh"))
assert(loaded and #calls == 2, "load plugins only after cloning and checking out the lock")
assert(vim.list_contains(calls[1], "--no-checkout"), "do not execute an unpinned checkout")
assert(vim.deep_equal(calls[2], { "git", "-C", lazypath, "checkout", "--detach", commit }),
  "bootstrap the exact lazy.nvim commit")

local ok, err = run("clone-failure")
assert(not ok and err:find("simulated git failure") and #calls == 1 and not loaded)
ok, err = run("checkout-failure")
assert(not ok and err:find("simulated git failure") and not loaded)
ok, err = run("invalid-lock")
assert(not ok and err:find("full lazy.nvim commit") and #calls == 0 and not loaded)
ok, err = run("incomplete")
assert(not ok and err:find("Incomplete lazy.nvim installation") and #calls == 0 and not loaded)
assert(run("installed"))
assert(loaded and #calls == 0, "ordinary startup must not clone or check out installed plugins")

vim.uv.fs_stat = original_stat
vim.system = original_system
vim.fn.readfile = original_readfile
print("Bootstrap regression assertions passed")
