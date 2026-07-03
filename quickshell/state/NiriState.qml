import QtQuick
import Quickshell
import Quickshell.Io
import Niri

/// Niri compositor state via qml-niri plugin + keyboard layout tracking.
Scope {
    id: root

    // ── Public: qml-niri instance ────────────────────────────────────
    property alias niri: niriInst

    // ── Public: keyboard layout ──────────────────────────────────────
    property var    layoutNames:   ["en"]
    property string currentLayout: "en"

    function switchLayout() {
        switchLayoutProc.running = false
        switchLayoutProc.running = true
    }

    // ── qml-niri core ────────────────────────────────────────────────
    Niri {
        id: niriInst
        onConnected:     console.info("[NiriState] connected")
        onErrorOccurred: function(e) { console.error("[NiriState] error:", e) }
    }

    Component.onCompleted: niriInst.connect()

    // ── Keyboard layout helpers ──────────────────────────────────────
    function mapLayout(name) {
        if (!name) return "en"
        var l = name.toLowerCase()
        if (l.indexOf("russian") !== -1 || l === "ru") return "ru"
        if (l.indexOf("english") !== -1 || l === "us") return "en"
        return name.slice(0, 2).toLowerCase()
    }

    function handleEvent(line) {
        var ev = null
        try {
            ev = JSON.parse(line)
        } catch(e) {
            return
        }
        if (!ev) return

        if (ev.KeyboardLayoutsChanged) {
            var kl = ev.KeyboardLayoutsChanged.keyboard_layouts
            root.layoutNames   = kl.names.map(root.mapLayout)
            root.currentLayout = root.layoutNames[kl.current_idx] || "en"
        }
        if (ev.KeyboardLayoutSwitched) {
            root.currentLayout = root.layoutNames[ev.KeyboardLayoutSwitched.idx] || "en"
        }
    }

    // Init keyboard layout on startup
    Process {
        id: initLayoutProc
        command: ["niri", "msg", "--json", "keyboard-layouts"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text)
                    root.layoutNames   = d.names.map(root.mapLayout)
                    root.currentLayout = root.layoutNames[d.current_idx] || "en"
                } catch(e) {
                    console.warn("[NiriState] keyboard-layouts parse error:", e)
                }
            }
        }
    }

    // Watch for keyboard layout changes via event-stream
    Process {
        id: layoutStream
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: function(data) { root.handleEvent(data) }
        }
        onRunningChanged: {
            if (!running) {
                Qt.callLater(function() { layoutStream.running = true })
            }
        }
    }

    // Switch layout action
    Process {
        id: switchLayoutProc
        command: ["niri", "msg", "action", "switch-layout", "next"]
        running: false
    }
}
