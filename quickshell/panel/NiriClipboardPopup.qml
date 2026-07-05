import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.core

/// Clipboard history popup using cliphist.
/// Triggered by `visible = true` from external keybind.
FloatingWindow {
    id: root

    implicitWidth: Config.clipboardWidth
    implicitHeight: Config.clipboardHeight
    title: "Clipboard History"
    color: "transparent"

    onVisibleChanged: {
        if (root.visible) {
            searchField.text = ""
            listProcess.running = false
            listProcess.running = true
            Qt.callLater(() => searchField.forceActiveFocus())
        }
    }

    Component.onCompleted: {
        loadProcess.running = true
    }

    contentItem.onActiveFocusChanged: {
        if (!contentItem.activeFocus) {
            Qt.callLater(() => {
                if (!contentItem.activeFocus && root.visible) root.visible = false
            })
        }
    }

    
    // --- State ---
    property var items: []       // [{id, display, isImage, timeStr}]
    property int selectedIdx: 0
    property string previewText: ""
    property string previewImagePath: ""
    property bool previewIsImage: false
    property var timestampCache: ({})

    property string searchText: searchField.text

    property var filteredItems: {
        const q = searchText.toLowerCase()
        if (q.length === 0) return items
        return items.filter(it => it.display.toLowerCase().includes(q))
    }

    // --- Load items from cliphist ---
    Process {
        id: listProcess
        command: ["cliphist", "list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.parseItems(this.text)
        }
    }

    // --- Copy selected item ---
    Process {
        id: copyProcess
        property string itemId: ""
        command: ["sh", "-c", `echo -n '${copyProcess.itemId}' | cliphist decode | wl-copy`]
        running: false
    }

    // --- Copy image item for terminal ---
    Process {
        id: copyImageProcess
        property string itemId: ""
        command: ["sh", "-c", `echo -n '${copyImageProcess.itemId}' | cliphist decode > /tmp/qs_clipboard_preview.png && echo -n '/tmp/qs_clipboard_preview.png' | wl-copy`]
        running: false
    }

    // --- Clear history ---
    Process {
        id: clearProcess
        command: ["cliphist", "wipe"]
        running: false
        onRunningChanged: { if (!running) root.visible = false }
    }

    // --- Preview decode ---
    Process {
        id: previewProcess
        property string itemId: ""
        property bool forImage: false
        command: forImage
            ? ["sh", "-c", `echo -n '${previewProcess.itemId}' | cliphist decode > /tmp/qs_clipboard_preview.png`]
            : ["sh", "-c", `echo -n '${previewProcess.itemId}' | cliphist decode`]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (previewProcess.forImage) {
                    root.previewIsImage = true
                    root.previewImagePath = "file:///tmp/qs_clipboard_preview.png?" + Date.now()
                } else {
                    root.previewIsImage = false
                    root.previewText = this.text
                }
            }
        }
    }

    // --- Load timestamp cache ---
    Process {
        id: loadProcess
        command: ["cat", "/home/trazxdxne/.cache/qs_clipboard_timestamps.json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.timestampCache = JSON.parse(this.text);
                } catch (e) {
                    root.timestampCache = {};
                }
            }
        }
    }

    // --- Real-time clipboard watcher ---
    Process {
        id: clipWatcher
        command: ["wl-paste", "--watch", "sh", "-c", "sleep 0.1 && cliphist list | head -n 1"]
        running: true
        
        stdout: SplitParser {
            onRead: function(line) {
                const tab = line.indexOf("\t")
                if (tab >= 0) {
                    const id = line.slice(0, tab).trim()
                    if (id && !root.timestampCache[id]) {
                        root.timestampCache[id] = Date.now()
                        root.saveTimestamps()
                    }
                }
            }
        }
        
        onRunningChanged: {
            if (!running) {
                Qt.callLater(function() { clipWatcher.running = true })
            }
        }
    }



    function saveTimestamps() {
        saveProcess.jsonText = JSON.stringify(root.timestampCache)
        saveProcess.running = false
        saveProcess.running = true
    }

    function escapeShell(str) {
        return str.replace(/'/g, "'\\''");
    }

    function formatTime(ts) {
        if (!ts) return ""
        var date = new Date(ts)
        var now = new Date()
        
        var hours = String(date.getHours()).padStart(2, '0')
        var minutes = String(date.getMinutes()).padStart(2, '0')
        var timeStr = hours + ":" + minutes
        
        if (date.toDateString() === now.toDateString()) {
            return "Today " + timeStr
        }
        
        var yesterday = new Date(now)
        yesterday.setDate(now.getDate() - 1)
        if (date.toDateString() === yesterday.toDateString()) {
            return "Yesterday " + timeStr
        }
        
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return date.getDate() + " " + months[date.getMonth()] + " " + timeStr
    }

    Process {
        id: saveProcess
        property string jsonText: ""
        command: ["sh", "-c", "mkdir -p ~/.cache && echo -n '" + root.escapeShell(jsonText) + "' > ~/.cache/qs_clipboard_timestamps.json"]
        running: false
    }

    function parseItems(text) {
        const lines = text.split("\n").filter(l => l.trim() !== "")
        const parsed = []
        
        lines.forEach(line => {
            const tab = line.indexOf("\t")
            if (tab < 0) return
            const id = line.slice(0, tab)
            const content = line.slice(tab + 1)
            if (content === "/tmp/pasted_screenshot.png" || content === "/tmp/qs_clipboard_preview.png") return
            const isImage = content.includes("[[ binary data")
            let display = content
            if (isImage) {
                display = "🖼 Image (" + content.split("[[ binary data")[1].trim() + ")"
            }
            
            const ts = root.timestampCache[id]
            const timeStr = ts ? root.formatTime(ts) : ""
            
            parsed.push({ id, display, isImage, timeStr })
        })
        root.items = parsed
        root.selectedIdx = 0
        if (parsed.length > 0) showPreview(parsed[0])
    }

    function showPreview(item) {
        if (!item) return
        previewProcess.itemId = item.id
        previewProcess.forImage = item.isImage
        previewProcess.running = false
        previewProcess.running = true
    }

    function copyItem(item) {
        if (!item) return
        root.visible = false
        if (item.isImage) {
            copyImageProcess.itemId = item.id
            copyImageProcess.running = false
            copyImageProcess.running = true
        } else {
            copyProcess.itemId = item.id
            copyProcess.running = false
            copyProcess.running = true
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    ShellSurface {
        anchors.fill: parent
        color: "#f21e1e2e"
        border.color: "#ccf5c2e7"
        border.width: 0
        radius: 0
        margin: 20
        focus: true
        Keys.onEscapePressed: root.visible = false

        RowLayout {
            anchors.fill: parent
            spacing: 16

            // ─── Left pane: list ───────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: false
                Layout.preferredWidth: 280
                Layout.maximumWidth: 280
                spacing: 12

                Text {
                    text: "Clipboard History (" + root.items.length + ")"
                    color: "#cba6f7"
                    font.family: "Adwaita Sans"
                    font.pixelSize: 18
                    font.bold: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    color: "#ff181825"
                    border.color: searchField.activeFocus ? "#f5c2e7" : "#4d45475a"
                    border.width: 1
                    radius: 0

                    TextInput {
                        id: searchField
                        anchors.fill: parent
                        anchors.margins: 8
                        color: "#cdd6f4"
                        font.family: "Adwaita Sans"
                        font.pixelSize: 14
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true

                        // Placeholder
                        Text {
                            anchors.fill: parent
                            text: "Type to search..."
                            color: "#585b70"
                            font.family: "Adwaita Sans"
                            font.pixelSize: 14
                            verticalAlignment: Text.AlignVCenter
                            visible: searchField.text.length === 0
                        }

                        Keys.onDownPressed: {
                            if (root.filteredItems.length > 0) {
                                root.selectedIdx = Math.min(root.selectedIdx + 1, root.filteredItems.length - 1)
                                root.showPreview(root.filteredItems[root.selectedIdx])
                            }
                        }
                        Keys.onUpPressed: {
                            if (root.filteredItems.length > 0) {
                                root.selectedIdx = Math.max(root.selectedIdx - 1, 0)
                                root.showPreview(root.filteredItems[root.selectedIdx])
                            }
                        }
                        Keys.onReturnPressed: {
                            if (root.filteredItems.length > root.selectedIdx) {
                                root.copyItem(root.filteredItems[root.selectedIdx])
                            }
                        }
                    }
                }

                // Clipboard list
                ScrollView {
                    id: listScrollView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    rightPadding: 8
                    
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical: ScrollBar {
                        id: listScrollBar
                        parent: listScrollView
                        x: listScrollView.width - width
                        y: listScrollView.topPadding
                        height: listScrollView.availableHeight
                        width: 8
                        policy: ScrollBar.AsNeeded
                        visible: size < 1.0
                        contentItem: Rectangle {
                            implicitWidth: 8
                            radius: 0
                            color: listScrollBar.pressed ? "#f5c2e7" : (listScrollBar.hovered ? "#cba6f7" : "#585b70")
                        }
                        background: Rectangle {
                            implicitWidth: 8
                            color: "transparent"
                        }
                    }

                    ListView {
                        id: clipList
                        width: listScrollView.availableWidth
                        height: listScrollView.availableHeight
                        model: root.filteredItems
                        spacing: 0
                        clip: true

                        onCountChanged: {
                            if (count > 0) root.showPreview(root.filteredItems[0])
                        }

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: clipList.width
                            height: 48
                            radius: 0
                            color: index === root.selectedIdx ? "#33f5c2e7" : (hovered ? "#19f5c2e7" : "transparent")
                            border.color: index === root.selectedIdx ? "#4df5c2e7" : "transparent"
                            border.width: index === root.selectedIdx ? 1 : 0

                            property bool hovered: ma.containsMouse

                            // Left accent bar for selected
                            Rectangle {
                                visible: index === root.selectedIdx
                                width: 3
                                height: parent.height
                                color: "#f5c2e7"
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: index === root.selectedIdx ? 12 : 10
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: modelData.display
                                    color: "#cdd6f4"
                                    font.family: "Adwaita Sans"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: modelData.timeStr
                                    color: "#6c7086"
                                    font.family: "Adwaita Sans"
                                    font.pixelSize: 10
                                }
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyItem(modelData)
                                onEntered: {
                                    root.selectedIdx = index
                                    root.showPreview(modelData)
                                }
                            }
                        }
                    }
                }

                // Clear history button
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    color: clearMa.containsMouse ? "#33f38ba8" : "#1af38ba8"
                    border.color: "#4df38ba8"
                    border.width: 1
                    radius: 0

                    Text {
                        anchors.centerIn: parent
                        text: "Clear History"
                        color: "#f38ba8"
                        font.family: "Adwaita Sans"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clearProcess.running = true
                    }
                }
            }

            // ─── Right pane: preview ───────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                Text {
                    text: "Preview"
                    color: "#f5c2e7"
                    font.family: "Adwaita Sans"
                    font.pixelSize: 16
                    font.bold: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#0f11111b"
                    radius: 0

                    // Text preview
                    ScrollView {
                        id: previewScrollView
                        anchors.fill: parent
                        anchors.margins: 12
                        rightPadding: 8
                        visible: !root.previewIsImage

                        ScrollBar.vertical: ScrollBar {
                            id: previewScrollBar
                            parent: previewScrollView
                            x: previewScrollView.width - width
                            y: previewScrollView.topPadding
                            height: previewScrollView.availableHeight
                            width: 8
                            policy: ScrollBar.AsNeeded
                            visible: size < 1.0
                            contentItem: Rectangle {
                                implicitWidth: 8
                                radius: 0
                                color: previewScrollBar.pressed ? "#f5c2e7" : (previewScrollBar.hovered ? "#cba6f7" : "#585b70")
                            }
                            background: Rectangle {
                                implicitWidth: 8
                                color: "transparent"
                            }
                        }

                        TextArea {
                            text: root.previewText
                            color: "#cdd6f4"
                            font.family: "monospace"
                            font.pixelSize: 13
                            readOnly: true
                            wrapMode: TextArea.Wrap
                            background: null
                            clip: true
                        }
                    }

                    // Image preview
                    Image {
                        anchors.fill: parent
                        anchors.margins: 12
                        visible: root.previewIsImage
                        source: root.previewIsImage ? root.previewImagePath : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                    }
                }
            }
        }
    }
}
