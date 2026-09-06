local M = {}

-- Update this baseline deliberately alongside lazy-lock.json.
M.known_good = {
  nvim = "0.12.2",
  ["tree-sitter"] = "0.26.12",
  ruff = "0.16.4",
  basedpyright = "1.39.10",
}

M.servers = {
  basedpyright = "basedpyright-langserver",
  ruff = "ruff",
}

return M
