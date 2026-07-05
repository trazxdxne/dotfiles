import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.core

Scope {
    id: root

    property var notifications: []
    property var history: []
    property var sortedHistory: {
        var arr = history.slice();
        arr.sort(function(a, b) {
            if (a.read === b.read) {
                return b.timestamp - a.timestamp;
            }
            return a.read ? 1 : -1;
        });
        return arr;
    }
    property bool historyVisible: false
    property int sequence: 0
    property int unreadCount: {
        var count = 0;
        for (var i = 0; i < history.length; i++) {
            if (!history[i].read) {
                count++;
            }
        }
        return count;
    }

    property int popupTimeoutMs: Config.notifTimeout
    property int criticalTimeoutMs: Config.notifTimeout * 2
    property int maxVisible: 4
    property int maxHistory: Config.notifMaxItems
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/dwm-titus"
    readonly property string historyPath: cacheDir + "/notification-history.json"

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", cacheDir])

    function urgencyName(urgency) {
        if (urgency === NotificationUrgency.Critical) {
            return "critical";
        }
        if (urgency === NotificationUrgency.Low) {
            return "low";
        }
        return "normal";
    }

    function add(notification) {
        if (!notification) {
            return;
        }

        if (notification.appName === "niri") {
            return;
        }

        notification.tracked = true;
        root.sequence += 1;

        const item = {
            "key": notification.id + "-" + root.sequence,
            "notification": notification,
            "appName": notification.appName || "Notification",
            "appIcon": notification.appIcon || "",
            "summary": notification.summary || "",
            "body": notification.body || "",
            "urgency": notification.urgency,
            "urgencyName": root.urgencyName(notification.urgency),
            "timeoutMs": notification.urgency === NotificationUrgency.Critical ? root.criticalTimeoutMs : root.popupTimeoutMs,
            "expireTime": Date.now() + (notification.urgency === NotificationUrgency.Critical ? root.criticalTimeoutMs : root.popupTimeoutMs)
        };

        const existing = root.notifications.filter(n => n.notification && n.notification.id !== notification.id);
        root.notifications = [item].concat(existing).slice(0, root.maxVisible);
        root.addHistory(item);
    }

    function remove(key) {
        root.notifications = root.notifications.filter(n => n.key !== key);
    }

    function clear() {
        const current = root.notifications.slice();
        for (const item of current) {
            if (item && item.notification) {
                try {
                    if (typeof item.notification.dismiss === "function") {
                        item.notification.dismiss();
                    }
                } catch(e) {}
            }
        }
        root.notifications = [];
    }

    function addHistory(item) {
        const entry = {
            "key": item.key,
            "appName": item.appName,
            "appIcon": item.appIcon,
            "summary": item.summary,
            "body": item.body,
            "urgency": item.urgency,
            "urgencyName": item.urgencyName,
            "timestamp": Date.now(),
            "read": false
        };

        root.history = [entry].concat(root.history).slice(0, root.maxHistory);
        root.saveHistory();
    }

    function clearHistory() {
        root.history = [];
        root.saveHistory();
        root.closeHistory();
    }

    function closeHistory() {
        root.historyVisible = false;
    }

    function openHistory() {
        root.historyVisible = true;
    }

    function toggleHistory() {
        root.historyVisible = !root.historyVisible;
    }

    function historyLatestSummary() {
        return root.history.length > 0 ? root.history[0].summary : "";
    }

    function loadHistory() {
        var raw = (historyAdapter.notifications || []).slice(0, root.maxHistory);
        root.history = raw.map(n => {
            if (n.read === undefined) {
                n.read = true;
            }
            return n;
        });
    }

    function saveHistory() {
        historyAdapter.notifications = root.history;
        historyFile.writeAdapter();
    }

    function appsMatch(focusedApp, notifApp) {
        if (!focusedApp || !notifApp) return false;
        var cleanFocused = focusedApp.replace(/^org\.\w+\./, "").replace(/^com\.\w+\./, "").split(/[.-]/)[0].toLowerCase();
        var cleanNotif = notifApp.replace(/^org\.\w+\./, "").replace(/^com\.\w+\./, "").split(/[.-]/)[0].toLowerCase();
        return cleanFocused.indexOf(cleanNotif) !== -1 || cleanNotif.indexOf(cleanFocused) !== -1;
    }

    function markAsReadForApp(appName) {
        if (!appName) return;
        var changed = false;
        var appLower = appName.toLowerCase();
        var updatedHistory = root.history.map(item => {
            var itemAppLower = (item.appName || "").toLowerCase();
            if (root.appsMatch(appLower, itemAppLower)) {
                if (!item.read) {
                    item.read = true;
                    changed = true;
                }
            }
            return item;
        });

        if (changed) {
            root.history = updatedHistory;
            root.saveHistory();
        }
    }

    function dismiss(key) {
        const item = root.notifications.find(n => n.key === key);
        if (item && item.notification) {
            try {
                if (typeof item.notification.dismiss === "function") {
                    item.notification.dismiss();
                }
            } catch(e) {}
        }
        root.remove(key);
    }

    function expire(key) {
        const item = root.notifications.find(n => n.key === key);
        if (item && item.notification) {
            try {
                if (typeof item.notification.expire === "function") {
                    item.notification.expire();
                }
            } catch(e) {}
        }
        root.remove(key);
    }

    FileView {
        id: historyFile

        path: root.historyPath
        printErrors: false
        onLoaded: root.loadHistory()
        onLoadFailed: error => {
            if (error === 2) {
                root.saveHistory();
            }
        }

        JsonAdapter {
            id: historyAdapter

            property var notifications: []
        }
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: false
        persistenceSupported: true

        onNotification: notification => root.add(notification)
    }
}
