import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core

PopupWindow {
    id: root

    required property var notificationModel
    required property var panelWindow

    visible: notificationModel.historyVisible
    implicitWidth: 380
    implicitHeight: 560
    color: Theme.transparent
    grabFocus: true

    anchor {
        window: root.panelWindow
        rect.x: root.panelWindow ? root.panelWindow.width - root.width - 12 : 0
        rect.y: Theme.panelHeight + 12
    }

    onVisibleChanged: {
        if (visible) {
            root.requestActivate();
            root.contentItem.forceActiveFocus();
        } else if (root.notificationModel.historyVisible) {
            root.notificationModel.closeHistory();
        }
    }

    contentItem.onActiveFocusChanged: {
        if (!contentItem.activeFocus) {
            root.notificationModel.closeHistory()
        }
    }

    ShellSurface {
        anchors.fill: parent
        margin: 16
        focus: true
        color: "#f21e1e2e"
        border.color: "#9945475a"
        border.width: 1
        radius: 0

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.popupSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.listSpacing * 2

                Text {
                    Layout.fillWidth: true
                    text: "Notifications"
                    color: "#cba6f7"
                    font.family: "Adwaita Sans"
                    font.pixelSize: 18
                    font.bold: true
                    elide: Text.ElideRight
                }

                Rectangle {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 28
                    color: clearMa.containsMouse ? "#33f38ba8" : "#1af38ba8"
                    border.color: "#4df38ba8"
                    border.width: 1
                    radius: 0

                    Text {
                        anchors.centerIn: parent
                        text: "Clear"
                        color: "#f38ba8"
                        font.family: "Adwaita Sans"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notificationModel.clearHistory()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.notificationModel.history.length === 0
                text: "No notifications"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
                horizontalAlignment: Text.AlignHCenter
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: historyColumn.implicitHeight
                clip: true

                ColumnLayout {
                    id: historyColumn

                    width: parent.width
                    spacing: Theme.listSpacing * 2

                    Repeater {
                        model: root.notificationModel.sortedHistory

                        delegate: Rectangle {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(74, historyContent.implicitHeight + 22)
                            radius: 0
                            color: itemMouseArea.containsMouse ? (modelData.read ? "#08ffffff" : "#19f5c2e7") : "transparent"
                            border.width: 0

                            MouseArea {
                                id: itemMouseArea
                                hoverEnabled: true
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData && modelData.appName) {
                                        Commands.focusApp(modelData.appName);
                                    }
                                    root.notificationModel.closeHistory();
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 11
                                spacing: Theme.rowSpacing

                                Rectangle {
                                    Layout.preferredWidth: 3
                                    Layout.fillHeight: true
                                    radius: 0
                                    color: "#f5c2e7"
                                    visible: !modelData.read
                                }

                                ColumnLayout {
                                    id: historyContent

                                    Layout.fillWidth: true
                                    spacing: Theme.tightSpacing

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.listSpacing

                                        Image {
                                            Layout.preferredWidth: 16
                                            Layout.preferredHeight: 16
                                            sourceSize.width: 16
                                            sourceSize.height: 16
                                            source: {
                                                let iconName = modelData.appIcon || (modelData.appName ? modelData.appName.toLowerCase().replace(" desktop", "") : "");
                                                return iconName ? Icons.launcherIcon(iconName) : "";
                                            }
                                            asynchronous: true
                                            visible: status === Image.Ready
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.appName || "Notification"
                                            color: "#cdd6f4"
                                            font.family: "Adwaita Sans"
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: Qt.formatTime(new Date(modelData.timestamp || Date.now()), "hh:mm")
                                            color: "#a6adc8"
                                            font.family: "Adwaita Sans"
                                            font.pixelSize: 12
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.summary || modelData.urgencyName || ""
                                        color: modelData.read ? "#7f849c" : "#cdd6f4"
                                        font.family: "Adwaita Sans"
                                        font.pixelSize: 14
                                        font.bold: !modelData.read
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: text.length > 0
                                        text: modelData.body || ""
                                        color: modelData.read ? "#585b70" : "#a6adc8"
                                        font.family: "Adwaita Sans"
                                        font.pixelSize: 12
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 6
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
