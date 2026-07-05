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

    Shortcut {
        sequence: "Escape"
        onActivated: root.notificationModel.closeHistory()
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

        Keys.onEscapePressed: {
            root.notificationModel.closeHistory()
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.popupSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.listSpacing * 2

                Text {
                    Layout.fillWidth: true
                    text: "Notifications"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.titleFontSize
                    font.bold: true
                    elide: Text.ElideRight
                }

                ShellButton {
                    Layout.preferredWidth: 58
                    Layout.preferredHeight: Theme.buttonHeight
                    label: "Clear"
                    onActivated: root.notificationModel.clearHistory()
                }

                ShellButton {
                    Layout.preferredWidth: Theme.closeButtonSize
                    Layout.preferredHeight: Theme.closeButtonSize
                    label: "\uF00D"
                    fontFamily: "FantasqueSansM Nerd Font"
                    onActivated: root.notificationModel.closeHistory()
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
                        model: root.notificationModel.history

                        delegate: Rectangle {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(74, historyContent.implicitHeight + 22)
                            radius: Theme.radius
                            color: modelData.urgencyName === "critical" ? Theme.dangerSurface : Theme.surface
                            border.color: modelData.urgencyName === "critical" ? Theme.danger : Theme.border
                            border.width: 1

                            MouseArea {
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
                                    Layout.preferredWidth: Theme.notificationAccentWidth
                                    Layout.fillHeight: true
                                    radius: Theme.notificationAccentRadius
                                    color: modelData.urgencyName === "critical" ? Theme.danger : Theme.accent
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
                                            color: Theme.textMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.smallFontSize
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: Qt.formatTime(new Date(modelData.timestamp || Date.now()), "hh:mm")
                                            color: Theme.textMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.smallFontSize
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.summary || modelData.urgencyName || ""
                                        color: modelData.read ? Theme.textMuted : Theme.textStrong
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.bodyFontSize
                                        font.bold: !modelData.read
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: text.length > 0
                                        text: modelData.body || ""
                                        color: modelData.read ? Theme.textMuted : Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.smallFontSize
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
