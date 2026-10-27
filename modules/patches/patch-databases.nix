/*
  @menu
  displayname = "Databases";
  icon = "network-server-symbolic";
  order = 35;
  description = "Local PostgreSQL, MariaDB and Redis containers with connection presets";
  category = "Patches";
  systems = [ "all" ];
*/

{ ... }:

{
  flake.modules.nixos.patch-databases =
    { config, lib, pkgs, ... }:
    let
      cfg = config.ojuny.patch.databases;

      engineNames = [ "postgres" "mariadb" "redis" ];
      enabledEngines = lib.filter (name: cfg.${name}.enable) engineNames;

      runtimeDir = "/run/ojuny-databases";
      containerName = engine: "ojuny-${engine}";
      unitName = engine: "docker-${containerName engine}.service";

      postgresPassword =
        if cfg.postgres.passwordFile != "" then cfg.postgres.passwordFile
        else "${cfg.credentialDir}/postgres.password";

      mariadbPassword =
        if cfg.mariadb.passwordFile != "" then cfg.mariadb.passwordFile
        else "${cfg.credentialDir}/mariadb.password";

      mariadbRootPassword =
        if cfg.mariadb.rootPasswordFile != "" then cfg.mariadb.rootPasswordFile
        else "${cfg.credentialDir}/mariadb-root.password";

      redisPassword =
        if cfg.redis.passwordFile != "" then cfg.redis.passwordFile
        else "${cfg.credentialDir}/redis.password";

      validPasswordPath = path:
        path == "" || (lib.hasPrefix "/" path && !lib.hasPrefix "/nix/store/" path);

      validVolume = name: builtins.match "[A-Za-z0-9][A-Za-z0-9_.-]*" name != null;

      ensureGenerated = path: ''
        if [ ! -f ${lib.escapeShellArg path} ]; then
          ${pkgs.coreutils}/bin/install -m 0600 /dev/null ${lib.escapeShellArg path}
          ${pkgs.openssl}/bin/openssl rand -hex 24 > ${lib.escapeShellArg path}
        fi
      '';

      prepare = engine: file: source: ''
        source=${lib.escapeShellArg source}
        if [ ! -f "$source" ]; then
          echo "ojuny-databases: password file not found: $source" >&2
          exit 1
        fi
        mode="$(${pkgs.coreutils}/bin/stat -c '%a' "$source")"
        case "$mode" in
          400|600) ;;
          *)
            echo "ojuny-databases: $source must be mode 0400 or 0600, got $mode" >&2
            exit 1
            ;;
        esac
        value="$(${pkgs.coreutils}/bin/cat "$source")"
        if [ -z "$value" ]; then
          echo "ojuny-databases: password file is empty: $source" >&2
          exit 1
        fi
        ${pkgs.coreutils}/bin/install -d -m 0750 -o root -g ${lib.escapeShellArg cfg.credentialGroup} ${lib.escapeShellArg "${runtimeDir}/${engine}"}
        printf '%s' "$value" > ${lib.escapeShellArg "${runtimeDir}/${engine}/${file}.tmp"}
        ${pkgs.coreutils}/bin/chmod 0440 ${lib.escapeShellArg "${runtimeDir}/${engine}/${file}.tmp"}
        ${pkgs.coreutils}/bin/chown ${lib.escapeShellArg "root:${cfg.credentialGroup}"} ${lib.escapeShellArg "${runtimeDir}/${engine}/${file}.tmp"}
        ${pkgs.coreutils}/bin/mv ${lib.escapeShellArg "${runtimeDir}/${engine}/${file}.tmp"} ${lib.escapeShellArg "${runtimeDir}/${engine}/${file}"}
      '';

      redisCheck = ''
        leftover="$(${pkgs.coreutils}/bin/tr -d 'A-Za-z0-9' < ${lib.escapeShellArg "${runtimeDir}/redis/password"} | ${pkgs.coreutils}/bin/wc -c)"
        if [ "$leftover" -ne 0 ]; then
          echo "ojuny-databases: the redis password must contain only letters and digits" >&2
          exit 1
        fi
      '';

      redisConfig = ''
        target=${lib.escapeShellArg "${runtimeDir}/redis/redis.conf"}
        ${pkgs.coreutils}/bin/install -m 0600 /dev/null "$target.tmp"
        {
          echo 'bind 0.0.0.0'
          echo 'protected-mode no'
          echo 'appendonly yes'
          echo 'dir /data'
          printf 'requirepass %s\n' "$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg "${runtimeDir}/redis/password"})"
        } > "$target.tmp"
        ${pkgs.coreutils}/bin/chmod 0444 "$target.tmp"
        ${pkgs.coreutils}/bin/chown ${lib.escapeShellArg "root:${cfg.credentialGroup}"} "$target.tmp"
        ${pkgs.coreutils}/bin/mv "$target.tmp" "$target"
      '';

      credentialScript = ''
        set -euo pipefail
        umask 077

        ${pkgs.coreutils}/bin/install -d -m 0700 -o root -g root ${lib.escapeShellArg cfg.credentialDir}
        ${pkgs.coreutils}/bin/install -d -m 0750 -o root -g ${lib.escapeShellArg cfg.credentialGroup} ${runtimeDir}

        ${lib.optionalString (cfg.postgres.enable && cfg.postgres.passwordFile == "") (ensureGenerated postgresPassword)}
        ${lib.optionalString cfg.postgres.enable (prepare "postgres" "password" postgresPassword)}

        ${lib.optionalString (cfg.mariadb.enable && cfg.mariadb.passwordFile == "") (ensureGenerated mariadbPassword)}
        ${lib.optionalString (cfg.mariadb.enable && cfg.mariadb.rootPasswordFile == "") (ensureGenerated mariadbRootPassword)}
        ${lib.optionalString cfg.mariadb.enable (prepare "mariadb" "password" mariadbPassword)}
        ${lib.optionalString cfg.mariadb.enable (prepare "mariadb" "root-password" mariadbRootPassword)}

        ${lib.optionalString (cfg.redis.enable && cfg.redis.passwordFile == "") (ensureGenerated redisPassword)}
        ${lib.optionalString cfg.redis.enable (prepare "redis" "password" redisPassword)}
        ${lib.optionalString cfg.redis.enable redisCheck}
        ${lib.optionalString cfg.redis.enable redisConfig}
      '';

      pgPreset = pkgs.writeShellScriptBin "ojuny-pg" ''
        set -euo pipefail
        export PGPASSWORD="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg "${runtimeDir}/postgres/password"})"
        exec ${pkgs.postgresql}/bin/psql \
          --host 127.0.0.1 \
          --port ${toString cfg.postgres.port} \
          --username ${lib.escapeShellArg cfg.postgres.user} \
          --dbname ${lib.escapeShellArg cfg.postgres.database} \
          "$@"
      '';

      mariadbPreset = pkgs.writeShellScriptBin "ojuny-mysql" ''
        set -euo pipefail
        export MYSQL_PWD="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg "${runtimeDir}/mariadb/password"})"
        exec ${pkgs.mariadb}/bin/mariadb \
          --host=127.0.0.1 \
          --port=${toString cfg.mariadb.port} \
          --user=${lib.escapeShellArg cfg.mariadb.user} \
          ${lib.escapeShellArg cfg.mariadb.database} \
          "$@"
      '';

      redisPreset = pkgs.writeShellScriptBin "ojuny-redis" ''
        set -euo pipefail
        export REDISCLI_AUTH="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg "${runtimeDir}/redis/password"})"
        exec ${pkgs.redis}/bin/redis-cli \
          --host 127.0.0.1 \
          --port ${toString cfg.redis.port} \
          "$@"
      '';

      passwordPreset = pkgs.writeShellScriptBin "ojuny-db-password" ''
        set -euo pipefail
        case "''${1:-}" in
          postgres) file=${lib.escapeShellArg "${runtimeDir}/postgres/password"} ;;
          mariadb) file=${lib.escapeShellArg "${runtimeDir}/mariadb/password"} ;;
          mariadb-root) file=${lib.escapeShellArg "${runtimeDir}/mariadb/root-password"} ;;
          redis) file=${lib.escapeShellArg "${runtimeDir}/redis/password"} ;;
          *)
            echo "usage: ojuny-db-password {postgres|mariadb|mariadb-root|redis}" >&2
            exit 2
            ;;
        esac
        exec ${pkgs.coreutils}/bin/cat "$file"
      '';
    in
    {
      options.ojuny.patch.databases = {
        enable = lib.mkEnableOption "the local databases patch";

        credentialDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/ojuny/databases";
          description = "Root-only directory for generated database passwords.";
        };

        credentialGroup = lib.mkOption {
          type = lib.types.str;
          default = "wheel";
          description = "Group allowed to read the staged passwords in /run/ojuny-databases.";
        };

        postgres = {
          enable = lib.mkEnableOption "the local PostgreSQL container";

          port = lib.mkOption {
            type = lib.types.port;
            default = 5432;
            description = "Loopback port for PostgreSQL.";
          };

          user = lib.mkOption {
            type = lib.types.str;
            default = "ojuny";
            description = "PostgreSQL superuser and default connection user.";
          };

          database = lib.mkOption {
            type = lib.types.str;
            default = "ojuny";
            description = "Database created on first start.";
          };

          passwordFile = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Absolute path to a password file. Empty generates one under credentialDir.";
          };

          volume = lib.mkOption {
            type = lib.types.str;
            default = "ojuny-postgres-data";
            description = "Docker volume that holds the PostgreSQL data directory.";
          };

          image = lib.mkOption {
            type = lib.types.str;
            default = "docker.io/library/postgres:17";
            description = "PostgreSQL container image.";
          };
        };

        mariadb = {
          enable = lib.mkEnableOption "the local MariaDB container";

          port = lib.mkOption {
            type = lib.types.port;
            default = 3306;
            description = "Loopback port for MariaDB.";
          };

          user = lib.mkOption {
            type = lib.types.str;
            default = "ojuny";
            description = "MariaDB application user.";
          };

          database = lib.mkOption {
            type = lib.types.str;
            default = "ojuny";
            description = "Database created on first start.";
          };

          passwordFile = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Absolute path to the application user password file. Empty generates one.";
          };

          rootPasswordFile = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Absolute path to the MariaDB root password file. Empty generates one.";
          };

          volume = lib.mkOption {
            type = lib.types.str;
            default = "ojuny-mariadb-data";
            description = "Docker volume that holds the MariaDB data directory.";
          };

          image = lib.mkOption {
            type = lib.types.str;
            default = "docker.io/library/mariadb:11.4";
            description = "MariaDB container image.";
          };
        };

        redis = {
          enable = lib.mkEnableOption "the local Redis container";

          port = lib.mkOption {
            type = lib.types.port;
            default = 6379;
            description = "Loopback port for Redis.";
          };

          passwordFile = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Absolute path to the Redis password file. Empty generates one.";
          };

          volume = lib.mkOption {
            type = lib.types.str;
            default = "ojuny-redis-data";
            description = "Docker volume that holds the Redis append-only data.";
          };

          image = lib.mkOption {
            type = lib.types.str;
            default = "docker.io/library/redis:7-alpine";
            description = "Redis container image.";
          };
        };
      };

      config = lib.mkMerge [
        {
          # @option widget = "switch"; label = "Databases"; group = "Databases"; description = "Run local PostgreSQL, MariaDB and Redis containers. Data is stored in Docker volumes and persists across rebuilds.";
          ojuny.patch.databases.enable = false;

          # @option widget = "path"; label = "Credential directory"; group = "Advanced"; hidden = true; description = "Root-only directory for generated database passwords.";
          ojuny.patch.databases.credentialDir = "/var/lib/ojuny/databases";

          # @option widget = "text"; label = "Credential group"; group = "Advanced"; hidden = true; description = "Group that can read staged passwords in /run/ojuny-databases. Members are administrator-equivalent.";
          ojuny.patch.databases.credentialGroup = "wheel";

          # @option widget = "switch"; label = "PostgreSQL"; group = "PostgreSQL"; visibleWhen.path = "ojuny.patch.databases.enable"; visibleWhen.equals = true; description = "Run a local PostgreSQL server with a named data volume.";
          ojuny.patch.databases.postgres.enable = true;

          # @option widget = "spin"; label = "Port"; group = "PostgreSQL"; min = 1; max = 65535; visibleWhen.path = "ojuny.patch.databases.postgres.enable"; visibleWhen.equals = true; description = "Loopback port published on 127.0.0.1.";
          ojuny.patch.databases.postgres.port = 5432;

          # @option widget = "text"; label = "User"; group = "PostgreSQL"; visibleWhen.path = "ojuny.patch.databases.postgres.enable"; visibleWhen.equals = true; description = "Superuser and default connection user.";
          ojuny.patch.databases.postgres.user = "ojuny";

          # @option widget = "text"; label = "Database"; group = "PostgreSQL"; visibleWhen.path = "ojuny.patch.databases.postgres.enable"; visibleWhen.equals = true; description = "Database created on first start.";
          ojuny.patch.databases.postgres.database = "ojuny";

          # @option widget = "text"; label = "Password file"; group = "PostgreSQL"; advanced = true; visibleWhen.path = "ojuny.patch.databases.postgres.enable"; visibleWhen.equals = true; description = "Absolute path to a password file. Empty generates a random password under the credential directory.";
          ojuny.patch.databases.postgres.passwordFile = "";

          # @option widget = "text"; label = "Volume"; group = "Advanced"; hidden = true; description = "Docker volume for PostgreSQL data.";
          ojuny.patch.databases.postgres.volume = "ojuny-postgres-data";

          # @option widget = "text"; label = "Image"; group = "Advanced"; hidden = true; description = "PostgreSQL container image.";
          ojuny.patch.databases.postgres.image = "docker.io/library/postgres:17";

          # @option widget = "switch"; label = "MariaDB"; group = "MariaDB"; visibleWhen.path = "ojuny.patch.databases.enable"; visibleWhen.equals = true; description = "Run a local MariaDB server with a named data volume.";
          ojuny.patch.databases.mariadb.enable = false;

          # @option widget = "spin"; label = "Port"; group = "MariaDB"; min = 1; max = 65535; visibleWhen.path = "ojuny.patch.databases.mariadb.enable"; visibleWhen.equals = true; description = "Loopback port published on 127.0.0.1.";
          ojuny.patch.databases.mariadb.port = 3306;

          # @option widget = "text"; label = "User"; group = "MariaDB"; visibleWhen.path = "ojuny.patch.databases.mariadb.enable"; visibleWhen.equals = true; description = "Application user created on first start.";
          ojuny.patch.databases.mariadb.user = "ojuny";

          # @option widget = "text"; label = "Database"; group = "MariaDB"; visibleWhen.path = "ojuny.patch.databases.mariadb.enable"; visibleWhen.equals = true; description = "Database created on first start.";
          ojuny.patch.databases.mariadb.database = "ojuny";

          # @option widget = "text"; label = "User password file"; group = "MariaDB"; advanced = true; visibleWhen.path = "ojuny.patch.databases.mariadb.enable"; visibleWhen.equals = true; description = "Absolute path to the application user password file. Empty generates one.";
          ojuny.patch.databases.mariadb.passwordFile = "";

          # @option widget = "text"; label = "Root password file"; group = "MariaDB"; advanced = true; visibleWhen.path = "ojuny.patch.databases.mariadb.enable"; visibleWhen.equals = true; description = "Absolute path to the root password file. Empty generates one.";
          ojuny.patch.databases.mariadb.rootPasswordFile = "";

          # @option widget = "text"; label = "Volume"; group = "Advanced"; hidden = true; description = "Docker volume for MariaDB data.";
          ojuny.patch.databases.mariadb.volume = "ojuny-mariadb-data";

          # @option widget = "text"; label = "Image"; group = "Advanced"; hidden = true; description = "MariaDB container image.";
          ojuny.patch.databases.mariadb.image = "docker.io/library/mariadb:11.4";

          # @option widget = "switch"; label = "Redis"; group = "Redis"; visibleWhen.path = "ojuny.patch.databases.enable"; visibleWhen.equals = true; description = "Run a local Redis server with a named data volume.";
          ojuny.patch.databases.redis.enable = false;

          # @option widget = "spin"; label = "Port"; group = "Redis"; min = 1; max = 65535; visibleWhen.path = "ojuny.patch.databases.redis.enable"; visibleWhen.equals = true; description = "Loopback port published on 127.0.0.1.";
          ojuny.patch.databases.redis.port = 6379;

          # @option widget = "text"; label = "Password file"; group = "Redis"; advanced = true; visibleWhen.path = "ojuny.patch.databases.redis.enable"; visibleWhen.equals = true; description = "Absolute path to the Redis password file. Empty generates one.";
          ojuny.patch.databases.redis.passwordFile = "";

          # @option widget = "text"; label = "Volume"; group = "Advanced"; hidden = true; description = "Docker volume for Redis data.";
          ojuny.patch.databases.redis.volume = "ojuny-redis-data";

          # @option widget = "text"; label = "Image"; group = "Advanced"; hidden = true; description = "Redis container image.";
          ojuny.patch.databases.redis.image = "docker.io/library/redis:7-alpine";
        }
        (lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = enabledEngines == [ ] || config.virtualisation.docker.enable;
              message = "patch-databases needs virtualisation.docker.enable, but it was explicitly disabled";
            }
            {
              assertion = enabledEngines == [ ] || config.virtualisation.oci-containers.backend == "docker";
              message = "patch-databases supports only the docker oci-containers backend";
            }
            {
              assertion = lib.hasPrefix "/" cfg.credentialDir && cfg.credentialDir != "/" && !lib.hasPrefix "/nix/store/" cfg.credentialDir;
              message = "ojuny.patch.databases.credentialDir must be an absolute path outside / and the Nix store";
            }
            {
              assertion = validPasswordPath cfg.postgres.passwordFile;
              message = "ojuny.patch.databases.postgres.passwordFile must be empty or an absolute path outside the Nix store";
            }
            {
              assertion = validPasswordPath cfg.mariadb.passwordFile;
              message = "ojuny.patch.databases.mariadb.passwordFile must be empty or an absolute path outside the Nix store";
            }
            {
              assertion = validPasswordPath cfg.mariadb.rootPasswordFile;
              message = "ojuny.patch.databases.mariadb.rootPasswordFile must be empty or an absolute path outside the Nix store";
            }
            {
              assertion = validPasswordPath cfg.redis.passwordFile;
              message = "ojuny.patch.databases.redis.passwordFile must be empty or an absolute path outside the Nix store";
            }
            {
              assertion = !cfg.postgres.enable || validVolume cfg.postgres.volume;
              message = "ojuny.patch.databases.postgres.volume is not a valid Docker volume name";
            }
            {
              assertion = !cfg.mariadb.enable || validVolume cfg.mariadb.volume;
              message = "ojuny.patch.databases.mariadb.volume is not a valid Docker volume name";
            }
            {
              assertion = !cfg.redis.enable || validVolume cfg.redis.volume;
              message = "ojuny.patch.databases.redis.volume is not a valid Docker volume name";
            }
            {
              assertion = !cfg.postgres.enable || (cfg.postgres.user != "" && cfg.postgres.database != "");
              message = "ojuny.patch.databases.postgres.user and database must not be empty";
            }
            {
              assertion = !cfg.mariadb.enable || (cfg.mariadb.user != "" && cfg.mariadb.database != "");
              message = "ojuny.patch.databases.mariadb.user and database must not be empty";
            }
          ];

          virtualisation.docker.enable = lib.mkIf (enabledEngines != [ ]) (lib.mkDefault true);
          virtualisation.docker.enableOnBoot = lib.mkIf (enabledEngines != [ ]) (lib.mkDefault true);
          virtualisation.oci-containers.backend = lib.mkDefault "docker";

          virtualisation.oci-containers.containers = lib.mkMerge [
            (lib.mkIf cfg.postgres.enable {
              "ojuny-postgres" = {
                image = cfg.postgres.image;
                ports = [ "127.0.0.1:${toString cfg.postgres.port}:5432" ];
                volumes = [
                  "${cfg.postgres.volume}:/var/lib/postgresql/data"
                  "${runtimeDir}/postgres/password:/run/secrets/postgres-password:ro"
                ];
                environment = {
                  POSTGRES_USER = cfg.postgres.user;
                  POSTGRES_DB = cfg.postgres.database;
                  POSTGRES_PASSWORD_FILE = "/run/secrets/postgres-password";
                };
                autoStart = true;
              };
            })

            (lib.mkIf cfg.mariadb.enable {
              "ojuny-mariadb" = {
                image = cfg.mariadb.image;
                ports = [ "127.0.0.1:${toString cfg.mariadb.port}:3306" ];
                volumes = [
                  "${cfg.mariadb.volume}:/var/lib/mysql"
                  "${runtimeDir}/mariadb/password:/run/secrets/mariadb-password:ro"
                  "${runtimeDir}/mariadb/root-password:/run/secrets/mariadb-root-password:ro"
                ];
                environment = {
                  MARIADB_DATABASE = cfg.mariadb.database;
                  MARIADB_USER = cfg.mariadb.user;
                  MARIADB_PASSWORD_FILE = "/run/secrets/mariadb-password";
                  MARIADB_ROOT_PASSWORD_FILE = "/run/secrets/mariadb-root-password";
                };
                autoStart = true;
              };
            })

            (lib.mkIf cfg.redis.enable {
              "ojuny-redis" = {
                image = cfg.redis.image;
                ports = [ "127.0.0.1:${toString cfg.redis.port}:6379" ];
                volumes = [
                  "${cfg.redis.volume}:/data"
                  "${runtimeDir}/redis/redis.conf:/usr/local/etc/redis/redis.conf:ro"
                ];
                cmd = [ "redis-server" "/usr/local/etc/redis/redis.conf" ];
                autoStart = true;
              };
            })
          ];

          environment.systemPackages =
            lib.optional cfg.postgres.enable pgPreset
            ++ lib.optional cfg.postgres.enable pkgs.postgresql
            ++ lib.optional cfg.mariadb.enable mariadbPreset
            ++ lib.optional cfg.mariadb.enable pkgs.mariadb
            ++ lib.optional cfg.redis.enable redisPreset
            ++ lib.optional cfg.redis.enable pkgs.redis
            ++ lib.optional (enabledEngines != [ ]) passwordPreset;

          systemd.services = lib.mkMerge [
            (lib.mkIf (enabledEngines != [ ]) {
              ojuny-databases-credentials = {
                description = "Stage local database credentials";
                wantedBy = [ "multi-user.target" ];
                before = map unitName enabledEngines;
                after = [ "local-fs.target" ];
                unitConfig.RequiresMountsFor =
                  [ cfg.credentialDir ]
                  ++ lib.optional (cfg.postgres.passwordFile != "") cfg.postgres.passwordFile
                  ++ lib.optional (cfg.mariadb.passwordFile != "") cfg.mariadb.passwordFile
                  ++ lib.optional (cfg.mariadb.rootPasswordFile != "") cfg.mariadb.rootPasswordFile
                  ++ lib.optional (cfg.redis.passwordFile != "") cfg.redis.passwordFile;
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  UMask = "0077";
                };
                script = credentialScript;
              };
            })

            (lib.mkMerge (map (engine: {
              "${unitName engine}" = {
                requires = [ "ojuny-databases-credentials.service" ];
                after = [ "ojuny-databases-credentials.service" ];
              };
            }) enabledEngines))
          ];
        })
      ];
    };
}
