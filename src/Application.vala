public class ClipboardHistory.Application : Gtk.Application {
    private const uint MAX_ITEMS = 25;

    // How long to wait after closing the window for focus to return to the previous app.
    private const uint PASTE_DELAY_MS = 150;

    private HistoryStore store;
    private ClipboardMonitor monitor;
    private VirtualKeyboard keyboard;
    private MainWindow? window = null;
    private bool start_in_background = false;

    public Application () {
        Object (
            application_id: "io.github.calderov.ClipboardHistory",
            flags: ApplicationFlags.DEFAULT_FLAGS
        );

        add_main_option (
            "background", 'b', OptionFlags.NONE, OptionArg.NONE,
            "Start monitoring the clipboard without showing the window", null
        );
        add_main_option (
            "quit", 'q', OptionFlags.NONE, OptionArg.NONE,
            "Stop the running instance", null
        );
    }

    protected override int handle_local_options (VariantDict options) {
        if (options.contains ("quit")) {
            try {
                register ();
                if (get_is_remote ()) {
                    activate_action ("quit", null);
                }
            } catch (Error e) {
                critical (e.message);
                return 1;
            }
            return 0;
        }

        if (options.contains ("background")) {
            try {
                register ();
            } catch (Error e) {
                critical (e.message);
                return 1;
            }
            // Already running: nothing to do.
            if (get_is_remote ()) {
                return 0;
            }
            start_in_background = true;
        }

        return -1;
    }

    protected override void startup () {
        base.startup ();

        Granite.init ();

        var gtk_settings = Gtk.Settings.get_default ();
        var granite_settings = Granite.Settings.get_default ();
        gtk_settings.gtk_application_prefer_dark_theme =
            granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme =
                granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        });

        var css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("/io/github/calderov/ClipboardHistory/style.css");
        Gtk.StyleContext.add_provider_for_display (
            Gdk.Display.get_default (), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        var quit_action = new SimpleAction ("quit", null);
        quit_action.activate.connect (() => {
            release ();
            quit ();
        });
        add_action (quit_action);
        set_accels_for_action ("app.quit", { "<Control>q" });

        store = new HistoryStore (MAX_ITEMS);
        monitor = new ClipboardMonitor (Gdk.Display.get_default ().get_clipboard ());
        monitor.item_copied.connect (store.add);

        keyboard = new VirtualKeyboard ();

        // Keep monitoring after the window is closed.
        hold ();
    }

    protected override void activate () {
        if (start_in_background) {
            start_in_background = false;
            return;
        }

        // Pressing the shortcut again while the window is open dismisses it.
        if (window != null && window.visible && window.is_active) {
            window.close ();
            return;
        }

        if (window == null) {
            window = new MainWindow (this, store);
            window.item_activated.connect (on_item_activated);
            window.close_request.connect (() => {
                window = null;
                return false;
            });
        }

        window.present ();
        window.reset_view ();
    }

    private void on_item_activated (ClipboardItem item) {
        monitor.restore (item);
        store.promote (item);
        window.close ();

        if (keyboard.available) {
            Timeout.add (PASTE_DELAY_MS, () => {
                keyboard.paste ();
                return Source.REMOVE;
            });
        }
    }

    public static int main (string[] args) {
        // Wayland doesn't let background apps watch the clipboard; XWayland does.
        Environment.set_variable ("GDK_BACKEND", "x11", true);

        return new Application ().run (args);
    }
}
