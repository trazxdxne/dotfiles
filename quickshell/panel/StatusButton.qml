import QtQuick
import QtQuick.Layouts
import qs.core

/// A status button with an icon and an optional counter badge.
/// Integrates with the global theme.
BarButton {
    id: root

    property string icon: ""
    property var value: null
    property bool showZero: false
    property int maxValue: 99
    property bool active: false

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: 4

        Text {
            id: iconText
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (root.icon === "bell") {
                    return "\uF0F3"; //  (bell / active)
                }
                if (root.icon === "clipboard") {
                    return "\uF0EA"; //  (clipboard)
                }
                return "";
            }
            color: {
                if (root.active) return "#f5c2e7"; // active/focused rosewater/pink highlight
                if (root.value === 0 || root.value === null) return "#6c7086"; // muted text
                return "#cba6f7"; // default mauve
            }
            font {
                family: "FantasqueSansM Nerd Font"
                pixelSize: 12
            }
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: valueText
            anchors.verticalCenter: parent.verticalCenter
            visible: {
                const num = Number(root.value);
                return !isNaN(num) && (num > 0 || root.showZero);
            }
            text: {
                const num = Number(root.value);
                if (num > root.maxValue) return root.maxValue + "+";
                return String(num);
            }
            color: root.active ? "#f5c2e7" : "#f5e0dc"
            font {
                family: "Adwaita Sans"
                pixelSize: 10
                weight: Font.Medium
            }
            verticalAlignment: Text.AlignVCenter
        }
    }
}
