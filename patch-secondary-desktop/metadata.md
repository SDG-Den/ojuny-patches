name: Secondary desktop
id: patch-secondary-desktop
description: Niri or Sway Wayland session installed alongside Mango and DMS
dependencies:
version: 1

## Session

The patch installs one extra Wayland session. It does not change
`services.displayManager.defaultSession`, the Mango session, or DMS settings,
so Ojuny remains the default login.

Niri is the default because the pinned nixpkgs `18dd725c` contains both the
Niri package and its NixOS module. Sway is available through the `desktop`
option as the fallback.

The NixOS session modules register the package in
`services.displayManager.sessionPackages`, which is the path the DMS greeter
scans. After enabling the patch and rebuilding, log out and pick the extra
session in the greeter.

## Configuration

The patch writes a minimal config:

- Niri: `/etc/niri/config.kdl`, used when the user has no
  `~/.config/niri/config.kdl`.
- Sway: `/etc/sway/config`.

Both configs bind `Mod+Return` to `ghostty` and `Mod+D` to the DMS spotlight.
The user can override either config in their home directory.
