import app from "ags/gtk3/app"
import { Astal, Gtk } from "ags/gtk3"
import { execAsync, subprocess } from "ags/process"
import { createPoll } from "ags/time"
import GLib from "gi://GLib"
import style from "./style.css"

const timeVal = createPoll("", 1000, 'date +"%H:%M"')

let barWindow = null
let monitorWidth = 1920
let monitorHeight = 1080

const handleWindows = (windows) => {
    if (!barWindow || !windows) return
    
    const hasFullscreen = windows.some(w => {
        if (!w.is_focused) return false
        const layout = w.layout
        if (!layout || !layout.window_size) return false
        const [width, height] = layout.window_size
        return width === monitorWidth && height === monitorHeight
    })
    
    const context = barWindow.get_style_context()
    if (hasFullscreen) {
        context.add_class("fullscreen")
        Astal.widget_set_click_through(barWindow, true)
    } else {
        context.remove_class("fullscreen")
        Astal.widget_set_click_through(barWindow, true)
    }
}

const checkFullscreen = () => {
    execAsync("niri msg --json windows")
        .then(out => {
            try {
                handleWindows(JSON.parse(out))
            } catch (e) {}
        })
        .catch(() => {})
}

const processNiriEvent = (event) => {
    if (event.WorkspaceActivated || event.WindowsChanged || event.WindowFocusChanged || event.WindowLayoutsChanged) {
        checkFullscreen()
    }
}

subprocess("niri msg --json event-stream", (line) => {
    if (!line) return
    const trimmed = line.trim()
    if (!trimmed) return
    try {
        processNiriEvent(JSON.parse(trimmed))
    } catch (e) {}
})

function Clock() {
    return (
        <box class="clock-box" halign={Gtk.Align.CENTER}>
            <label class="clock-time" label={timeVal} />
        </box>
    )
}

function Bar(gdkmonitor) {
    const { TOP, LEFT, RIGHT } = Astal.WindowAnchor
    
    try {
        const rect = gdkmonitor.get_geometry()
        monitorWidth = rect.width
        monitorHeight = rect.height
    } catch (e) {}
    
    barWindow = (
        <window
            class="Bar"
            gdkmonitor={gdkmonitor}
            exclusivity={Astal.Exclusivity.IGNORE}
            anchor={TOP | LEFT | RIGHT}
            layer={Astal.Layer.OVERLAY}
            application={app}
        >
            <centerbox class="bar-content">
                <box $type="start" />
                <box $type="center" halign={Gtk.Align.CENTER}>
                    <Clock />
                </box>
                <box $type="end" />
            </centerbox>
        </window>
    )
    
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
        checkFullscreen()
        return GLib.SOURCE_REMOVE
    })
    
    return barWindow
}

app.start({
    css: style,
    main() {
        app.get_monitors().map(Bar)
    }
})
