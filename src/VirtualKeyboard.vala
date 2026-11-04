/*
 * Presses keys in whatever window has focus, through a virtual keyboard (/dev/uinput).
 *
 * Wayland gives apps no way to send key presses to other windows, and XWayland's
 * fake input only reaches X11 apps. The compositor treats a uinput device like a
 * real keyboard, so this works everywhere. It needs write access to /dev/uinput,
 * which a udev "uaccess" rule grants to the logged-in user (see README.md).
 */
public class ClipboardHistory.VirtualKeyboard : Object {
    private const string DEVICE_NAME = "Clipboard History virtual keyboard";

    // Evdev keycodes are offset by 8 from X11 keycodes.
    private const uint X11_KEYCODE_OFFSET = 8;

    private int fd = -1;

    public bool available {
        get { return fd >= 0; }
    }

    construct {
        fd = Posix.open ("/dev/uinput", Posix.O_WRONLY | Posix.O_NONBLOCK | Posix.O_CLOEXEC);
        if (fd < 0) {
            warning ("Auto-paste is off: can't open /dev/uinput: %s", strerror (errno));
            return;
        }

        // Created once at startup: the compositor needs a moment to pick up a new device.
        if (!create_device ()) {
            warning ("Auto-paste is off: can't create a virtual keyboard: %s", strerror (errno));
            Posix.close (fd);
            fd = -1;
        }
    }

    ~VirtualKeyboard () {
        if (fd >= 0) {
            Posix.ioctl (fd, Linux.UserspaceInput.UI_DEV_DESTROY);
            Posix.close (fd);
        }
    }

    // Presses Ctrl+V, using whichever key types "v" in the current keyboard layout.
    public void paste () {
        press_keys ({ Linux.Input.KEY_LEFTCTRL, find_key (Gdk.Key.v, Linux.Input.KEY_V) });
    }

    private bool create_device () {
        if (Posix.ioctl (fd, Linux.UserspaceInput.UI_SET_EVBIT, Linux.Input.EV_KEY) < 0) {
            return false;
        }

        // Any key the layout lookup might pick, so the device can type it.
        for (int key = Linux.Input.KEY_ESC; key <= Linux.Input.KEY_MICMUTE; key++) {
            if (Posix.ioctl (fd, Linux.UserspaceInput.UI_SET_KEYBIT, key) < 0) {
                return false;
            }
        }

        var setup = Linux.UserspaceInput.UserSetup ();
        setup.id.bustype = (uint16) Linux.Input.BUS_VIRTUAL;
        // Byte by byte: Memory.copy () on a struct's array field writes to a temporary copy.
        for (int i = 0; i < DEVICE_NAME.length; i++) {
            setup.name[i] = DEVICE_NAME[i];
        }

        return Posix.ioctl (fd, Linux.UserspaceInput.UI_DEV_SETUP, &setup) >= 0
            && Posix.ioctl (fd, Linux.UserspaceInput.UI_DEV_CREATE) >= 0;
    }

    // Looks up the physical key for a symbol in the first layout, like the compositor will.
    private static int find_key (uint keyval, int fallback) {
        Gdk.KeymapKey[] keys;
        if (Gdk.Display.get_default ().map_keyval (keyval, out keys)) {
            foreach (var key in keys) {
                if (key.group == 0 && key.level == 0) {
                    return (int) (key.keycode - X11_KEYCODE_OFFSET);
                }
            }
        }
        return fallback;
    }

    // Presses the keys in order, then releases them in reverse, like a person would.
    private void press_keys (int[] keys) {
        foreach (var key in keys) {
            send (Linux.Input.EV_KEY, key, 1);
        }
        for (int i = keys.length - 1; i >= 0; i--) {
            send (Linux.Input.EV_KEY, keys[i], 0);
        }
    }

    private void send (uint16 type, int code, int32 value) {
        var event = Linux.Input.Event () {
            type = type,
            code = (uint16) code,
            value = value,
        };
        var report = Linux.Input.Event () {
            type = Linux.Input.EV_SYN,
            code = (uint16) Linux.Input.SYN_REPORT,
            value = 0,
        };

        if (Posix.write (fd, &event, sizeof (Linux.Input.Event)) < 0
            || Posix.write (fd, &report, sizeof (Linux.Input.Event)) < 0) {
            warning ("Could not send a key press: %s", strerror (errno));
        }
    }
}
