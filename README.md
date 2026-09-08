# WezTerm configuration

A muted, Everforest-inspired dark theme for writing and coding, with JetBrains
Mono at 13 pt, gentle line spacing, and 50,000 lines of scrollback. The font is
bundled with WezTerm on macOS and Windows; no separate font installation is
required. Shortcuts remain macOS-oriented, and this config does not change your
shell environment or Neovim theme.

## Set up another Mac

Install WezTerm and the GitHub CLI using Homebrew:

```sh
brew install gh
brew install --cask wezterm
```

Authenticate with a GitHub account that has access to this private repository:

```sh
gh auth login
mkdir -p ~/.config
gh repo clone hariscats/wezterm ~/.config/wezterm
```

If `~/.config/wezterm` already exists, move it to a uniquely named backup before
cloning.

Open WezTerm. Saved configuration edits reload automatically; `Cmd+Shift+,`
also reloads the configuration. No terminal plugins are required.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| `Cmd+D` / `Cmd+Shift+D` | Split right / below |
| `Cmd+Option+Arrow` | Move between panes |
| `Cmd+Ctrl+Arrow` | Resize panes |
| `Cmd+Shift+Enter` | Zoom or unzoom the current pane |
| `Cmd+W` | Close the current pane, with confirmation for active work |
| `Cmd+F` | Search terminal output |
| `Cmd+Shift+X` | Copy mode: `hjkl` to move, `v` to select, `y` to copy, `Esc` to exit |
| `Cmd+Shift+Space` | Quickly copy paths, URLs, hashes, and other matches |
| `Cmd+Shift+P` | Command palette |

Left Option sends Alt shortcuts; right Option remains available for accented
characters. Standard WezTerm tab, clipboard, and font-size shortcuts remain enabled.

## Pull updates

Commit or otherwise preserve local edits before pulling:

```sh
git -C ~/.config/wezterm pull --ff-only
```
