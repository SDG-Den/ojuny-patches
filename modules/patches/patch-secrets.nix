/*
  @menu
  displayname = "Secrets";
  icon = "dialog-password-symbolic";
  order = 210;
  description = "Age or sops secrets decrypted at boot from a user-held key";
  category = "Patches";
  systems = [ "all" ];
*/

/*
  @snippet
  name = "secret";
  label = "Add secret";
  snippet = ''
    # @option widget = "path"; label = "%%name%% encrypted file"; group = "Secrets";
    ojuny.patch.secrets.files."%%name%%".source = ../../secrets/%%name%%.age;
    # @option widget = "text"; label = "%%name%% owner"; group = "Secrets";
    ojuny.patch.secrets.files."%%name%%".owner = "root";
    # @option widget = "text"; label = "%%name%% group"; group = "Secrets";
    ojuny.patch.secrets.files."%%name%%".group = "root";
    # @option widget = "text"; label = "%%name%% mode"; group = "Secrets";
    ojuny.patch.secrets.files."%%name%%".mode = "0400";
  '';
  placeholders.name.label = "Secret name";
  placeholders.name.default = "example";
*/

# @inputs name = "sops-nix"; url = "github:Mic92/sops-nix";

{ self, inputs, ... }:
let
  hasSops = inputs ? sops-nix;
