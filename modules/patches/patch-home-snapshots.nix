/*
  @menu
  displayname = "Home snapshots";
  icon = "document-save-symbolic";
  order = 200;
  description = "Scheduled restic snapshots of /home only";
  category = "Patches";
  systems = [ "all" ];
*/

{ ... }: {

  flake.modules.nixos.patch-home-snapshots =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.ojuny.patch.home-snapshots;
      excludes = map (pattern: "--exclude=${pattern}") cfg.exclude;
    in
    {
      options.ojuny.patch.home-snapshots = {
        enable = lib.mkEnableOption "scheduled home snapshots";
        repository = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/ojuny/home-restic";
        };
        passwordFile = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/ojuny/home-restic-password";
        };
        paths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "/home" ];
        };
        exclude = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "**/.cache"
            "**/.local/share/Trash"
            "**/node_modules"
            "**/.gradle"
            "**/.npm"
          ];
        };
        schedule = lib.mkOption {
          type = lib.types.enum [
            "hourly"
            "daily"
            "weekly"
          ];
          default = "daily";
        };
        keepDaily = lib.mkOption {
          type = lib.types.int;
          default = 7;
        };
        keepWeekly = lib.mkOption {
          type = lib.types.int;
          default = 4;
        };
        keepMonthly = lib.mkOption {
          type = lib.types.int;
          default = 6;
        };
      };

      config = lib.mkMerge [
        {
          # @option widget = "switch"; label = "Home snapshots"; group = "Home snapshots";
          ojuny.patch.home-snapshots.enable = false;

          # @option widget = "text"; label = "Repository"; group = "Home snapshots";
          ojuny.patch.home-snapshots.repository = "/var/lib/ojuny/home-restic";

          # @option widget = "text"; label = "Password file"; group = "Home snapshots";
          ojuny.patch.home-snapshots.passwordFile = "/var/lib/ojuny/home-restic-password";

          # @option widget = "list"; label = "Paths"; group = "Home snapshots";
          ojuny.patch.home-snapshots.paths = [ "/home" ];

          # @option widget = "list"; label = "Excludes"; group = "Home snapshots";
          ojuny.patch.home-snapshots.exclude = [
            "**/.cache"
            "**/.local/share/Trash"
            "**/node_modules"
            "**/.gradle"
            "**/.npm"
          ];

          # @option widget = "dropdown"; label = "Schedule"; group = "Home snapshots"; choices = [ "hourly" "daily" "weekly" ];
          ojuny.patch.home-snapshots.schedule = "daily";

          # @option widget = "spin"; label = "Keep daily"; group = "Home snapshots";
          ojuny.patch.home-snapshots.keepDaily = 7;

          # @option widget = "spin"; label = "Keep weekly"; group = "Home snapshots";
          ojuny.patch.home-snapshots.keepWeekly = 4;

          # @option widget = "spin"; label = "Keep monthly"; group = "Home snapshots";
          ojuny.patch.home-snapshots.keepMonthly = 6;
        }
        (lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = cfg.repository != "";
              message = "home-snapshots requires a repository";
            }
            {
              assertion = cfg.passwordFile != "";
              message = "home-snapshots requires a passwordFile";
            }
            {
              assertion = lib.all (path: path == "/home" || lib.hasPrefix "/home/" path) cfg.paths;
              message = "home-snapshots may only snapshot paths under /home";
            }
          ];

          environment.systemPackages = [ pkgs.restic ];

          systemd.services.restic-home = {
            serviceConfig.Type = "oneshot";
            environment = {
              RESTIC_REPOSITORY = cfg.repository;
              RESTIC_PASSWORD_FILE = cfg.passwordFile;
            };
            preStart = ''
              install -d -m 700 ${builtins.dirOf cfg.repository}
              install -d -m 700 ${builtins.dirOf cfg.passwordFile}
              if [ ! -f ${cfg.passwordFile} ]; then
                install -m 600 /dev/null ${cfg.passwordFile}
                ${pkgs.openssl}/bin/openssl rand -base64 32 > ${cfg.passwordFile}
              fi
            '';
            script = ''
              ${pkgs.restic}/bin/restic snapshots >/dev/null 2>&1 \
                || ${pkgs.restic}/bin/restic init
              ${pkgs.restic}/bin/restic backup --tag ojuny-home \
                ${lib.escapeShellArgs cfg.paths} ${lib.escapeShellArgs excludes}
              ${pkgs.restic}/bin/restic forget --tag ojuny-home \
                --keep-daily ${toString cfg.keepDaily} \
                --keep-weekly ${toString cfg.keepWeekly} \
                --keep-monthly ${toString cfg.keepMonthly} --prune
            '';
          };

          systemd.timers.restic-home = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar =
                if cfg.schedule == "hourly" then
                  "hourly"
                else if cfg.schedule == "daily" then
                  "daily"
                else
                  "weekly";
              Persistent = true;
            };
          };
        })
      ];
    };
}
