local uv = vim.uv or vim.loop

local function fail(message, path)
  if path then
    local removed, err = uv.fs_unlink(path)
    if not removed then
      message = message .. "\nCould not delete " .. path .. ": " .. tostring(err)
        .. ". Remove this export manually."
    end
  end
  io.stderr:write("Scrollback allocation failed: " .. message .. "\n")
  os.exit(1)
end

local directory, directory_error = uv.os_tmpdir()
if not directory then
  fail("Could not locate the system temporary directory: " .. tostring(directory_error))
end
local changed, change_error = uv.chdir(directory)
if not changed then
  fail("Could not enter " .. directory .. ": " .. tostring(change_error))
end
directory, directory_error = uv.cwd()
if not directory then
  fail("Could not resolve the temporary directory: " .. tostring(directory_error))
end

-- mkstemp atomically creates a private file, unlike Windows Lua os.tmpname().
-- Use the OS directory, not Neovim's auto-deleted tempname directory.
local fd, name = uv.fs_mkstemp(".wezterm-scrollback-XXXXXX")
if not fd then
  fail("Could not create an export in " .. directory .. ": " .. tostring(name))
end
local last = directory:sub(-1)
local separator = (last == "/" or (package.config:sub(1, 1) == "\\" and last == "\\")) and "" or "/"
local path = directory .. separator .. name
local closed, close_error = uv.fs_close(fd)
if not closed then
  fail("Could not close the allocated export: " .. tostring(close_error), path)
end
local encoded, json = pcall(vim.json.encode, path)
if not encoded then
  fail("Could not encode the export path: " .. tostring(json), path)
end
local wrote, write_error = io.stdout:write(json)
if not wrote then
  fail("Could not return the export name: " .. tostring(write_error), path)
end
local flushed, flush_error = io.stdout:flush()
if not flushed then
  fail("Could not return the export name: " .. tostring(flush_error), path)
end
