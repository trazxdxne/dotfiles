import Quickshell
import Quickshell.Io

Scope {
    id: root

    property bool visible: false
    property bool confirming: false
    property var pendingAction: null
    property string status: ""

    readonly property var sessionActions: [
        {
            "id": "sleep",
            "label": "Sleep",
            "detail": "Suspend the system",
            "icon": "system-suspend-symbolic",
            "command": ["systemctl", "suspend"],
            "confirm": false
        },
        {
            "id": "logout",
            "label": "Logout",
            "detail": "End the current session",
            "icon": "system-log-out-symbolic",
            "command": ["niri", "msg", "action", "quit", "--skip-confirmation"],
            "confirm": true
        },
        {
            "id": "reboot",
            "label": "Reboot",
            "detail": "Restart this system",
            "icon": "system-reboot-symbolic",
            "command": ["systemctl", "reboot"],
            "confirm": true
        },
        {
            "id": "shutdown",
            "label": "Shutdown",
            "detail": "Power off this system",
            "icon": "system-shutdown-symbolic",
            "command": ["systemctl", "poweroff"],
            "confirm": true
        }
    ]

    function open() {
        root.visible = true;
        root.confirming = false;
        root.pendingAction = null;
        root.status = "";
    }

    function close() {
        root.visible = false;
        root.confirming = false;
        root.pendingAction = null;
        root.status = "";
    }

    function toggle() {
        if (root.visible) {
            root.close();
        } else {
            root.open();
        }
    }

    function requestAction(action) {
        if (!action) {
            return;
        }

        if (action.confirm) {
            root.pendingAction = action;
            root.confirming = true;
            root.status = "";
            return;
        }

        root.runAction(action);
    }

    function cancelConfirmation() {
        root.confirming = false;
        root.pendingAction = null;
        root.status = "";
    }

    function confirmAction() {
        if (!root.pendingAction) {
            root.cancelConfirmation();
            return;
        }

        root.runAction(root.pendingAction);
    }

    function runAction(action) {
        if (!action || !action.command || action.command.length === 0) {
            return;
        }

        actionProcess.command = action.command;
        actionProcess.running = true;
        root.close();
    }

    Process {
        id: actionProcess

        command: ["sh", "-c", "exit 0"]
        running: false
    }
}
