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

    implicitWidth: 960
    implicitHeight: 620
    title: "Clipboard History"
    color: "transparent"

    onVisibleChanged: {
        if (root.visible) {
            searchField.text = ""
            loadItems()
            Qt.callLater(() => searchField.forceActiveFocus())
        }
    }

    contentItem.onActiveFocusChanged: {
        if (!contentItem.activeFocus) {
            Qt.callLater(() => {
                if (!contentItem.activeFocus && root.visible) root.visible = false
            })
        }
    }

    
    // --- State ---
    property var items: []       // [{id, display, isImage}]
    property int selectedIdx: 0
    property string previewText: ""
    property string previewImagePath: ""
    property bool previewIsImage: false

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

    function loadItems() {
        listProcess.running = false
        listProcess.running = true
    }

    function parseItems(text) {
        const lines = text.split("\n").filter(l => l.trim() !== "")
        const parsed = []
        lines.forEach(line => {
            const tab = line.indexOf("\t")
            if (tab < 0) return
            const id = line.slice(0, tab)
            const content = line.slice(tab + 1)
            if (content === "/tmp/pasted_screenshot.png") return
            const isImage = content.includes("[[ binary data")
            let display = content
            if (isImage) {
                display = "🖼 Image (" + content.split("[[ binary data")[1].trim() + ")"
            }
            parsed.push({ id, display, isImage })
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

    // --- UI ---
    ShellSurface {
        anchors.fill: parent
        color: "#f21e1e2e"
        border.color: "#ccf5c2e7"
        border.width: 1
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
                    text: "Clipboard History"
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
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical: ScrollBar {
                        width: 8
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 8
                            radius: 4
                            color: parent.pressed ? "#f5c2e7" : (parent.hovered ? "#cba6f7" : "#45475a")
                        }
                        background: Rectangle {
                            implicitWidth: 8
                            color: "transparent"
                        }
                    }

                    ListView {
                        id: clipList
                        width: parent.width
                        model: root.filteredItems
                        spacing: 0
                        clip: true

                        onCountChanged: {
                            if (count > 0) root.showPreview(root.filteredItems[0])
                        }

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: ListView.view.width
                            height: 38
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

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: index === root.selectedIdx ? 12 : 10
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.display
                                color: "#cdd6f4"
                                font.family: "Adwaita Sans"
                                font.pixelSize: 12
                                elide: Text.ElideRight
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
                        anchors.fill: parent
                        anchors.margins: 12
                        visible: !root.previewIsImage
                        clip: true
                        ScrollBar.vertical: ScrollBar {
                            width: 8
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: 8
                                radius: 4
                                color: parent.pressed ? "#f5c2e7" : (parent.hovered ? "#cba6f7" : "#45475a")
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
