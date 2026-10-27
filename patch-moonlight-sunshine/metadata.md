name: Moonlight and Sunshine
id: patch-moonlight-sunshine
description: Moonlight client and optional Sunshine streaming host
dependencies:
version: 1

## What this patch installs

Moonlight Qt as a client and, optionally, Sunshine as a streaming host. The
client can connect to a Sunshine host on another machine. The host switch turns
this machine into a Sunshine host for another Moonlight client.

The client and host are independent. A machine can be client-only, host-only,
or both.

## Requirements

- NixOS 26.11 or newer, because the client is installed through the
  `programs.moonlight-qt` module.
- A graphical session on the host. Sunshine is a systemd user service tied to
  `graphical-session.target`.
- For DRM/KMS capture, the default `capSysAdmin` switch must stay on.
- A Moonlight client on the other machine, or on this machine when both
  switches are on.

## Install and enable

```sh
ojuny-patches sync
ojuny-patches list available
ojuny-patches install patch-moonlight-sunshine
```

Then enable "Moonlight and Sunshine" on the Patches page, or set:

```nix
ojuny.patch.moonlight-sunshine.enable = true;
```

Installation alone installs nothing. The patch defaults to off.

## Client setup

1. Enable the patch and keep "Sunshine host" off.
2. Rebuild and launch Moonlight from the application menu.
3. Let Moonlight discover the host on the local network, or choose Add Host and
   enter the host's LAN IP address, Tailscale IP address, or MagicDNS name.
4. Start a stream on the host. Sunshine shows a four-digit PIN.
5. Enter the PIN in Moonlight and accept the pairing on the host.

The client can use a Sunshine host that does not run this patch. The host only
needs Sunshine, its firewall ports, and a graphical session.

## Host setup

1. Enable the patch and turn on "Sunshine host".
2. Leave "Host name" unset to keep Sunshine configurable from the web UI. Set
   it only when you want Nix to own the advertised name.
3. Leave "Base port" at 47989 unless it conflicts with another service.
4. Leave "Open firewall ports" on for a normal LAN or Tailscale host, or turn
   it off and manage the ports yourself. See the firewall section below.
5. Leave "KMS/DRM capture capability" on for the normal DRM/KMS capture path.
6. Rebuild, then log out and back in. Sunshine is a user service, and the
   `uinput` group membership is applied to a new login session, not to the
   session that is already running.
7. Start a graphical session. The Sunshine user service starts automatically.
8. Open `https://localhost:47990` (or base port plus one after a port change)
   and create the Sunshine web UI credentials.
9. Pair Moonlight with the PIN shown by Sunshine.

Check the service:

```sh
systemctl --user status sunshine
```

## Host name and port

Setting a host name or a non-default base port writes
`services.sunshine.settings`. The NixOS module then renders a Sunshine config
file and disables configuration from the Sunshine web UI. This is an upstream
NixOS limitation, not a patch choice.

- Leave "Host name" unset and "Base port" at 47989 to configure Sunshine from
  the web UI.
- Set them when you want the name or port managed by Nix. Change Sunshine's
  other settings in Nix as well after that.
- Changing the port also shifts the firewall ports. With base port P, TCP uses
  P-5, P, P+1, and P+21; UDP uses P+9, P+10, P+11, P+13, and P+21.
- Non-default ports can break automatic discovery. Add the host manually if
  discovery does not find it.

## Firewall and Tailscale

The default `Open firewall ports` switch uses the NixOS Sunshine module. With
base port 47989 it opens:

```text
TCP  47984, 47989, 47990, 48010
UDP  47998, 47999, 48000, 48002, 48010
```

TCP 47990 is the HTTPS admin UI. The switch opens these ports on every
interface, including `tailscale0` when Tailscale is running. Avahi separately
opens UDP 5353 for discovery.

For a stricter setup:

1. Turn off "Open firewall ports" and rebuild.
2. Allow only the Moonlight ports from your LAN ranges or on `tailscale0`.
   Do not expose 47990 to the network.
3. Keep the host on the tailnet and use Tailscale ACLs to limit who can reach
   it.
4. Do not forward Sunshine directly from the public internet.

Omarchy uses this narrower model. This patch documents it but does not
implement it automatically in v1.

## Controller and keyboard input

The host adds every normal user to the `uinput` group. Sunshine needs that
group to create virtual input devices for Moonlight's controller and keyboard
input.

After the first host rebuild, log out and back in, then check:

```sh
id -nG
```

The output should include `uinput`. Restarting only the Sunshine service does
not add the group to the already-running user manager. A full logout or reboot
does.

If input still fails, check `systemctl --user status sunshine`,
`journalctl --user -u sunshine`, and the Sunshine log in the web UI.

## Troubleshooting

- The host does not start: confirm a graphical session is running and check
  `systemctl --user status sunshine`.
- Moonlight cannot find the host: add it by IP address or tailnet name. Check
  that the firewall ports are open.
- Pairing fails: start pairing from Moonlight, then confirm the PIN in the
  Sunshine web UI.
- The stream starts but input does not work: check `id -nG` for `uinput` and
  log out and back in.
- The stream starts but is black: check the Sunshine capture backend, the
  GPU driver, and whether `capSysAdmin` is still on for DRM/KMS capture.
- The web UI cannot change settings: a host name or non-default port is set in
  Nix. Remove it or manage the settings in Nix.

## Data and removal

Sunshine keeps credentials, pairings, and applications under
`~/.config/sunshine/`. Moonlight keeps its own settings under the user's
configuration directory. Neither is Nix state, and neither is deleted when the
patch is disabled or removed.

To remove the patch:

1. Disable "Moonlight and Sunshine" and rebuild.
2. Run:

```sh
ojuny-patches remove patch-moonlight-sunshine
```

Removing the module while `ojuny.patch.moonlight-sunshine.*` is still set causes
an evaluation error. Reinstalling overwrites local edits to the installed
module.
