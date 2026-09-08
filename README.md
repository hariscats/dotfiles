# WezTerm configuration

A muted, Everforest-inspired dark theme for writing and coding, with JetBrains
Mono at 13 pt, gentle line spacing, and 50,000 lines of scrollback. The font is
bundled with WezTerm on macOS and Windows; no separate font installation is
required. Shortcuts adapt to macOS or Windows/Linux without changing your
default shell, shell environment, or normal Neovim theme.

## Setup

Back up an existing `~/.config/wezterm` directory under a unique name before
cloning. Use a GitHub account with access to this private repository.

### macOS

Install WezTerm, the GitHub CLI, and Neovim using Homebrew:

```sh
brew install gh neovim
brew install --cask wezterm
gh auth login
mkdir -p ~/.config
gh repo clone hariscats/wezterm ~/.config/wezterm
```

### Windows

Install the native Windows applications from PowerShell:

```powershell
winget install --id wez.wezterm --exact
winget install --id Git.Git --exact
winget install --id GitHub.cli --exact
winget install --id Neovim.Neovim --exact
```

Open a new PowerShell window so the installed programs are on PATH, then clone
into your Windows home directory, not your WSL home:

```powershell
gh auth login
New-Item -ItemType Directory -Force "$HOME\.config" | Out-Null
gh repo clone hariscats/wezterm "$HOME\.config\wezterm"
```

Restart WezTerm after installing Neovim so it inherits the updated PATH.
Neovim is only needed for the scrollback viewer. The default Windows shell is
unchanged (normally Command Prompt); this config does not select PowerShell or
WSL automatically.

Saved configuration edits reload automatically. No terminal plugins are required.

## Shortcuts

| Action | macOS | Windows / Linux |
| --- | --- | --- |
| Split right | `Cmd+D` | `Ctrl+Shift+D` |
| Split below | `Cmd+Shift+D` | `Ctrl+Shift+Alt+D` |
| Move between panes | `Cmd+Option+Arrow` | `Ctrl+Shift+Arrow` |
| Resize panes | `Cmd+Ctrl+Arrow` | `Ctrl+Shift+Alt+Arrow` |
| Zoom or unzoom the current pane | `Cmd+Shift+Enter` | `Ctrl+Shift+Enter` |
| Close the current pane, confirming active work | `Cmd+W` | `Ctrl+Shift+W` |
| Search terminal output | `Cmd+F` | `Ctrl+Shift+F` |
| Copy mode | `Cmd+Shift+X` | `Ctrl+Shift+X` |
| Quickly copy paths, URLs, hashes, and other matches | `Cmd+Shift+Space` | `Ctrl+Shift+Space` |
| Command palette | `Cmd+Shift+P` | `Ctrl+Shift+P` |
| Reload configuration | `Cmd+Shift+,` | `Ctrl+Shift+R` |
| Open scrollback in Neovim | `Cmd+Shift+S` | `Ctrl+Shift+S` |

In copy mode, use `hjkl` to move, `v` to select, `y` to copy, and `Esc` to exit.
On macOS, left Option sends Alt shortcuts and right Option types accented
characters; Windows AltGr handling is left unchanged. Standard WezTerm tab,
clipboard, and font-size shortcuts remain enabled.

## Scrollback in Neovim

The scrollback shortcut captures the focused pane's available history and screen
as plain text, preserving soft-wrapped logical lines, then opens a read-only
viewer in a new local Neovim tab at the end of the output. Use `/` to search,
`n`/`N` for matches, `gg`/`G` to navigate, and `q` or `:q` to close it. The
original terminal and its running command are left alone.

Install native Neovim 0.9+ on the machine running WezTerm and make `nvim`
available on WezTerm's PATH. A Neovim installation only inside WSL or on an SSH
host is not sufficient: even those panes are viewed with local Neovim.
The standard macOS Homebrew locations are also supported. For a custom location,
set `WEZTERM_NVIM` to the full executable path (without extra arguments) in the
environment used to launch WezTerm, then restart WezTerm.

The viewer does not load your normal Neovim configuration, plugins, or modelines.
It disables swap, persistent undo, and ShaDa history. Exports are privately
allocated in the OS temporary directory, not this repository, and removed after
Neovim reads them; there is no fixed-delay deletion timer. A crash or forced
termination before the read can leave an export behind. Error messages identify
failed exports that need manual removal; these files may contain sensitive output.

## Pull updates

Commit or otherwise preserve local edits before pulling:

```sh
git -C ~/.config/wezterm pull --ff-only
```

## Regression checks

From this directory, with Neovim 0.10+:

```sh
nvim --headless -u NONE -i NONE -n -l tests/keys.lua
nvim --headless -u NONE -i NONE -n -l tests/scrollback.lua
```

The scripts cover platform-specific keybindings, the local viewer, and export
failure/cleanup paths without loading your normal Neovim configuration.