in
{
  flake.modules.nixos."patch-secrets" =
    {
      config,
      lib,
      ...
    }:
    {
      options.ojuny.patch.secrets.enable = lib.mkEnableOption "the age or sops secrets patch";

      # @option widget = "switch"; label = "Secrets"; group = "Secrets"; description = "Enable age-encrypted or sops secrets.";
      config.ojuny.patch.secrets.enable = false;

      imports = lib.optionals hasSops [ inputs.sops-nix.nixosModules.sops ] ++ [
        self.modules.nixos.secrets-backend
      ];
    };

  flake.modules.nixos.secrets-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      active = config.ojuny.patch.secrets.enable && (config.ojuny.patches or true);
      cfg = config.ojuny.patch.secrets // {
        enable = active;
      };

      staging = "/run/ojuny-secrets-staging";

      validName = name: builtins.match "[A-Za-z0-9._-]+" name != null && name != "." && name != "..";
      validMode = mode: builtins.match "0?[0-7]{3}" mode != null;

      decrypt = name: file: ''
        ${pkgs.age}/bin/age --decrypt \
          --identity "$key" \
          --output ${lib.escapeShellArg "${staging}/${name}"} \
          ${lib.escapeShellArg (toString file.source)}
      '';

      installSecret = name: file: ''
        ${pkgs.coreutils}/bin/rm -f ${lib.escapeShellArg "${cfg.destination}/${name}"}
        ${pkgs.coreutils}/bin/install -m ${lib.escapeShellArg file.mode} \
          -o ${lib.escapeShellArg file.owner} \
          -g ${lib.escapeShellArg file.group} \
          ${lib.escapeShellArg "${staging}/${name}"} \
          ${lib.escapeShellArg "${cfg.destination}/${name}"}
      '';

      run = ''
        set -euo pipefail
        umask 077

        key=${lib.escapeShellArg cfg.keyFile}
        destination=${lib.escapeShellArg cfg.destination}

        if [ ! -f "$key" ]; then
          echo "ojuny-secrets: key file not found: $key" >&2
          exit 1
        fi

        key_mode="$(${pkgs.coreutils}/bin/stat -c '%a' "$key")"
        if [ "$key_mode" != "400" ] && [ "$key_mode" != "600" ]; then
          echo "ojuny-secrets: key file must be mode 0400 or 0600, got $key_mode" >&2
          exit 1
        fi

        ${pkgs.coreutils}/bin/rm -rf ${lib.escapeShellArg staging}
        ${pkgs.coreutils}/bin/install -d -m 0700 ${lib.escapeShellArg staging}
        trap "${pkgs.coreutils}/bin/rm -rf ${staging}" EXIT

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList decrypt cfg.files)}

        ${pkgs.coreutils}/bin/install -d -m 0700 "$destination"

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList installSecret cfg.files)}
      '';
    in
    {
      options.ojuny.patch.secrets = {
        backend = lib.mkOption {
          type = lib.types.enum [
            "age"
            "sops"
          ];
          default = "age";
          description = "Secret backend. age decrypts individual files, sops decrypts a sops file with the same age identity.";
        };

        keyFile = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/ojuny-age/keys.txt";
          description = "Absolute path to the age identity file used by the age or sops backend. It must stay outside the flake and outside the Nix store.";
        };

        sopsFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Encrypted sops file in the flake, for example ./secrets.yaml.";
        };

        sopsFormat = lib.mkOption {
          type = lib.types.enum [
            "yaml"
            "json"
            "ini"
            "dotenv"
            "binary"
          ];
          default = "yaml";
          description = "Format of the sops file.";
        };

        sopsSecrets = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                key = lib.mkOption {
                  type = lib.types.str;
                  default = "";
                  description = "Key inside the sops file. Empty uses the secret name.";
                };
                owner = lib.mkOption {
                  type = lib.types.str;
                  default = "root";
                  description = "Owner of the decrypted file.";
                };
                group = lib.mkOption {
                  type = lib.types.str;
                  default = "root";
                  description = "Group of the decrypted file.";
                };
                mode = lib.mkOption {
                  type = lib.types.str;
                  default = "0400";
                  description = "Octal mode of the decrypted file.";
                };
              };
            }
          );
          default = { };
          description = "Named secrets read from the sops file.";
        };

        destination = lib.mkOption {
          type = lib.types.str;
          default = "/run/secrets";
          description = "Runtime directory that receives decrypted files. It is recreated at boot.";
        };

        files = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                source = lib.mkOption {
                  type = lib.types.either lib.types.path lib.types.str;
                  description = "Encrypted .age file in the flake, for example ../../secrets/vpn.age.";
                };
                owner = lib.mkOption {
                  type = lib.types.str;
                  default = "root";
                  description = "Owner of the decrypted file.";
                };
                group = lib.mkOption {
                  type = lib.types.str;
                  default = "root";
                  description = "Group of the decrypted file.";
                };
                mode = lib.mkOption {
                  type = lib.types.str;
                  default = "0400";
                  description = "Octal mode of the decrypted file.";
                };
              };
            }
          );
          default = { };
          description = "Named secrets decrypted before multi-user.target.";
        };
      };

      config = lib.mkMerge [
        {
          # @option widget = "dropdown"; label = "Backend"; group = "Backend"; choices = [ "age" "sops" ]; description = "age decrypts individual files. sops decrypts a sops file with the same age identity.";
          ojuny.patch.secrets.backend = "age";

          # @option widget = "path"; label = "Key file"; group = "Advanced"; hidden = true; description = "Age identity file used by the age or sops backend. It must stay outside the flake and the Nix store.";
          ojuny.patch.secrets.keyFile = "/var/lib/ojuny-age/keys.txt";

          # @option widget = "path"; label = "Sops file"; group = "Sops"; nullable = true; visibleWhen.path = "ojuny.patch.secrets.backend"; visibleWhen.equals = "sops"; description = "Encrypted sops file in the flake, for example ./secrets.yaml.";
          ojuny.patch.secrets.sopsFile = null;

          # @option widget = "dropdown"; label = "Sops format"; group = "Sops"; choices = [ "yaml" "json" "ini" "dotenv" "binary" ]; visibleWhen.path = "ojuny.patch.secrets.backend"; visibleWhen.equals = "sops";
          ojuny.patch.secrets.sopsFormat = "yaml";

          # @option widget = "table-attrset"; label = "Sops secrets"; group = "Sops"; columns = [ "key" "owner" "group" "mode" ]; columnTypes = [ "str" "str" "str" "str" ]; keyEditable = true; description = "Named secrets read from the sops file. The key defaults to the secret name."; visibleWhen.path = "ojuny.patch.secrets.backend"; visibleWhen.equals = "sops";
          ojuny.patch.secrets.sopsSecrets = { };

          # @option widget = "text"; label = "Destination"; group = "Advanced"; hidden = true; description = "Runtime directory for decrypted age files."; visibleWhen.path = "ojuny.patch.secrets.backend"; visibleWhen.equals = "age";
          ojuny.patch.secrets.destination = "/run/secrets";

          # @option widget = "table-attrset"; label = "Secret files"; group = "Secrets"; columns = [ "source" "owner" "group" "mode" ]; columnTypes = [ "str" "str" "str" "str" ]; keyEditable = true; description = "Named age files and their installed permissions."; visibleWhen.path = "ojuny.patch.secrets.backend"; visibleWhen.equals = "age";
          ojuny.patch.secrets.files = { };

          /*
            @insert
            name = "secret";
            group = "Secrets";
            order = 10;
          */
        }
        (lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = lib.hasPrefix "/" cfg.keyFile;
              message = "ojuny.patch.secrets.keyFile must be an absolute path";
            }
            {
              assertion = !lib.hasPrefix "/nix/store/" cfg.keyFile;
              message = "ojuny.patch.secrets.keyFile must not point into the Nix store";
            }
          ];
        })
        (lib.mkIf (cfg.enable && cfg.backend == "age") {
          assertions = [
            {
              assertion = lib.hasPrefix "/" cfg.destination && cfg.destination != "/";
              message = "ojuny.patch.secrets.destination must be an absolute directory other than /";
            }
            {
              assertion = lib.all validName (lib.attrNames cfg.files);
              message = "secret names may contain only A-Z, a-z, 0-9, dot, underscore and dash";
            }
            {
              assertion = lib.all (file: lib.hasPrefix "/" (toString file.source)) (lib.attrValues cfg.files);
              message = "secret source paths must resolve to an absolute path";
            }
            {
              assertion = lib.all (file: validMode file.mode) (lib.attrValues cfg.files);
              message = "secret modes must be three or four octal digits";
            }
          ];

          environment.systemPackages = [ pkgs.age ];

          systemd.services.ojuny-secrets = lib.mkIf (cfg.files != { }) {
            description = "Decrypt age-encrypted secrets";
            wantedBy = [ "multi-user.target" ];
            before = [ "multi-user.target" ];
            after = [ "local-fs.target" ];
            unitConfig.RequiresMountsFor = cfg.keyFile;
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              UMask = "0077";
            };
            script = run;
          };

          systemd.targets.ojuny-secrets = {
            description = "Age secrets are available";
            wantedBy = [ "multi-user.target" ];
            requires = lib.optional (cfg.files != { }) "ojuny-secrets.service";
            after = lib.optional (cfg.files != { }) "ojuny-secrets.service";
          };
        })
        (lib.mkIf (cfg.enable && cfg.backend == "sops") {
          assertions = [
            {
              assertion = hasSops;
              message = "ojuny.patch.secrets backend = \"sops\" requires inputs.sops-nix. Add github:Mic92/sops-nix to the host flake or use backend = \"age\".";
            }
            {
              assertion = cfg.sopsFile != null;
              message = "ojuny.patch.secrets.sopsFile must be set when backend = \"sops\"";
            }
            {
              assertion = lib.all validName (lib.attrNames cfg.sopsSecrets);
              message = "sops secret names may contain only A-Z, a-z, 0-9, dot, underscore and dash";
            }
            {
              assertion = lib.all (secret: validMode secret.mode) (lib.attrValues cfg.sopsSecrets);
              message = "sops secret modes must be three or four octal digits";
            }
          ];
        })
        (lib.mkIf (cfg.enable && cfg.backend == "sops" && hasSops && cfg.sopsFile != null) {
          sops.defaultSopsFile = cfg.sopsFile;
          sops.defaultSopsFormat = cfg.sopsFormat;
          sops.age.keyFile = cfg.keyFile;
          sops.secrets = lib.mapAttrs (name: secret: {
            sopsFile = cfg.sopsFile;
            key = if secret.key != "" then secret.key else name;
            inherit (secret) owner group mode;
          }) cfg.sopsSecrets;
        })
      ];
    };
}
