import GLib from "gi://GLib"
import { Gtk, Gdk } from "ags/gtk3"

export const CONFIG_PATH = `${GLib.get_home_dir()}/.config/ags/config.json`

const DEFAULT_CONFIG = {
  bar: {
    layer: "OVERLAY",
    anchor: ["TOP"],
    marginTop: 9,
    monitor: "primary"
  },
  clock: {
    format: "%H:%M",
    interval: 1000,
    leftClick: "noctalia msg panel-toggle control-center calendar",
    rightClick: "alarm-menu"
  },
  fullscreen: {
    border: {
      width: 1,
      style: "solid",
      fallbackColor: "#f5c2e7"
    },
    layer: "OVERLAY"
  },
  appearance: {
    fontFamily: "'Adwaita Sans', 'Noto Sans', sans-serif",
    fontSize: 12,
    clockFontSize: 14,
    clockColor: "#f2f2f3",
    borderRadius: 12,
    themeImport: "noctalia.css"
  },
  alarms: {
    snoozeDuration: 5,
    autoSnoozeDuration: 1,
    missedThreshold: 30,
    checkInterval: 60,
    sound: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga",
    player: "pw-play",
    wakeBeforeAlarm: 5,
    defaultTime: "08:00",
    defaultDays: "All"
  },
  alarmOSD: {
    layer: "OVERLAY",
    anchor: ["TOP"],
    marginTop: 84
  },
  alarmMenu: {
    layer: "OVERLAY",
    anchor: ["TOP", "BOTTOM", "LEFT", "RIGHT"],
    marginTop: 24,
    marginBottom: 40,
    width: 360,
    maxScrollHeight: 600
  },
  hotReload: {
    enabled: true,
    debounce: 200
  }
}

function deepMerge(target, source) {
  for (const key of Object.keys(source)) {
    if (source[key] instanceof Object && key in target && target[key] instanceof Object) {
      Object.assign(source[key], deepMerge(target[key], source[key]))
    }
  }
  return { ...target, ...source }
}

export function getConfig() {
  try {
    const [ok, contents] = GLib.file_get_contents(CONFIG_PATH)
    if (ok) {
      const userConfig = JSON.parse(new TextDecoder("utf-8").decode(contents))
      return deepMerge(DEFAULT_CONFIG, userConfig)
    }
  } catch (e) {
    // Return defaults if parsing fails
  }
  return DEFAULT_CONFIG
}

let dynamicCssProvider = null

export function applyCssVariables() {
  const cfg = getConfig()
  const a = cfg.appearance

  const home = GLib.get_home_dir()
  const themeImport = `@import url("file://${home}/.config/gtk-3.0/${a.themeImport}");`

  const vars = `
    ${themeImport}

    * {
      --panel-font-family: ${a.fontFamily};
      --panel-font-size: ${a.fontSize}px;
      --panel-clock-font-size: ${a.clockFontSize}px;
      --panel-clock-color: ${a.clockColor ?? 'inherit'};
      --panel-border-radius: ${a.borderRadius}px;
      --panel-fs-border-width: ${cfg.fullscreen.border.width}px;
      --panel-fs-border-style: ${cfg.fullscreen.border.style};
      --panel-fs-border-color: ${cfg.fullscreen.border.fallbackColor};
    }
  `
  
  if (!dynamicCssProvider) {
      dynamicCssProvider = new Gtk.CssProvider()
      Gtk.StyleContext.add_provider_for_screen(
          Gdk.Screen.get_default(),
          dynamicCssProvider,
          Gtk.STYLE_PROVIDER_PRIORITY_USER
      )
  }
  dynamicCssProvider.load_from_data(vars)
}
