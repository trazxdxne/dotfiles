import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import { execAsync, subprocess } from "ags/process"
import { createPoll } from "ags/time"
import GLib from "gi://GLib"
import Tray from "gi://AstalTray?version=0.1"
import GdkPixbuf from "gi://GdkPixbuf"
import style from "./style.css"

// time poll updates every second with Russian formatted date and time
const timeVal = createPoll("", 1000, 'date +"%H:%M"')
const dateVal = createPoll("", 10000, 'date +"%a, %d %b"')

let barWindow = null
let calendarWindow = null
let workspacesBox = null
let sysInfoLabel = null

// monitor dimensions, updated dynamically during Bar initialization
let monitorWidth = 1920
let monitorHeight = 1080

// checks if the active window is fullscreen in niri by comparing its size to the monitor geometry
const handleWindows = (windows) => {
    if (!barWindow || !windows) return
    
    // check if the currently focused window is fullscreen
    const hasFullscreen = windows.some(w => {
        if (!w.is_focused) return false
        
        const layout = w.layout
        if (!layout || !layout.window_size) return false
        
        const [width, height] = layout.window_size
        return width === monitorWidth && height === monitorHeight
    })
    
    // use native Gtk StyleContext to add/remove classes
    const context = barWindow.get_style_context()
    if (hasFullscreen) {
        context.add_class("fullscreen")
        Astal.widget_set_click_through(barWindow, true)
    } else {
        context.remove_class("fullscreen")
        Astal.widget_set_click_through(barWindow, false)
    }
}

const checkFullscreen = () => {
    execAsync("niri msg --json windows")
        .then(out => {
            try {
                handleWindows(JSON.parse(out))
            } catch (e) {
                console.error(e)
            }
        })
        .catch(console.error)
}

// cache to track workspace IDs and prevent layout shifts/click bugs
let currentWorkspaceIds = []

// updates the workspaces list from niri dynamically (sorted to prevent scrambling)
const handleWorkspaces = (list) => {
    if (!workspacesBox || !list) return
    
    // filter out empty, inactive workspaces to keep the bar clean
    const filteredList = list.filter(ws => {
        const isActive = ws.is_focused || ws.is_active || ws.active || false
        const hasWindows = ws.active_window_id !== null && ws.active_window_id !== undefined
        return isActive || hasWindows
    })
    
    // sort workspaces by index/id to keep them in order (1, 2, 3...)
    filteredList.sort((a, b) => (a.idx || a.id) - (b.idx || b.id))
    
    const newIds = filteredList.map(ws => ws.id)
    const isIdentical = newIds.length === currentWorkspaceIds.length &&
        newIds.every((id, idx) => id === currentWorkspaceIds[idx])
    
    if (isIdentical) {
        // update existing buttons in-place to keep mouse grab and prevent double-click bugs
        const children = workspacesBox.get_children()
        filteredList.forEach((ws, idx) => {
            const btn = children[idx]
            if (btn) {
                const isActive = ws.is_focused || ws.is_active || ws.active || false
                const labelText = ws.name || `${ws.idx || ws.id}`
                
                const context = btn.get_style_context()
                if (isActive) {
                    context.add_class("active")
                } else {
                    context.remove_class("active")
                }
                
                const lbl = btn.get_child()
                if (lbl && lbl.set_text) {
                    lbl.set_text(labelText)
                }
            }
        })
    } else {
        currentWorkspaceIds = newIds
        
        // remove old buttons
        workspacesBox.get_children().forEach(ch => ch.destroy())
        
        // add new buttons using native GTK constructors
        filteredList.forEach(ws => {
            const isActive = ws.is_focused || ws.is_active || ws.active || false
            const labelText = ws.name || `${ws.idx || ws.id}`
            
            const btn = new Gtk.Button()
            btn.get_style_context().add_class("workspace-button")
            if (isActive) {
                btn.get_style_context().add_class("active")
            }
            
            // Niri's focus-workspace action takes the 1-based workspace index (ws.idx), NOT the internal unique ID (ws.id)
            btn.connect("clicked", () => {
                execAsync(`niri msg action focus-workspace ${ws.idx}`).catch(console.error)
            })
            
            const lbl = new Gtk.Label({ label: labelText })
            btn.add(lbl)
            
            workspacesBox.add(btn)
        })
        workspacesBox.show_all()
    }
}

