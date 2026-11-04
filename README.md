# Clipboard History

A Windows-style clipboard history for elementary OS, written in Vala with GTK 4 and Granite.

It runs in the background, remembers the last 25 texts and images you copied, and shows them in a
small window when you press a shortcut (Super+V suggested). Click an entry and it is pasted into
the app you were using (see [Auto-paste](#auto-paste)).

History is kept in memory only. Nothing is written to disk, and it is gone when you log out.

<img width="1068" height="945" alt="image" src="https://github.com/user-attachments/assets/16979f11-6431-4fee-8835-65285ea349a2" />


## Build

Dependencies (elementary OS 8):

```sh
sudo apt install valac meson libgtk-4-dev libgranite-7-dev
```

Build and install:

```sh
meson setup build --prefix=/usr
ninja -C build
sudo ninja -C build install
```

With `--prefix=/usr` the autostart entry goes to `/etc/xdg/autostart`, so the monitor starts on
every login. Log out and back in, or start it now with
`io.github.calderov.ClipboardHistory --background &`.

## Keyboard shortcut

In **System Settings → Keyboard → Shortcuts → Custom**, add a shortcut with the command
`io.github.calderov.ClipboardHistory` and press **Super+V**.

Or from a terminal (this replaces your existing list of custom shortcuts, so only use it if you
have none):

```sh
KEY=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/clipboard-history/
SCHEMA=org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['$KEY']"
gsettings set $SCHEMA name 'Clipboard History'
gsettings set $SCHEMA command 'io.github.calderov.ClipboardHistory'
gsettings set $SCHEMA binding '<Super>v'
```

## Usage

| Action | How |
| --- | --- |
| Open / close the history | Super+V (runs the command again) |
| Paste an entry | Click it, or select it with the arrow keys and press Enter |
| Remove an entry | ✕ button, or Delete |
| Remove everything | **Clear all** |
| Hide the window | Esc, or click anywhere else |
| Stop the background monitor | Ctrl+Q in the window, or `io.github.calderov.ClipboardHistory --quit` |

## Auto-paste

After you pick an entry, the window closes and the app presses Ctrl+V in the app you were using.
It works out which key types "v" in your keyboard layout, so layouts like Dvorak work too.

Wayland doesn't let one app send key presses to another, so the app creates a virtual keyboard
through `/dev/uinput`. That needs write access to `/dev/uinput` for the logged-in user. Check with:

```sh
getfacl /dev/uinput | grep "user:$USER"
```

If that prints nothing (Steam's input rules grant this access, so it may already be set), add a
udev rule and log out and back in:

```sh
echo 'KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput"' \
    | sudo tee /etc/udev/rules.d/60-clipboard-history-uinput.rules
```

This lets programs you run create virtual input devices while you're logged in. Without that
access the app still works: picking an entry only copies it, and you paste with Ctrl+V yourself.

Terminals usually paste with Ctrl+Shift+V. Elementary Terminal accepts Ctrl+V while its "natural
copy/paste" setting is on, which is the default.

## Running from the build directory

```sh
./build/src/io.github.calderov.ClipboardHistory --background &   # start monitoring
./build/src/io.github.calderov.ClipboardHistory                  # show the window
```

## Why it uses XWayland

On Wayland only the focused window may read the clipboard, and elementary's compositor doesn't
offer the protocol other clipboard managers use (`wl-paste --watch` doesn't work). So the app sets
`GDK_BACKEND=x11` and runs through XWayland. The compositor mirrors the clipboard between Wayland
and X11, and X11 apps can watch it in the background. Copying and pasting still work across all
apps.
