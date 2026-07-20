import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import { execAsync, subprocess } from "ags/process"
import { createPoll } from "ags/time"
import GLib from "gi://GLib"
import Gio from "gi://Gio"
import style from "./style.css"
import { toggleAlarmMenu, setupAlarmWindows } from "./alarms.jsx"
import { getConfig, applyCssVariables } from "./config.js"

const config = getConfig()
const timeVal = createPoll("", config.clock.interval, `date +"${config.clock.format}"`)

const barWindows = []
const fileMonitors = []
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
    return "#f5c2e7"
}

function updateAccentColor() {
    const accentColor = readNiriAccentColor() || config.fullscreen.border.fallbackColor

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
                border-color: ${accentColor};
                border-style: ${config.fullscreen.border.style};
                border-width: ${config.fullscreen.border.width}px;
            }
        `)
    } catch (e) {
        console.error(`[bar] failed to update accent color CSS: ${e.message}`)
    }
}

function setupNiriMonitor() {
    try {
        const path = GLib.build_filenamev([GLib.get_home_dir(), ".config", "niri"])
        const file = Gio.File.new_for_path(path)
        const monitor = file.monitor_directory(Gio.FileMonitorFlags.NONE, null)
        monitor.connect("changed", (monitor, file, other_file, event_type) => {
            if (event_type === Gio.FileMonitorEvent.CHANGES_DONE_HINT || event_type === Gio.FileMonitorEvent.CREATED) {
                const name = file.get_basename()
                if (NIRI_CONFIG_FILES.includes(name)) {
                    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
                        updateAccentColor()
                        return GLib.SOURCE_REMOVE
                    })
                }
            }
        })
        fileMonitors.push(monitor)
    } catch (e) {
        console.error(`[bar] failed to watch niri dir: ${e.message}`)
    }
}

let reloadTimeout = null;

function setupHotReload() {
    const watchDir = (dirPath) => {
        try {
            const monitor = Gio.File.new_for_path(dirPath).monitor_directory(Gio.FileMonitorFlags.NONE, null)
            monitor.connect("changed", (monitor, file, other_file, event_type) => {
                if (event_type === Gio.FileMonitorEvent.CHANGES_DONE_HINT || event_type === Gio.FileMonitorEvent.CREATED) {
                    const path = file.get_path()
                    if (path && (path.endsWith(".js") || path.endsWith(".jsx") || path.endsWith(".ts") || path.endsWith(".css") || path.endsWith("config.json"))) {
                        if (reloadTimeout) GLib.source_remove(reloadTimeout);
                        reloadTimeout = GLib.timeout_add(GLib.PRIORITY_DEFAULT, config.hotReload.debounce, () => {
                            console.log(`[hot-reload] File changed: ${path}, restarting ags via systemd...`)
                            GLib.spawn_command_line_async('systemctl --user restart ags.service')
                            reloadTimeout = null;
                            return GLib.SOURCE_REMOVE;
                        });
                    }
                }
            })
            fileMonitors.push(monitor)
        } catch (e) {
            console.error(`[hot-reload] failed to watch ${dirPath}: ${e.message}`)
        }
    }
    
    watchDir(GLib.build_filenamev([GLib.get_home_dir(), ".config", "ags"]))
    watchDir(GLib.build_filenamev([GLib.get_home_dir(), ".config", "gtk-3.0"]))
}

const handleWindows = (windows) => {
    if (!windows) return

    barWindows.forEach(win => {
        if (!win) return

        let monitorWidth = 1920
        let monitorHeight = 1080
        try {
            // Astal Window uses gdkmonitor property
            const monitor = win.gdkmonitor || win.monitor
            if (monitor) {
                const rect = monitor.get_geometry()
                monitorWidth = rect.width
                monitorHeight = rect.height
            }
        } catch (e) {
            console.error(`[bar] failed to get monitor geometry: ${e.message}`)
        }

        const context = win.get_style_context()

        if (monitorWidth === null || monitorHeight === null) {
            context.remove_class("fullscreen")
            Astal.widget_set_click_through(win, false)
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
            Astal.widget_set_click_through(win, true)
            win.set_layer(Astal.Layer.OVERLAY)
        } else {
            context.remove_class("fullscreen")
            Astal.widget_set_click_through(win, false)
            win.set_layer(win.defaultLayer !== undefined ? win.defaultLayer : Astal.Layer.BOTTOM)
        }
    })
}

const checkFullscreen = () => {
    if (GLib.getenv("XDG_CURRENT_DESKTOP") === "Hyprland") {
        execAsync("hyprctl clients -j")
            .then(out => {
                try {
                    const clients = JSON.parse(out)
                    const mapped = clients.map(w => ({
                        is_focused: w.focusHistoryID === 0,
                        layout: { window_size: w.size }
                    }))
                    handleWindows(mapped)
                } catch(e) {
                    console.error(`[bar] failed to parse hyprctl: ${e.message}`)
                }
            })
            .catch(e => console.error(`[bar] hyprctl failed: ${e.message}`))
    } else {
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
}

const processNiriEvent = (event) => {
    if (event.WorkspaceActivated || event.WindowsChanged || event.WindowFocusChanged || event.WindowLayoutsChanged) {
        checkFullscreen()
    }
    if (event.ConfigLoaded) {
        updateAccentColor()
    }
}

const desktop = GLib.getenv("XDG_CURRENT_DESKTOP")
if (desktop === "Hyprland") {
    const sig = GLib.getenv("HYPRLAND_INSTANCE_SIGNATURE")
    if (sig) {
        subprocess(["bash", "-c", `socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/${sig}/.socket2.sock`], (line) => {
            if (line) checkFullscreen()
        })
    }
} else {
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
}

function Clock() {
    return (
        <button
            class="clock-box"
            halign={Gtk.Align.CENTER}
            onButtonReleaseEvent={(self, event) => {
                const btn = event.get_button()[1]
                if (btn === 1 && config.clock.leftClick) {
                    if (config.clock.leftClick === "alarm-menu") toggleAlarmMenu()
                    else execAsync(["bash", "-c", config.clock.leftClick]).catch(() => {})
                } else if (btn === 3 && config.clock.rightClick) {
                    if (config.clock.rightClick === "alarm-menu") toggleAlarmMenu()
                    else execAsync(["bash", "-c", config.clock.rightClick]).catch(() => {})
                }
            }}
            onEnterNotifyEvent={(self) => {
                const display = self.get_display()
                const window = self.get_window()
                if (window) window.set_cursor(Gdk.Cursor.new_from_name(display, "pointer"))
                return false
            }}
            onLeaveNotifyEvent={(self) => {
                const window = self.get_window()
                if (window) window.set_cursor(null)
                return false
            }}
        >
            <label class="clock-time" label={timeVal} />
        </button>
    )
}

function Bar(gdkmonitor) {
    const anchor = config.bar.anchor.reduce((acc, a) => acc | Astal.WindowAnchor[a], 0)
    const layer = Astal.Layer[config.bar.layer] || Astal.Layer.OVERLAY

    const barWindow = (
        <window
            class="Bar"
            gdkmonitor={gdkmonitor}
            monitor={gdkmonitor}
            exclusivity={Astal.Exclusivity.IGNORE}
            anchor={anchor}
            layer={layer}
            application={app}
            margin_top={config.bar.marginTop}
        >
            <Clock />
        </window>
    )

    barWindow.defaultLayer = layer
    barWindow.gdkmonitor = gdkmonitor
    barWindows.push(barWindow)


    return barWindow
}

app.start({
    css: style,
    main() {
        applyCssVariables(app)
        setupAlarmWindows()
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
            const monitors = app.get_monitors();
            let targetMonitor = null;
            
            if (config.bar.monitor === "primary") {
                targetMonitor = monitors.find(m => {
                    const rect = m.get_geometry();
                    return rect.x === 0 && rect.y === 0;
                }) || monitors[0];
            } else if (typeof config.bar.monitor === "number") {
                targetMonitor = monitors[config.bar.monitor] || monitors[0];
            } else {
                targetMonitor = monitors.find(m => m.get_model() === config.bar.monitor) || monitors[0];
            }
            
            if (targetMonitor) {
                console.log("[bar] creating bar on monitor");
                Bar(targetMonitor);
            }
            return GLib.SOURCE_REMOVE;
        });

        updateAccentColor()
        setupNiriMonitor()
        setupHotReload()

        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
            checkFullscreen()
            return GLib.SOURCE_REMOVE
        })
    }
})
