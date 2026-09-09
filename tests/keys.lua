local function load_config(target)
  package.loaded.wezterm = {
    target_triple = target,
    config_builder = function()
      return {}
    end,
    font = function(family)
      return { family = family }
    end,
    action = setmetatable({}, {
      __index = function(_, name)
        return setmetatable({ name = name }, {
          __call = function(_, value)
            return { name = name, value = value }
          end,
        })
      end,
    }),
    action_callback = function(callback)
      return { name = "Callback", callback = callback }
    end,
  }
  return dofile("wezterm.lua")
end

local function binding(config, key, mods, action)
  for _, entry in ipairs(config.keys) do
    if entry.key == key and entry.mods == mods then
      assert(entry.action.name == action, key .. ": unexpected action")
      return entry.action
    end
  end
  error("Missing shortcut: " .. mods .. "+" .. key)
end

local targets = {
  "aarch64-apple-darwin",
  "x86_64-apple-darwin",
  "x86_64-pc-windows-msvc",
  "aarch64-pc-windows-msvc",
  "x86_64-unknown-linux-gnu",
}

for _, target in ipairs(targets) do
  local config = load_config(target)
  local mac = target:find("apple-darwin", 1, true) ~= nil
  local primary = mac and "CMD" or "CTRL|SHIFT"
  local utility = mac and "CMD|SHIFT" or "CTRL|SHIFT"
  local secondary = mac and "CMD|SHIFT" or "CTRL|SHIFT|ALT"
  local navigate = mac and "CMD|ALT" or "CTRL|SHIFT"
  local resize = mac and "CMD|CTRL" or "CTRL|SHIFT|ALT"

  assert(#config.keys == 18)
  local seen = {}
  for _, entry in ipairs(config.keys) do
    local modifiers, unique = {}, {}
    for modifier in entry.mods:gmatch("[^|]+") do
      assert(not unique[modifier], "Repeated modifier: " .. entry.mods)
      unique[modifier] = true
      modifiers[#modifiers + 1] = modifier
      if not mac then
        assert(modifier ~= "CMD" and modifier ~= "SUPER" and modifier ~= "WIN")
      end
    end
    table.sort(modifiers)
    local signature = entry.key .. "|" .. table.concat(modifiers, "|")
    assert(not seen[signature], "Duplicate shortcut: " .. signature)
    seen[signature] = true
  end

  assert(binding(config, "d", primary, "SplitHorizontal").value.domain == "CurrentPaneDomain")
  assert(binding(config, "d", secondary, "SplitVertical").value.domain == "CurrentPaneDomain")
  binding(config, "Enter", utility, "TogglePaneZoomState")
  assert(binding(config, "w", primary, "CloseCurrentPane").value.confirm == true)
  for _, direction in ipairs({ "Left", "Right", "Up", "Down" }) do
    assert(binding(config, direction .. "Arrow", navigate, "ActivatePaneDirection").value == direction)
    local action = binding(config, direction .. "Arrow", resize, "AdjustPaneSize")
    assert(action.value[1] == direction and action.value[2] == 5)
  end
  assert(binding(config, "f", primary, "Search").value.CaseInSensitiveString == "")
  binding(config, "x", utility, "ActivateCopyMode")
  binding(config, "Space", utility, "QuickSelect")
  binding(config, "p", utility, "ActivateCommandPalette")
  binding(config, mac and "phys:Comma" or "r", utility, "ReloadConfiguration")

  local window, pane, opened = {}, {}, false
  package.loaded.scrollback = {
    open = function(actual_window, actual_pane)
      assert(actual_window == window and actual_pane == pane)
      opened = true
    end,
  }
  binding(config, "s", utility, "Callback").callback(window, pane)
  assert(opened, "Scrollback action must invoke the viewer")

  if mac then
    assert(config.macos_window_background_blur == 0)
    assert(config.send_composed_key_when_left_alt_is_pressed == false)
    assert(config.send_composed_key_when_right_alt_is_pressed == true)
  else
    assert(config.macos_window_background_blur == nil)
    assert(config.send_composed_key_when_left_alt_is_pressed == nil)
    assert(config.send_composed_key_when_right_alt_is_pressed == nil)
  end
  if target:find("windows", 1, true) then
    assert(#config.default_prog == 2)
    assert(config.default_prog[1] == [[C:\Program Files\PowerShell\7\pwsh.exe]])
    assert(config.default_prog[2] == "-NoLogo")
  else
    assert(config.default_prog == nil)
  end
  assert(config.default_domain == nil)
  assert(config.set_environment_variables == nil)
  assert(config.disable_default_key_bindings == nil)
  assert(config.font.family == "JetBrains Mono" and config.font_size == 13)
  assert(config.line_height == 1.08 and config.scrollback_lines == 50000)
  assert(config.colors.background == "#222436")
  assert(config.colors.ansi[5] == "#2f436e")
end

print("Platform shortcuts: " .. #targets .. " targets passed")
