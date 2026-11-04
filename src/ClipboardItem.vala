public enum ClipboardHistory.ItemKind {
    TEXT,
    IMAGE,
    FILES
}

public class ClipboardHistory.ClipboardItem : Object {
    // Longer texts are cut down for display; the full text is kept for pasting.
    private const int PREVIEW_LENGTH = 400;
    private const int PREVIEW_LINES = 3;

    public ItemKind kind { get; construct; }
    public string? text { get; construct; }
    public Gdk.Texture? texture { get; construct; }

    // Files copied in a file manager, as file:// URIs, and what pasting should do
    // with them: "copy", "cut" (move) or "link".
    public string[]? uris { get; construct; }
    public string? operation { get; construct; }

    // Identifies the content so the same thing copied twice shows up only once.
    public string fingerprint { get; private set; }

    public ClipboardItem.from_text (string text) {
        Object (kind: ItemKind.TEXT, text: text);
    }

    public ClipboardItem.from_texture (Gdk.Texture texture) {
        Object (kind: ItemKind.IMAGE, texture: texture);
    }

    public ClipboardItem.from_files (string[] uris, string operation) {
        Object (kind: ItemKind.FILES, uris: uris, operation: operation);
    }

    construct {
        switch (kind) {
            case ItemKind.TEXT:
                fingerprint = "text:" + Checksum.compute_for_string (ChecksumType.SHA1, text);
                break;

            case ItemKind.IMAGE:
                var png = texture.save_to_png_bytes ();
                fingerprint = "image:" + Checksum.compute_for_bytes (ChecksumType.SHA1, png);
                break;

            case ItemKind.FILES:
                var files = operation + "\n" + string.joinv ("\n", uris);
                fingerprint = "files:" + Checksum.compute_for_string (ChecksumType.SHA1, files);
                break;
        }
    }

    // Local paths of the copied files, or the URI where there is no local path.
    public string[] get_paths () {
        string[] paths = {};
        foreach (var uri in uris) {
            paths += File.new_for_uri (uri).get_path () ?? uri;
        }
        return paths;
    }

    // Labels limit wrapped lines per paragraph, so line breaks are capped here.
    public string get_preview () {
        var preview = text.strip ();
        var truncated = false;

        var lines = preview.split ("\n", PREVIEW_LINES + 1);
        if (lines.length > PREVIEW_LINES) {
            preview = string.joinv ("\n", lines[0:PREVIEW_LINES]);
            truncated = true;
        }

        if (preview.char_count () > PREVIEW_LENGTH) {
            preview = preview.substring (0, preview.index_of_nth_char (PREVIEW_LENGTH));
            truncated = true;
        }

        return truncated ? preview + " …" : preview;
    }
}
