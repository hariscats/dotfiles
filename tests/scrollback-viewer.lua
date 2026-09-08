local M = {}
local uv = vim.uv or vim.loop

function M.lines()
  return {
    "oldest history",
    "/Users/Source code Ü/" .. string.rep("very-long-directory/", 100) .. "main.go:123",
    "C:\\Source code Ü\\" .. string.rep("long-directory\\", 100) .. "script.py:42",
    "$(echo do-not-execute); 'quotes' % # | lua error('not code')",
    "vim: set modeline modelineexpr ft=scrollback_injected:",
    "newest visible output",
  }
end

function M.prepare()
  local mode = vim.env.SCROLLBACK_TEST_MODE
  if mode == "read-failure" then
    vim.fn.readfile = function() error("injected read failure") end
  elseif mode == "cleanup-failure" then
    local original = uv.fs_unlink
    local attempts = 0
    uv.fs_unlink = function(path)
      attempts = attempts + 1
      if attempts == 1 then return nil, "injected cleanup failure", "EACCES" end
      return original(path)
    end
  end
end

function M.check()
  local mode, path = vim.env.SCROLLBACK_TEST_MODE, vim.env.SCROLLBACK_TEST_PATH
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  assert(vim.o.loadplugins == false and vim.g.scrollback_user_init_ran == nil)
  assert(not vim.o.modeline and not vim.o.modelineexpr and not vim.o.exrc)
  assert(not vim.o.undofile and vim.o.undolevels == -1 and vim.o.shada == "")
  assert(vim.o.shadafile == "NONE" and not vim.o.backup and not vim.o.writebackup)
  assert(vim.bo.buftype == "nofile" and vim.bo.bufhidden == "wipe")
  assert(not vim.bo.modifiable and vim.bo.readonly and not vim.bo.modified)
  assert(vim.bo.filetype == "" and not vim.bo.swapfile and vim.fn.swapname(0) == "")
  assert(vim.env.WEZTERM_SCROLLBACK_FILE == nil and vim.env.WEZTERM_SCROLLBACK_VIEWER == nil)
  assert(not pcall(vim.api.nvim_buf_set_lines, 0, 0, 0, false, { "must not change" }))
  assert(vim.fn.maparg("q", "n") == "<Cmd>qa!<CR>")
  if mode == "missing" or mode == "read-failure" then
    assert(lines[1]:find("Could not read scrollback export", 1, true))
  elseif mode == "empty" then
    assert(#lines == 1 and lines[1] == "")
  else
    assert(vim.deep_equal(lines, M.lines()), vim.inspect(lines))
    assert(vim.api.nvim_win_get_cursor(0)[1] == #lines)
  end
  if mode == "cleanup-failure" then
    assert(uv.fs_stat(path), "Fault should retain file until exit retry")
    assert(vim.b.scrollback_error:find("injected cleanup failure", 1, true))
    assert(vim.o.statusline:find("FAILED", 1, true))
  else
    assert(not uv.fs_stat(path), "Export must be removed before viewer exit")
  end
end

return M
