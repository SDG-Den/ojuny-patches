# ojuny-patches

Default patch registry for ojuny.

## Layout

Each patch has two paths:

```
modules/patches/<id>.nix
<id>/metadata.md
```

The ID is lowercase, uses single dashes, and starts with `patch-`.

## Metadata

```
name: Development Tools
id: patch-development-tools
description: Command line development tools
dependencies:
version: 1
```

`dependencies` is a comma-separated list of patch IDs.

## Usage

```sh
ojuny-patches repo list
ojuny-patches sync
ojuny-patches list available
ojuny-patches install patch-development-tools
```
