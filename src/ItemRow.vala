public class ClipboardHistory.ItemRow : Gtk.ListBoxRow {
    public signal void remove_requested ();

    public ClipboardItem item { get; construct; }

    public ItemRow (ClipboardItem item) {
        Object (item: item);
    }

    construct {
        add_css_class ("clipboard-item");
        add_css_class (Granite.CssClass.CARD);

        Gtk.Widget content;
        switch (item.kind) {
            case ItemKind.TEXT:
                content = new Gtk.Label (item.get_preview ()) {
                    wrap = true,
                    wrap_mode = Pango.WrapMode.WORD_CHAR,
                    lines = 3,
                    ellipsize = Pango.EllipsizeMode.END,
                    xalign = 0,
                    valign = Gtk.Align.START,
                };
                break;

            case ItemKind.IMAGE:
                content = new Thumbnail (item.texture) {
                    halign = Gtk.Align.START,
                };
                break;

            default:
                content = create_files_content ();
                break;
        }
        content.hexpand = true;

        var remove_button = new Gtk.Button.from_icon_name ("window-close-symbolic") {
            valign = Gtk.Align.START,
            tooltip_text = "Remove from history",
        };
        remove_button.add_css_class (Granite.STYLE_CLASS_FLAT);
        remove_button.clicked.connect (() => remove_requested ());

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        box.append (content);
        box.append (remove_button);

        child = box;
    }

    // File icon, then the file name (or count) above where it is, like a file manager list.
    private Gtk.Widget create_files_content () {
        var paths = item.get_paths ();
        var first_path = paths[0];

        string title;
        string subtitle;
        if (paths.length == 1) {
            title = Filename.display_basename (first_path);
            subtitle = Filename.display_name (Path.get_dirname (first_path));
        } else {
            title = "%d files".printf (paths.length);

            string[] names = {};
            foreach (var path in paths) {
                names += Filename.display_basename (path);
            }
            subtitle = string.joinv (", ", names);
        }

        if (item.operation == "cut") {
            subtitle = "Cut · " + subtitle;
        } else if (item.operation == "link") {
            subtitle = "Link · " + subtitle;
        }

        var icon = new Gtk.Image.from_gicon (get_file_icon (first_path)) {
            pixel_size = 32,
            valign = Gtk.Align.START,
        };

        var title_label = new Gtk.Label (title) {
            ellipsize = Pango.EllipsizeMode.MIDDLE,
            xalign = 0,
        };

        var subtitle_label = new Gtk.Label (subtitle) {
            ellipsize = Pango.EllipsizeMode.END,
            xalign = 0,
        };
        subtitle_label.add_css_class (Granite.CssClass.DIM);
        subtitle_label.add_css_class (Granite.CssClass.SMALL);

        var labels = new Gtk.Box (Gtk.Orientation.VERTICAL, 2) {
            valign = Gtk.Align.CENTER,
        };
        labels.append (title_label);
        labels.append (subtitle_label);

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        box.append (icon);
        box.append (labels);
        return box;
    }

    private static Icon get_file_icon (string path) {
        if (FileUtils.test (path, FileTest.IS_DIR)) {
            return new ThemedIcon ("folder");
        }

        var content_type = ContentType.guess (path, null, null);
        return ContentType.get_icon (content_type);
    }
}

// Draws an image scaled down to a fixed thumbnail size, keeping its aspect ratio.
public class ClipboardHistory.Thumbnail : Gtk.Widget {
    private const int MAX_HEIGHT = 64;
    private const int MAX_WIDTH = 260;

    public Gdk.Paintable paintable { get; construct; }

    private int thumb_width;
    private int thumb_height;

    public Thumbnail (Gdk.Paintable paintable) {
        Object (paintable: paintable);
    }

    construct {
        add_css_class ("thumbnail");
        overflow = Gtk.Overflow.HIDDEN;

        double width = int.max (paintable.get_intrinsic_width (), 1);
        double height = int.max (paintable.get_intrinsic_height (), 1);
        double scale = double.min (1.0, double.min (MAX_HEIGHT / height, MAX_WIDTH / width));

        thumb_width = int.max ((int) (width * scale), 1);
        thumb_height = int.max ((int) (height * scale), 1);
    }

    public override Gtk.SizeRequestMode get_request_mode () {
        return Gtk.SizeRequestMode.CONSTANT_SIZE;
    }

    public override void measure (Gtk.Orientation orientation, int for_size, out int minimum, out int natural, out int minimum_baseline, out int natural_baseline) {
        minimum = natural = orientation == Gtk.Orientation.HORIZONTAL ? thumb_width : thumb_height;
        minimum_baseline = natural_baseline = -1;
    }

    public override void snapshot (Gtk.Snapshot snapshot) {
        paintable.snapshot (snapshot, get_width (), get_height ());
    }
}
