name: Remote Desktop
id: patch-remote-desktop
description: RustDesk, Waypipe, WayVNC, VNC/RDP clients and a privacy-first session watch
dependencies:
version: 1

## What this patch installs

Remote desktop clients, an optional WayVNC server binary, and an optional
session indicator for the Ojuny desktop bar.

Client options:

- RustDesk
- waypipe for forwarding individual Wayland applications over SSH
- WayVNC, the wlroots VNC server binary
- TigerVNC's `vncviewer` or Remmina
- Optional AnyDesk and TeamViewer clients

The patch does not install an RDP server. The RDP watch only reports an RDP
listener that another module or the user started. Remmina can act as an RDP,
VNC, and SSH client.

WayVNC is a binary, not a NixOS service. Start it inside the graphical session
when you need it. The patch does not start it for you.

## Install and enable

```sh
ojuny-patches sync
ojuny-patches list available
ojuny-patches install patch-remote-desktop
```

Then enable "Remote desktop patch" on the Patches page, or set:

```nix
ojuny.patch.remoteDesktop.enable = true;
```

Installation alone installs nothing. The patch defaults to off.

## Session indicator

The indicator uses three existing desktop surfaces:

- `localServices` for VNC, RDP, extra watches, and the optional broad
  listening-port watch.
- `privacyIndicator` for active microphone, camera, and screen sharing.
- `screenCaptureToolbar` for the recording pill.

Defaults when the patch and the indicator are enabled:

- VNC watch on, port 5900.
- RDP watch on, port 3389.
- Recording pill on.
- Privacy indicator on, active-only.
- Broad listening-port watch off.

The VNC and RDP pills appear only while those TCP ports are listening. They do
not prove that a client is connected. A VNC server can listen with no viewer
attached.

The broad "Listening ports" switch adds one `Ports` pill for other TCP
listeners in ports 1000-9999. It is off by default because a permanent list of
local services is noisy. The pill shows a count, not one pill per port.

The privacy indicator appears only while microphone, camera, or screen sharing
is active. It does not block a device and it does not send a notification. It
is a state display.

The recording pill is a floating screen-capture toolbar overlay. It is not a
bar widget. The privacy indicator's screen-sharing icon is the bar surface for
portal-based screen capture, but it is not a recording state.

## Ports and labels

| Service | TCP port | Default state |
|---|---:|---|
| VNC | 5900 | Watched as `VNC` |
| RDP | 3389 | Watched as `RDP` |
| Other TCP listeners | 1000-9999 | Off by default |
| RustDesk, AnyDesk, TeamViewer | vendor ports | Not watched by default |

The `localServices` plugin only scans listening **TCP** ports in the range
1000-9999. UDP listeners and ports outside that range are not detected.

To watch another service, add a port or range under "Extra port watches". For
example, a RustDesk listener can be added as `21115-21119`. Add a label under
"Extra port labels" with the range's low port as the key.

If a watched port moves, change "VNC port" or "RDP port". The range watch and
label follow the new port.

## Privacy boundary

- Listening is not connected. The VNC and RDP pills mean a server is listening,
  not that someone is connected.
- WayVNC may not register with the screen-cast portal. The privacy indicator may
  not see a WayVNC session. The port watch is the fallback.
- The privacy indicator depends on the desktop portal. A capture path that
  bypasses the portal may not appear.
- RustDesk, AnyDesk, and TeamViewer are not watched by default. Add their
  listening ports if you need them.
- The default does not block, notify, or disconnect anything. It only displays
  state.
- While the indicator is enabled, this patch owns `localServices` and
  `screenCaptureToolbar` plugin settings. Use the Remote Desktop page for port
  watches, ignored ports, labels, refresh interval, favicon lookup, and the
  recording pill. Manual changes to those two plugin settings are overwritten on
  the next rebuild.
- The privacy indicator is added to the default and custom bars only. Other bar
  presets need the widget added through the bar editor.

## Verify

After a rebuild, check the evaluated settings:

```sh
nix eval --json .#nixosConfigurations.<host>.config.desktop.ojuny.dux.plugins.localServices.settings
nix eval --json .#nixosConfigurations.<host>.config.desktop.ojuny.dux.barConfigs.default.rightWidgets
nix eval --raw .#nixosConfigurations.<host>.config.desktop.ojuny.dux.plugins.screenCaptureToolbar.settings.showRecPill
ss -ltnp | grep -E ':(5900|3389)\b'
```

Start WayVNC inside the session:

```sh
wayvnc 127.0.0.1 5900
```

The bar should show `VNC` while the server listens and remove it when the server
stops. Start an RDP server yourself to test the `RDP` label. Start a listener on
another port to test the broad watch:

```sh
nc -l 8080
```

With "Listening ports" off, the broad `Ports` pill should not appear. With it on,
the pill should appear while the listener is active.

## Troubleshooting

- No VNC pill: confirm WayVNC is running in the same user session and
  `ss -ltnp` shows TCP 5900.
- No RDP pill: confirm an RDP server is running and listening on TCP 3389. This
  patch does not install one.
- No privacy indicator: add it to the current bar preset in the bar editor.
  Confirm the session uses the portal for the capture path.
- No recording pill: confirm the screen capture toolbar is enabled and recording
  started.
- A port is missing: confirm it is TCP, between 1000 and 9999, and not listed in
  "Ignored ports".
- A label is missing: labels for ranges use the range's low port as the key.
- A setting reverted: the indicator owns the two plugin settings. Change it on
  the Remote Desktop page, not on the plugin page.

## Data and removal

The patch stores no state. The indicator settings are Nix configuration. Dux
Shell runtime state stays under the user's configuration and state directories.
RustDesk, AnyDesk, TeamViewer, Remmina, and WayVNC keep their own user data.

To remove the patch:

1. Turn off "Session indicator" or the whole patch and rebuild.
2. Run:

```sh
ojuny-patches remove patch-remote-desktop
```

Removing the module while `ojuny.patch.remoteDesktop.*` or
`ojuny.apps.remoteDesktop.*` is still set causes an evaluation error.
Reinstalling overwrites local edits to the installed module.
