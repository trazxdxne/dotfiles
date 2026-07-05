import QtQuick
import QtQuick.Layouts
import Quickshell

/// Calendar popup anchored below the bar clock button.
/// Открывается/закрывается через visible.
PopupWindow {
    id: root

    grabFocus: true

    required property var barWindow
    anchor {
        window: root.barWindow
        rect.x: root.barWindow && root.barWindow.clockButton ? root.barWindow.clockButton.x : 0
        rect.y: root.barWindow && root.barWindow.clockButton ? root.barWindow.clockButton.y + 12 : 0
        rect.width: root.barWindow && root.barWindow.clockButton ? root.barWindow.clockButton.width : 0
        rect.height: root.barWindow && root.barWindow.clockButton ? root.barWindow.clockButton.height : 0
        edges: Edges.Bottom
        gravity: Edges.Bottom
        adjustment: PopupAdjustment.None
    }

    implicitWidth:  calBox.implicitWidth
    implicitHeight: calBox.implicitHeight
    color: "transparent"

    contentItem.onActiveFocusChanged: {
        if (!contentItem.activeFocus) {
            root.visible = false
        }
    }

    // ── State ────────────────────────────────────────────────────────
    property date today:    new Date()
    property int viewYear:  today.getFullYear()
    property int viewMonth: today.getMonth() // 0-based

    onVisibleChanged: if (visible) { today = new Date(); Qt.callLater(() => calBox.forceActiveFocus()) }

    function prevMonth() {
        if (viewMonth === 0) { viewMonth = 11; viewYear-- }
        else viewMonth--
    }
    function nextMonth() {
        if (viewMonth === 11) { viewMonth = 0; viewYear++ }
        else viewMonth++
    }

    // Returns array of {date, inMonth} for a 6×7 grid starting on Monday
    function buildGrid(year, month) {
        const first = new Date(year, month, 1)
        const startDow = (first.getDay() + 6) % 7 // Mon=0
        const cells = []
        const cursor = new Date(year, month, 1 - startDow)
        for (let i = 0; i < 42; i++) {
            cells.push({ date: new Date(cursor), inMonth: cursor.getMonth() === month })
            cursor.setDate(cursor.getDate() + 1)
        }
        return cells
    }

    property var gridCells: buildGrid(viewYear, viewMonth)

    // Rebuild when month changes
    onViewMonthChanged: gridCells = buildGrid(viewYear, viewMonth)
    onViewYearChanged:  gridCells = buildGrid(viewYear, viewMonth)

    // Month names in Russian
    readonly property var monthNames: [
        "Январь","Февраль","Март","Апрель","Май","Июнь",
        "Июль","Август","Сентябрь","Октябрь","Ноябрь","Декабрь"
    ]
    readonly property var dayNames: ["Пн","Вт","Ср","Чт","Пт","Сб","Вс"]

    // ── UI ───────────────────────────────────────────────────────────
    Rectangle {
        id: calBox
        focus: true
        implicitWidth:  7 * 36 + 32
        implicitHeight: dayRow.height + grid.height + header.height + 32 + 16
        color: "#f21e1e2e"
        border.color: "#9945475a"
        border.width: 0
        radius: 0

        Column {
            anchors { fill: parent; margins: 16 }
            spacing: 8

            // ── Header: month name + prev/next ───────────────────────
            RowLayout {
                id: header
                width: parent.width

                // Prev month
                Text {
                    text: "◀"
                    color: "#a6adc8"
                    font.pixelSize: 12
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.prevMonth()
                    }
                }

                // Month + Year
                Text {
                    Layout.fillWidth: true
                    text: root.monthNames[root.viewMonth] + " " + root.viewYear
                    color: "#f5c2e7"
                    font { family: "Adwaita Sans"; pixelSize: 14; bold: true }
                    horizontalAlignment: Text.AlignHCenter
                }

                // Next month
                Text {
                    text: "▶"
                    color: "#a6adc8"
                    font.pixelSize: 12
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.nextMonth()
                    }
                }
            }

            // ── Day-of-week headers ──────────────────────────────────
            Row {
                id: dayRow
                spacing: 0
                Repeater {
                    model: root.dayNames
                    Text {
                        required property string modelData
                        width: 36
                        text: modelData
                        color: "#585b70"
                        font { family: "Adwaita Sans"; pixelSize: 11 }
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // ── Day grid ─────────────────────────────────────────────
            Grid {
                id: grid
                columns: 7
                spacing: 0

                Repeater {
                    model: root.gridCells

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: 36; height: 32
                        radius: 0

                        property bool isToday: {
                            const t = root.today
                            return modelData.date.getFullYear() === t.getFullYear()
                                && modelData.date.getMonth()    === t.getMonth()
                                && modelData.date.getDate()     === t.getDate()
                        }

                        color: isToday ? "#cba6f7" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.date.getDate()
                            color: {
                                if (isToday) return "#1e1e2e"
                                if (!modelData.inMonth) return "#45475a"
                                // Weekend (index%7 >= 5 → Sat/Sun)
                                if (index % 7 >= 5) return "#f38ba8"
                                return "#f5e0dc"
                            }
                            font { family: "Adwaita Sans"; pixelSize: 12; bold: isToday }
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
