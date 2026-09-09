# Neovim configuration

This configuration targets Neovim 0.12 or newer. Keep it and `lazy-lock.json`
in the same version-controlled dotfiles repository; retain a known-good commit
before changing the toolchain.

## Dependencies and first installation

The known-good executable versions are recorded in `lua/config/tools.lua`.
The current baseline is Neovim 0.12.2, Tree-sitter CLI 0.26.12, Ruff 0.16.4,
and Basedpyright 1.39.10. Install Git, curl, tar, and a C compiler as well.
Tree-sitter CLI must be at least 0.26.1; install it with the OS package manager,
not npm. Package-manager upgrades may advance these tools independently of
`lazy-lock.json`, so retain the ability to reinstall the recorded versions.

For the Python tools, with `uv` installed:

```sh
uv tool install 'ruff==0.16.4'
uv tool install 'basedpyright==1.39.10'
```

Ensure the tools' executable directory is on the PATH inherited by Neovim.
Missing servers are skipped rather than repeatedly failing to start;
`:checkhealth config` reports missing executables and version drift.

On its first launch, Neovim bootstraps lazy.nvim at the exact commit in
`lazy-lock.json`. Missing plugins are not installed automatically, and project
`.lazy.lua` files cannot modify the plugin specification.

Install missing plugins at their locked commits, then provision parsers in a
fresh process:

```sh
nvim --headless '+lua require("lazy").install({ wait = true, lockfile = true })' +qa
nvim --headless '+ConfigParsers' +qa
```

Review installation errors before proceeding. `:ConfigParsers` is also available
interactively: it waits for both parser updates and missing-parser installation,
reports failures, and does not run during ordinary startup. Restart Neovim
afterward because native parsers may already be loaded.

## Controlled updates and rollback

Update one layer at a time: external executables, or plugins and their parsers.
Use `:Lazy update` deliberately; it advances plugin commits and rewrites the
lockfile. `:Lazy sync` includes an update and is not a restore command.
Automatic update checks and unused LuaRocks support are disabled.

After a plugin update, exit Neovim and run the parser-provisioning command above.
The Tree-sitter build hook also runs `:TSUpdate`, but the separate provisioning
step ensures completion and loads the newly checked-out plugin in a fresh
process. Keep Tree-sitter on `main` for Neovim 0.12, not the frozen `master`.
Review the documented callout/link overrides in `lua/plugins.lua` when updating
render-markdown.

Before accepting an update, open representative Python, Go, and Markdown files,
exercise completion, formatting, prose toggling, and splits, and run:

```vim
:checkhealth config nvim-treesitter vim.lsp lazy
```

Run the dependency-free regression scripts from this configuration directory:

```sh
nvim --headless -u NONE -l tests/prose.lua
nvim --headless -u NONE -l tests/treesitter.lua
nvim --headless -u NONE -l tests/bootstrap.lua
nvim --headless -u NONE -l tests/theme.lua
```

With the plugins and Python servers installed, also exercise the full config:

```sh
nvim --headless -u init.lua -i NONE -n -S tests/integration.lua \
  '+if !get(g:, "config_integration_ok", 0) | cquit | endif' '+qa!'
nvim --headless -u NONE -i NONE -n -l tests/markdown.lua
```

Commit the new lockfile together with any configuration changes. If executable
versions changed intentionally, update `lua/config/tools.lua` and the installation
instructions above.

To roll back, first preserve uncommitted work, then restore the desired config
and lockfile from version control. Run `:Lazy restore`, exit Neovim, and provision
parsers in a fresh process again. Restore external executable versions separately;
the plugin lockfile does not manage them.

## Syntax highlighting

The existing Tree-sitter plugin provides highlighting for Python, Go, and
Markdown, including inline Markdown and Python/Go fenced code blocks. Both
`go` and `golang` fence labels use the Go parser. The parser list also includes
`gomod`, `gosum`, and `gowork` for Go module and workspace files.

