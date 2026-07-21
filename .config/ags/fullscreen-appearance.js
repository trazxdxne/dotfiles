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
    const { appearance } = config
    
    // Apply opacity if specified
    const opacity = border.opacity !== undefined ? border.opacity : 1.0
    const borderColor = opacity < 1.0 ? `alpha(${accentColor}, ${opacity})` : accentColor

    const isOutside = border.position === "outside"
    const wrapperRadius = (appearance?.borderRadius || 12) + border.width

    try {
        const css = isOutside ? `
            .clock-wrapper {
                border: ${border.width}px solid transparent;
                border-radius: ${wrapperRadius}px;
                margin: -${border.width}px;
            }
            .Bar.fullscreen .clock-wrapper {
                border-color: ${borderColor};
                border-style: ${border.style};
                transition: all ${background?.transition || '0.15s'};
            }
            .Bar.fullscreen .clock-box {
                background-color: ${background?.color || 'transparent'};
                transition: all ${background?.transition || '0.15s'};
            }` : `
            .clock-wrapper {
                border: none;
                margin: 0;
            }
            .Bar.fullscreen .clock-box {
                border-color: ${borderColor};
                border-style: ${border.style};
                border-width: ${border.width}px;
                background-color: ${background?.color || 'transparent'};
                background-clip: padding-box;
                transition: all ${background?.transition || '0.15s'};
            }`

        cssProvider.load_from_data(css)
    } catch (e) {
        console.error(`[fullscreen-appearance] failed to update fullscreen CSS: ${e.message}`)
    }
}
