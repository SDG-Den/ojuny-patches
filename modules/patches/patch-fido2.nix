/*
  @menu
  displayname = "FIDO2 hardware";
  icon = "security-high-symbolic";
  order = 195;
  description = "FIDO2/U2F security keys for login, sudo, polkit and the lock screen";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }:

{
  flake.modules.nixos.patch-fido2 =
    { config, lib, ... }:
    {
      options.ojuny.patch.fido2.enable = lib.mkEnableOption "FIDO2/U2F hardware authentication";

      # @option widget = "switch"; label = "FIDO2 hardware"; group = "FIDO2 hardware"; description = "Enable FIDO2/U2F security-key authentication and install the ojuny-fido2 helper.";
      config.ojuny.patch.fido2.enable = false;

      imports = [ self.modules.nixos.fido2-backend ];
    };

  flake.modules.nixos.fido2-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      active = config.ojuny.patch.fido2.enable && (config.ojuny.patches or true);
      cfg = config.ojuny.patch.fido2 // {
        enable = active;
      };

      pamModule = "${pkgs.pam_u2f}/lib/security/pam_u2f.so";
      pamPermit = "${pkgs.pam}/lib/security/pam_permit.so";
      pamDeny = "${pkgs.pam}/lib/security/pam_deny.so";

      pamArgs = [
        "authfile=${cfg.authFile}"
        "origin=${cfg.origin}"
        "appid=${cfg.appid}"
      ]
      ++ lib.optional cfg.cue "cue";

      pamArgsText = lib.concatStringsSep " " pamArgs;

      u2fMode = if cfg.control == "required" then "and" else "or";

      fido2 = pkgs.writeShellApplication {
        name = "ojuny-fido2";
        runtimeInputs = with pkgs; [
          coreutils
          gawk
          gnugrep
          libfido2
          pam_u2f
          pamtester
          util-linux
        ];
        text = ''
          set -euo pipefail

          auth_file=${lib.escapeShellArg cfg.authFile}
          origin=${lib.escapeShellArg cfg.origin}
          appid=${lib.escapeShellArg cfg.appid}

          die() { printf 'ojuny-fido2: %s\n' "$*" >&2; exit 1; }

          require_root() {
            [ "$(id -u)" -eq 0 ] || die "run as root: sudo ojuny-fido2 ..."
          }

          check_file() {
            [ -e "$auth_file" ] || die "auth file missing: $auth_file (rebuild first)"
          }

          default_user() {
            printf '%s\n' "''${SUDO_USER:-''${USER:-}}"
          }

          cmd_status() {
            printf 'auth file: %s\n' "$auth_file"
            if [ -e "$auth_file" ]; then
              stat -c 'owner=%U group=%G mode=%a size=%s' "$auth_file"
            else
              printf 'auth file missing\n'
            fi

            printf '\ndevices:\n'
            fido2-token -L 2>/dev/null || true

            printf '\nPAM services:\n'
            for service in login greetd sudo polkit-1 dankshell-u2f; do
              if [ -f "/etc/pam.d/$service" ] && grep -q 'pam_u2f' "/etc/pam.d/$service"; then
                printf '  %-14s wired\n' "$service"
              else
                printf '  %-14s not wired\n' "$service"
              fi
            done
          }

          cmd_list() {
            check_file
            awk -F: '
              NF > 1 {
                count = 0
                for (i = 2; i <= NF; i++) if ($i != "") count++
                printf "%s: %d key(s)\n", $1, count
              }
            ' "$auth_file"
          }

          write_credential() {
            local user="$1"
            local credential="$2"
            local directory
            local temporary

            directory=$(dirname "$auth_file")
            install -d -m 0755 -o root -g root "$directory"
            touch "$auth_file"
            chown root:root "$auth_file"
            chmod 0644 "$auth_file"

            exec 9>"$auth_file.lock"
            flock -x 9

            temporary=$(mktemp "$directory/.fido2.XXXXXX")
            awk -v user="$user" -v credential="$credential" -F: '
              BEGIN { replaced = 0 }
              $1 == user {
                line = $1
                for (i = 2; i <= NF; i++) if ($i != "") line = line ":" $i
                print line ":" credential
                replaced = 1
                next
              }
              { print }
              END { if (!replaced) print user ":" credential }
            ' "$auth_file" > "$temporary"

            chown root:root "$temporary"
            chmod 0644 "$temporary"
            mv -f "$temporary" "$auth_file"
          }

          cmd_enroll() {
            require_root
            local user="''${1:-$(default_user)}"
            local credential

            [ -n "$user" ] || die "no user given and SUDO_USER is empty"
            id "$user" >/dev/null 2>&1 || die "unknown user: $user"
            fido2-token -L 2>/dev/null | grep -q . || die "no FIDO2 device detected"

            printf 'Touch the security key now...\n'
            credential=$(pamu2fcfg -u "$user" -o "$origin" -i "$appid" -n)
            [ -n "$credential" ] || die "enrollment produced no credential"

            write_credential "$user" "$credential"
            printf 'Enrolled %s in %s\n' "$user" "$auth_file"
            printf 'Run: sudo ojuny-fido2 verify login %s\n' "$user"
          }

          cmd_remove() {
            require_root
            check_file
            local user="$1"
            local index="$2"
            local directory
            local temporary
            local count

            [ -n "$user" ] || die "usage: ojuny-fido2 remove USER INDEX"
            [ -n "$index" ] || die "usage: ojuny-fido2 remove USER INDEX"
            case "$index" in
              '''|*[!0-9]*) die "index must be a positive integer" ;;
            esac
            [ "$index" -ge 1 ] || die "index must be a positive integer"
            count=$(awk -F: -v user="$user" '
              $1 == user {
                total = 0
                for (i = 2; i <= NF; i++) if ($i != "") total++
                print total
                found = 1
              }
              END { if (!found) print 0 }
            ' "$auth_file")
            [ "$count" -ge "$index" ] || die "$user has no key $index (has $count)"

            directory=$(dirname "$auth_file")
            exec 9>"$auth_file.lock"
            flock -x 9

            temporary=$(mktemp "$directory/.fido2.XXXXXX")
            awk -F: -v user="$user" -v index="$index" '
              $1 != user { print; next }
              {
                line = $1
                total = 0
                for (i = 2; i <= NF; i++) {
                  if ($i == "") continue
                  total++
                  if (total == index) continue
                  line = line ":" $i
                }
                if (line != $1) print line
              }
            ' "$auth_file" > "$temporary"

            chown root:root "$temporary"
            chmod 0644 "$temporary"
            mv -f "$temporary" "$auth_file"
            printf 'Removed key %s from %s\n' "$index" "$user"
          }

          cmd_verify() {
            local service="''${1:-login}"
            local user="''${2:-$(default_user)}"
            [ -n "$user" ] || die "no user given and SUDO_USER is empty"
            printf 'Verifying %s for %s. Use the key or the password fallback.\n' "$service" "$user"
            pamtester "$service" "$user" authenticate
          }

          cmd_backup() {
            require_root
            check_file
            local destination="''${1:-/root/fido2-$(date +%Y%m%d-%H%M%S)}"
            umask 077
            install -m 0600 "$auth_file" "$destination"
            printf 'Backup written to %s\n' "$destination"
          }

          usage() {
            cat <<'USAGE'
          Usage: ojuny-fido2 <command> [arguments]

            status
            list
            enroll [USER]
            verify [SERVICE] [USER]
            remove USER INDEX
            backup [DESTINATION]
          USAGE
          }

          command="''${1:-}"
          [ "$#" -gt 0 ] && shift || true

          case "$command" in
            status) cmd_status ;;
            list) cmd_list ;;
            enroll) cmd_enroll "''${1:-}" ;;
            verify) cmd_verify "''${1:-login}" "''${2:-}" ;;
            remove) cmd_remove "''${1:-}" "''${2:-}" ;;
            backup) cmd_backup "''${1:-}" ;;
            *) usage; exit 1 ;;
          esac
        '';
      };
    in
    {
      options.ojuny.patch.fido2 = {
        authFile = lib.mkOption {
          type = lib.types.str;
          default = "/etc/fido2/fido2";
          description = "Runtime key mapping file. Must be an absolute path outside the Nix store.";
        };

        origin = lib.mkOption {
          type = lib.types.str;
          default = "pam://ojuny";
          description = "pam_u2f origin and pamu2fcfg relying-party ID.";
        };

        appid = lib.mkOption {
          type = lib.types.str;
          default = "pam://ojuny";
          description = "pam_u2f app ID and pamu2fcfg relying-party name.";
        };

        control = lib.mkOption {
          type = lib.types.enum [
            "sufficient"
            "required"
          ];
          default = "sufficient";
          description = "PAM control for login, greetd, sudo and polkit-1. sufficient keeps password fallback.";
        };

        cue = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Ask pam_u2f to print the touch prompt.";
        };

        services = {
          login = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Wire the login PAM service.";
          };
          greetd = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Wire the greetd PAM service.";
          };
          sudo = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Wire the sudo PAM service.";
          };
          polkit = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Wire the polkit-1 PAM service.";
          };
          lock = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Create the dankshell-u2f PAM service used by DMS.";
          };
        };
      };

      config = lib.mkMerge [
        {
          # @option widget = "text"; label = "Auth file"; group = "Advanced"; advanced = true; visibleWhen.path = "ojuny.patch.fido2.enable"; visibleWhen.equals = true; description = "Runtime key mapping file. Keep the default unless another absolute path is required. This path is never a Nix store path.";
          ojuny.patch.fido2.authFile = "/etc/fido2/fido2";

          # @option widget = "text"; label = "Origin"; group = "Advanced"; advanced = true; visibleWhen.path = "ojuny.patch.fido2.enable"; visibleWhen.equals = true; description = "pam_u2f origin and pamu2fcfg relying-party ID. Enrollment and PAM must use the same value.";
          ojuny.patch.fido2.origin = "pam://ojuny";

          # @option widget = "text"; label = "App ID"; group = "Advanced"; advanced = true; visibleWhen.path = "ojuny.patch.fido2.enable"; visibleWhen.equals = true; description = "pam_u2f app ID and pamu2fcfg relying-party name. Enrollment and PAM must use the same value.";
          ojuny.patch.fido2.appid = "pam://ojuny";

          # @option widget = "dropdown"; label = "PAM control"; group = "PAM services"; advanced = true; choices = [ "sufficient" "required" ]; visibleWhen.path = "ojuny.patch.fido2.enable"; visibleWhen.equals = true; description = "sufficient keeps the password fallback. required makes the key mandatory for login, greetd, sudo and polkit and can lock you out.";
          ojuny.patch.fido2.control = "sufficient";

          # @option widget = "switch"; label = "Touch prompt"; group = "Advanced"; advanced = true; visibleWhen.path = "ojuny.patch.fido2.enable"; visibleWhen.equals = true; description = "Add the pam_u2f cue argument so the user is told to touch the key.";
          ojuny.patch.fido2.cue = true;

          # @option widget = "switch"; label = "Console login"; group = "PAM services"; visibleWhen.path = "ojuny.patch.fido2.enable"; visibleWhen.equals = true; description = "Allow the security key as an alternative to the password for the login PAM service.";
          ojuny.patch.fido2.services.login = true;

          # @option widget = "switch"; label = "Greeter"; group = "PAM services"; visibleWhen.path = "ojuny.patch.fido2.enable"; visibleWhen.equals = true; description = "Allow the security key for the greetd PAM service used by the graphical login.";
          ojuny.patch.fido2.services.greetd = true;

          # @option widget = "switch"; label = "sudo"; group = "PAM services"; visibleWhen.path = "ojuny.patch.fido2.enable"; visibleWhen.equals = true; description = "Allow the security key for sudo. With sufficient control this replaces the password, so keep it off unless that policy is intended.";
          ojuny.patch.fido2.services.sudo = false;

          # @option widget = "switch"; label = "polkit"; group = "PAM services"; visibleWhen.path = "ojuny.patch.fido2.enable"; visibleWhen.equals = true; description = "Allow the security key for polkit-1. With sufficient control this replaces the password, so keep it off unless that policy is intended.";
          ojuny.patch.fido2.services.polkit = false;

          # @option widget = "switch"; label = "Lock screen"; group = "PAM services"; visibleWhen.path = "ojuny.patch.fido2.enable"; visibleWhen.equals = true; description = "Create /etc/pam.d/dankshell-u2f for the DMS lock screen. Also enable the Lock screen Security key switch.";
          ojuny.patch.fido2.services.lock = true;
        }
        (lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = lib.hasPrefix "/" cfg.authFile;
              message = "patch-fido2 authFile must be an absolute runtime path.";
            }
            {
              assertion = cfg.authFile != "/etc/fido2";
              message = "patch-fido2 authFile must name a file, not /etc/fido2.";
            }
            {
              assertion = cfg.origin != "";
              message = "patch-fido2 origin must not be empty.";
            }
            {
              assertion = cfg.appid != "";
              message = "patch-fido2 appid must not be empty.";
            }
            {
              assertion = lib.any (enabled: enabled) (lib.attrValues cfg.services);
              message = "patch-fido2 is enabled but every PAM service switch is off.";
            }
          ];

          warnings = lib.optional (cfg.control == "required") ''
            patch-fido2 uses control = "required" for login, greetd, sudo and polkit.
            A missing or broken key can lock you out. Keep a root shell or a password-capable
            TTY and a backup of ${cfg.authFile} before rebuilding.
          '';

          environment.systemPackages = [
            fido2
            pkgs.pam_u2f
            pkgs.libfido2
            pkgs.pamtester
          ];

          services.udev.packages = [ pkgs.libfido2 ];

          systemd.tmpfiles.rules = [
            "d ${builtins.dirOf cfg.authFile} 0755 root root -"
            "f ${cfg.authFile} 0644 root root -"
          ];

          security.pam.u2f.control = cfg.control;
          security.pam.u2f.settings = {
            authfile = cfg.authFile;
            origin = cfg.origin;
            appid = cfg.appid;
            cue = cfg.cue;
          };

          security.pam.services.login.u2fAuth = lib.mkIf cfg.services.login true;
          security.pam.services.greetd.u2fAuth = lib.mkIf cfg.services.greetd true;
          security.pam.services.sudo.u2fAuth = lib.mkIf cfg.services.sudo true;
          security.pam.services."polkit-1".u2fAuth = lib.mkIf cfg.services.polkit true;

          security.pam.services."dankshell-u2f" = lib.mkIf cfg.services.lock {
            text = ''
              auth     required ${pamModule} ${pamArgsText}
              account  required ${pamPermit}
              password required ${pamDeny}
              session  required ${pamPermit}
            '';
          };

          desktop.ojuny.dms.settings.enableU2f = lib.mkIf cfg.services.lock (lib.mkForce true);
          desktop.ojuny.dms.settings.u2fMode = lib.mkIf cfg.services.lock (lib.mkForce u2fMode);
        })
      ];
    };
}
