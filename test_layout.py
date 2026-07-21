import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk

def check(scenario, border_width):
    provider = Gtk.CssProvider()
    css = b"""
    * { min-height: 0; min-width: 0; padding: 0; margin: 0; }
    .clock-time { font-size: 14px; }
    button.clock-box { padding: 1px 10px; }
    """
    
    if scenario == "old":
        css += b".clock-wrapper { border: 0px solid transparent; }\n"
        css += b"button.clock-box { border: 2px solid transparent; }\n"
    elif scenario == "new_inside":
        css += b".clock-wrapper { border: 0px solid transparent; }\n"
        css += f"button.clock-box {{ border: {border_width}px solid transparent; }}\n".encode()
    elif scenario == "new_outside":
        css += f".clock-wrapper {{ border: {border_width}px solid transparent; }}\n".encode()
        css += b"button.clock-box { border: 0px solid transparent; }\n"

    provider.load_from_data(css)
    
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(),
        provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )

    window = Gtk.OffscreenWindow()
    wrapper = Gtk.Box()
    wrapper.get_style_context().add_class("clock-wrapper")
    
    btn = Gtk.Button()
    btn.set_valign(Gtk.Align.CENTER)
    btn.get_style_context().add_class("clock-box")
    
    label = Gtk.Label(label="12:34")
    label.get_style_context().add_class("clock-time")
    
    btn.add(label)
    wrapper.add(btn)
    window.add(wrapper)
    window.show_all()
    
    window.get_preferred_height()
    alloc = Gdk.Rectangle()
    alloc.x = 0; alloc.y = 0; alloc.width = 100; alloc.height = 40
    window.size_allocate(alloc)
    
    wrapper_alloc = wrapper.get_allocation()
    btn_alloc = btn.get_allocation()
    label_alloc = label.get_allocation()
    
    print(f"[{scenario} bw={border_width}] Wrapper Y: {wrapper_alloc.y}, H: {wrapper_alloc.height} | Btn Y: {btn_alloc.y}, H: {btn_alloc.height} | Lbl Y: {label_alloc.y}, H: {label_alloc.height}")
    # Absolute Y of label
    abs_y = wrapper_alloc.y + btn_alloc.y + label_alloc.y
    print(f"[{scenario} bw={border_width}] Label Absolute Y: {abs_y}")

check("old", 2)
check("new_outside", 2)
check("new_outside", 3)
check("new_outside", 4)
check("new_outside", 1)
