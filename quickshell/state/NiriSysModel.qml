import QtQuick
import Quickshell
import Quickshell.Io

/// Polls volume via wpctl and battery via /sys every 2 seconds.
Scope {
    id: root

    property string volumeText: ""
    property string batteryText: ""

    // Run on start and every 2000ms
    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            volProcess.running = false
            volProcess.running = true
            batProcess.running = false
            batProcess.running = true
        }
    }

    Process {
        id: volProcess
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()
                const m = text.match(/Volume:\s+([0-9.]+)(\s+\[MUTED\])?/)
                if (m) {
                    const pct = Math.round(parseFloat(m[1]) * 100)
                    const icon = m[2] ? "🔇" : "🔊"
                    root.volumeText = icon + " " + pct + "%"
                }
            }
        }
    }

    Process {
        id: batProcess
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null; echo ':'; cat /sys/class/power_supply/BAT0/status 2>/dev/null"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.split(":")
                const cap = (parts[0] || "").trim()
                const status = (parts[1] || "").trim()
                if (cap.length > 0 && !isNaN(parseInt(cap))) {
                    const icon = status === "Charging" ? "⚡" : "🔋"
                    root.batteryText = icon + " " + cap + "%"
                } else {
                    root.batteryText = ""
                }
            }
        }
    }
}
