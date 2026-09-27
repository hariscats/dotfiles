# Dotfiles

Personal configuration for:

- [Neovim](nvim/)
- [WezTerm](wezterm/)

Both configurations work on macOS and Windows.

## Installation

### macOS

Clone this repository to `~/.config` so both applications use their
configuration directly:

```sh
git clone https://github.com/hariscats/dotfiles.git ~/.config
```

### Windows

WezTerm reads `%USERPROFILE%\.config\wezterm\wezterm.lua`, but Neovim looks in
`%LOCALAPPDATA%\nvim` unless `XDG_CONFIG_HOME` is set. Clone the repository to
`%USERPROFILE%\.config` and point `XDG_CONFIG_HOME` at it (PowerShell):

```powershell
git clone https://github.com/hariscats/dotfiles.git "$HOME\.config"
[Environment]::SetEnvironmentVariable("XDG_CONFIG_HOME", "$HOME\.config", "User")
```

Restart WezTerm and Neovim afterwards. WezTerm starts
[PowerShell 7](https://github.com/PowerShell/PowerShell) (`pwsh.exe`), which
must be on `PATH`. Neovim requires `git` on `PATH` to install plugins.

Neovim installs its plugins with [lazy.nvim](https://github.com/folke/lazy.nvim)
on first launch. Commit the generated `nvim/lazy-lock.json` to pin plugin
versions.
