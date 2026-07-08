import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core

FloatingWindow {
    id: root

    required property var powerMenuModel

    property int focusedIndex: 0
    property string activeHotkey: ""
    property bool isEnterPressed: false

    title: "dwm power menu"
    visible: powerMenuModel.visible || content.opacity > 0.0
    implicitWidth: 620
    implicitHeight: 200
    color: Theme.transparent

    onVisibleChanged: {
        if (visible) {
            focusedIndex = 0;
            activeHotkey = "";
            isEnterPressed = false;
            Qt.callLater(content.forceActiveFocus);
        }
    }

    // Reset state to close the menu on focus loss, preventing double-press trigger
    contentItem.onActiveFocusChanged: {
        if (!contentItem.activeFocus) {
            Qt.callLater(function() {
                if (!contentItem.activeFocus && root.powerMenuModel.visible) {
                    root.powerMenuModel.close();
                }
            });
        }
    }

    ShellSurface {
        id: content

        anchors.fill: parent
        focus: true

        opacity: powerMenuModel.visible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        Keys.onPressed: function(event) {
            if (event.isAutoRepeat) return;

            if (event.key === Qt.Key_Escape) {
                root.powerMenuModel.close();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Left) {
                root.focusedIndex = Math.max(0, root.focusedIndex - 1);
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Right) {
                root.focusedIndex = Math.min(root.powerMenuModel.sessionActions.length - 1, root.focusedIndex + 1);
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.isEnterPressed = true;
                event.accepted = true;
                return;
            }

            var keyText = event.text ? event.text.toUpperCase() : String.fromCharCode(event.key).toUpperCase();
            var ruToEn = { "Я": "Z", "Ы": "S", "Д": "L", "К": "R" };
            if (ruToEn[keyText]) {
                keyText = ruToEn[keyText];
            }

            if (keyText === "Z" || keyText === "L" || keyText === "R" || keyText === "S") {
                root.activeHotkey = keyText;
                event.accepted = true;
                return;
            }
        }

        Keys.onReleased: function(event) {
            if (event.isAutoRepeat) return;

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.isEnterPressed = false;
                event.accepted = true;
                return;
            }

            var keyText = event.text ? event.text.toUpperCase() : String.fromCharCode(event.key).toUpperCase();
            var ruToEn = { "Я": "Z", "Ы": "S", "Д": "L", "К": "R" };
            if (ruToEn[keyText]) {
                keyText = ruToEn[keyText];
            }

            if (keyText === root.activeHotkey) {
                root.activeHotkey = "";
                event.accepted = true;
                return;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.popupSpacing

            Text {
                text: "Power Menu"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleFontSize
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }

            // Horizontal layout for the 4 power actions
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.listSpacing * 3

                Repeater {
                    model: root.powerMenuModel.sessionActions
                    delegate: PowerMenuActionButton {
                        required property int index
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 110
                        action: modelData
                        danger: modelData.id === "shutdown" || modelData.id === "reboot"
                        
                        focused: root.focusedIndex === index
                        externalPressed: (root.focusedIndex === index && root.isEnterPressed) || (root.activeHotkey === modelData.hotkeyStr)

                        onActivated: root.powerMenuModel.requestAction(modelData)
                    }
                }
            }
        }
    }
}
