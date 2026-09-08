local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- A soft, Everforest-inspired dark palette for prose and code.
local palette = {
  bg = "#2d353b",
  fg = "#d3c6aa",
  cursor = "#a7c080",
  insert_cursor = "#d3c6aa",
  muted = "#9da9a0",
  panel = "#272e33",
  border = "#4f585e",
  selection = "#425047",
  search = "#4f5144",
  red = "#e67e80",
  green = "#a7c080",
  yellow = "#dbbc7f",
  blue = "#7fbbb3",
  purple = "#d699b6",
  cyan = "#83c092",
}

config.colors = {
  foreground = palette.fg,
  background = palette.bg,
  cursor_bg = palette.cursor,
  cursor_fg = palette.bg,
  -- Bar cursors use cursor_border; block cursors use cursor_bg.
  cursor_border = palette.insert_cursor,
  selection_fg = palette.fg,
  selection_bg = palette.selection,
  scrollbar_thumb = palette.border,
  split = palette.border,
  compose_cursor = palette.yellow,
  ansi = {
    "#475258", palette.red, palette.green, palette.yellow,
    palette.blue, palette.purple, palette.cyan, palette.fg,
  },
  brights = {
    palette.muted, palette.red, palette.green, palette.yellow,
    palette.blue, palette.purple, palette.cyan, "#e6ddcb",
  },
  copy_mode_active_highlight_bg = { Color = palette.search },
  copy_mode_active_highlight_fg = { Color = palette.fg },
  copy_mode_inactive_highlight_bg = { Color = palette.selection },
  copy_mode_inactive_highlight_fg = { Color = palette.fg },
  quick_select_label_bg = { Color = palette.blue },
  quick_select_label_fg = { Color = palette.bg },
  quick_select_match_bg = { Color = palette.search },
  quick_select_match_fg = { Color = palette.fg },
  tab_bar = {
    background = palette.panel,
    active_tab = { bg_color = palette.bg, fg_color = palette.fg, intensity = "Bold" },
    inactive_tab = { bg_color = palette.panel, fg_color = palette.muted },
    inactive_tab_hover = { bg_color = palette.selection, fg_color = palette.fg },
  },
}

config.font = wezterm.font_with_fallback({ "IBM Plex Mono", "Menlo" })
config.font_size = 13
config.line_height = 1.08
config.harfbuzz_features = { "calt=0", "liga=0", "dlig=0" }
config.bold_brightens_ansi_colors = false

config.initial_cols = 160
config.initial_rows = 45
config.window_padding = { left = 8, right = 8, top = 6, bottom = 6 }
config.window_background_opacity = 1.0
config.text_background_opacity = 1.0
config.macos_window_background_blur = 0
-- Preserve the background and syntax contrast in inactive splits.
config.inactive_pane_hsb = { saturation = 1.0, brightness = 1.0 }
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 32

-- Neovim can still request its own mode-specific cursor shape and color.
config.default_cursor_style = "SteadyBar"
config.cursor_blink_rate = 0
config.force_reverse_video_cursor = false
config.hide_mouse_cursor_when_typing = true
config.audible_bell = "Disabled"
config.scrollback_lines = 50000
config.window_close_confirmation = "AlwaysPrompt"
config.automatically_reload_config = true

-- Left Option sends Alt shortcuts; right Option can type accented prose.
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = true

-- Keep the default shell, environment, and editor shortcuts intact.
-- Splits use the current domain and WezTerm's working-directory inheritance.
config.keys = {
  { key = "d", mods = "CMD", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "d", mods = "CMD|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { key = "Enter", mods = "CMD|SHIFT", action = act.TogglePaneZoomState },
  { key = "w", mods = "CMD", action = act.CloseCurrentPane({ confirm = true }) },

  { key = "LeftArrow", mods = "CMD|ALT", action = act.ActivatePaneDirection("Left") },
  { key = "RightArrow", mods = "CMD|ALT", action = act.ActivatePaneDirection("Right") },
  { key = "UpArrow", mods = "CMD|ALT", action = act.ActivatePaneDirection("Up") },
  { key = "DownArrow", mods = "CMD|ALT", action = act.ActivatePaneDirection("Down") },
  { key = "LeftArrow", mods = "CMD|CTRL", action = act.AdjustPaneSize({ "Left", 5 }) },
  { key = "RightArrow", mods = "CMD|CTRL", action = act.AdjustPaneSize({ "Right", 5 }) },
  { key = "UpArrow", mods = "CMD|CTRL", action = act.AdjustPaneSize({ "Up", 5 }) },
  { key = "DownArrow", mods = "CMD|CTRL", action = act.AdjustPaneSize({ "Down", 5 }) },

  { key = "f", mods = "CMD", action = act.Search({ CaseInSensitiveString = "" }) },
  -- Copy mode: h/j/k/l to move, v to select, y to copy, Esc to leave.
  { key = "x", mods = "CMD|SHIFT", action = act.ActivateCopyMode },
  -- Label and copy paths, URLs, hashes, and other matches from visible output.
  { key = "Space", mods = "CMD|SHIFT", action = act.QuickSelect },
  { key = "p", mods = "CMD|SHIFT", action = act.ActivateCommandPalette },
  { key = "phys:Comma", mods = "CMD|SHIFT", action = act.ReloadConfiguration },
}

return config