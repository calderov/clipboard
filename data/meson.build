resources = gnome.compile_resources(
    'resources',
    'clipboardhistory.gresource.xml',
    source_dir: meson.current_source_dir(),
    c_name: 'clipboardhistory',
)

install_data(
    app_id + '.desktop',
    install_dir: get_option('datadir') / 'applications',
)

# Starts the background monitor at login. Meson only maps sysconfdir to /etc when a
# build directory is first set up with --prefix=/usr, so handle that case explicitly.
if get_option('prefix') == '/usr'
    autostart_dir = '/etc/xdg/autostart'
else
    autostart_dir = get_option('prefix') / get_option('sysconfdir') / 'xdg' / 'autostart'
endif

install_data(
    app_id + '-autostart.desktop',
    install_dir: autostart_dir,
    rename: app_id + '.desktop',
)
