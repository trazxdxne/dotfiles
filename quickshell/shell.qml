//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "./panel"
import "./state"

ShellRoot {
    id: root

    // ── Niri compositor state (qml-niri plugin + keyboard layout) ────
    NiriState {
        id: niriState
    }

    // ── System info: volume + battery (polls wpctl / /sys) ───────────
    NiriSysModel {
        id: sysModel
    }

    // ── Clock ────────────────────────────────────────────────────────
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ── IPC: clipboard popup ─────────────────────────────────────────
    IpcHandler {
        target: "clipboard"
        function open(): void   { clipboardPopup.visible = true  }
        function close(): void  { clipboardPopup.visible = false }
        function toggle(): void { clipboardPopup.visible = !clipboardPopup.visible }
    }

    // ── Top bar ──────────────────────────────────────────────────────
    NiriBar {
        id: panelWindow

        niriState:     niriState
        clock:         clock
        volumeText:    sysModel.volumeText
        batteryText:   sysModel.batteryText

        onCalendarToggled: calendarPopup.visible = !calendarPopup.visible
    }

    // ── Calendar popup ────────────────────────────────────────────────
    NiriCalendarPopup {
        id: calendarPopup
        barWindow: panelWindow
        visible: false
    }

    // ── Clipboard popup ───────────────────────────────────────────────
    NiriClipboardPopup {
        id: clipboardPopup
        visible: false
    }
}
