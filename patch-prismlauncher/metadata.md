name: Prism Launcher
id: patch-prismlauncher
description: Prism Launcher with per-instance Java and modloaders for Minecraft
dependencies:
version: 1

## What this patch installs

Prism Launcher for Minecraft. Prism manages separate instances, mods, Java
runtimes, and modloaders inside the launcher. This patch installs the launcher
and controls which Java runtimes it can see. It does not create instances or
download Minecraft.

## Install

```sh
ojuny-patches sync
ojuny-patches list available
ojuny-patches install patch-prismlauncher
```

Then enable "Prism Launcher" on the Patches page, or set:

```nix
ojuny.patch.prismlauncher.enable = true;
```

Rebuild the system and launch Prism from the application menu. Installation
alone does not enable anything; the patch defaults to off.

## Per-instance Java

Prism builds its Java list from `PRISMLAUNCHER_JAVA_PATHS`. The package includes
JDK 8, 17, 21, and 25. To add another runtime, choose it under "Extra Java
runtimes" on the patch page, rebuild, then select it for an instance:

Instance -> Edit -> Settings -> Java -> Java installation.

The selected Java is stored by Prism in the instance's user data, not in Nix.
Changing the patch's Java list does not change existing instances.

## Modloaders

Modloaders are installed by Prism when an instance is created. On the Add
Instance screen, choose Vanilla, Fabric, Forge, NeoForge, or Quilt, then choose
the loader and Minecraft versions. Prism downloads Minecraft, the loader, and
mods from the network. Nix does not package, pin, or update them.

## Microsoft account

Sign in with the Microsoft account that owns Minecraft. The login and ownership
check cannot be automated. By default Prism uses its built-in OAuth client ID.
If that ID does not work for you and you have registered your own Microsoft
identity application, set "Microsoft client ID" on the patch page. That option
rebuilds Prism from source and is only needed for that case.

## Data and removal

Instances, accounts, mods, settings, and Java selections live under
`~/.local/share/PrismLauncher`. They are user data, not Nix state, and are not
deleted when the patch is disabled or removed. Back them up separately.

To remove the patch, disable "Prism Launcher", rebuild, then run:

```sh
ojuny-patches remove patch-prismlauncher
```

Removing the module while `ojuny.patch.prismlauncher.*` is still set causes an
evaluation error. Reinstalling overwrites local edits to the installed module.
