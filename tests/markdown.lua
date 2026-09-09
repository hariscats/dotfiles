local note = vim.fn.tempname() .. ".md"
local lines = {
  "# Heading", "", "Text with **bold** and a [link](https://example.com).",
  "", "- [x] Done", "", "| Name | Value |", "| --- | --- |", "| One | Two |",
  "", "```python", "answer = 42", "```",
  "", "## Priorities", "", "### Notes", "", "#### Details", "", "##### Reference", "", "###### Done",
  "", "- [ ] Pending", "", "> A quoted note.", "", "Text with *emphasis* and `inline code`.",
}
vim.fn.writefile(lines, note)
local child = vim.fn.jobstart({
  vim.v.progpath, "--embed", "--headless", "-i", "NONE", "-n",
  "--cmd", "set lines=55 columns=140", note,
}, { rpc = true })
assert(child > 0, "Could not start Neovim for Markdown regression")

local function exec(code, ...)
  return vim.rpcrequest(child, "nvim_exec_lua", code, { ... })
end

local function snapshot()
  return exec([[
    local api = vim.api
    local ns = api.nvim_get_namespaces()["render-markdown.nvim"]
    return {
      mode = api.nvim_get_mode().mode,
      filetype = vim.bo.filetype,
      file = api.nvim_buf_get_name(0),
      filetype_status = api.nvim_exec2("filetype", { output = true }).output,
      messages = api.nvim_exec2("messages", { output = true }).output,
      conceallevel = vim.wo.conceallevel,
      concealcursor = vim.wo.concealcursor,
      marks = ns and api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true }) or {},
      lines = api.nvim_buf_get_lines(0, 0, -1, false),
    }
  ]])
end

local function wait_for(description, predicate)
  local last
  assert(vim.wait(5000, function()
    last = snapshot()
    return predicate(last)
  end, 25), description .. ": " .. vim.inspect(last))
end

local function has_mark(state, row, field, value)
  for _, mark in ipairs(state.marks) do
    if mark[2] == row and mark[4][field] == value then
      return true
    end
  end
  return false
end

local function rendered(state)
  return state.mode == "n" and state.conceallevel == 3 and state.concealcursor == "nc"
    and has_mark(state, 0, "conceal", "")
    and has_mark(state, 0, "hl_group", "RenderMarkdownH1Bg")
end

local function raw(state)
  return #state.marks == 0 and state.conceallevel == 0 and state.concealcursor == ""
end

local ok, err = xpcall(function()
  assert(vim.wait(10000, function()
    return vim.rpcrequest(child, "nvim_eval", "v:vim_did_enter") == 1
  end, 25), "Child Neovim did not finish loading its configuration")
  wait_for("Normal mode must render and conceal the heading under the cursor", rendered)
  assert(exec([[
    local plugins = require("lazy.core.config").plugins
    for _, name in ipairs({ "nvim-lspconfig", "nvim-cmp", "cmp-nvim-lsp", "LuaSnip" }) do
      assert(not plugins[name]._.loaded, name .. " must not load just to display a daily note")
    end
    return not package.loaded.cmp and not package.loaded.luasnip
  ]]), "note startup must keep completion and snippets lazy")
  assert(exec([[
    local colors = { 0xffc777, 0xc3e88d, 0x82aaff, 0xc099ff, 0x86e1fc, 0xff757f }
    local rows = { 0, 14, 16, 18, 20, 22 }
    local ns = vim.api.nvim_get_namespaces()["render-markdown.nvim"]
    local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
    for level, row in ipairs(rows) do
      local group = "RenderMarkdownH" .. level .. "Bg"
      assert(vim.iter(marks):any(function(mark)
        return mark[2] == row and mark[4].hl_group == group
      end), "missing rendered heading level " .. level)
      assert(vim.api.nvim_get_hl(0, { name = group, link = false }).fg == colors[level])
      local source = "@markup.heading." .. level .. ".markdown"
      assert(vim.api.nvim_get_hl(0, { name = source, link = false }).fg == colors[level])
    end
    return true
  ]]), "visible headings must retain their distinct colors")
  local original = snapshot().lines

  vim.rpcrequest(child, "nvim_input", "i")
  wait_for("Insert mode must show raw Markdown", function(state)
    return state.mode == "i" and raw(state)
  end)
  assert(exec([[
    local cmp = assert(package.loaded.cmp, "completion must load on InsertEnter")
    assert(vim.deep_equal(vim.tbl_map(function(source)
      return source.name
    end, cmp.get_config().sources), { "buffer", "path" }), "keep prose completion unchanged")
    return not require("lazy.core.config").plugins["nvim-lspconfig"]._.loaded
  ]]), "typing Markdown must not load Python LSP setup")
  vim.rpcrequest(child, "nvim_input", "<Esc>")
  wait_for("Esc from Insert mode must restore rendering", rendered)

  vim.rpcrequest(child, "nvim_input", "v")
  wait_for("Visual mode must show selectable source", function(state)
    return state.mode == "v" and raw(state)
  end)
  vim.rpcrequest(child, "nvim_input", "<Esc>")
  wait_for("Esc from Visual mode must restore rendering", rendered)

  vim.rpcrequest(child, "nvim_input", ":")
  wait_for("Command-line mode must keep the cursor heading rendered", function(state)
    return state.mode == "c" and state.concealcursor == "nc"
      and has_mark(state, 0, "conceal", "")
  end)
  vim.rpcrequest(child, "nvim_input", "<Esc>")
  wait_for("Esc from command-line mode must restore Normal mode", rendered)

  vim.rpcrequest(child, "nvim_input", " m")
  wait_for("Space m must expose raw source in Normal mode", function(state)
    return state.mode == "n" and raw(state)
  end)
  vim.rpcrequest(child, "nvim_input", " m")
  wait_for("Space m must restore rendering", rendered)

  exec([[vim.cmd.vsplit()]])
  wait_for("A new split must render the cursor heading", rendered)
  assert(exec([[
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.wo[win].conceallevel ~= 3 or vim.wo[win].concealcursor ~= "nc" then
        return false
      end
    end
    return true
  ]]), "All Markdown splits must use reading-mode concealment")
  assert(vim.deep_equal(snapshot().lines, original), "Rendering must not change document content")
end, debug.traceback)

vim.fn.jobstop(child)
vim.fn.jobwait({ child }, 2000)
vim.fn.delete(note)
assert(ok, err)
print("Markdown rendering and mode-transition assertions passed")