const updateWorkspaces = () => {
    execAsync("niri msg --json workspaces")
        .then(out => {
            try {
                handleWorkspaces(JSON.parse(out))
            } catch (e) {
                console.error(e)
            }
        })
        .catch(console.error)
}

// updates volume and battery status
const updateSysInfo = () => {
    Promise.all([
        execAsync("wpctl get-volume @DEFAULT_AUDIO_SINK@").catch(() => "Volume: 0"),
        execAsync("cat /sys/class/power_supply/BAT0/capacity").catch(() => ""),
        execAsync("cat /sys/class/power_supply/BAT0/status").catch(() => ""),
    ]).then(([volOut, batCap, batStatus]) => {
        let info = ""
        
        // format volume
        const volMatch = volOut.match(/Volume:\s+([0-9.]+)/)
        if (volMatch) {
            const volPercent = Math.round(parseFloat(volMatch[1]) * 100)
            info += `🔊 ${volPercent}%`
        }
        
        // format battery if laptop
        if (batCap) {
            const cap = batCap.trim()
            const status = batStatus.trim()
            const icon = status === "Charging" ? "⚡" : "🔋"
            if (info) info += "  |  "
            info += `${icon} ${cap}%`
        }
        
        if (sysInfoLabel) {
            sysInfoLabel.label = info
        }
    }).catch(console.error)
}

let layoutLabels = []
let layoutNames = ["en", "ru"]

const mapLayoutName = (name) => {
    if (!name) return ""
    const lower = name.toLowerCase()
    if (lower.includes("russian") || lower.includes("ru")) return "ru"
    if (lower.includes("english") || lower === "us") return "en"
    return name.slice(0, 2).toLowerCase()
}

const processNiriEvent = (event) => {
    if (event.WorkspacesChanged) {
        handleWorkspaces(event.WorkspacesChanged.workspaces)
    }
    if (event.WorkspaceActivated) {
        updateWorkspaces()
        checkFullscreen()
    }
    if (event.WindowsChanged || event.WindowFocusChanged || event.WindowLayoutsChanged) {
        checkFullscreen()
    }
    if (event.KeyboardLayoutsChanged) {
        const layouts = event.KeyboardLayoutsChanged.keyboard_layouts
        layoutNames = layouts.names.map(mapLayoutName)
        const currentIdx = layouts.current_idx
        const name = layoutNames[currentIdx] || "en"
        layoutLabels.forEach(lbl => {
            lbl.label = name
        })
    }
    if (event.KeyboardLayoutSwitched) {
        const idx = event.KeyboardLayoutSwitched.idx
        const name = layoutNames[idx] || "en"
        layoutLabels.forEach(lbl => {
            lbl.label = name
        })
    }
}

const handleNiriStream = (text) => {
    if (!text) return
    const trimmed = text.trim()
    if (!trimmed) return
    try {
        const event = JSON.parse(trimmed)
        processNiriEvent(event)
    } catch (e) {
        // silent parse error
    }
}

const initKeyboardLayout = () => {
    execAsync("niri msg --json keyboard-layouts")
        .then(out => {
            try {
                const data = JSON.parse(out)
                layoutNames = data.names.map(mapLayoutName)
                const currentIdx = data.current_idx
                const name = layoutNames[currentIdx] || "en"
                layoutLabels.forEach(lbl => {
                    lbl.label = name
                })
            } catch (e) {
                console.error(e)
            }
        })
        .catch(console.error)
}

// watch for niri events in the background (using event-stream)
subprocess("niri msg --json event-stream", (line) => {
    handleNiriStream(line)
})

