import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Niri
import Quickshell.Io
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects
import qs.panel
import qs.core

/// Niri top bar — Velvet Night
PanelWindow {
    id: root

    required property var niriState   // NiriState scope
    required property var clock       // SystemClock
    required property var volumeText  // string from NiriSysModel
    required property var batteryText // string from NiriSysModel
    required property var notificationModel
    required property var clipboardPopup
    required property var settingsWindow

    property alias clockButton: clockAnchor
    property alias notifButton: notifButton
    property string activeAppId: ""
    readonly property int notifButtonGlobalX: rightArea.x + notifButton.x

    signal calendarToggled()

    implicitHeight: Theme.panelHeight
    color: root.isFullscreenActive ? "transparent" : "#fe1e1e2e"
    aboveWindows: true
    exclusiveZone: root.isFullscreenActive ? 0 : Theme.panelHeight
    WlrLayershell.layer: WlrLayer.Overlay
    surfaceFormat: { "opaque": false }

    anchors { top: true; left: true; right: true }

    property bool isFullscreenActive: false

    mask: Region {
        width: root.isFullscreenActive ? 0 : root.width
        height: root.isFullscreenActive ? 0 : root.height
    }

    Behavior on color {
        ColorAnimation { duration: 0 }
    }

    Connections {
        target: niriState
        function onNiriEvent(event) {
            if (event.WorkspaceActivated || event.WindowsChanged || event.WindowFocusChanged || event.WindowLayoutsChanged) {
                checkFullscreenProc.running = false
                checkFullscreenProc.running = true
            }
        }
    }

    Process {
        id: checkFullscreenProc
        command: ["niri", "msg", "--json", "windows"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var rawText = this.text.trim()
                    if (rawText === "") return
                    var windows = JSON.parse(rawText)
                    var hasFullscreen = false
                    const screenWidth = root.screen ? root.screen.width : 1920
                    const screenHeight = root.screen ? root.screen.height : 1080
                    
                    for (var i = 0; i < windows.length; i++) {
                        var w = windows[i]
                        if (w.is_focused) {
                            root.activeAppId = w.app_id || ""
                            root.notificationModel.markAsReadForApp(root.activeAppId)
                            var layout = w.layout
                            if (layout && layout.window_size) {
                                var width = layout.window_size[0]
                                var height = layout.window_size[1]
                                if (width === screenWidth && height === screenHeight) {
                                    hasFullscreen = true
                                    break
                                }
                            }
                        }
                    }
                    root.isFullscreenActive = hasFullscreen
                } catch(e) {
                    console.warn("[NiriBar] windows parse error:", e)
                }
            }
        }
    }

    Component.onCompleted: {
        checkFullscreenProc.running = true
    }

    // Bottom separator
    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 1
        color: "#1a45475a"
        visible: !root.isFullscreenActive
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.settingsWindow.visible = !root.settingsWindow.visible
                if (root.settingsWindow.visible) root.settingsWindow.requestActivate()
            }
        }
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
        opacity: root.isFullscreenActive ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

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
                    required property string output

                    wsName: name !== "" ? name : String(index)
                    active: isFocused
                    visible: (isFocused || isActive || activeWindowId !== 0) && (output === (root.screen ? root.screen.name : ""))
                    
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

            Item {
                width: timeText.implicitWidth
                height: timeText.implicitHeight
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: pillBg
                    anchors.centerIn: parent
                    width: timeText.implicitWidth + 16
                    height: timeText.implicitHeight + 4
                    radius: 0
                    color: "#731e1e2e"
                    opacity: root.isFullscreenActive ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }
                }

                Text {
                    id: timeText
                    text: root.rusTimeDate.time
                    color: "#cba6f7"
                    font { family: "Adwaita Sans"; pixelSize: 12; bold: true }
                    verticalAlignment: Text.AlignVCenter
                    anchors.centerIn: parent
                }
            }
            Text {
                text: "•"
                color: "#f5c2e7"
                font { family: "Adwaita Sans"; pixelSize: 12; bold: true }
                verticalAlignment: Text.AlignVCenter
                opacity: root.isFullscreenActive ? 0 : 1
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
            Text {
                text: root.rusTimeDate.dateStr
                color: "#f5e0dc"
                font { family: "Adwaita Sans"; pixelSize: 12; weight: Font.Medium }
                verticalAlignment: Text.AlignVCenter
                opacity: root.isFullscreenActive ? 0 : 1
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }
        visible: Config.showClock
    }

    Process {
        id: pavucontrolProc
        command: ["sh", "-c", "pavucontrol || pavucontrol-qt"]
        running: false
    }

    // ── RIGHT: Tray + Layout + SysInfo ─────────────────────────
    Row {
        id: rightArea
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        opacity: root.isFullscreenActive ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

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

        // Separator
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1; height: 14
            color: "#2a45475a"
            visible: root.volumeText.length > 0
        }

        // Volume + Battery button
        BarButton {
            id: volBtn
            anchors.verticalCenter: parent.verticalCenter
            onActivated: {
                pavucontrolProc.running = false
                pavucontrolProc.running = true
            }
            visible: root.volumeText.length > 0 && (Config.showVolume || Config.showBattery)

            Row {
                anchors.centerIn: parent
                spacing: 4

                // Volume Icon
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.volumeText.charAt(0)
                    font { family: "FantasqueSansM Nerd Font"; pixelSize: 12 }
                    color: "#fab387"
                    verticalAlignment: Text.AlignVCenter
                    visible: Config.showVolume
                }

                // Battery Icon
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.batteryText.length > 0 && Config.showBattery
                    text: root.batteryText.charAt(0)
                    font { family: "FantasqueSansM Nerd Font"; pixelSize: 12 }
                    color: "#fab387"
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Separator
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1; height: 14
            color: "#2a45475a"
        }

        // Notifications button (bell count status, Far Right Corner)
        StatusButton {
            id: notifButton
            anchors.verticalCenter: parent.verticalCenter
            icon: "bell"
            value: root.notificationModel.unreadCount
            active: root.notificationModel.historyVisible
            onActivated: root.notificationModel.toggleHistory()
        }
    }
}
