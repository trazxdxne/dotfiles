pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool loaded: false

    // Theme properties
    property bool darkTheme: true
    property string activeTheme: "Velvet Night"

    // Bar properties
    property int barHeight: 24
    property int barMargins: 0
    property string barFont: "Adwaita Sans"
    property bool showClock: true
    property bool showVolume: true
    property bool showBattery: true

    // Clipboard properties
    property int clipboardWidth: 960
    property int clipboardHeight: 620
    property string clipboardFont: "Adwaita Sans"
    property int clipboardMaxItems: 100

    // Notifications properties
    property int notifWidth: 380
    property int notifTimeout: 5000
    property int notifMaxItems: 50
    property string notifFont: "Adwaita Sans"

    function toJson() {
        return JSON.stringify({
            darkTheme: darkTheme,
            activeTheme: activeTheme,
            barHeight: barHeight,
            barMargins: barMargins,
            barFont: barFont,
            showClock: showClock,
            showVolume: showVolume,
            showBattery: showBattery,
            clipboardWidth: clipboardWidth,
            clipboardHeight: clipboardHeight,
            clipboardFont: clipboardFont,
            clipboardMaxItems: clipboardMaxItems,
            notifWidth: notifWidth,
            notifTimeout: notifTimeout,
            notifMaxItems: notifMaxItems,
            notifFont: notifFont
        });
    }

    function fromJson(str) {
        if (!str || str.trim() === "") {
            loaded = true;
            return;
        }
        try {
            var obj = JSON.parse(str);
            if (obj.darkTheme !== undefined) darkTheme = obj.darkTheme;
            if (obj.activeTheme !== undefined) activeTheme = obj.activeTheme;
            if (obj.barHeight !== undefined) barHeight = obj.barHeight;
            if (obj.barMargins !== undefined) barMargins = obj.barMargins;
            if (obj.barFont !== undefined) barFont = obj.barFont;
            if (obj.showClock !== undefined) showClock = obj.showClock;
            if (obj.showVolume !== undefined) showVolume = obj.showVolume;
            if (obj.showBattery !== undefined) showBattery = obj.showBattery;
            
            if (obj.clipboardWidth !== undefined) clipboardWidth = obj.clipboardWidth;
            if (obj.clipboardHeight !== undefined) clipboardHeight = obj.clipboardHeight;
            if (obj.clipboardFont !== undefined) clipboardFont = obj.clipboardFont;
            if (obj.clipboardMaxItems !== undefined) clipboardMaxItems = obj.clipboardMaxItems;

            if (obj.notifWidth !== undefined) notifWidth = obj.notifWidth;
            if (obj.notifTimeout !== undefined) notifTimeout = obj.notifTimeout;
            if (obj.notifMaxItems !== undefined) notifMaxItems = obj.notifMaxItems;
            if (obj.notifFont !== undefined) notifFont = obj.notifFont;
        } catch(e) {
            console.warn("Failed to parse config:", e);
        }
        loaded = true;
    }

    Process {
        id: loadProc
        command: ["sh", "-c", "cat ~/.config/quickshell-config.json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.fromJson(this.text)
        }
    }

    function save() {
        if (!loaded) return;
        var data = root.toJson();
        // Use python to write safely to the config
        saveProc.command = ["python3", "-c", "import sys, os; open(os.path.expanduser('~/.config/quickshell-config.json'), 'w').write(sys.argv[1])", data];
        saveProc.running = false;
        saveProc.running = true;
    }

    Process {
        id: saveProc
        running: false
    }

    onDarkThemeChanged: save()
    onActiveThemeChanged: save()
    onBarHeightChanged: save()
    onBarMarginsChanged: save()
    onBarFontChanged: save()
    onShowClockChanged: save()
    onShowVolumeChanged: save()
    onShowBatteryChanged: save()
    onClipboardWidthChanged: save()
    onClipboardHeightChanged: save()
    onClipboardFontChanged: save()
    onClipboardMaxItemsChanged: save()
    onNotifWidthChanged: save()
    onNotifTimeoutChanged: save()
    onNotifMaxItemsChanged: save()
    onNotifFontChanged: save()
}
