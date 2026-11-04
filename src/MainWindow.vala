public class ClipboardHistory.MainWindow : Gtk.ApplicationWindow {
    public signal void item_activated (ClipboardItem item);

    public HistoryStore store { get; construct; }

    private Gtk.ListBox list_box;
    private Gtk.ScrolledWindow scrolled;

    public MainWindow (Gtk.Application application, HistoryStore store) {
        Object (
            application: application,
            store: store,
            title: "Clipboard",
            default_width: 380,
            default_height: 460,
            resizable: false
        );
    }

    construct {
        // The header below replaces the regular title bar, as in the reference design.
        titlebar = new Gtk.Grid () { visible = false };

        var title_label = new Granite.HeaderLabel ("Clipboard") {
            size = Granite.HeaderLabel.Size.H3,
            hexpand = true,
        };

        var clear_button = new Gtk.Button.with_label ("Clear all");
        clear_button.clicked.connect (() => store.clear ());

        var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        header.add_css_class ("clipboard-header");
        header.append (title_label);
        header.append (clear_button);

        var placeholder = new Granite.Placeholder ("Nothing copied yet") {
            description = "Text and images you copy will show up here.",
            icon = new ThemedIcon ("edit-paste-symbolic"),
        };

        list_box = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.NONE,
            activate_on_single_click = true,
        };
        list_box.add_css_class ("clipboard-list");
        list_box.set_placeholder (placeholder);
        list_box.bind_model (store.items, create_row);
        list_box.row_activated.connect ((row) => item_activated (((ItemRow) row).item));

        scrolled = new Gtk.ScrolledWindow () {
            child = list_box,
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            vexpand = true,
        };

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.append (new Gtk.WindowHandle () { child = header });
        box.append (scrolled);
        child = box;

        store.items.items_changed.connect (() => {
            clear_button.sensitive = store.items.get_n_items () > 0;
        });
        clear_button.sensitive = store.items.get_n_items () > 0;

        var key_controller = new Gtk.EventControllerKey ();
        key_controller.key_pressed.connect (on_key_pressed);
        ((Gtk.Widget) this).add_controller (key_controller);

        // Like the Windows version: clicking elsewhere dismisses the window.
        notify["is-active"].connect (() => {
            if (!is_active && visible) {
                close ();
            }
        });
    }

    public void reset_view () {
        scrolled.vadjustment.value = 0;

        var first_row = list_box.get_row_at_index (0);
        if (first_row != null) {
            first_row.grab_focus ();
        }
    }

    private Gtk.Widget create_row (Object object) {
        var row = new ItemRow ((ClipboardItem) object);
        row.remove_requested.connect (() => store.remove (row.item));
        return row;
    }

    private bool on_key_pressed (uint keyval, uint keycode, Gdk.ModifierType state) {
        switch (keyval) {
            case Gdk.Key.Escape:
                close ();
                return Gdk.EVENT_STOP;

            case Gdk.Key.Delete:
            case Gdk.Key.KP_Delete:
                var row = list_box.get_focus_child () as ItemRow;
                if (row != null) {
                    var index = row.get_index ();
                    store.remove (row.item);
                    focus_row_near (index);
                }
                return Gdk.EVENT_STOP;

            default:
                return Gdk.EVENT_PROPAGATE;
        }
    }

    private void focus_row_near (int index) {
        var row = list_box.get_row_at_index (index) ?? list_box.get_row_at_index (index - 1);
        if (row != null) {
            row.grab_focus ();
        }
    }
}
