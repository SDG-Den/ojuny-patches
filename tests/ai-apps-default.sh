#!/usr/bin/env bash
# Regression check for ojuny-docs/canon/10-ai-policy.md D15 and D22.
#
# Evaluates a fixture that imports patch-ai-apps with its defaults and asserts
# that no hosted AI package and no AI web app is present. Requires nix. This
# script is meant to be run from a machine that can fetch the fixture inputs.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cp -r "$repo_root/modules" "$tmp/modules"

cat > "$tmp/webapps-stub.nix" <<'EOF'
{ lib, ... }:
{
  options.programs.chromium-webapps = {
    enable = lib.mkEnableOption "chromium web apps";
    webApps = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [ ];
    };
  };
}
EOF

cat > "$tmp/home.nix" <<'EOF'
{ ... }:
{
  imports = [ ./webapps-stub.nix ];
  home.stateVersion = "25.05";
}
EOF

cat > "$tmp/flake.nix" <<'EOF'
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      imports = [ ./modules/patches/patch-ai-apps.nix ];

      flake.nixosConfigurations.fixture = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          inputs.home-manager.nixosModules.home-manager
          inputs.self.modules.nixos.patch-ai-apps
          ({ ... }: {
            system.stateVersion = "25.05";
            home-manager.users.fixture = import ./home.nix;
          })
        ];
      };
    };
}
EOF

flake="path:$tmp"

enabled="$(nix eval --raw "$flake#nixosConfigurations.fixture.config.ojuny.patch.ai-apps.enable")"
if [[ "$enabled" != "false" ]]; then
  printf 'FAIL: patch-ai-apps enable defaults to %s, expected false\n' "$enabled" >&2
  exit 1
fi

packages="$(nix eval --json \
  --apply 'ps: map (p: p.name or "") ps' \
  "$flake#nixosConfigurations.fixture.config.environment.systemPackages")"

for package in chatgpt t3code openclaw lmstudio; do
  if grep -q "\"$package\"" <<<"$packages"; then
    printf 'FAIL: %s is installed with patch-ai-apps defaults\n' "$package" >&2
    exit 1
  fi
done

webapps="$(nix eval --json "$flake#nixosConfigurations.fixture.config.home-manager.users.fixture.programs.chromium-webapps.webApps")"
if [[ "$webapps" != "[]" ]]; then
  printf 'FAIL: programs.chromium-webapps.webApps is %s, expected []\n' "$webapps" >&2
  exit 1
fi

printf 'ok: patch-ai-apps defaults install no hosted AI package and no AI web app\n'
