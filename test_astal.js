import { Astal, Gtk, Gdk } from "ags/gtk3";
import app from "ags/gtk3/app";

app.start({
    main() {
        const win = new Astal.Window({
            layer: Astal.Layer.OVERLAY
        });
        print("Before: " + win.click_through);
        try {
            win.click_through = true;
            print("After: " + win.click_through);
        } catch(e) {
            print("Error: " + e.message);
        }
        
        try {
            Astal.widget_set_click_through(win, true);
            print("widget_set_click_through success");
        } catch(e) {
            print("Error set_click_through: " + e.message);
        }
        
        print("Paintable before: " + win.app_paintable);
        win.app_paintable = true;
        print("Paintable after: " + win.app_paintable);
        
        app.quit();
    }
});