// System Tray widget using AstalTray
function SysTray() {
    const tray = Tray.get_default()
    const box = <box class="tray" spacing={6} />
    
    const updateTray = () => {
        // remove old children
        box.get_children().forEach(ch => ch.destroy())
        
        // render current items
        const items = tray.get_items() || tray.items || []
        // Sort items by stable ID to prevent random order scrambling on updates
        items.sort((a, b) => {
            const idA = a.id || a.title || "";
            const idB = b.id || b.title || "";
            return idA.localeCompare(idB);
        })
        items.forEach(item => {
            const btn = new Gtk.Button()
            btn.get_style_context().add_class("tray-item")
            
            // set tooltip
            btn.tooltip_markup = item.tooltip_markup || item.title || ""
            
            // append custom icon theme path if provided by the application
            if (item.icon_theme_path) {
                const theme = Gtk.IconTheme.get_default()
                const paths = theme.get_search_path()
                if (!paths.includes(item.icon_theme_path)) {
                    theme.append_search_path(item.icon_theme_path)
                }
            }
            
            // create icon
            let iconWidget
            if (item.icon_name) {
                if (item.icon_name.startsWith("/") || item.icon_name.includes("/")) {
                    try {
                        const pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(item.icon_name, 12, 12, true)
                        iconWidget = Gtk.Image.new_from_pixbuf(pixbuf)
                    } catch (e) {
                        iconWidget = Gtk.Image.new_from_icon_name("image-missing", Gtk.IconSize.MENU)
                        iconWidget.pixel_size = 12
                    }
                } else {
                    iconWidget = Gtk.Image.new_from_icon_name(item.icon_name, Gtk.IconSize.MENU)
                    iconWidget.pixel_size = 12
                }
            } else if (item.gicon) {
                iconWidget = Gtk.Image.new_from_gicon(item.gicon, Gtk.IconSize.MENU)
                iconWidget.pixel_size = 12
            } else if (item.icon_pixbuf) {
                try {
                    const scaled = item.icon_pixbuf.scale_simple(12, 12, GdkPixbuf.InterpType.BILINEAR)
                    iconWidget = Gtk.Image.new_from_pixbuf(scaled)
                } catch (e) {
                    iconWidget = Gtk.Image.new_from_pixbuf(item.icon_pixbuf)
                }
            } else {
                iconWidget = new Gtk.Label({ label: "⚙" })
            }
            btn.add(iconWidget)
            
            // handle click and right-click
            btn.connect("button-press-event", (widget, event) => {
                const [_, button] = event.get_button()
                const [__, rootX, rootY] = event.get_root_coords()
                const roundedX = Math.round(rootX)
                const roundedY = Math.round(rootY)
                
                if (button === 3 || (button === 1 && item.is_menu)) {
                    // Right click or left click on a menu-only item: show native GTK menu
                    if (item.menu_model) {
                        const menu = Gtk.Menu.new_from_model(item.menu_model)
                        menu.insert_action_group("dbusmenu", item.action_group)
                        menu.attach_to_widget(widget, null)
                        menu.popup_at_widget(widget, Gdk.Gravity.SOUTH, Gdk.Gravity.NORTH, event)
                        return true
                    }
                }
                
                if (button === 3) {
                    item.secondary_activate(roundedX, roundedY)
                    return true
                } else if (button === 2) {
                    item.secondary_activate(roundedX, roundedY)
                    return true
                } else if (button === 1) {
                    item.activate(roundedX, roundedY)
                    return true
                }
                return false
            })
            
            box.add(btn)
        })
        box.show_all()
    }
    
    // update when items are added or removed
    tray.connect("item-added", updateTray)
    tray.connect("item-removed", updateTray)
    
    // initial render
    updateTray()
    
    return box
}

