import QtQuick
import QtQuick.Layouts

/// Generic clickable bar button with hover effect.
Rectangle {
    id: root

    default property alias content: container.data
    signal activated()

    property bool hovered: ma.containsMouse

    implicitWidth: container.childrenRect.width + 16
    implicitHeight: 28
    radius: 0
    color: hovered ? "#1a45475a" : "transparent"

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Item {
        id: container
        anchors.fill: parent
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
