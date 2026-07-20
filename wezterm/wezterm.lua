local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Modern default settings
config.font = wezterm.font_with_fallback {
  { family = 'Geist Mono' },
  { family = 'Twemoji' },
}
config.font_size = 12.0
config.initial_cols = 140
config.initial_rows = 38
config.use_fancy_tab_bar = false
config.enable_wayland = true
config.max_fps = 200

-- Enable terminal ligatures and ensure emoji fallback
-- WezTerm natively supports flags and emojis via HarfBuzz and font shaping
config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' }


config.color_scheme = 'Noctalia'
-- Optional: Window appearance
config.window_background_opacity = 0.95
config.window_close_confirmation = 'NeverPrompt'
config.hide_tab_bar_if_only_one_tab = true

local act = wezterm.action

local function smart_copy()
  return wezterm.action_callback(function(window, pane)
    local has_selection = window:get_selection_text_for_pane(pane) ~= ""
    if has_selection then
      window:perform_action(act.CopyTo('ClipboardAndClearSelection'), pane)
    else
      window:perform_action(act.SendKey{key='c', mods='CTRL'}, pane)
    end
  end)
end

config.keys = {
  -- Вставка на обеих раскладках
  { key = 'v', mods = 'CTRL', action = act.PasteFrom('Clipboard') },
  { key = 'м', mods = 'CTRL', action = act.PasteFrom('Clipboard') },
  -- Копирование (умное: если нет выделения мышью, отправляет Ctrl-c в терминал)
  { key = 'c', mods = 'CTRL', action = smart_copy() },
  { key = 'с', mods = 'CTRL', action = smart_copy() },
  -- Прерывание программы (как старый Ctrl+C)
  { key = 'C', mods = 'CTRL|SHIFT', action = act.SendKey { key = 'c', mods = 'CTRL' } },
  { key = 'С', mods = 'CTRL|SHIFT', action = act.SendKey { key = 'c', mods = 'CTRL' } },
}

config.tab_max_width = 25
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local index = tab.tab_index + 1
  local pane = tab.active_pane
  local title = pane.foreground_process_name
  if title then
    title = title:match("([^/\\\\]+)$") or title
  else
    title = pane.title
  end
  if string.len(title) > 15 then
    title = string.sub(title, 1, 15) .. "…"
  end
  return { { Text = ' ' .. index .. '  ' .. title .. ' ' } }
end)

return config
