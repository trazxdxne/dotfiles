import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.core

Rectangle {
    id: root

    required property var item

    signal dismiss
    signal expired

    Layout.fillWidth: true
    Layout.preferredHeight: Math.max(72, content.implicitHeight + 24)

    radius: Theme.radius
    color: item.urgency === NotificationUrgency.Critical ? Theme.dangerSurface : Theme.surface
    border.color: item.urgency === NotificationUrgency.Critical ? Theme.danger : Theme.border
    border.width: 1

    Timer {
        interval: Math.max(10, root.item.expireTime - Date.now())
        running: true
        repeat: false
        onTriggered: root.expired()
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.item && root.item.appName) {
                Commands.focusApp(root.item.appName);
            }
            root.dismiss();
        }
    }

    RowLayout {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: Theme.rowSpacing

        Rectangle {
            Layout.preferredWidth: Theme.notificationAccentWidth
            Layout.fillHeight: true
            radius: Theme.notificationAccentRadius
            color: root.item.urgency === NotificationUrgency.Critical ? Theme.danger : Theme.accent
        }

        ColumnLayout {
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
                        let iconName = root.item.appIcon || root.item.appName.toLowerCase().replace(" desktop", "");
                        return iconName ? Icons.launcherIcon(iconName) : "";
                    }
                    asynchronous: true
                    visible: status === Image.Ready
                }

                Text {
                    Layout.fillWidth: true
                    text: root.item.appName
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                    elide: Text.ElideRight
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.item.summary || root.item.urgencyName
                color: Theme.textStrong
                font.family: Theme.fontFamily
                font.pixelSize: Theme.bodyFontSize
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.item.body || ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
                wrapMode: Text.Wrap
                maximumLineCount: 6
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.preferredWidth: Theme.closeButtonSize - Theme.listSpacing
            Layout.preferredHeight: Theme.closeButtonSize - Theme.listSpacing
            radius: Theme.radius
            color: closeMouse.containsMouse ? Theme.surfaceHover : Theme.transparent
            border.color: Theme.border
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "\uF00D"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.panelFontSize
            }

            MouseArea {
                id: closeMouse

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dismiss()
            }
        }
    }
}
