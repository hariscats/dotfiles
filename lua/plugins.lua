return require("lazy").setup({
  --------------------------------------------------------------------
  -- Treesitter
  --------------------------------------------------------------------
  -- The `main` branch, not `master`: master is frozen and its README states
  -- that Neovim 0.12 is not supported. On 0.12 its markdown injections query
  -- throws on every redraw of a fenced code block, because the
  -- `set-lang-from-info-string!` directive was never updated for Neovim's
  -- quantified captures.
  --
  -- `main` is a rewrite with a different contract: the plugin supplies
  -- parsers and queries only, and highlighting is a Neovim feature that this
  -- config turns on itself, below. It also cannot be lazy-loaded, and needs
  -- `tree-sitter-cli` on PATH to build parsers.
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      -- Provision parsers explicitly with :ConfigParsers, never during editing.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("UserTreesitter", { clear = true }),
        callback = function(args)
          require("config.treesitter").start(args.buf)
        end,
      })
    end,
  },

  --------------------------------------------------------------------
  -- LSP
  --------------------------------------------------------------------
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "hrsh7th/cmp-nvim-lsp" },
    config = function()
      -- Applies to every server, so each vim.lsp.config below carries only
      -- what actually differs from the defaults nvim-lspconfig ships in its
      -- `lsp/` directory, which Neovim deep-merges underneath these.
      vim.lsp.config("*", {
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
      })

      -- Types, go-to-definition, hover docs. `uv tool install basedpyright`.
      vim.lsp.config("basedpyright", {
        settings = {
          basedpyright = {
            analysis = {
              -- The default is "recommended", which flags a great deal of
              -- ordinary code. "standard" is pyright's own baseline.
              typeCheckingMode = "standard",
              -- ruff already reports these, with better messages.
              diagnosticSeverityOverrides = {
                reportUnusedImport = "none",
                reportUnusedVariable = "none",
              },
            },
          },
        },
      })

      -- Lint and format, one static binary. `uv tool install ruff`.
      -- lspconfig's own lsp/ruff.lua already runs `ruff server` with the
      -- right filetypes and root markers; the only thing wanted on top is a
      -- guard for buffers that have no file name, where the server panics
      -- with "a path to a document should have a parent path". Declining to
      -- name a root directory is what stops it being started at all.
      vim.lsp.config("ruff", {
        root_dir = function(bufnr, on_dir)
          local name = vim.api.nvim_buf_get_name(bufnr)
          if name == "" then
            return
          end
          local markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" }
          on_dir(vim.fs.root(bufnr, markers) or vim.fs.dirname(name))
        end,
      })

      -- Missing executables are reported by :checkhealth config rather than
      -- attempting to spawn them on every buffer.
      for server, exe in pairs(require("config.tools").servers) do
        if vim.fn.executable(exe) == 1 then
          vim.lsp.enable(server)
        end
      end

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)

          -- Both Python servers answer hover, but ruff only has blurbs about
          -- its own noqa codes where basedpyright has the real docstrings.
          if client and client.name == "ruff" then
            client.server_capabilities.hoverProvider = false
          end

          local opts = { buffer = args.buf }
          local map = vim.keymap.set
          map("n", "gd", vim.lsp.buf.definition, opts)
          map("n", "gD", vim.lsp.buf.declaration, opts)
          map("n", "grr", vim.lsp.buf.references, opts)
          map("n", "K", vim.lsp.buf.hover, opts)
          map("n", "<leader>rn", vim.lsp.buf.rename, opts)
          map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)
          map("n", "<leader>f", function()
            vim.lsp.buf.format({
              bufnr = args.buf,
              name = "ruff",
              async = false,
              timeout_ms = 2000,
            })
          end, opts)
          -- Drop unused imports and sort what is left (ruff).
          map("n", "<leader>i", function()
            vim.lsp.buf.code_action({
              context = {
                only = { "source.organizeImports.ruff" },
                diagnostics = {},
              },
              apply = true,
            })
          end, opts)
        end,
      })
    end,
  },

  --------------------------------------------------------------------
  -- Markdown rendering
  --------------------------------------------------------------------
  -- Renders headings, lists, tables, code blocks, and checkboxes in the
  -- buffer itself. Pure Lua; treesitter is its only hard dependency.
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = function()
      -- Every icon this plugin ships by default is a Nerd Font glyph, and
      -- this config deliberately has no Nerd Font (see the diagnostic signs
      -- in init.lua). Replacements below are either characters IBM Plex Mono
      -- actually contains, or box/block drawing, which Ghostty renders from
      -- its own sprites rather than from a font at all. Checked with
      -- `ghostty +show-face --string=... --style=regular`.
      --
      -- Override documented keys instead of inspecting plugin internals.
      -- Review these lists when updating the plugin's locked revision.
      local callout = {}
      for _, name in ipairs({
        "note", "tip", "important", "warning", "caution",
        "abstract", "summary", "tldr", "info", "todo", "hint",
        "success", "check", "done", "question", "help", "faq",
        "attention", "failure", "fail", "missing", "danger",
        "error", "bug", "example", "quote", "cite",
      }) do
        callout[name] = { rendered = name:sub(1, 1):upper() .. name:sub(2) }
      end

      local link_custom = {}
      for _, name in ipairs({
        "web", "apple", "discord", "github", "gitlab", "google",
        "hackernews", "linkedin", "microsoft", "neovim", "reddit",
        "slack", "stackoverflow", "steam", "twitter", "wikipedia",
        "x", "youtube", "youtube_short",
      }) do
        link_custom[name] = { icon = "› " }
      end

      return {
        heading = {
          icons = { "# ", "## ", "### ", "#### ", "##### ", "###### " },
          width = "block",
          sign = false,
        },
        code = {
          style = "normal", -- "language" would pull in an icon plugin
          width = "block",
          border = "thin",
          left_pad = 2,
          right_pad = 2,
          sign = false,
        },
        bullet = { icons = { "•", "·", "-", "*" } },
        checkbox = {
          unchecked = { icon = "· " },
          checked = { icon = "✓ " },
          custom = { todo = { rendered = "› " } }, -- the `[-]` in-progress box
        },
        callout = callout,
        quote = { icon = "│" }, -- the same glyph as fillchars.vert
        link = {
          image = "» ",
          email = "@ ",
          hyperlink = "› ",
          footnote = { icon = "« " },
          wiki = { icon = "» " },
          custom = link_custom,
        },
        -- The signcolumn stays reserved for diagnostics.
        sign = { enabled = false },
      }
    end,
  },

  --------------------------------------------------------------------
  -- Completion
  --------------------------------------------------------------------
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        -- Required: basedpyright returns snippet completions, which error
        -- out without a snippet engine wired up.
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = {
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = false }),
          ["<C-y>"] = cmp.mapping.confirm({ select = false }),
          ["<C-n>"] = cmp.mapping.select_next_item(),
          ["<C-p>"] = cmp.mapping.select_prev_item(),
          ["<Down>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
          ["<Up>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
        },
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" },
        }, {
          { name = "buffer" },
        }),
      })

      -- Prose gets buffer words only; LSP noise is unwelcome mid-sentence.
      for _, ft in ipairs({ "markdown", "text", "gitcommit" }) do
        cmp.setup.filetype(ft, {
          sources = { { name = "buffer" }, { name = "path" } },
        })
      end
    end,
  },

  --------------------------------------------------------------------
  -- Autopairs
  --------------------------------------------------------------------
  -- Closes quotes, parens, and braces as you type. This is a separate
  -- concern from nvim-cmp: cmp suggests identifiers, autopairs inserts the
  -- matching delimiter. Neovim has no built-in equivalent.
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    dependencies = { "hrsh7th/nvim-cmp" },
    config = function()
      local npairs = require("nvim-autopairs")

      npairs.setup({
        -- Uses treesitter to know when the cursor is inside a string or a
        -- comment, so typing an apostrophe in a docstring does not leave a
        -- stray closing quote behind.
        check_ts = true,
        ts_config = {
          python = { "string", "comment" },
        },
        -- Auto-closing a quote or bracket mid-sentence is a nuisance when
        -- what you are writing is prose rather than code.
        disable_filetype = { "markdown", "text", "gitcommit" },
        -- `<M-e>` wraps the rest of the line in the pair you just opened.
        fast_wrap = {},
      })

      -- Completing a function name from the LSP should also type the `()`.
      local cmp = require("cmp")
      cmp.event:on(
        "confirm_done",
        require("nvim-autopairs.completion.cmp").on_confirm_done()
      )
    end,
  },
}, {
  ui = { border = "rounded" },
  install = { missing = false },
  rocks = { enabled = false },
  local_spec = false,
  checker = { enabled = false },
  change_detection = { notify = false },
})
