//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "./panel"
import "./state"
import "./notifications"
import "./settings"
import "./power"

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

    // ── IPC: power menu ──────────────────────────────────────────────
    IpcHandler {
        target: "power"
        function open(): void   { powerMenuModel.open() }
        function close(): void  { powerMenuModel.close() }
        function toggle(): void { powerMenuModel.toggle() }
    }

    // ── Notifications state ──────────────────────────────────────────
    NotificationModel {
        id: notificationModel
    }

    // ── Notifications popup (toast) ──────────────────────────────────
    NotificationPopupWindow {
        id: notificationPopup
        notificationModel: notificationModel
        panelWindow: panelWindow
    }

    // ── Notification history ─────────────────────────────────────────
    NotificationHistoryWindow {
        id: notificationHistory
        notificationModel: notificationModel
        panelWindow: panelWindow
    }

    // ── Top bar ──────────────────────────────────────────────────────
    NiriBar {
        id: panelWindow

        niriState:          niriState
        clock:              clock
        volumeText:         sysModel.volumeText
        batteryText:        sysModel.batteryText
        notificationModel:  notificationModel
        clipboardPopup:     clipboardPopup
        settingsWindow:     settingsWindow

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

    // ── Settings window ───────────────────────────────────────────────
    SettingsWindow {
        id: settingsWindow
    }

    // ── Power menu ────────────────────────────────────────────────────
    PowerMenuModel {
        id: powerMenuModel
    }

    PowerMenuWindow {
        id: powerMenuWindow
        powerMenuModel: powerMenuModel
    }
}
