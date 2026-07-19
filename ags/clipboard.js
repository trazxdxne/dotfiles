import { Astal, Gtk, Gdk } from "ags/gtk3"
import { execAsync } from "ags/process"
import app from "ags/gtk3/app"
import GLib from "gi://GLib"
import GdkPixbuf from "gi://GdkPixbuf"

let clipboardWindow = null;
let listContainer = null;
let previewContainer = null;

const currentPreviewPath = "/tmp/ags_clipboard_preview.png";

const copyItem = async (id, isImage) => {
    try {
        if (clipboardWindow) clipboardWindow.visible = false;
        
        // Wait for Niri to restore focus to the underlying window before checking
        await new Promise(resolve => GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => { resolve(); return GLib.SOURCE_REMOVE; }));
        
        if (isImage) {
            try {
                let isWezterm = false;
                if (GLib.getenv("XDG_CURRENT_DESKTOP") === "Hyprland") {
                    const activeOut = await execAsync("hyprctl activewindow -j");
                    const active = JSON.parse(activeOut);
                    isWezterm = (active && active.class === "org.wezfurlong.wezterm");
                } else {
                    const windowsOut = await execAsync("niri msg -j windows");
                    const windows = JSON.parse(windowsOut);
                    const focused = windows.find(w => w.is_focused);
                    isWezterm = (focused && focused.app_id === "org.wezfurlong.wezterm");
                }
                
                if (isWezterm) {
                    const tempFile = "/tmp/pasted_screenshot.png";
                    await execAsync(`sh -c "echo -n '${id}' | cliphist decode > ${tempFile}"`);
                    await execAsync(`sh -c "echo -n '${tempFile}' | wl-copy"`);
                    
                    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 150, () => {
                        execAsync(`sh -c "cliphist list | grep '${tempFile}' | cliphist delete"`).catch(() => {});
                        return GLib.SOURCE_REMOVE;
                    });
                    return;
                }
            } catch (err) {
                console.error("Niri check error", err);
            }
        }
        await execAsync(`sh -c "echo -n '${id}' | cliphist decode | wl-copy"`);
    } catch (e) {
        console.error(e);
    }
}

const clearHistory = async () => {
    try {
        await execAsync("cliphist wipe");
        if (clipboardWindow) clipboardWindow.visible = false;
    } catch (e) {}
}

let previewSequence = 0;

const showPreview = async (id, isImage) => {
    if (!previewContainer) return;
    
    const seq = ++previewSequence;
    
    try {
        if (isImage) {
            await execAsync(`sh -c "echo -n '${id}' | cliphist decode > ${currentPreviewPath}"`);
            if (seq !== previewSequence) return;
            
            previewContainer.get_children().forEach(ch => ch.destroy());
            const imgBox = new Gtk.Box()
            imgBox.get_style_context().add_class("clipboard-preview-image")
            
            try {
                const pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(currentPreviewPath, 418, 418, true)
                const img = Gtk.Image.new_from_pixbuf(pixbuf)
                imgBox.pack_start(img, true, true, 0)
            } catch (err) {
                console.error(err)
            }
            
            previewContainer.add(imgBox);
            previewContainer.show_all();
        } else {
            const fullText = await execAsync(`sh -c "echo -n '${id}' | cliphist decode"`);
            if (seq !== previewSequence) return;
            
            previewContainer.get_children().forEach(ch => ch.destroy());
            const scroll = new Gtk.ScrolledWindow()
            scroll.get_style_context().add_class("clipboard-preview-scroll")
            scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            scroll.set_hexpand(true)
            scroll.set_vexpand(true)
            scroll.set_min_content_height(400)
            
            const lbl = new Gtk.Label({ 
                label: fullText,
                wrap: true,
                xalign: 0,
                yalign: 0,
                selectable: true
            })
            lbl.set_hexpand(true)
            lbl.set_vexpand(true)
            lbl.set_halign(Gtk.Align.FILL)
            lbl.set_valign(Gtk.Align.FILL)
            lbl.get_style_context().add_class("clipboard-preview-text")
            
            scroll.add(lbl)
            previewContainer.add(scroll);
            previewContainer.show_all();
        }
    } catch(e) {}
}

