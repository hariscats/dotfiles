-- Buffer-local mode and mappings, with reversible presentation per window.
local M = {}
local api = vim.api
local buffers, windows, history = {}, {}, {}
local previous_window

local PROSE_FILETYPES = {
  markdown = true,
  text = true,
  gitcommit = true,
  rst = true,
  asciidoc = true,
  tex = true,
  typst = true,
  mail = true,
}

local PROSE_OPTIONS = {
  wrap = true,
  linebreak = true,
  breakindent = true,
  number = false,
  relativenumber = false,
  cursorline = false,
  signcolumn = "no",
  spell = true,
  conceallevel = 3,
}

local MAPPINGS = {
  j = { "v:count == 0 ? 'gj' : 'j'", expr = true },
  k = { "v:count == 0 ? 'gk' : 'k'", expr = true },
  ["0"] = { "g0" },
  ["$"] = { "g$" },
}

function M.enabled(buf)
  buf = buf or api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= "" then
    return false
  end
  local override = vim.b[buf].prose_override
  if override ~= nil then
    return override
  end
  return PROSE_FILETYPES[vim.bo[buf].filetype] == true
end

local function update_buffer(buf)
  local enabled = M.enabled(buf)
  vim.b[buf].prose_mode = enabled
  if enabled == (buffers[buf] ~= nil) then
    return
  end

  api.nvim_buf_call(buf, function()
    if enabled then
      local saved = { spelllang = vim.bo.spelllang, mappings = {} }
      buffers[buf] = saved
      vim.bo.spelllang = "en_us"
      for key, mapping in pairs(MAPPINGS) do
        local before = vim.fn.maparg(key, "n", false, true)
        vim.keymap.set("n", key, mapping[1], {
          buffer = buf,
          silent = true,
          expr = mapping.expr == true,
          desc = "Prose: visual-line motion",
        })
        saved.mappings[key] = {
          before = before.buffer == 1 and before or nil,
          applied = vim.fn.maparg(key, "n", false, true),
        }
      end
    else
      local saved = buffers[buf]
      buffers[buf] = nil
      if vim.bo.spelllang == "en_us" then
        vim.bo.spelllang = saved.spelllang
      end
      for key, mapping in pairs(saved.mappings) do
        -- A mapping replaced while prose was active belongs to its new owner.
        if vim.deep_equal(vim.fn.maparg(key, "n", false, true), mapping.applied) then
          if mapping.before then
            vim.fn.mapset("n", false, mapping.before)
          else
            vim.keymap.del("n", key, { buffer = buf })
          end
        end
      end
    end
  end)
end

local function restore_window(win)
  local saved = windows[win]
  if saved then
    -- Neovim remembers the overlaid options for each visited buffer too.
    -- Keep the original values so returning cannot capture prose as a default.
    history[win] = history[win] or {}
    if not saved.discard then
      history[win][saved.buf] = saved
    end
    for key, value in pairs(saved.before) do
      if vim.wo[win][key] == saved.applied[key] then
        vim.wo[win][key] = value
      end
    end
    windows[win] = nil
  end
end

local function update_window(win)
  local config = api.nvim_win_get_config(win)
  if config.relative ~= "" or config.external then
    return -- floating previews own their presentation
  end
  local buf = api.nvim_win_get_buf(win)
  if windows[win] and (windows[win].buf ~= buf or windows[win].discard) then
    restore_window(win)
  end

  local desired = {}
  if M.enabled(buf) then
    desired = vim.tbl_extend("force", PROSE_OPTIONS, {
      colorcolumn = vim.b[buf].prose_colorcolumn or "",
    })
  elseif vim.bo[buf].buftype == "" and vim.b[buf].ft_colorcolumn then
    desired.colorcolumn = vim.b[buf].ft_colorcolumn
  end

  history[win] = history[win] or {}
  local saved = windows[win] or history[win][buf] or { buf = buf, before = {}, applied = {} }
  for key, value in pairs(saved.before) do
    if desired[key] == nil then
      if vim.wo[win][key] == saved.applied[key] then
        vim.wo[win][key] = value
      end
      saved.before[key], saved.applied[key] = nil, nil
    end
  end
  for key, value in pairs(desired) do
    if saved.before[key] == nil then
      saved.before[key] = vim.wo[win][key]
    end
    vim.wo[win][key] = value
    saved.applied[key] = value
  end
  windows[win] = next(saved.before) and saved or nil
  history[win][buf] = windows[win]
end

function M.refresh(buf)
  buf = buf or api.nvim_get_current_buf()
  update_buffer(buf)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    update_window(win)
  end
end

function M.apply()
  vim.b.prose_override = true
  M.refresh()
end

function M.clear()
  vim.b.prose_override = false
  M.refresh()
end

-- Turn prose mode on in any buffer, including code files.
function M.toggle()
  if vim.bo.buftype ~= "" then
    vim.notify("Prose mode is only available in normal editing buffers", vim.log.levels.WARN)
    return
  end
  if M.enabled() then
    M.clear()
    vim.notify("Prose mode off")
  else
    M.apply()
    vim.notify("Prose mode on")
  end
end

function M.setup()
  local group = api.nvim_create_augroup("ProseMode", { clear = true })

  api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function(args)
      -- after/ftplugin and its undo commands must finish before presentation.
      vim.schedule(function()
        if api.nvim_buf_is_loaded(args.buf) then
          M.refresh(args.buf)
        end
      end)
    end,
  })
  api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "WinEnter" }, {
    group = group,
    callback = function()
      M.refresh()
    end,
  })
  api.nvim_create_autocmd("WinLeave", {
    group = group,
    callback = function()
      previous_window = api.nvim_get_current_win()
    end,
  })
  api.nvim_create_autocmd("WinNew", {
    group = group,
    callback = function()
      -- Splits inherit window options, but not our original-value snapshots.
      local win = api.nvim_get_current_win()
      local config = api.nvim_win_get_config(win)
      if config.relative == "" and not config.external
          and not windows[win] and windows[previous_window] then
        windows[win] = vim.deepcopy(windows[previous_window])
      end
    end,
  })
  api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
      windows[tonumber(args.match)] = nil
      history[tonumber(args.match)] = nil
    end,
  })
  api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(args)
      -- :bdelete clears buffer mappings, but retains remembered window options.
      buffers[args.buf] = nil
    end,
  })
  api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      buffers[args.buf] = nil
      for _, saved in pairs(history) do
        saved[args.buf] = nil
      end
      for _, saved in pairs(windows) do
        if saved.buf == args.buf then
          saved.discard = true
        end
      end
    end,
  })
  api.nvim_create_user_command("ProseAuto", function()
    vim.b.prose_override = nil
    M.refresh()
  end, { desc = "Use the filetype default for prose mode" })
end

return M
