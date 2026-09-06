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

Before accepting an update, open representative Python and Markdown files,
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
```

Commit the new lockfile together with any configuration changes. If executable
versions changed intentionally, update `lua/config/tools.lua` and the installation
instructions above.

To roll back, first preserve uncommitted work, then restore the desired config
and lockfile from version control. Run `:Lazy restore`, exit Neovim, and provision
parsers in a fresh process again. Restore external executable versions separately;
the plugin lockfile does not manage them.

## Editing behavior

- `<leader>z` toggles prose mode for the current buffer, including all its splits.
  An explicit choice persists across filetype changes. `:ProseAuto` returns to
  the filetype default. Existing mappings and window settings are restored when
  the mode relinquishes them; changes made by another owner are not overwritten
  during restoration.
- `<leader>m` toggles Markdown rendering independently of prose mode.
- `<leader>f` formats the current Python buffer synchronously with Ruff, with a
  two-second timeout. It does not format on save or apply delayed asynchronous
  formatting edits.
- In Normal mode, counts work with `h/j/k/l`: `10j` moves ten actual lines down,
  `10k` ten lines up, and `10h`/`10l` ten characters left/right within the line.
  In prose, only uncounted `j/k` use wrapped screen lines. Use `10gj`/`10gk`
  to move ten screen lines. Press Esc before using these motions from Insert mode.

## Writing theme

`colors/paper.lua` builds on Neovim's bundled `quiet` theme, without another
plugin. It uses a warm off-white page (`#faf9f6`), charcoal text (`#3f3a34`),
muted accents, and restrained heading/code backgrounds. Spelling feedback
remains enabled, with underlines rather than recoloring the whole word.

Normal/Visual mode uses a steady light-gray block (`#d3cec4`) with dark text
(`#3f3a34`) so the character under the cursor remains readable. Insert mode uses
a darker charcoal bar (`#68645e`). `guicursor` explicitly selects the appropriate
highlight for each mode. Ghostty uses full cursor opacity to preserve text
contrast and `adjust-cursor-thickness` for bar width; terminal cursor protocols
do not carry Neovim's GUI percentage widths.

Ghostty's matching theme is `~/.config/ghostty/themes/paper`; keep its background,
foreground, cursor, selection, and 16 ANSI colors synchronized with the Neovim
theme. The macOS Ghostty config selects `theme = paper` and `window-theme = light`,
with an opaque background and no blur so desktop colors cannot tint the page.
Fonts, font size, and line spacing are unchanged.

To include Ghostty's palette in the theme regression script:

```sh
nvim --headless -u NONE -l tests/theme.lua ~/.config/ghostty/themes/paper
```

Restart Neovim to load the default theme, or use `:colorscheme paper` to change
only the theme in an existing session. Reload Ghostty with Cmd+Shift+Comma for
the new colors; changing background opacity requires quitting and reopening
Ghostty on macOS. Save your editor buffers before quitting the terminal.
