name: Secrets
id: patch-secrets
description: Age or sops secrets in the flake, decrypted at boot with a user-held key
dependencies:
version: 2

# Secrets

The patch supports two backends:

- `age` decrypts one encrypted file per secret into `destination`.
- `sops` decrypts named keys from one sops file with the same age identity.

## Install and enable

```sh
ojuny-patches sync
ojuny-patches install patch-secrets
```

Enable the patch in the settings GUI under Patches, then choose `Backend`.

The age backend needs a key file, normally `/var/lib/ojuny-age/keys.txt`, and a
table of encrypted files. The sops backend needs `inputs.sops-nix`, a sops file,
its format, and the secret names to expose.

The sops input is declared in the patch with:

```nix
# @inputs name = "sops-nix"; url = "github:Mic92/sops-nix";
```

Add it through the Flake Inputs page or the patch reports an evaluation error
when `backend = "sops"`.

## Key file

`keyFile` is the age identity used by both backends. It must be an absolute
path outside the flake and outside the Nix store. The age backend also checks
that the file mode is `0400` or `0600` before decrypting.

## Age backend

`files.<name>.source` is the encrypted `.age` file in the flake. `owner`,
`group`, and `mode` set the installed file. The patch creates a one-shot
`ojuny-secrets` service before `multi-user.target`.

## Sops backend

`sopsFile` is the encrypted sops file in the flake. `sopsFormat` is one of
`yaml`, `json`, `ini`, `dotenv`, or `binary`. `sopsSecrets.<name>` exposes one
key from that file. `key` defaults to the secret name. `owner`, `group`, and
`mode` set the installed file.

The sops file stays encrypted in the Nix store. Decryption happens at boot
through the sops-nix activation path.

## Removal

1. Turn the patch off and rebuild.
2. Run `ojuny-patches remove patch-secrets`.
3. Remove the `@inputs` entry if no other patch uses it.
4. Rebuild again.
