local wezterm = require("wezterm")
local M = {}

local function report(window, message)
  wezterm.log_error("Scrollback to Neovim: " .. message)
  local ok, err = pcall(window.toast_notification, window, "Scrollback to Neovim", message, nil, 10000)
  if not ok then
    wezterm.log_error("Could not show scrollback error notification: " .. tostring(err))
  end
  return nil, message
end

local function cleanup(path)
  local ok, removed, err = pcall(os.remove, path)
  if not ok or not removed then
    return "\nCould not delete export " .. path .. ": " .. tostring(ok and err or removed)
      .. ". Remove this file manually; it may contain sensitive terminal output."
  end
  return ""
end

local function candidates()
  local override = os.getenv("WEZTERM_NVIM")
  if override and override ~= "" then
    return { override }
  end
  if wezterm.target_triple:find("apple-darwin", 1, true) then
    return { "/opt/homebrew/bin/nvim", "/usr/local/bin/nvim", "nvim" }
  end
  return { wezterm.target_triple:find("windows", 1, true) and "nvim.exe" or "nvim" }
end

local function export_path(stdout)
  if type(stdout) ~= "string" then
    return nil
  end
  local decoded, path = pcall(wezterm.json_parse, stdout)
  if not decoded or type(path) ~= "string" or path:find("\0", 1, true) then
    return nil
  end
  local windows = wezterm.target_triple:find("windows", 1, true)
  local normalized = windows and path:gsub("\\", "/") or path
  if windows then
    if not normalized:match("^%a:/") and not normalized:match("^//[^/]+/[^/]+/") then
      return nil
    end
    if normalized:match("^//[%.%?]/") then
      return nil
    end
  elseif normalized:sub(1, 1) ~= "/" then
    return nil
  end
  for component in normalized:gmatch("[^/]+") do
    if component == "." or component == ".." then
      return nil
    end
  end
  if normalized:match("/%.wezterm%-scrollback%-%w%w%w%w%w%w$") then
    return path
  end
end

local function allocate()
  local failures = {}
  for _, executable in ipairs(candidates()) do
    local ok, success, stdout, stderr = pcall(wezterm.run_child_process, {
      executable, "--headless", "-u", "NONE", "-i", "NONE", "-n", "--noplugin",
      "-l", wezterm.config_dir .. "/scrollback-allocate.lua",
    })
    if ok then
      if not success then
        return nil, nil, "Neovim could not allocate a scrollback export using " .. executable
          .. ": " .. tostring(stderr) .. "\nThe system temporary directory must be writable. "
          .. "Neovim 0.9+ is required."
      end
      local path = export_path(stdout)
      if not path then
        return nil, nil, "The Neovim allocator returned invalid JSON or an unsafe export path. "
          .. "No file was opened or deleted. Check the system temporary directory "
          .. "for leftover .wezterm-scrollback-* files."
      end
      return executable, path
    end
    failures[#failures + 1] = executable .. ": " .. tostring(success)
  end
  return nil, nil, "Could not start local native Neovim. Install Neovim 0.9+ on the host "
    .. "(Windows needs nvim.exe, even for WSL/SSH panes), put it on WezTerm's PATH, "
    .. "or set WEZTERM_NVIM to its full executable path and restart WezTerm.\n"
    .. table.concat(failures, "\n")
end

local function write_export(path, text)
  local ok, file, err = pcall(io.open, path, "wb")
  if not ok or not file then
    return nil, "Could not open scrollback export " .. path .. ": " .. tostring(ok and err or file)
  end
  local wrote, result, write_error = pcall(file.write, file, text)
  local closed, close_result, close_error = pcall(file.close, file)
  local errors = {}
  if not wrote or not result then
    errors[#errors + 1] = "Could not write scrollback export " .. path .. ": "
      .. tostring(wrote and write_error or result)
  end
  if not closed or not close_result then
    errors[#errors + 1] = "Could not close scrollback export " .. path .. ": "
      .. tostring(closed and close_error or close_result)
  end
  if #errors > 0 then
    return nil, table.concat(errors, "\n")
  end
  return true
end

function M.open(window, pane)
  local dimensions_ok, dimensions = pcall(pane.get_dimensions, pane)
  if not dimensions_ok then
    return report(window, "Could not inspect the source pane: " .. tostring(dimensions))
  end
  local rows = type(dimensions) == "table" and dimensions.scrollback_rows
  if type(rows) ~= "number" or rows < 0 or rows == math.huge or rows ~= math.floor(rows) then
    return report(window, "The source pane returned invalid scrollback dimensions.")
  end
  -- scrollback_rows includes the viewport; logical lines rejoin soft-wrapped paths.
  local captured, text = pcall(pane.get_logical_lines_as_text, pane, rows)
  if not captured or type(text) ~= "string" then
    return report(window, "Could not capture the source pane's scrollback: " .. tostring(text))
  end
  local found_window, mux_window = pcall(window.mux_window, window)
  if not found_window or not mux_window then
    return report(window, "Could not find the viewer's mux window: " .. tostring(mux_window))
  end

  local executable, path, allocation_error = allocate()
  if not executable then
    return report(window, allocation_error)
  end
  local written, write_error = write_export(path, text)
  if not written then
    return report(window, write_error .. cleanup(path))
  end

  -- Only small, opaque paths cross the process boundary, never terminal output.
  local spawned, tab = pcall(mux_window.spawn_tab, mux_window, {
    domain = { DomainName = "local" },
    cwd = wezterm.config_dir,
    args = {
      executable, "-u", "NONE", "-i", "NONE", "-n", "--noplugin", "-R",
      "--cmd", "set nomodeline nomodelineexpr noexrc noswapfile noundofile",
      "-c", "lua dofile(vim.env.WEZTERM_SCROLLBACK_VIEWER).open(vim.env.WEZTERM_SCROLLBACK_FILE)",
    },
    set_environment_variables = {
      WEZTERM_SCROLLBACK_VIEWER = wezterm.config_dir .. "/scrollback-viewer.lua",
      WEZTERM_SCROLLBACK_FILE = path,
    },
  })
  if not spawned or not tab then
    return report(window, "Could not spawn the local Neovim viewer: " .. tostring(tab) .. cleanup(path))
  end
  local activated, activation_error = pcall(tab.activate, tab)
  if not activated then
    return report(window, "The Neovim viewer was started, but its tab could not be activated: "
      .. tostring(activation_error) .. ". Select the new tab manually.")
  end
  -- Ownership transfers to the viewer only after spawning. It unlinks after reading.
  return true
end

return M
