name: Password manager
id: patch-password-manager
description: KeePassXC GUI vaults with an optional pass or gopass CLI store
dependencies:
version: 1

# Password manager

The patch installs KeePassXC as the opt-in GUI password manager. KeePassXC is
offline, open source, and keeps each vault in a single encrypted `.kdbx` file.
`keepassxc-cli` is installed with the GUI.

The patch does not start a server and does not default to a cloud manager. A
Vaultwarden server, Bitwarden, and Proton Pass are not part of it.

## Install and enable

```sh
ojuny-patches sync
ojuny-patches install patch-password-manager
```

Enable the patch in the settings GUI under Patches, then leave the KeePassXC
switch on. The patch owns the `org.keepassxc.KeePassXC.desktop` entry and sets
it as the default application for `application/x-keepass2`, so `.kdbx` files
open in KeePassXC from the file manager.

## Vault location

The vault is outside the repository by default. The recommended path is:

```
$HOME/vaults/<name>.kdbx
```

Nix does not write that path. Create the vault in KeePassXC and save it there.
The home directory is not tracked by Git, so the vault, its attachments, and
its automatic backups stay out of the flake.

An encrypted `.kdbx` inside tracked files is an explicit backup exception to
`ojuny-template/docs/00-overview.md` section 3 principle 1, not the default.
Use it only for a backup copy. Binary vaults merge and diff poorly, so do not
edit the same tracked vault on several machines.

## Key file

A key file is optional. When the vault uses one, keep it outside the repository
and outside the Nix store. Use an absolute path under `$HOME` or `/var/lib`,
for example:

```
$HOME/.config/keepassxc/<name>.key
/var/lib/ojuny-keepass/<name>.key
```

Set the file mode to `0600`. This matches the `patch-secrets` rule for
`/var/lib/ojuny-age/keys.txt`. Never commit the key with the vault, and never
put the key in the same commit as the vault. A master password alone is also
supported, but the key file adds a second factor that is not stored beside the
vault.

## Split from patch-secrets

The two patches cover different secrets:

- `patch-password-manager` is for user vaults: websites, accounts, recovery
  codes, and other personal credentials that a person opens and edits.
- `patch-secrets` is for system and service secrets: age or sops files that
  are decrypted at boot and installed with an owner, group, and mode for a
  daemon.

Do not merge a password vault into `patch-secrets`. The vault has no system
owner and no boot-time consumer, while a service secret has no interactive
GUI. The `patch-secrets` settings page renders only after the annotation
baseline from `22-other-editors-patches.md` lands: `patch-secrets.nix` still
keeps its annotated options inside `config = lib.mkMerge [...]`, which the
scanner does not read.

## CLI alternative

`ojuny.patch.password-manager.cli` is `none` by default. Set it to `pass` or
`gopass` to install a text- and Git-friendly store:

- `pass` encrypts each entry with GPG and stores it as a file.
- `gopass` adds Git-backed history and team-oriented commands.

They are CLI-first and are not the GUI default. The patch does not configure a
GPG key or a Git remote for either one.

## Browser integration

Browser integration is off by default. When
`ojuny.patch.password-manager.browserIntegration` is on, the patch registers
the `org.keepassxc.keepassxc_browser` native-messaging manifest with Firefox
and Chromium through Home Manager. The KeePassXC package already ships the
manifest under `lib/mozilla/native-messaging-hosts` and
`etc/chromium/native-messaging-hosts`.

The manifest alone is not enough. Install the KeePassXC-Browser extension in
the browser, enable browser integration in KeePassXC, unlock the database, and
restart the browser. The patch does not install the extension and does not
enable browser integration inside a KeePassXC profile.

## Removal

1. Turn the patch off and rebuild.
2. Run `ojuny-patches remove patch-password-manager`.
3. Rebuild again.

The vault and key stay where they are. Removing the patch does not delete
them.
