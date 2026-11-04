# Clipboard History

A Windows-style clipboard history for elementary OS, written in Vala with GTK 4 and Granite.

It runs in the background, remembers the last 25 texts, images and files you copied, and shows them in a
small window when you press a shortcut (Super+V suggested). Click an entry to put it back on the
clipboard, then paste as usual with Ctrl+V.

History is kept in memory only. Nothing is written to disk, and it is gone when you log out.

<img width="2240" height="1400" alt="image" src="https://github.com/user-attachments/assets/e1af1c0a-e42d-4abf-b935-05bb232fa509" />

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
| Copy an entry back to the clipboard | Click it, or select it with the arrow keys and press Enter |
| Remove an entry | ✕ button, or Delete |
| Remove everything | **Clear all** |
| Hide the window | Esc, or click anywhere else |
| Stop the background monitor | Ctrl+Q in the window, or `io.github.calderov.ClipboardHistory --quit` |

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
