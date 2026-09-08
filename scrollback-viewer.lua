local M = {}
local uv = vim.uv or vim.loop

local function unlink(path)
  local removed, err, code = uv.fs_unlink(path)
  if removed or code == "ENOENT" then
    return true
  end
  return nil, "Could not delete scrollback export " .. path .. ": " .. tostring(err)
    .. ". Remove this file manually; it may contain sensitive terminal output."
end

local function scratch(lines)
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buffer)
  vim.api.nvim_buf_set_name(buffer, "WezTerm Scrollback")
  vim.bo[buffer].buftype = "nofile"
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].undofile = false
  vim.bo[buffer].undolevels = -1
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, #lines > 0 and lines or { "" })
  vim.bo[buffer].modified = false
  vim.bo[buffer].readonly = true
  vim.bo[buffer].modifiable = false
  vim.wo.wrap = false
  vim.wo.number = true
  vim.wo.conceallevel = 0
  vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buffer), 0 })
  vim.keymap.set("n", "q", "<Cmd>qa!<CR>", { buffer = buffer, silent = true })
  return buffer
end

function M.open(path)
  vim.env.WEZTERM_SCROLLBACK_FILE = nil
  vim.env.WEZTERM_SCROLLBACK_VIEWER = nil
  vim.o.modeline = false
  vim.o.modelineexpr = false
  vim.o.exrc = false
  vim.o.swapfile = false
  vim.o.undofile = false
  vim.o.undolevels = -1
  vim.o.shada = ""
  vim.o.shadafile = "NONE"
  vim.o.backup = false
  vim.o.writebackup = false
  vim.o.title = true
  vim.o.titlestring = "WezTerm Scrollback"
  vim.o.laststatus = 2
  vim.o.statusline = " WezTerm scrollback  |  / search  |  q close %=%l/%L "

  if type(path) ~= "string" or path == "" then
    local message = "Missing scrollback export path."
    scratch({ message, "Press q to close." })
    vim.api.nvim_err_writeln(message)
    return nil, message
  end

  -- readfile treats the contents as data, never as a file to :edit or :source.
  local read, lines = pcall(vim.fn.readfile, path, "b")
  local removed, remove_error = unlink(path)
  if not removed then
    vim.api.nvim_create_autocmd("VimLeavePre", {
      once = true,
      callback = function()
        local retried, retry_error = unlink(path)
        if not retried then
          vim.api.nvim_err_writeln(retry_error)
        end
      end,
    })
  end
  if not read then
    local message = "Could not read scrollback export " .. path .. ": " .. tostring(lines)
    if remove_error then
      message = message .. "\n" .. remove_error
    end
    scratch(vim.split(message .. "\nPress q to close.", "\n", { plain = true }))
    vim.api.nvim_err_writeln(message)
    return nil, message
  end

  local buffer = scratch(lines)
  if remove_error then
    vim.b[buffer].scrollback_error = remove_error
    vim.o.statusline = " Scrollback export cleanup FAILED: see :messages %=%l/%L "
    vim.api.nvim_err_writeln(remove_error)
  end
  return buffer, remove_error
end

return M
