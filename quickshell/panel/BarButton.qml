import QtQuick
import QtQuick.Layouts

import qs.core

/// Generic clickable bar button with hover effect.
Rectangle {
    id: root

    default property alias content: container.data
    signal activated()

    property bool hovered: ma.containsMouse

    implicitWidth: Math.ceil((container.children.length > 0 ? container.children[0].implicitWidth : 0) + 16)
    implicitHeight: Theme.panelHeight
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
