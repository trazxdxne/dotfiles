import GLib from "gi://GLib"
import Gio from "gi://Gio"
import { Gtk, Gdk } from "ags/gtk3"
import { getConfig } from "./config.js"

const NIRI_CONFIG_FILES = ["noctalia.kdl", "config.kdl"]

function readNiriAccentColor() {
    for (const filename of NIRI_CONFIG_FILES) {
        try {
            const path = GLib.build_filenamev([GLib.get_home_dir(), ".config", "niri", filename])
            const file = Gio.File.new_for_path(path)
            const [ok, content] = file.load_contents(null)
            if (ok) {
                const text = new TextDecoder("utf-8").decode(content)
                const focusRingMatch = text.match(/focus-ring\s*\{([^}]+)\}/)
                if (focusRingMatch) {
                    const colorMatch = focusRingMatch[1].match(/active-color\s*"([^"]+)"/)
                    if (colorMatch) {
                        return colorMatch[1]
                    }
                }
            }
        } catch (e) {
            console.error(`[fullscreen-appearance] failed to read ${filename}: ${e.message}`)
        }
    }
    return null
}

let cssProvider = null

export function refreshAccentColor() {
    applyFullscreenStyles()
}

export function applyFullscreenStyles() {
    const config = getConfig()
    const accentColor = readNiriAccentColor() || config.fullscreen.border.fallbackColor

    if (!cssProvider) {
        cssProvider = new Gtk.CssProvider()
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            cssProvider,
            Gtk.STYLE_PROVIDER_PRIORITY_USER
        )
    }

    const { border, background } = config.fullscreen

    try {
        cssProvider.load_from_data(`
            .Bar.fullscreen .clock-box {
                border-color: ${accentColor};
                border-style: ${border.style};
                border-width: ${border.width}px;
                background-color: ${background?.color || 'transparent'};
                transition: all ${background?.transition || '0.15s'};
            }
        `)
    } catch (e) {
        console.error(`[fullscreen-appearance] failed to update fullscreen CSS: ${e.message}`)
    }
}