The local theme distinguishes purple keywords and booleans, blue functions,
cyan types and fields, green strings, and amber numbers and parameters. Ordinary
variables keep the normal text color, punctuation and comments stay muted, and
Python's LSP semantic colors follow the same palette. Markdown headings use
amber, green, blue, purple, cyan, and rose accents by level, including when the
heading markers are hidden. Links and quotes are cyan, bullets and completed
tasks green, and pending tasks amber. Bold text and inline code use amber;
italic emphasis uses purple. Source and rendered views share these colors, while
fenced blocks keep the embedded language's syntax colors.

No extra theme, highlighting, or Go LSP plugins are required. The plugin list,
completion behavior, and native indentation remain unchanged. On another
machine, run `:ConfigParsers` and restart Neovim after pulling these changes;
parsers are never downloaded automatically during editing.

## Daily-note startup

Opening a Markdown note loads Tree-sitter and the renderer, not the Python LSP
configuration or completion/snippet plugins. Python LSP setup loads on the
Python filetype; completion remains deferred until Insert mode. The renderer's
optional completion probe cannot pull in nvim-cmp early, and prose completion
still offers only buffer words and paths. Rendering updates use a 50 ms debounce.

The shell's `n` command opens the note with the regular configuration; no separate
"fast mode", reduced-functionality editor, or extra plugin is needed.

## Editing behavior

- `<leader>z` toggles prose mode for the current buffer, including all its splits.
  An explicit choice persists across filetype changes. `:ProseAuto` returns to
  the filetype default. Existing mappings and window settings are restored when
  the mode relinquishes them; changes made by another owner are not overwritten
  during restoration.
- Markdown stays rendered in Normal and command-line modes, including the cursor
  line. Headings hide their hash markers and use full-width shaded backgrounds.
  Insert and Visual modes show raw markup; Esc restores the rendered view.
  `<leader>m` (Space, then m) toggles rendering independently of prose mode.
- `<leader>f` formats the current Python buffer synchronously with Ruff, with a
  two-second timeout. It does not format on save or apply delayed asynchronous
  formatting edits.
- In Normal mode, counts work with `h/j/k/l`: `10j` moves ten actual lines down,
  `10k` ten lines up, and `10h`/`10l` ten characters left/right within the line.
  In prose, only uncounted `j/k` use wrapped screen lines. Use `10gj`/`10gk`
  to move ten screen lines. Press Esc before using these motions from Insert mode.

## Writing theme

The default `tokyonight-moon` theme uses Tokyo Night Moon's deep navy background
(`#222436`), soft blue-white text (`#c8d3f5`), and clear blue, cyan, green,
yellow, purple, and red accents. It matches the current WezTerm configuration at
`~/.config/wezterm/wezterm.lua`, retaining strong contrast for normal text,
comments, menus, selections, and rendered Markdown.

Normal/Visual mode uses a steady blue-white block (`#c8d3f5`) with dark text so
the character under the cursor remains readable. Insert mode uses a bright blue
bar (`#82aaff`). Cursor, selection, and all 16 ANSI colors match WezTerm. The
normal ANSI blue is deliberately darker than the syntax accent because
PowerShell renders directories as light text on an ANSI-blue background.
Terminal rendering controls the bar's actual thickness; Neovim's `guicursor`
percentage widths apply to GUIs, not terminal cursor protocols.

`colors/tokyonight-moon.lua`, `colors/forest.lua`, and `colors/paper.lua` use
the shared highlight definitions in `lua/config/theme.lua`, built on Neovim's
bundled `quiet` theme. No new plugins or runtime dependency on a terminal
configuration are needed; the colors work on macOS and Windows. Fonts and
terminal settings are unchanged.

Use `:colorscheme tokyonight-moon` to apply the default theme immediately, or
restart Neovim. `:colorscheme forest` selects the previous Everforest-inspired
dark palette, and `:colorscheme paper` selects the warm-white palette for the
current session. To change the default, update the colorscheme in `init.lua`.
The existing Ghostty Paper theme is unchanged and still matches the light option.

The theme regression script covers all three palettes. Optionally compare the
local WezTerm configuration with Tokyo Night Moon, or the Ghostty theme with Paper:

```sh
nvim --headless -u NONE -l tests/theme.lua --wezterm="$HOME/.config/wezterm/wezterm.lua"
nvim --headless -u NONE -l tests/theme.lua ~/.config/ghostty/themes/paper
```
