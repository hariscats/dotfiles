local M = {}

M.languages = {
  "lua", "vim", "vimdoc", "query", "bash", "diff",
  "python", "go", "gomod", "gosum", "gowork",
  "toml", "markdown", "markdown_inline", "yaml",
}

-- Accept the common Markdown fence alias without a second parser.
vim.treesitter.language.register("go", "golang")

local function report(message, level)
  vim.schedule(function()
    vim.notify_once(message .. "\nSee :checkhealth config", level)
  end)
end

function M.load(lang)
  if #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".*", false) == 0 then
    return false, "No parser installed for " .. lang, true
  end
  local ok, loaded, err = pcall(vim.treesitter.language.add, lang)
  if not ok then
    return false, tostring(loaded), false
  end
  if loaded ~= true then
    return false, err or ("Parser loader returned no result for " .. lang), false
  end
  return true, nil, false
end

function M.start(buf)
  local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
  if not lang then
    return
  end
  local loaded, err, missing = M.load(lang)
  if not loaded then
    if not missing or vim.list_contains(M.languages, lang) then
      report(("Tree-sitter (%s): %s. Run :ConfigParsers, then restart Neovim.")
        :format(lang, err), missing and vim.log.levels.WARN or vim.log.levels.ERROR)
    end
    return
  end
  local ok, start_err = pcall(vim.treesitter.start, buf, lang)
  if not ok then
    report(("Tree-sitter (%s): %s"):format(lang, start_err), vim.log.levels.ERROR)
  end
  -- Neovim's indent scripts remain in charge; Tree-sitter indentation is experimental.
end

function M.install()
  local ts = require("nvim-treesitter")
  assert(ts.update():wait(300000), "Parser update failed; see :messages for details")
  assert(ts.install(M.languages):wait(300000), "Parser installation failed; see :messages for details")
  vim.notify("Parsers are ready. Restart Neovim before editing to load the new versions.")
end

return M
