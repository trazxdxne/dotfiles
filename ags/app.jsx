import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import { execAsync, subprocess } from "ags/process"
import { createPoll } from "ags/time"
import GLib from "gi://GLib"
import Gio from "gi://Gio"
import style from "./style.css"

const timeVal = createPoll("", 1000, 'date +"%H:%M"')

const barWindows = []
const fileMonitors = [] // держим ссылки живыми, иначе GC их убьёт
let cssProvider = null

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
            console.error(`[bar] failed to read ${filename}: ${e.message}`)
        }
    }
    return "#f5c2e7" // fallback
}

function updateAccentColor() {
    const accentColor = readNiriAccentColor()

    if (!cssProvider) {
        cssProvider = new Gtk.CssProvider()
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            cssProvider,
            Gtk.STYLE_PROVIDER_PRIORITY_USER
        )
    }

    try {
        cssProvider.load_from_data(`
            .Bar.fullscreen .clock-box {
                background-color: rgba(36, 33, 48, 0.7);
                border-color: ${accentColor};
                border-style: solid;
                border-width: 1px;
            }
        `)
    } catch (e) {
        console.error(`[bar] failed to update accent color CSS: ${e.message}`)
    }
}

function monitorConfig(filename) {
    try {
        const path = GLib.build_filenamev([GLib.get_home_dir(), ".config", "niri", filename])
        const file = Gio.File.new_for_path(path)
        const monitor = file.monitor_file(Gio.FileMonitorFlags.NONE, null)
        monitor.connect("changed", () => {
            // Небольшая задержка, чтобы файл успел записаться на диск
            GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
                updateAccentColor()
                return GLib.SOURCE_REMOVE
            })
        })
        fileMonitors.push(monitor) // важно: без этого monitor может быть собран GC
    } catch (e) {
        console.error(`[bar] failed to watch ${filename}: ${e.message}`)
    }
}

const handleWindows = (windows) => {
    if (!windows) return

    barWindows.forEach(win => {
        if (!win) return

        let monitorWidth = null
        let monitorHeight = null
        try {
            const rect = win.monitor.get_geometry()
            monitorWidth = rect.width
            monitorHeight = rect.height
        } catch (e) {
            console.error(`[bar] failed to get monitor geometry: ${e.message}`)
        }

        const context = win.get_style_context()

        if (monitorWidth === null || monitorHeight === null) {
            context.remove_class("fullscreen")
            return
        }

        const hasFullscreen = windows.some(w => {
            if (!w.is_focused) return false
            const layout = w.layout
            if (!layout || !layout.window_size) return false
            const [width, height] = layout.window_size
            return width >= monitorWidth && height >= monitorHeight
        })

        if (hasFullscreen) {
            context.add_class("fullscreen")
        } else {
            context.remove_class("fullscreen")
        }
    })
}

const checkFullscreen = () => {
    execAsync("niri msg --json windows")
        .then(out => {
            try {
                handleWindows(JSON.parse(out))
            } catch (e) {
                console.error(`[bar] failed to parse windows JSON: ${e.message}`)
            }
        })
        .catch(e => {
            console.error(`[bar] niri msg windows failed: ${e.message}`)
        })
}

const processNiriEvent = (event) => {
    if (event.WorkspaceActivated || event.WindowsChanged || event.WindowFocusChanged || event.WindowLayoutsChanged) {
        checkFullscreen()
    }
    if (event.ConfigLoaded) {
        updateAccentColor()
    }
}

subprocess("niri msg --json event-stream", (line) => {
    if (!line) return
    const trimmed = line.trim()
    if (!trimmed) return
    try {
        processNiriEvent(JSON.parse(trimmed))
    } catch (e) {
        console.error(`[bar] failed to parse event-stream line: ${e.message}`)
    }
})

function Clock() {
    return (
        <box class="clock-box" halign={Gtk.Align.CENTER}>
            <label class="clock-time" label={timeVal} />
        </box>
    )
}

function Bar(gdkmonitor) {
    const { TOP } = Astal.WindowAnchor

    const barWindow = (
        <window
            class="Bar"
            gdkmonitor={gdkmonitor}
            exclusivity={Astal.Exclusivity.IGNORE}
            anchor={TOP}
            layer={Astal.Layer.OVERLAY}
            application={app}
            margin_top={9}
        >
            <Clock />
        </window>
    )

    barWindow.monitor = gdkmonitor
    barWindows.push(barWindow)

    Astal.widget_set_click_through(barWindow, true)

    return barWindow
}

app.start({
    css: style,
    main() {
        app.get_monitors().map(Bar)

        // Первичная настройка цвета и запуск мониторинга конфигов для hot-reload
        updateAccentColor()
        NIRI_CONFIG_FILES.forEach(monitorConfig)

        // Один общий вызов после создания всех окон, а не по разу на монитор
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
            checkFullscreen()
            return GLib.SOURCE_REMOVE
        })
    }
})
