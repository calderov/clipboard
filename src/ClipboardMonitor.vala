/*
 * Watches the system clipboard and reports every new text or image copied.
 *
 * On Wayland only the focused window may read the clipboard, so the app runs
 * through XWayland (see Application.vala). Mutter mirrors the Wayland clipboard
 * to the X11 selection, which GTK can watch while in the background.
 */
public class ClipboardHistory.ClipboardMonitor : Object {
    // Formats file managers use for copied files; they also offer the paths as plain text.
    private const string COPIED_FILES_MIME = "x-special/gnome-copied-files";
    private const string URI_LIST_MIME = "text/uri-list";

    public signal void item_copied (ClipboardItem item);

    public Gdk.Clipboard clipboard { get; construct; }

    // Bumped on every change so a slow read can't report outdated content.
    private uint serial = 0;

    public ClipboardMonitor (Gdk.Clipboard clipboard) {
        Object (clipboard: clipboard);
    }

    construct {
        clipboard.changed.connect (on_changed);
        on_changed ();
    }

    // Puts a history item back on the clipboard.
    public void restore (ClipboardItem item) {
        switch (item.kind) {
            case ItemKind.TEXT:
                clipboard.set_text (item.text);
                break;

            case ItemKind.IMAGE:
                clipboard.set_texture (item.texture);
                break;

            case ItemKind.FILES:
                clipboard.set_content (create_files_provider (item));
                break;
        }
    }

    // Offers files the same way file managers do, so they can be pasted as files again.
    private Gdk.ContentProvider create_files_provider (ClipboardItem item) {
        var copied_files = item.operation + "\n" + string.joinv ("\n", item.uris);
        var uri_list = string.joinv ("\r\n", item.uris) + "\r\n";
        var paths = string.joinv ("\n", item.get_paths ());

        return new Gdk.ContentProvider.union ({
            new Gdk.ContentProvider.for_bytes (COPIED_FILES_MIME, new Bytes (copied_files.data)),
            new Gdk.ContentProvider.for_bytes (URI_LIST_MIME, new Bytes (uri_list.data)),
            new Gdk.ContentProvider.for_bytes ("text/plain;charset=utf-8", new Bytes (paths.data)),
        });
    }

    private void on_changed () {
        serial++;

        // Content we set ourselves via restore () is already in the history.
        if (clipboard.is_local ()) {
            return;
        }

        // union_deserialize_gtypes () consumes its instance, so hand it a reference of its own.
        Gdk.ContentFormats formats = clipboard.formats;
        formats = formats.union_deserialize_gtypes ();
        var has_text = formats.contain_gtype (typeof (string));

        if (formats.contain_mime_type (COPIED_FILES_MIME) || formats.contain_mime_type (URI_LIST_MIME)) {
            read_files.begin (serial, formats.contain_mime_type (COPIED_FILES_MIME), has_text);
        } else if (has_text) {
            read_text.begin (serial);
        } else if (formats.contain_gtype (typeof (Gdk.Texture))) {
            read_texture.begin (serial);
        }
    }

    private async void read_text (uint read_serial) {
        try {
            var text = yield clipboard.read_text_async (null);
            if (read_serial == serial && text != null && text.strip () != "") {
                item_copied (new ClipboardItem.from_text (text));
            }
        } catch (Error e) {
            debug ("Could not read text from clipboard: %s", e.message);
        }
    }

    private async void read_files (uint read_serial, bool has_copied_files, bool has_text) {
        string[] uris = {};
        var operation = "copy";

        try {
            if (has_copied_files) {
                // The operation, then the URIs. GNOME Files puts a line break after the
                // operation ("copy\nfile:///a"), elementary Files doesn't ("copyfile:///a\r\n").
                var data = yield read_string (COPIED_FILES_MIME);
                foreach (var prefix in new string[] { "copy", "cut", "link" }) {
                    if (data.has_prefix (prefix)) {
                        operation = prefix;
                        data = data.substring (prefix.length);
                        break;
                    }
                }
                uris = Uri.list_extract_uris (data);
            } else {
                uris = Uri.list_extract_uris (yield read_string (URI_LIST_MIME));
            }
        } catch (Error e) {
            debug ("Could not read files from clipboard: %s", e.message);
        }

        // A plain URI list may hold web links rather than files; keep those as text.
        var all_local = uris.length > 0;
        foreach (var uri in uris) {
            all_local = all_local && uri.has_prefix ("file://");
        }

        if (all_local) {
            if (read_serial == serial) {
                item_copied (new ClipboardItem.from_files (uris, operation));
            }
        } else if (has_text) {
            yield read_text (read_serial);
        }
    }

    private async string read_string (string mime_type) throws Error {
        unowned string out_mime_type;
        var input = yield clipboard.read_async ({ mime_type }, Priority.DEFAULT, null, out out_mime_type);

        var output = new MemoryOutputStream.resizable ();
        yield output.splice_async (
            input,
            OutputStreamSpliceFlags.CLOSE_SOURCE | OutputStreamSpliceFlags.CLOSE_TARGET,
            Priority.DEFAULT,
            null
        );

        // The data isn't nul-terminated, so copy it by length.
        var bytes = output.steal_as_bytes ();
        var text = new StringBuilder ();
        text.append_len ((string) bytes.get_data (), (ssize_t) bytes.get_size ());
        return text.str;
    }

    private async void read_texture (uint read_serial) {
        try {
            var texture = yield clipboard.read_texture_async (null);
            if (read_serial == serial && texture != null) {
                item_copied (new ClipboardItem.from_texture (texture));
            }
        } catch (Error e) {
            debug ("Could not read image from clipboard: %s", e.message);
        }
    }
}
