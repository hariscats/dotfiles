local uv = vim.uv or vim.loop
local fault, root = arg[1], arg[2]
local real_close = uv.fs_close
if fault == "os_tmpdir" then
  uv.os_tmpdir = function() return nil, "injected os_tmpdir failure" end
elseif fault == "cwd" then
  uv.cwd = function() return nil, "injected cwd failure" end
elseif fault == "mkstemp" then
  uv.fs_mkstemp = function() return nil, "injected mkstemp failure" end
elseif fault == "close" then
  uv.fs_close = function(fd)
    assert(real_close(fd))
    return nil, "injected close failure"
  end
elseif fault == "json" then
  vim.json.encode = function() error("injected json failure") end
elseif fault == "stdout" then
  io.stdout = { write = function() return nil, "injected stdout failure" end }
elseif fault == "flush" then
  io.stdout = {
    write = function() return true end,
    flush = function() return nil, "injected flush failure" end,
  }
else
  error("Unknown fault: " .. tostring(fault))
end
dofile(root .. "/scrollback-allocate.lua")
error("Allocator must exit nonzero on failure")
