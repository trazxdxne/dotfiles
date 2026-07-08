import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.core

Rectangle {
    id: root

    required property var action
    property bool danger: false
    property bool focused: false
    property bool externalPressed: false

    readonly property bool isPressed: actionMouse.pressed || root.externalPressed

    signal activated

    radius: Theme.radius
    color: (actionMouse.containsMouse || focused) ? Theme.surfaceHover : Theme.surface
    border.color: danger ? Theme.danger : ((actionMouse.containsMouse || focused) ? Theme.accent : Theme.border)
    border.width: focused ? 2 : 1

    scale: (actionMouse.containsMouse || focused || root.isPressed) ? 1.03 : 1.0

    Timer {
        id: holdTimer
        interval: 600
        running: root.isPressed
        repeat: false
        onTriggered: root.activated()
    }

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Behavior on border.color {
        ColorAnimation { duration: 150 }
    }

    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.isPressed ? parent.width : 0
        radius: Theme.radius
        color: danger ? Theme.danger : Theme.accent
        opacity: 0.2

        Behavior on width {
            NumberAnimation { 
                duration: root.isPressed ? 600 : 150
                easing.type: Easing.Linear 
            }
        }
    }

    MouseArea {
        id: actionMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 4

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

                scale: (actionMouse.containsMouse || focused) ? 0.55 : 0.5
                Behavior on scale {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }

                layer.enabled: true
                layer.smooth: true
                layer.effect: ColorOverlay {
                    color: root.danger ? Theme.textStrong : ((actionMouse.containsMouse || focused) ? Theme.accent : Theme.text)
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

        Text {
            Layout.fillWidth: true
            text: root.action && root.action.hotkeyStr ? "Hold [" + root.action.hotkeyStr + "]" : ""
            color: Theme.text
            opacity: 0.6
            font.family: Theme.fontFamily
            font.pixelSize: Theme.bodyFontSize * 0.8
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
