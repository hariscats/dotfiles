local uv = vim.uv or vim.loop
local root = assert(uv.cwd())
local nvim = vim.v.progpath
local passed = 0

local function test(name, fn)
  local ok, err = xpcall(fn, debug.traceback)
  if not ok then
    io.stderr:write("FAIL " .. name .. "\n" .. err .. "\n")
    os.exit(1)
  end
  passed = passed + 1
end

local function contains(text, expected)
  assert(text and text:find(expected, 1, true), tostring(text) .. " does not contain " .. expected)
end

local function mocked(fn)
  local original_open, original_remove, original_getenv = io.open, os.remove, os.getenv
  local original_wezterm = package.loaded.wezterm
  local state = {
    target = "aarch64-apple-darwin",
    config_dir = "C:/Users/Example Ü/WezTerm config",
    basename = ".wezterm-scrollback-Ab12Cd",
    path = "/test exports/Example Ü/.wezterm-scrollback-Ab12Cd",
    text = "oldest history\n" .. string.rep("long/path/", 100) .. "source.py:12\nvisible output",
    calls = {}, removals = {}, errors = {}, opens = 0,
  }
  local tab = {
    activate = function()
      if state.activation_error then error(state.activation_error) end
      state.activated = true
    end,
  }
  local mux = {
    spawn_tab = function(_, options)
      state.spawn = options
      assert(state.written == state.text and state.closed, "Spawned before export was closed")
      if state.spawn_error then error(state.spawn_error) end
      if state.spawn_nil then return nil end
      return tab, {}, {}
    end,
  }
  local window = {
    mux_window = function()
      if state.window_error then error(state.window_error) end
      return mux
    end,
    toast_notification = function(_, title, message)
      assert(title == "Scrollback to Neovim")
      state.toast = message
      if state.toast_error then error(state.toast_error) end
    end,
  }
  local pane = {
    get_dimensions = function()
      if state.dimensions_error then error(state.dimensions_error) end
      return { scrollback_rows = state.rows or 50321, viewport_rows = 24 }
    end,
    get_logical_lines_as_text = function(_, rows)
      assert(rows == 50321, "Must capture history plus viewport exactly once")
      if state.capture_error then error(state.capture_error) end
      return state.text
    end,
  }
  io.open = function(path, mode)
    state.opens = state.opens + 1
    assert(path == state.path and mode == "wb")
    if state.open_throw then error(state.open_throw) end
    if state.open_error then return nil, state.open_error end
    return {
      write = function(_, text)
        if state.write_throw then error(state.write_throw) end
        if state.write_error then return nil, state.write_error end
        state.written = text
        return true
      end,
      close = function()
        state.closed = true
        if state.close_throw then error(state.close_throw) end
        if state.close_error then return nil, state.close_error end
        return true
      end,
    }
  end
  os.remove = function(path)
    assert(path == state.path)
    state.removals[#state.removals + 1] = path
    if state.remove_throw then error(state.remove_throw) end
    if state.remove_error then return nil, state.remove_error end
    return true
  end
  os.getenv = function(name)
    if name == "WEZTERM_NVIM" then return state.override end
    return original_getenv(name)
  end
  local wezterm = {
    config_dir = state.config_dir,
    target_triple = state.target,
    json_parse = vim.json.decode,
    log_error = function(message) state.errors[#state.errors + 1] = message end,
    run_child_process = function(args)
      state.calls[#state.calls + 1] = args
      if state.child then return state.child(args) end
      return true, vim.json.encode(state.path), ""
    end,
  }
  package.loaded.wezterm = wezterm
  local module = dofile("scrollback.lua")
  local ok, err = xpcall(function() fn(module, window, pane, state, wezterm) end, debug.traceback)
  io.open, os.remove, os.getenv = original_open, original_remove, original_getenv
  package.loaded.wezterm = original_wezterm
  assert(ok, err)
end

for _, target in ipairs({
  "aarch64-apple-darwin", "x86_64-pc-windows-msvc", "aarch64-pc-windows-msvc",
  "x86_64-unknown-linux-gnu",
}) do
  test("capture and local spawn on " .. target, function()
    mocked(function(module, window, pane, state, wezterm)
      wezterm.target_triple = target
      if target:find("windows", 1, true) then
        state.path = "C:\\Users\\Example Ü\\AppData\\Local\\Temp\\" .. state.basename
      end
      assert(module.open(window, pane))
      assert(state.spawn.domain.DomainName == "local")
      assert(state.spawn.cwd == state.config_dir)
      assert(state.activated and #state.removals == 0 and #state.errors == 0)
      local executable = target:find("darwin", 1, true) and "/opt/homebrew/bin/nvim"
        or target:find("windows", 1, true) and "nvim.exe" or "nvim"
      assert(state.calls[1][1] == executable and state.spawn.args[1] == executable)
      assert(#state.calls[1] == 10, "Allocator must not need the config directory as an argument")
      assert(state.spawn.set_environment_variables.WEZTERM_SCROLLBACK_FILE == state.path)
      contains(table.concat(state.spawn.args, " "), "-u NONE -i NONE -n --noplugin -R")
    end)
  end)
end

test("large scrollback stays out of argv and environment", function()
  mocked(function(module, window, pane, state)
    state.text = string.rep("Go/very long source path/main.go:100\n", 100000)
    assert(module.open(window, pane))
    assert(#state.written > 3000000)
    assert(#table.concat(state.calls[1], " ") < 1000)
    assert(#table.concat(state.spawn.args, " ") < 1000)
    for _, value in pairs(state.spawn.set_environment_variables) do assert(#value < 1000) end
  end)
end)

test("GUI PATH fallback", function()
  mocked(function(module, window, pane, state)
    state.child = function(args)
      if args[1] == "/opt/homebrew/bin/nvim" then error("No such file") end
      return true, vim.json.encode(state.path), ""
    end
    assert(module.open(window, pane))
    assert(#state.calls == 2 and state.spawn.args[1] == "/usr/local/bin/nvim")
  end)
end)

test("explicit native executable with spaces and Unicode", function()
  mocked(function(module, window, pane, state)
    state.override = "C:/Program Files/Neovim Ü/bin/nvim.exe"
    assert(module.open(window, pane))
    assert(state.calls[1][1] == state.override and state.spawn.args[1] == state.override)
  end)
end)

for _, failure in ipairs({
  { "dimensions_error", "Could not inspect", false },
  { "capture_error", "Could not capture", false },
  { "window_error", "mux window", false },
  { "open_error", "Could not open", true },
  { "open_throw", "Could not open", true },
  { "write_error", "Could not write", true },
  { "write_throw", "Could not write", true },
  { "close_error", "Could not close", true },
  { "close_throw", "Could not close", true },
  { "spawn_error", "Could not spawn", true },
  { "spawn_nil", "Could not spawn", true },
  { "activation_error", "Select the new tab manually", false },
}) do
  test("handles " .. failure[1], function()
    mocked(function(module, window, pane, state)
      state[failure[1]] = "injected failure"
      local ok, err = module.open(window, pane)
      assert(not ok)
      contains(err, failure[2])
      assert(state.toast == err and #state.errors == 1)
      assert(#state.removals == (failure[3] and 1 or 0))
      if failure[1]:match("^write") then assert(state.closed) end
    end)
  end)
end

test("invalid dimensions fail before allocation", function()
  mocked(function(module, window, pane, state)
    state.rows = -1
    local ok, err = module.open(window, pane)
    assert(not ok and #state.calls == 0)
    contains(err, "invalid scrollback dimensions")
  end)
end)

test("missing native Neovim error is actionable", function()
  mocked(function(module, window, pane, state, wezterm)
    wezterm.target_triple = "x86_64-pc-windows-msvc"
    state.child = function() error("Executable not found") end
    local ok, err = module.open(window, pane)
    assert(not ok and not state.spawn and #state.removals == 0)
    contains(err, "Windows needs nvim.exe")
    contains(err, "WEZTERM_NVIM")
  end)
end)

test("allocator failure is not retried as executable discovery", function()
  mocked(function(module, window, pane, state)
    state.child = function() return false, "", "Permission denied" end
    local ok, err = module.open(window, pane)
    assert(not ok and #state.calls == 1 and not state.spawn)
    contains(err, "Permission denied")
    contains(err, "writable")
  end)
end)

for _, output in ipairs({
  "../unrelated-file",
  "null", "false", "123", "{}", '["/test/.wezterm-scrollback-Ab12Cd"]',
  '"unterminated',
  vim.json.encode("/test/.wezterm-scrollback-Ab12Cd") .. " trailing garbage",
  vim.json.encode(".wezterm-scrollback-Ab12Cd"),
  vim.json.encode("/test/unrelated-file"),
  vim.json.encode("/test/../.wezterm-scrollback-Ab12Cd"),
  vim.json.encode("/test/./.wezterm-scrollback-Ab12Cd"),
  vim.json.encode("/test/\0/.wezterm-scrollback-Ab12Cd"),
}) do
  test("invalid allocator output is never opened or deleted: " .. output, function()
    mocked(function(module, window, pane, state)
      state.child = function() return true, output, "" end
      local ok, err = module.open(window, pane)
      assert(not ok and not state.spawn and state.opens == 0 and #state.removals == 0)
      contains(err, "invalid JSON or an unsafe export path")
    end)
  end)
end

for _, path in ipairs({
  "C:.wezterm-scrollback-Ab12Cd",
  "\\test\\.wezterm-scrollback-Ab12Cd",
  "\\\\server\\.wezterm-scrollback-Ab12Cd",
  "\\\\?\\C:\\test\\.wezterm-scrollback-Ab12Cd",
  "C:\\test\\..\\.wezterm-scrollback-Ab12Cd",
}) do
  test("rejects noncanonical Windows export path " .. path, function()
    mocked(function(module, window, pane, state, wezterm)
      wezterm.target_triple = "x86_64-pc-windows-msvc"
      state.path = path
      local ok, err = module.open(window, pane)
      assert(not ok and state.opens == 0 and #state.removals == 0)
      contains(err, "unsafe export path")
    end)
  end)
end

for _, entry in ipairs({
  { "aarch64-apple-darwin", "/test Ü/quotes '\" and \\ newline\n/.wezterm-scrollback-Ab12Cd" },
  { "x86_64-pc-windows-msvc", "\\\\server\\share\\Test Ü directory\\.wezterm-scrollback-Ab12Cd" },
}) do
  test("JSON preserves opaque absolute paths on " .. entry[1], function()
    mocked(function(module, window, pane, state, wezterm)
      wezterm.target_triple, state.path = entry[1], entry[2]
      assert(module.open(window, pane))
      assert(state.spawn.set_environment_variables.WEZTERM_SCROLLBACK_FILE == state.path)
    end)
  end)
end

for _, kind in ipairs({ "remove_error", "remove_throw" }) do
  test("reports cleanup " .. kind, function()
    mocked(function(module, window, pane, state)
      state.spawn_error, state[kind] = "spawn failed", "access denied"
      local ok, err = module.open(window, pane)
      assert(not ok)
      contains(err, "Could not spawn")
      contains(err, "Could not delete export " .. state.path)
      contains(err, "manually")
    end)
  end)
end

test("toast failure remains logged", function()
  mocked(function(module, window, pane, state)
    state.capture_error, state.toast_error = "pane gone", "window gone"
    assert(not module.open(window, pane))
    assert(#state.errors == 2)
  end)
end)

local function run(args, env, cwd)
  -- Redirect OS-temp APIs into the project; tests never use a system temp directory.
  env = vim.tbl_extend("force", { TMPDIR = root, TMP = root, TEMP = root }, env or {})
  return vim.system(args, { text = true, env = env, cwd = cwd }):wait()
end

local function allocate(env)
  return run({
    nvim, "--headless", "-u", "NONE", "-i", "NONE", "-n", "--noplugin",
    "-l", root .. "/scrollback-allocate.lua",
  }, env, root .. "/tests")
end

local function exports()
  local paths = {}
  local scan = assert(uv.fs_scandir("."))
  while true do
    local name = uv.fs_scandir_next(scan)
    if not name then break end
    if name:match("^%.wezterm%-scrollback%-") then paths[#paths + 1] = name end
  end
  table.sort(paths)
  return table.concat(paths, "\n")
end

test("real secure OS-temp allocation survives allocator exit and ignores cwd", function()
  local result = allocate()
  assert(result.code == 0, result.stderr)
  local path = vim.json.decode(result.stdout)
  assert(path:sub(1, #root + 1) == root .. "/", path)
  assert(path:sub(#root + 2):match("^%.wezterm%-scrollback%-%w%w%w%w%w%w$"), path)
  local stat = assert(uv.fs_stat(path))
  assert(stat.size == 0 and stat.type == "file")
  if uv.os_uname().sysname ~= "Windows_NT" then assert(stat.mode % 512 == 384, "Expected mode 0600") end
  assert(uv.fs_unlink(path))
end)

test("real allocator directory failure returns nonzero", function()
  local before = exports()
  local missing = root .. "/scrollback-directory-that-does-not-exist"
  local result = allocate({ TMPDIR = missing, TMP = missing, TEMP = missing })
  assert(result.code ~= 0)
  contains(result.stderr, "Could not enter")
  assert(exports() == before)
end)

for _, fault in ipairs({ "os_tmpdir", "cwd", "mkstemp", "close", "json", "stdout", "flush" }) do
  test("real allocator " .. fault .. " failure cleans up and exits nonzero", function()
    local before = exports()
    local result = run({
      nvim, "--headless", "-u", "NONE", "-i", "NONE", "-n", "--noplugin",
      "-l", root .. "/tests/scrollback-allocate.lua", fault, root,
    })
    assert(result.code ~= 0)
    contains(result.stderr, "injected " .. fault)
    assert(exports() == before, "Allocator abandoned an export")
  end)
end

local viewer_tests = dofile("tests/scrollback-viewer.lua")
for _, mode in ipairs({ "success", "empty", "missing", "read-failure", "cleanup-failure" }) do
  test("real isolated viewer " .. mode, function()
    local result = allocate()
    assert(result.code == 0, result.stderr)
    local path = vim.json.decode(result.stdout)
    local named = path .. " Ü space ' % #.log"
    assert(uv.fs_rename(path, named))
    path = named
    local file = assert(io.open(path, "wb"))
    assert(file:write(mode == "empty" and "" or table.concat(viewer_tests.lines(), "\n")))
    assert(file:close())
    if mode == "missing" then assert(uv.fs_unlink(path)) end
    local absolute_path = path
    local command
    mocked(function(module, window, pane, state, wezterm)
      wezterm.config_dir, state.config_dir = root, root
      assert(module.open(window, pane))
      command = state.spawn.args
    end)
    command[1] = nvim
    table.insert(command, 2, "--headless")
    -- Arrange faults before the exact production viewer command executes.
    table.insert(command, #command - 1, "-c")
    table.insert(command, #command - 1, "lua dofile(vim.env.SCROLLBACK_TEST_DRIVER).prepare()")
    command[#command + 1] = "-c"
    command[#command + 1] = "lua local ok,e=pcall(function() dofile(vim.env.SCROLLBACK_TEST_DRIVER).check() end); "
      .. "if not ok then io.stderr:write(tostring(e)); vim.cmd('cquit 1') end"
    command[#command + 1] = "-c"
    command[#command + 1] = "qa!"
    local viewed = run(command, {
      WEZTERM_SCROLLBACK_FILE = absolute_path,
      WEZTERM_SCROLLBACK_VIEWER = root .. "/scrollback-viewer.lua",
      SCROLLBACK_TEST_DRIVER = root .. "/tests/scrollback-viewer.lua",
      SCROLLBACK_TEST_PATH = absolute_path,
      SCROLLBACK_TEST_MODE = mode,
      VIMINIT = "lua vim.g.scrollback_user_init_ran = true",
      EXINIT = "let g:scrollback_user_init_ran = 1",
    })
    local remains = uv.fs_stat(path) ~= nil
    if remains then assert(uv.fs_unlink(path)) end
    assert(viewed.code == 0, viewed.stderr)
    assert(not remains, "Viewer failed to clean its export, including the exit retry")
  end)
end

print("Scrollback: " .. passed .. " tests passed")
