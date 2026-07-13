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


config.colors = {
  background = '#1e1e2e',
  foreground = '#cdd6f4',
  cursor_bg = '#f5e0dc',
  cursor_fg = '#1e1e2e',
  cursor_border = '#f5e0dc',
  selection_bg = '#585b70',
  selection_fg = '#cdd6f4',
  ansi = {
    '#1e1e2e', -- 0 black
    '#f38ba8', -- 1 red (high usage)
    '#cba6f7', -- 2 green -> mauve/purple (low usage in fastfetch, bars in alsamixer)
    '#fab387', -- 3 yellow -> peach (mid usage)
    '#89b4fa', -- 4 blue
    '#f5c2e7', -- 5 magenta -> pink
    '#f5e0dc', -- 6 cyan -> rosewater (text in alsamixer)
    '#a6adc8', -- 7 white -> light grey (subtext1)
  },
  brights = {
    '#6c7086', -- 8 bright black -> medium grey (overlay0)
    '#f38ba8', -- 9 bright red
    '#cba6f7', -- 10 bright green -> mauve/purple
    '#fab387', -- 11 bright yellow -> peach
    '#89b4fa', -- 12 bright blue
    '#f5c2e7', -- 13 bright magenta -> pink
    '#f5e0dc', -- 14 bright cyan -> rosewater
    '#bac2de', -- 15 bright white -> light grey (subtext0)
  }
}
-- Optional: Window appearance
config.window_background_opacity = 0.99
config.window_close_confirmation = 'NeverPrompt'
config.hide_tab_bar_if_only_one_tab = true

local act = wezterm.action
config.keys = {
  -- Вставка на обеих раскладках
  { key = 'v', mods = 'CTRL', action = act.PasteFrom('Clipboard') },
  { key = 'м', mods = 'CTRL', action = act.PasteFrom('Clipboard') },
  -- Копирование
  { key = 'c', mods = 'CTRL', action = act.CopyTo('Clipboard') },
  { key = 'с', mods = 'CTRL', action = act.CopyTo('Clipboard') },
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
