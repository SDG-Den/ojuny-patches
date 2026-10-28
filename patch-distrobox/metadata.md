name: Distrobox
id: patch-distrobox
description: Container-based distro environments backed by Podman
dependencies:
version: 1

## Install

```sh
ojuny-patches sync
ojuny-patches list available
ojuny-patches install patch-distrobox
```

Installation copies the module but enables nothing. The patch defaults to off.

## Enable

Turn on "Distrobox patch" on the Patches page, or set:

```nix
ojuny.patch.distrobox.enable = true;
```

Enabling it turns on Podman, provides a Docker-compatible Podman socket by default, and installs `distrobox`. Turn off "Docker compatibility" to omit the socket. The patch does not enable Docker and does not depend on patch-docker.

Create environments after a rebuild with `distrobox create` and enter them with `distrobox enter`.

## Remove

1. Turn "Distrobox patch" off and rebuild.
2. Run `ojuny-patches remove patch-distrobox`.
3. Rebuild again.

Removing the module while `ojuny.patch.distrobox.*` is still set causes an evaluation error. Containers and images are stored by Podman outside Nix and are not deleted by this patch.