function KeyboardLayoutWidget() {
    const label = <label class="layout-text" label="en" />
    layoutLabels.push(label)
    
    label.connect("destroy", () => {
        const idx = layoutLabels.indexOf(label)
        if (idx > -1) {
            layoutLabels.splice(idx, 1)
        }
    })
    
    return (
        <button
            class="layout-button"
            onClicked={() => execAsync("niri msg action switch-layout next").catch(console.error)}
        >
            {label}
        </button>
    )
}

// clock button widget that toggles the calendar popup
function Clock() {
    return (
        <button
            class="clock-button"
            onClicked={() => {
                if (calendarWindow) {
                    calendarWindow.visible = !calendarWindow.visible
                }
            }}
            halign={Gtk.Align.CENTER}
        >
            <box spacing={8} class="clock-box">
                <label class="clock-time" label={timeVal} />
                <label class="clock-dot" label="•" />
                <label class="clock-date" label={dateVal} />
            </box>
        </button>
    )
}

// main top bar window
function Bar(gdkmonitor) {
    const { TOP, LEFT, RIGHT } = Astal.WindowAnchor
    
    // update monitor geometry dynamically
    try {
        const rect = gdkmonitor.get_geometry()
        monitorWidth = rect.width
        monitorHeight = rect.height
    } catch (e) {
        console.error(e)
    }
    
    // create container boxes first to hold references
    const wsContainer = <box class="workspaces" spacing={0} />
    workspacesBox = wsContainer

    const sysLabel = <label class="sys-info" />
    sysInfoLabel = sysLabel

    // wrap system info in an interactive button that opens the audio mixer
    const sysButton = (
        <button
            class="sys-button"
            onClicked={() => execAsync("pavucontrol").catch(() => execAsync("pavucontrol-qt").catch(() => {}))}
        >
            {sysLabel}
        </button>
    )
    
    barWindow = (
        <window
            class="Bar"
            gdkmonitor={gdkmonitor}
            exclusivity={Astal.Exclusivity.EXCLUSIVE}
            anchor={TOP | LEFT | RIGHT}
            layer={Astal.Layer.OVERLAY}
            application={app}
        >
            <centerbox class="bar-content">
                {/* $type attributes are required by astal's centerbox to align children correctly */}
                <box $type="start" class="left-widgets" halign={Gtk.Align.START}>
                    {wsContainer}
                </box>
                <box $type="center" class="center-widgets" halign={Gtk.Align.CENTER}>
                    <Clock />
                </box>
                <box $type="end" class="right-widgets" halign={Gtk.Align.END} spacing={6}>
                    <SysTray />
                    <KeyboardLayoutWidget />
                    {sysButton}
                </box>
            </centerbox>
        </window>
    )
    
    // run initial check after window mapping
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
        checkFullscreen()
        updateWorkspaces()
        updateSysInfo()
        initKeyboardLayout()
        return GLib.SOURCE_REMOVE
    })
    
    return barWindow
}

// floating calendar popup
function CalendarPopup() {
    const { TOP } = Astal.WindowAnchor
    
    calendarWindow = (
        <window
            name="calendar-popup"
            class="calendar-popup-window"
            anchor={TOP}
            layer={Astal.Layer.OVERLAY}
            visible={false}
            application={app}
            margin_top={10}
            keymode={Astal.Keymode.ON_DEMAND}
            onKeyPressEvent={(self, event) => {
                const [_, keyval] = event.get_keyval()
                if (keyval === Gdk.KEY_Escape) {
                    self.visible = false
                    return true
                }
                return false
            }}
        >
            <box class="calendar-box">
                <Gtk.Calendar
                    showDayNames={true}
                    showHeading={true}
                />
            </box>
        </window>
    )

    calendarWindow.connect("notify::has-toplevel-focus", () => {
        if (calendarWindow && !calendarWindow.has_toplevel_focus) {
            calendarWindow.visible = false
        }
    })
    
    return calendarWindow
}

app.start({
    css: style,
    main() {
        app.get_monitors().map(Bar)
        CalendarPopup()
        
        // poll system info every 2 seconds
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
            updateSysInfo()
            return GLib.SOURCE_CONTINUE
        })
    }
})