const loadItems = async () => {
    if (!listContainer) return;
    listContainer.get_children().forEach(ch => ch.destroy());
    if (previewContainer) {
        previewContainer.get_children().forEach(ch => ch.destroy());
    }
    let out = "";
    try {
        out = await execAsync("cliphist list");
    } catch (e) {
        return;
    }
    
    const lines = out.split("\n").filter(l => l.trim() !== "");
    
    lines.forEach((line, index) => {
        const parts = line.split("\t");
        if (parts.length < 2) return;
        const id = parts[0];
        const content = parts.slice(1).join("\t");
        
        if (content === "/tmp/pasted_screenshot.png") return;
        
        const isImage = content.includes("[[ binary data");
        let displayTxt = content;
        if (isImage) {
            displayTxt = "Image (" + content.split("[[ binary data")[1].trim() + ")";
        }
        
        const btn = new Gtk.Button()
        btn.get_style_context().add_class("clipboard-item-btn")
        btn.connect("clicked", () => copyItem(id, isImage))
        btn.connect("focus-in-event", () => {
            showPreview(id, isImage)
            return false
        })
        
        const lbl = new Gtk.Label({ label: displayTxt, xalign: 0, max_width_chars: 35 })
        lbl.set_ellipsize(3) // END
        btn.add(lbl)
        
        // Add hover effect by connecting enter-notify
        btn.connect("enter-notify-event", () => {
            showPreview(id, isImage);
            return false;
        });

        listContainer.add(btn);
        
        if (index === 0) {
            GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
                showPreview(id, isImage);
                return GLib.SOURCE_REMOVE;
            })
        }
    })
    
    listContainer.show_all();
}

export function ClipboardPopup() {
    const { CENTER } = Astal.WindowAnchor
    
    listContainer = <box vertical={true} spacing={4} class="clipboard-list-box" />
    previewContainer = <box class="clipboard-preview-container" hexpand={true} vexpand={true} />
    
    const searchEntry = (
        <entry 
            class="clipboard-search" 
            placeholder_text="Type to search..."
            onChanged={(self) => {
                const text = self.text.toLowerCase();
                let firstMatch = null;
                listContainer.get_children().forEach(ch => {
                    const lbl = ch.get_child();
                    if (!lbl) return;
                    const content = lbl.get_text().toLowerCase();
                    const isMatch = content.includes(text);
                    ch.visible = isMatch;
                    if (isMatch && !firstMatch) {
                        firstMatch = ch;
                    }
                });
            }}
            onActivate={() => {
                const children = listContainer.get_children();
                const visibleChild = children.find(ch => ch.visible);
                if (visibleChild) {
                    visibleChild.clicked();
                }
            }}
        />
    )
    
    const clearBtn = (
        <button class="clipboard-clear-btn" onClicked={clearHistory}>
            <label label="Clear History" xalign={0.5} />
        </button>
    )
    
    clipboardWindow = (
        <window
            name="clipboard-popup"
            class="clipboard-popup-window"
            anchor={CENTER}
            layer={Astal.Layer.OVERLAY}
            visible={false}
            application={app}
            keymode={Astal.Keymode.EXCLUSIVE}
            onKeyPressEvent={(self, event) => {
                const [_, keyval] = event.get_keyval()
                if (keyval === Gdk.KEY_Escape) {
                    self.visible = false
                    return true
                }
                
                // Allow using Down arrow in search to focus list
                if (keyval === Gdk.KEY_Down && searchEntry.has_focus) {
                    const children = listContainer.get_children();
                    const firstVisible = children.find(ch => ch.visible);
                    if (firstVisible) firstVisible.grab_focus();
                    return true;
                }
                
                return false
            }}
        >
            <box class="clipboard-main-box" spacing={16} css="min-width: 800px; min-height: 520px;">
                <box vertical={true} class="clipboard-left-pane" spacing={12}>
                    <label class="clipboard-title" label="Clipboard History" xalign={0} />
                    {searchEntry}
                    <scrollable class="clipboard-list-scroll" hscroll={Gtk.PolicyType.NEVER} vscroll={Gtk.PolicyType.AUTOMATIC} vexpand={true}>
                        {listContainer}
                    </scrollable>
                    {clearBtn}
                </box>
                
                <box vertical={true} class="clipboard-right-pane">
                    <label class="clipboard-preview-title" label="Preview" xalign={0} />
                    {previewContainer}
                </box>
            </box>
        </window>
    )

    clipboardWindow.connect("notify::visible", () => {
        if (clipboardWindow.visible) {
            searchEntry.text = "";
            loadItems();
            GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
                searchEntry.grab_focus();
                return GLib.SOURCE_REMOVE;
            });
        }
    })
    
    clipboardWindow.connect("notify::has-toplevel-focus", () => {
        if (clipboardWindow && !clipboardWindow.has_toplevel_focus) {
            GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
                if (clipboardWindow && !clipboardWindow.has_toplevel_focus && clipboardWindow.visible) {
                    clipboardWindow.visible = false;
                }
                return GLib.SOURCE_REMOVE;
            });
        }
    })
    
    return clipboardWindow
}
