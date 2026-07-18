import { Astal, Gtk, Gdk } from "ags/gtk3";
import app from "ags/gtk3/app";
import GLib from "gi://GLib";

const cssProvider = new Gtk.CssProvider();
cssProvider.load_from_data(`
    window { background: transparent; }
    .my-box { background: red; border-radius: 20px; }
`);
Gtk.StyleContext.add_provider_for_screen(
    Gdk.Screen.get_default(),
    cssProvider,
    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
);

app.start({
    main() {
        const win = new Astal.Window({
            layer: Astal.Layer.OVERLAY,
            anchor: Astal.WindowAnchor.TOP | Astal.WindowAnchor.LEFT,
            margin_top: 200,
            margin_left: 200,
            application: app
        });
        const box = new Gtk.Box();
        box.get_style_context().add_class("my-box");
        box.set_size_request(200, 200);
        win.add(box);
        win.show_all();
        
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 3000, () => {
            app.quit();
            return GLib.SOURCE_REMOVE;
        });
    }
});
