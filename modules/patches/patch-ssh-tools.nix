/*
  @menu
  displayname = "SSH tools";
  icon = "network-server-symbolic";
  order = 55;
  description = "Graphical SSH server, client hosts and forwarding helpers";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }:

{
  flake.modules.nixos.patch-ssh-tools =
    {
      config,
      lib,
      ...
    }:
    {
      options.ojuny.patch.ssh-tools.enable = lib.mkEnableOption "the SSH tools patch";

      imports = [ self.modules.nixos.ssh-tools-backend ];

      config = {
        # @option widget = "switch"; label = "SSH tools"; group = "SSH tools"; groupOrder = 10; order = 10; description = "Install SSH server and client configuration and helpers.";
        ojuny.patch.ssh-tools.enable = false;

        # @option widget = "switch"; label = "SSH server"; group = "Server"; groupOrder = 20; order = 10; description = "Run sshd. Off by default; enabling it exposes a network service."; visibleWhen.path = "ojuny.patch.ssh-tools.enable"; visibleWhen.equals = true;
        ojuny.patch.ssh-tools.server.enable = false;

        # @option widget = "spin"; label = "Port"; group = "Server"; groupOrder = 20; order = 20; min = 1; max = 65535; description = "TCP port sshd listens on."; visibleWhen.path = "ojuny.patch.ssh-tools.server.enable"; visibleWhen.equals = true;
        ojuny.patch.ssh-tools.server.port = 22;

        # @option widget = "switch"; label = "Open firewall"; group = "Server"; groupOrder = 20; order = 30; description = "Open the selected TCP port in the firewall. This exposes the server beyond localhost."; visibleWhen.path = "ojuny.patch.ssh-tools.server.enable"; visibleWhen.equals = true;
        ojuny.patch.ssh-tools.server.openFirewall = false;

        # @option widget = "switch"; label = "Password login"; group = "Server"; groupOrder = 20; order = 40; advanced = true; description = "Allow password authentication. Keep this off when keys are available."; visibleWhen.path = "ojuny.patch.ssh-tools.server.enable"; visibleWhen.equals = true;
        ojuny.patch.ssh-tools.server.passwordAuthentication = false;

        # @option widget = "dropdown"; label = "Root login"; group = "Server"; groupOrder = 20; order = 50; choices = [ "no" "prohibit-password" "yes" ]; description = "PermitRootLogin value. no is the safe default."; visibleWhen.path = "ojuny.patch.ssh-tools.server.enable"; visibleWhen.equals = true;
        ojuny.patch.ssh-tools.server.permitRootLogin = "no";

        # @option widget = "switch"; label = "TCP forwarding"; group = "Server"; groupOrder = 20; order = 60; advanced = true; description = "Allow remote TCP forwarding through the server."; visibleWhen.path = "ojuny.patch.ssh-tools.server.enable"; visibleWhen.equals = true;
        ojuny.patch.ssh-tools.server.allowTcpForwarding = false;

        # @option widget = "switch"; label = "Agent forwarding"; group = "Server"; groupOrder = 20; order = 70; advanced = true; description = "Allow clients to forward their SSH agent to the server."; visibleWhen.path = "ojuny.patch.ssh-tools.server.enable"; visibleWhen.equals = true;
        ojuny.patch.ssh-tools.server.allowAgentForwarding = false;

        # @option widget = "list"; label = "Allowed groups"; group = "Server"; groupOrder = 20; order = 80; advanced = true; description = "Groups allowed to log in. Empty allows all groups."; visibleWhen.path = "ojuny.patch.ssh-tools.server.enable"; visibleWhen.equals = true;
        ojuny.patch.ssh-tools.server.allowGroups = [ ];

        # @option widget = "switch"; label = "Use DNS"; group = "Server"; groupOrder = 20; order = 90; advanced = true; description = "Look up client host names with DNS."; visibleWhen.path = "ojuny.patch.ssh-tools.server.enable"; visibleWhen.equals = true;
        ojuny.patch.ssh-tools.server.useDns = true;

        # @option widget = "switch"; label = "X11 forwarding"; group = "Server"; groupOrder = 20; order = 100; advanced = true; description = "Allow X11 forwarding."; visibleWhen.path = "ojuny.patch.ssh-tools.server.enable"; visibleWhen.equals = true;
        ojuny.patch.ssh-tools.server.x11Forwarding = true;

        # @option widget = "switch"; label = "SFTP"; group = "Server"; groupOrder = 20; order = 110; description = "Allow SFTP subsystem access."; visibleWhen.path = "ojuny.patch.ssh-tools.server.enable"; visibleWhen.equals = true;
        ojuny.patch.ssh-tools.server.allowSftp = true;

        # @option widget = "switch"; label = "Keyboard-interactive login"; group = "Server"; groupOrder = 20; order = 120; advanced = true; description = "Allow keyboard-interactive authentication."; visibleWhen.path = "ojuny.patch.ssh-tools.server.enable"; visibleWhen.equals = true;
        ojuny.patch.ssh-tools.server.kbdInteractiveAuthentication = false;

        # @option widget = "table-list"; label = "Authorized keys"; group = "Keys"; groupOrder = 30; order = 10; columns = [ "user" "key" ]; columnTypes = [ "str" "str" ]; description = "Public keys added to each user's authorized_keys. The User page list remains additive."; visibleWhen.path = "ojuny.patch.ssh-tools.enable"; visibleWhen.equals = true;
        ojuny.patch.ssh-tools.authorizedKeys = [ ];

        # @option widget = "table-list"; label = "Client hosts"; group = "Client"; groupOrder = 40; order = 10; columns = [ "alias" "hostName" "user" "port" "identityFile" "proxyJump" "forwardAgent" ]; columnTypes = [ "str" "str" "str" "int" "str" "str" "bool" ]; description = "Host aliases written to /etc/ssh/ssh_config. IdentityFile is a path to your existing private key; the patch never stores key material."; visibleWhen.path = "ojuny.patch.ssh-tools.enable"; visibleWhen.equals = true;
        ojuny.patch.ssh-tools.hosts = [ ];

        # @option widget = "table-list"; label = "Known hosts"; group = "Client"; groupOrder = 40; order = 20; advanced = true; columns = [ "hostName" "publicKey" ]; columnTypes = [ "str" "str" ]; description = "Optional system-wide host public keys. Use ssh-keyscan to obtain them."; visibleWhen.path = "ojuny.patch.ssh-tools.enable"; visibleWhen.equals = true;
        ojuny.patch.ssh-tools.knownHosts = [ ];

        # @option widget = "switch"; label = "Forwarding helpers"; group = "Helpers"; groupOrder = 50; order = 10; description = "Install fip, dip and lip, backed by PID files instead of pattern-based process matching."; visibleWhen.path = "ojuny.patch.ssh-tools.enable"; visibleWhen.equals = true;
        ojuny.patch.ssh-tools.forwardingHelpers = true;

        # @option widget = "switch"; label = "Keepalive defaults"; group = "Helpers"; groupOrder = 50; order = 20; description = "Set ServerAliveInterval, ServerAliveCountMax and ConnectTimeout for all hosts."; visibleWhen.path = "ojuny.patch.ssh-tools.enable"; visibleWhen.equals = true;
        ojuny.patch.ssh-tools.keepalive = true;
      };
    };

  flake.modules.nixos.ssh-tools-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      active = config.ojuny.patch.ssh-tools.enable && (config.ojuny.patches or true);
      cfg = config.ojuny.patch.ssh-tools // {
        enable = active;
      };

      forwardHelper = pkgs.writeShellApplication {
        name = "ojuny-ssh-forward";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.openssh
        ];
        text = ''
          set -eu
          state="''${XDG_RUNTIME_DIR:-$HOME/.cache}/ojuny-ssh-forward"
          mkdir -p "$state"
          chmod 700 "$state"
          cmd="''${1:-}"
          shift || true
          case "$cmd" in
            start)
              host="''${1:?usage: ojuny-ssh-forward start <host> <port>...}"
              shift
              [ "$#" -gt 0 ] || {
                echo "usage: ojuny-ssh-forward start <host> <port>..." >&2
                exit 2
              }
              for port in "$@"; do
                slug="$(printf '%s' "$host" | tr -c 'A-Za-z0-9_.@-' '_')"
                pidfile="$state/$slug-$port.pid"
                if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
                  echo "already forwarding localhost:$port -> $host:$port"
                  continue
                fi
                nohup ssh -N -o ExitOnForwardFailure=yes \
                  -L "$port:localhost:$port" "$host" \
                  </dev/null >/dev/null 2>&1 &
                echo "$!" >"$pidfile"
                echo "forwarding localhost:$port -> $host:$port"
              done
              ;;
            stop)
              [ "$#" -gt 0 ] || {
                echo "usage: ojuny-ssh-forward stop <port>..." >&2
                exit 2
              }
              for port in "$@"; do
                stopped=0
                for pidfile in "$state"/*-"$port".pid; do
                  [ -f "$pidfile" ] || continue
                  pid="$(cat "$pidfile")"
                  if [ "$(cat "/proc/$pid/comm" 2>/dev/null)" = "ssh" ]; then
                    kill "$pid"
                    stopped=1
                  fi
                  rm -f "$pidfile"
                done
                [ "$stopped" -eq 1 ] && echo "stopped port $port" || echo "no forward on port $port"
              done
              ;;
            list)
              found=0
              for pidfile in "$state"/*.pid; do
                [ -f "$pidfile" ] || continue
                pid="$(cat "$pidfile")"
                if [ "$(cat "/proc/$pid/comm" 2>/dev/null)" = "ssh" ]; then
                  printf '%s pid %s\n' "$(basename "$pidfile" .pid)" "$pid"
                  found=1
                else
                  rm -f "$pidfile"
                fi
              done
              [ "$found" -eq 1 ] || echo "no active forwards"
              ;;
            *)
              echo "usage: ojuny-ssh-forward start <host> <port>... | stop <port>... | list" >&2
              exit 2
              ;;
          esac
        '';
      };
    in
    {
      options.ojuny.patch.ssh-tools = {
        server = {
          enable = lib.mkEnableOption "the OpenSSH server";
          port = lib.mkOption {
            type = lib.types.port;
            default = 22;
            description = "TCP port sshd listens on.";
          };
          openFirewall = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Open the SSH port in the firewall.";
          };
          passwordAuthentication = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Allow password authentication.";
          };
          permitRootLogin = lib.mkOption {
            type = lib.types.enum [
              "no"
              "prohibit-password"
              "yes"
            ];
            default = "no";
            description = "PermitRootLogin value.";
          };
          allowTcpForwarding = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Allow server-side TCP forwarding.";
          };
          allowAgentForwarding = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Allow server-side agent forwarding.";
          };
          allowGroups = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Groups allowed to log in. Empty allows all groups.";
          };
          useDns = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Look up client host names with DNS.";
          };
          x11Forwarding = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Allow X11 forwarding.";
          };
          allowSftp = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Allow SFTP subsystem access.";
          };
          kbdInteractiveAuthentication = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Allow keyboard-interactive authentication.";
          };
        };

        authorizedKeys = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                user = lib.mkOption { type = lib.types.nonEmptyStr; };
                key = lib.mkOption { type = lib.types.nonEmptyStr; };
              };
            }
          );
          default = [ ];
          description = "Public keys added to each user's authorized_keys.";
        };

        hosts = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                alias = lib.mkOption { type = lib.types.nonEmptyStr; };
                hostName = lib.mkOption { type = lib.types.nonEmptyStr; };
                user = lib.mkOption {
                  type = lib.types.str;
                  default = "";
                };
                port = lib.mkOption {
                  type = lib.types.port;
                  default = 22;
                };
                identityFile = lib.mkOption {
                  type = lib.types.str;
                  default = "";
                };
                proxyJump = lib.mkOption {
                  type = lib.types.str;
                  default = "";
                };
                forwardAgent = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                };
              };
            }
          );
          default = [ ];
          description = "Client host aliases written through programs.ssh.hosts.";
        };

        knownHosts = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                hostName = lib.mkOption { type = lib.types.nonEmptyStr; };
                publicKey = lib.mkOption { type = lib.types.nonEmptyStr; };
              };
            }
          );
          default = [ ];
          description = "Optional system-wide known host public keys.";
        };

        forwardingHelpers = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install fip, dip, and lip.";
        };

        keepalive = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install global SSH keepalive defaults.";
        };
      };

      config = lib.mkIf cfg.enable {
          services.openssh = lib.mkIf cfg.server.enable {
            enable = true;
            ports = [ cfg.server.port ];
            openFirewall = cfg.server.openFirewall;
            allowSFTP = cfg.server.allowSftp;
            settings = {
              PasswordAuthentication = cfg.server.passwordAuthentication;
              KbdInteractiveAuthentication = cfg.server.kbdInteractiveAuthentication;
              PermitRootLogin = cfg.server.permitRootLogin;
              PubkeyAuthentication = true;
              UseDns = cfg.server.useDns;
              X11Forwarding = cfg.server.x11Forwarding;
              AllowTcpForwarding = cfg.server.allowTcpForwarding;
              AllowAgentForwarding = cfg.server.allowAgentForwarding;
            }
            // lib.optionalAttrs (cfg.server.allowGroups != [ ]) {
              AllowGroups = cfg.server.allowGroups;
            };
          };

          users.users = lib.mkMerge (
            map (entry: {
              ${entry.user}.openssh.authorizedKeys.keys = [ entry.key ];
            }) cfg.authorizedKeys
          );

          programs.ssh.hosts = lib.listToAttrs (
            lib.imap1 (index: host: {
              name = host.alias;
              value = {
                order = 100 + index;
                HostName = host.hostName;
                Port = host.port;
                ForwardAgent = host.forwardAgent;
              }
              // lib.optionalAttrs (host.user != "") { User = host.user; }
              // lib.optionalAttrs (host.identityFile != "") { IdentityFile = host.identityFile; }
              // lib.optionalAttrs (host.proxyJump != "") { ProxyJump = host.proxyJump; };
            }) cfg.hosts
          );

          programs.ssh.knownHosts = lib.listToAttrs (
            map (host: {
              name = host.hostName;
              value = {
                hostNames = [ host.hostName ];
                publicKey = host.publicKey;
              };
            }) cfg.knownHosts
          );

          programs.ssh.extraConfig = lib.mkIf cfg.keepalive ''
            Host *
              ServerAliveInterval 15
              ServerAliveCountMax 3
              ConnectTimeout 10
          '';

          environment.systemPackages = lib.mkIf cfg.forwardingHelpers [ forwardHelper ];

          environment.shellAliases = lib.mkIf cfg.forwardingHelpers {
            fip = "ojuny-ssh-forward start";
            dip = "ojuny-ssh-forward stop";
            lip = "ojuny-ssh-forward list";
          };

          assertions =
            map (entry: {
              assertion =
                builtins.hasAttr entry.user config.users.users
                && !(lib.hasInfix "\n" entry.key)
                && !(lib.hasInfix "\r" entry.key);
              message = "SSH tools: authorized key must name an existing user and must be single-line.";
            }) cfg.authorizedKeys
            ++ [
              {
                assertion =
                  lib.length (lib.unique (map (host: host.alias) cfg.hosts)) == lib.length cfg.hosts
                  && lib.all (host: builtins.match "[A-Za-z0-9_.-]+" host.alias != null) cfg.hosts
                  && lib.all (host: builtins.match ".*[[:space:]].*" host.hostName == null) cfg.hosts
                  && lib.all (
                    host:
                    builtins.match "[A-Za-z0-9_.-]*" host.user != null
                    && !(lib.hasInfix "\n" host.identityFile)
                    && !(lib.hasInfix "\r" host.identityFile)
                    && !(lib.hasInfix "\n" host.proxyJump)
                    && !(lib.hasInfix "\r" host.proxyJump)
                  ) cfg.hosts;
                message = "SSH tools: host aliases must be unique and simple, host names must not contain whitespace, and client fields must be single-line.";
              }
              {
                assertion =
                  lib.length (lib.unique (map (host: host.hostName) cfg.knownHosts)) == lib.length cfg.knownHosts
                  && lib.all (
                    host: !(lib.hasInfix "\n" host.publicKey) && !(lib.hasInfix "\r" host.publicKey)
                  ) cfg.knownHosts;
                message = "SSH tools: known host names must be unique and public keys must be single-line.";
              }
            ];
      };
    };
}
