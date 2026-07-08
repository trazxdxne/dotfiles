import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core

FloatingWindow {
    id: root

    required property var powerMenuModel

    title: "dwm power menu"
    visible: powerMenuModel.visible
    implicitWidth: 620
    implicitHeight: powerMenuModel.confirming ? 150 : 200
    color: Theme.transparent
    readonly property var cancelAction: {
        "label": "Cancel",
        "detail": "Return to menu",
        "icon": "dialog-cancel-symbolic"
    }

    readonly property var confirmButtonAction: {
        "label": "Confirm",
        "detail": powerMenuModel.pendingAction ? powerMenuModel.pendingAction.label : "",
        "icon": "dialog-ok-symbolic"
    }

    onVisibleChanged: {
        if (visible) {
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

        opacity: root.visible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (root.powerMenuModel.confirming) {
                    root.powerMenuModel.cancelConfirmation();
                } else {
                    root.powerMenuModel.close();
                }
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.popupSpacing

            Text {
                text: root.powerMenuModel.confirming ? "Confirm Action" : "Power Menu"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleFontSize
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }

            // Horizontal layout for the 4 power actions
            RowLayout {
                visible: !root.powerMenuModel.confirming
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
                        onActivated: root.powerMenuModel.requestAction(modelData)
                    }
                }
            }

            // Horizontal layout for confirmation
            RowLayout {
                visible: root.powerMenuModel.confirming
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.listSpacing * 3

                PowerMenuActionButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 110
                    action: root.cancelAction
                    onActivated: root.powerMenuModel.cancelConfirmation()
                }

                PowerMenuActionButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 110
                    action: root.confirmButtonAction
                    danger: true
                    onActivated: root.powerMenuModel.confirmAction()
                }
            }
        }
    }
}
