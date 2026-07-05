import QtQuick
import QtQuick.Layouts
import qs.core

/// Workspace button for Niri panel. Velvet Night theme.
Rectangle {
    id: root

    required property string wsName
    required property bool active
    signal clicked()

    width: Math.ceil(Math.max(24, label.implicitWidth + 12))
    height: Theme.panelHeight
    Layout.preferredWidth: width
    Layout.preferredHeight: height
    radius: 0
    color: active ? "#cba6f7" : (hovered ? "#0dffffff" : "transparent")

    property bool hovered: ma.containsMouse

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.wsName
        color: root.active ? "#1e1e2e" : (root.hovered ? "#f5c2e7" : "#f5e0dc")
        font.family: "Adwaita Sans"
        font.pixelSize: 13
        verticalAlignment: Text.AlignVCenter

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
