name: Zen Browser
id: patch-zen-browser
description: Zen Browser with optional default-browser registration
dependencies:
version: 1

# Zen Browser

Installs Zen Browser and optionally registers it as the default browser. The
Mango browser keybind can point at Zen when `browserBind` is on.

## Install and enable

```sh
ojuny-patches sync
ojuny-patches install patch-zen-browser
```

Then enable Zen Browser on the Patches page.

The patch declares its flake input with:

```nix
# @inputs name = "zen-browser"; url = "github:youwen5/zen-browser-flake";
```

Add it through the Flake Inputs page. The patch reports an evaluation error
when the input is missing.

## Default browser

With `defaultBrowser` on, Zen handles HTML, HTTP, HTTPS, PDF, and mail links.
Turn it off to install Zen without changing the current browser defaults.

## Removal

1. Turn Zen Browser off and rebuild.
2. Run `ojuny-patches remove patch-zen-browser`.
3. Remove the `zen-browser` input if no other patch uses it.
4. Rebuild again.
