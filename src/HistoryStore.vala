public class ClipboardHistory.HistoryStore : Object {
    public uint max_items { get; construct; }

    // Newest item first.
    public ListStore items { get; private set; }

    public HistoryStore (uint max_items) {
        Object (max_items: max_items);
    }

    construct {
        items = new ListStore (typeof (ClipboardItem));
    }

    public void add (ClipboardItem item) {
        for (uint i = 0; i < items.get_n_items (); i++) {
            var existing = (ClipboardItem) items.get_item (i);
            if (existing.fingerprint == item.fingerprint) {
                items.remove (i);
                break;
            }
        }

        items.insert (0, item);

        while (items.get_n_items () > max_items) {
            items.remove (items.get_n_items () - 1);
        }
    }

    public void promote (ClipboardItem item) {
        uint position;
        if (items.find (item, out position) && position > 0) {
            items.remove (position);
            items.insert (0, item);
        }
    }

    public void remove (ClipboardItem item) {
        uint position;
        if (items.find (item, out position)) {
            items.remove (position);
        }
    }

    public void clear () {
        items.remove_all ();
    }
}
