local M = {}

function M.check()
  local health = vim.health
  local tools = require("config.tools")
  health.start("Supported toolchain")
  if vim.fn.has("nvim-0.12") == 1 then
    health.ok("Neovim >= 0.12")
  else
    health.error("This configuration requires Neovim >= 0.12")
  end

  for _, executable in ipairs({ "git", "curl", "tar" }) do
    if vim.fn.executable(executable) == 1 then
      health.ok(executable .. ": " .. vim.fn.exepath(executable))
    else
      health.error(executable .. " is missing from PATH")
    end
  end
  if vim.fn.executable("cc") == 1 or vim.fn.executable("gcc") == 1
      or vim.fn.executable("clang") == 1 then
    health.ok("C compiler available for parser builds")
  else
    health.error("Install a C compiler before running :ConfigParsers")
  end

  for executable, expected in pairs(tools.known_good) do
    local version
    if executable == "nvim" then
      version = tostring(vim.version())
    elseif vim.fn.executable(executable) == 1 then
      local result = vim.system({ executable, "--version" }, { text = true }):wait(10000)
      if result.code ~= 0 then
        health.error(executable .. " --version failed: " .. (result.stderr or ""))
      else
        version = (result.stdout or ""):match("%d+%.%d+%.%d+")
        if not version then
          health.error("Cannot determine " .. executable .. " version: " .. (result.stdout or ""))
        end
      end
    else
      health.error(executable .. " is missing; see the installation instructions in README.md")
    end
    if version then
      if executable == "tree-sitter" and not vim.version.ge(version, "0.26.1") then
        health.error("Tree-sitter CLI >= 0.26.1 is required; found " .. version)
      elseif version == expected then
        health.ok(executable .. " " .. version .. " matches the known-good baseline")
      else
        health.warn(executable .. " " .. version .. "; known-good version is " .. expected,
          "After an intentional upgrade, update lua/config/tools.lua with the new baseline")
      end
    end
  end

  health.start("Python language servers")
  for server, executable in pairs(tools.servers) do
    if vim.fn.executable(executable) == 1 then
      health.ok(server .. ": " .. vim.fn.exepath(executable))
    else
      health.error(executable .. " is missing; " .. server .. " will not be enabled",
        "Install the pinned tool version from README.md and restart Neovim")
    end
  end

  health.start("Configured parsers")
  local ts = require("config.treesitter")
  for _, lang in ipairs(ts.languages) do
    local loaded, err = ts.load(lang)
    if loaded then
      health.ok(lang)
    else
      health.error(lang .. ": " .. err, "Run :ConfigParsers, then restart Neovim")
    end
  end
  health.info("Use :checkhealth nvim-treesitter to inspect parser/query compatibility")
end

return M
