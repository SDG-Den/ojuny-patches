name: Custom Fastfetch
id: patch-custom-fastfetch
description: Fully configurable fastfetch settings through a raw GUI option
dependencies:
version: 1

# Custom Fastfetch

Replaces the template fastfetch settings with a complete value edited through
the raw GUI field. An empty value keeps the template defaults.

## Install and enable

```sh
ojuny-patches sync
ojuny-patches install patch-custom-fastfetch
```

Then enable Custom Fastfetch on the Patches page and fill the Fastfetch
settings field with the complete `programs.fastfetch.settings` value.

## Settings format

The field takes a Nix attrset, for example:

```nix
{
  logo.source = "nixos";
  modules = [ "title" "os" "kernel" "uptime" ];
}
```

A non-empty value replaces the template settings. Leave it empty to keep the
template layout, colors, and logo.

## Removal

1. Clear the Fastfetch settings field and turn Custom Fastfetch off, then rebuild.
2. Run `ojuny-patches remove patch-custom-fastfetch`.
3. Rebuild again.
