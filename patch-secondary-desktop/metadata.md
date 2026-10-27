name: Secondary desktop
id: patch-secondary-desktop
description: Optional KDE Plasma 6, GNOME, XFCE, COSMIC and Cinnamon sessions alongside Mango and DMS
dependencies:
version: 1

## Session

Each desktop is an independent toggle: KDE Plasma 6, GNOME, XFCE, COSMIC, and
Cinnamon. Enable only the sessions you want. The patch does not change the
default login session, so Ojuny remains the default after a rebuild.

The NixOS desktop modules register their sessions in
`services.displayManager.sessionPackages`, which is the path the DMS greeter
scans. Log out and pick the extra session in the greeter after enabling a
desktop.

## Configuration

There is no per-desktop configuration in this patch. Each desktop is installed
and left at its own defaults. Configure it from that desktop's own settings
menu after logging in. Ojuny does not manage those settings declaratively.

XFCE and Cinnamon also enable the X server because their sessions need it.
Plasma, GNOME, and COSMIC use their own Wayland sessions.
