import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.core

Rectangle {
    id: root

    required property var action
    property bool danger: false

    signal activated

    radius: Theme.radius
    color: actionMouse.containsMouse ? Theme.surfaceHover : Theme.surface
    border.color: danger ? Theme.danger : (actionMouse.containsMouse ? Theme.accent : Theme.border)
    border.width: 1

    scale: actionMouse.containsMouse ? 1.03 : 1.0

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Behavior on border.color {
        ColorAnimation { duration: 150 }
    }

    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
    }

    MouseArea {
        id: actionMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32

            Image {
                id: iconImage
                anchors.centerIn: parent
                width: 64
                height: 64
                source: root.action && root.action.icon ? Quickshell.iconPath(root.action.icon, true) : ""
                sourceSize: Qt.size(64, 64)
                fillMode: Image.PreserveAspectFit
                visible: source.toString().length > 0
                smooth: true
                antialiasing: true

                scale: actionMouse.containsMouse ? 0.55 : 0.5
                Behavior on scale {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }

                layer.enabled: true
                layer.smooth: true
                layer.effect: ColorOverlay {
                    color: root.danger ? Theme.textStrong : (actionMouse.containsMouse ? Theme.accent : Theme.text)
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.action ? root.action.label : ""
            color: root.danger ? Theme.textStrong : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.bodyFontSize
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
