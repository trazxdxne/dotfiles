import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Niri
import Quickshell.Io
import qs.panel
import qs.core

/// Niri top bar — Catppuccin Mocha
PanelWindow {
    id: root

    required property var niriState   // NiriState scope
    required property var clock       // SystemClock
    required property var volumeText  // string from NiriSysModel
    required property var batteryText // string from NiriSysModel

    property alias clockButton: clockAnchor

    signal calendarToggled()

    implicitHeight: Theme.panelHeight
    color: "#ff1e1e2e"
    aboveWindows: true
    exclusiveZone: Theme.panelHeight

    anchors { top: true; left: true; right: true }

    // Bottom separator
    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 1
        color: "#1a45475a"
    }

    function openTrayMenu(trayItem, anchorItem) {
        if (!trayItem?.hasMenu) return
        const pt = anchorItem.mapToItem(root.contentItem, anchorItem.width / 2, anchorItem.height)
        trayItem.display(root, Math.round(pt.x), Math.round(pt.y))
    }

    // --- Функция ручного форматирования даты на русском ---
    function getRussianDate(date) {
        const days = ["вс", "пн", "вт", "ср", "чт", "пт", "сб"]
        const months = ["янв", "фев", "мар", "апр", "май", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]
        
        const hh = String(date.getHours()).padStart(2, '0')
        const mm = String(date.getMinutes()).padStart(2, '0')
        const dayName = days[date.getDay()]
        const dayNum = date.getDate()
        const monthName = months[date.getMonth()]
        
        return {
            time: hh + ":" + mm,
            dateStr: dayName + ", " + dayNum + " " + monthName
        }
    }

    readonly property var rusTimeDate: getRussianDate(clock.date)

    // --- Workspaces logic: показываем все от 1 до MaxActive ---
    readonly property int maxWorkspaceIndex: {
        var model = niriState.niri.workspaces
        if (!model) return 1
        var count = model.count
        console.log("[NiriBar] Workspaces count: " + count)
        var maxIdx = 1
        for (var i = 0; i < count; i++) {
            var ws = typeof model.get === "function" ? model.get(i) : null
            if (ws) {
                console.log("[NiriBar] ws row " + i + " id: " + ws.id + " index: " + ws.index)
                if ((ws.index + 1) > maxIdx) {
                    maxIdx = ws.index + 1
                }
            }
        }
        console.log("[NiriBar] Computed maxWorkspaceIndex: " + maxIdx)
        return maxIdx
    }

    // ── LEFT: Workspaces ───────────────────────────────────────
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: "#0d45475a"
        width: wsRow.implicitWidth + 2

        Row {
            id: wsRow
            anchors.fill: parent
            spacing: 0

            Repeater {
                model: root.niriState.niri.workspaces

                delegate: NiriWorkspaceButton {
                    required property var id
                    required property int index
                    required property string name
                    required property bool isFocused
                    required property bool isActive
                    required property var activeWindowId

                    wsName: name !== "" ? name : String(index)
                    active: isFocused
                    visible: isFocused || isActive || activeWindowId !== 0
                    
                    onClicked: {
                        root.niriState.niri.focusWorkspaceById(id)
                    }
                }
            }
        }
    }

    // ── CENTER: Clock ──────────────────────────────────────────
    BarButton {
        id: clockAnchor
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        onActivated: root.calendarToggled()

        Row {
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: root.rusTimeDate.time
                color: "#cba6f7"
                font { family: "Adwaita Sans"; pixelSize: 12; bold: true }
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                text: "•"
                color: "#f5c2e7"
                font { family: "Adwaita Sans"; pixelSize: 12; bold: true }
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                text: root.rusTimeDate.dateStr
                color: "#f5e0dc"
                font { family: "Adwaita Sans"; pixelSize: 12; weight: Font.Medium }
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Process {
        id: pavucontrolProc
        command: ["sh", "-c", "pavucontrol || pavucontrol-qt"]
        running: false
    }

    // ── RIGHT: Tray + Layout + SysInfo ─────────────────────────
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        // System Tray
        TrayArea {
            anchors.verticalCenter: parent.verticalCenter
            onOpenMenu: (item, anchor) => root.openTrayMenu(item, anchor)
        }

        // Separator
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1; height: 14
            color: "#2a45475a"
            visible: SystemTray.items.values.length > 0
        }

        // Keyboard layout button
        BarButton {
            anchors.verticalCenter: parent.verticalCenter
            onActivated: root.niriState.switchLayout()
            Text {
                anchors.centerIn: parent
                text: root.niriState.currentLayout.toUpperCase()
                color: "#cba6f7"
                font { family: "Adwaita Sans"; pixelSize: 12; bold: true }
                verticalAlignment: Text.AlignVCenter
            }
        }

        // Volume + Battery button
        BarButton {
            anchors.verticalCenter: parent.verticalCenter
            onActivated: {
                pavucontrolProc.running = false
                pavucontrolProc.running = true
            }
            visible: root.volumeText.length > 0
            Text {
                anchors.centerIn: parent
                text: root.volumeText + (root.batteryText.length > 0 ? "  |  " + root.batteryText : "")
                color: "#fab387"
                font { family: "Adwaita Sans"; pixelSize: 12; weight: Font.Medium }
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
