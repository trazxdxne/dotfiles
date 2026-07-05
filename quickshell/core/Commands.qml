pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    function helperCommand(helper, action, args, preferManaged) {
        const argv = args || [];
        const managedScript = "\"$data_dir/scripts/" + helper + "\"";
        const dataDir = "data_dir=${XDG_DATA_HOME:-$HOME/.local/share}/dwm-titus";
        const runManaged = "[ -x " + managedScript + " ] && exec " + managedScript + " \"$@\"";
        const runPath = "command -v " + helper + " >/dev/null 2>&1 && exec " + helper + " \"$@\"";
        const fallback = "exec " + managedScript + " \"$@\"";
        const orderedChecks = preferManaged
            ? [runManaged, runPath, fallback]
            : [runPath, runManaged, fallback];
        const script = [dataDir].concat(orderedChecks).join("; ");

        return ["sh", "-c", script, helper, action].concat(argv);
    }

    function launcherHelperCommand(action, args) {
        return helperCommand("dwm-quickshell-launcher", action, args, true);
    }

    function networkHelperCommand(action, args) {
        return helperCommand("dwm-quickshell-network", action, args, false);
    }

    function controlsHelperCommand(action, args) {
        return helperCommand("dwm-quickshell-controls", action, args, false);
    }

    function controlCenterHelperCommand(action, args) {
        return helperCommand("dwm-quickshell-controlcenter", action, args, true);
    }

    Process {
        id: focusProcess
        property string targetApp: ""
        command: ["niri", "msg", "-j", "windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const windows = JSON.parse(this.text);
                    let query = focusProcess.targetApp.toLowerCase().replace(" desktop", "").replace("-bin", "");
                    if (query.includes("ayugram") || query.includes("telegram")) query = "ayugram";
                    
                    let targetId = -1;
                    for (let i = 0; i < windows.length; i++) {
                        const win = windows[i];
                        const appId = (win.app_id || "").toLowerCase();
                        const title = (win.title || "").toLowerCase();
                        if (appId.includes(query) || title.includes(query)) {
                            targetId = win.id;
                            break;
                        }
                    }
                    
                    if (targetId !== -1) {
                        Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", targetId.toString()]);
                    }
                } catch (e) {}
            }
        }
    }

    function focusApp(appName) {
        if (!appName) return;
        focusProcess.targetApp = appName;
        focusProcess.running = true;
    }
}
