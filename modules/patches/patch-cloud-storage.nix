/*
  @menu
  displayname = "Cloud Storage";
  icon = "folder-remote-symbolic";
  order = 180;
  description = "FOSS cloud sync clients with provider selection and Nix-configured autostart";
  category = "Patches";
  systems = [ "all" ];
*/

{ ... }:

{
  flake.modules.nixos.patch-cloud-storage =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.ojuny.patch.cloud-storage;
      greetdEnabled = (config.services ? greetd) && config.services.greetd.enable;
    in
    {
      options.ojuny.patch.cloud-storage = {
        enable = lib.mkEnableOption "the cloud storage patch";

        provider = lib.mkOption {
          type = lib.types.enum [
            "nextcloud"
            "owncloud"
            "opencloud"
            "seafile"
          ];
          default = "nextcloud";
          description = "FOSS cloud storage provider and desktop client to install.";
        };

        keyring = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable GNOME Keyring as the Secret Service for client credentials.";
        };

        nextcloud = {
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.nextcloud-client;
            defaultText = lib.literalExpression "pkgs.nextcloud-client";
            description = "Nextcloud desktop client package.";
          };
          startInBackground = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Start the Nextcloud client without opening the main window.";
          };
          serverUrl = lib.mkOption {
            type = lib.types.str;
            default = "";
            example = "https://cloud.example.com";
            description = "Optional URL for the next Nextcloud account setup. Passed as --overrideserverurl.";
          };
          localFolder = lib.mkOption {
            type = lib.types.str;
            default = "";
            example = "/home/den/Nextcloud";
            description = "Optional local folder for the next Nextcloud account setup. Passed as --overridelocaldir.";
          };
        };

        owncloud.package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.owncloud-client;
          defaultText = lib.literalExpression "pkgs.owncloud-client";
          description = "ownCloud desktop client package.";
        };

        opencloud = {
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.opencloud-desktop;
            defaultText = lib.literalExpression "pkgs.opencloud-desktop";
            description = "OpenCloud desktop client package.";
          };
          showOnStart = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Open the OpenCloud window on start instead of starting in the background.";
          };
        };

        seafile.package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.seafile-client;
          defaultText = lib.literalExpression "pkgs.seafile-client";
          description = "Seafile desktop client package.";
        };
      };

      config = lib.mkMerge [
        {
          # @option widget = "switch"; label = "Cloud storage"; group = "Cloud storage"; description = "Enable the cloud storage patch."
          ojuny.patch.cloud-storage.enable = false;

          # @option widget = "dropdown"; label = "Provider"; group = "Cloud storage"; choices = [ "nextcloud" "owncloud" "opencloud" "seafile" ]; description = "FOSS cloud provider and desktop client."; visibleWhen.path = "ojuny.patch.cloud-storage.enable"; visibleWhen.equals = true;
          ojuny.patch.cloud-storage.provider = "nextcloud";

          # @option widget = "switch"; label = "GNOME Keyring"; group = "System integration"; description = "Store client credentials in GNOME Keyring through the Secret Service API."; visibleWhen.path = "ojuny.patch.cloud-storage.enable"; visibleWhen.equals = true;
          ojuny.patch.cloud-storage.keyring = true;

          # @option widget = "switch"; label = "Start in background"; group = "Nextcloud"; description = "Start the Nextcloud client without opening the main window."; visibleWhen.path = "ojuny.patch.cloud-storage.provider"; visibleWhen.equals = "nextcloud";
          ojuny.patch.cloud-storage.nextcloud.startInBackground = true;

          # @option widget = "text"; label = "Server URL"; group = "Nextcloud"; description = "Optional URL to prefill the next account setup. Passed as --overrideserverurl. Never a password."; visibleWhen.path = "ojuny.patch.cloud-storage.provider"; visibleWhen.equals = "nextcloud";
          ojuny.patch.cloud-storage.nextcloud.serverUrl = "";

          # @option widget = "text"; label = "Local folder"; group = "Nextcloud"; description = "Optional local folder to prefill the next account setup. Passed as --overridelocaldir. Use an absolute path."; visibleWhen.path = "ojuny.patch.cloud-storage.provider"; visibleWhen.equals = "nextcloud";
          ojuny.patch.cloud-storage.nextcloud.localFolder = "";
        }

        (lib.mkIf cfg.enable {
          assertions = [
            {
              assertion =
                cfg.provider != "nextcloud"
                || cfg.nextcloud.serverUrl == ""
                || lib.hasPrefix "https://" cfg.nextcloud.serverUrl
                || lib.hasPrefix "http://" cfg.nextcloud.serverUrl;
              message = "ojuny.patch.cloud-storage.nextcloud.serverUrl must be empty or start with http:// or https://.";
            }
            {
              assertion =
                cfg.nextcloud.localFolder == ""
                || lib.hasPrefix "/" cfg.nextcloud.localFolder;
              message = "ojuny.patch.cloud-storage.nextcloud.localFolder must be empty or an absolute path.";
            }
          ];

          services.gnome.gnome-keyring.enable = lib.mkIf cfg.keyring true;
          security.pam.services.login.enableGnomeKeyring = lib.mkIf cfg.keyring true;
          security.pam.services.greetd.enableGnomeKeyring =
            lib.mkIf (cfg.keyring && greetdEnabled) true;
        })
      ];
    };

  flake.modules.homeManager.patch-cloud-storage =
    {
      config,
      lib,
      osConfig,
      ...
    }:
    let
      cfg = osConfig.ojuny.patch.cloud-storage;

      mkClientUnit =
        {
          description,
          package,
          binary,
          args ? [ ],
          stopArgs ? [ ],
        }:
        {
          Unit = {
            inherit description;
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Service =
            {
              Environment = [ "PATH=${config.home.profileDirectory}/bin" ];
              ExecStart = lib.concatStringsSep " " (
                [ "${package}/bin/${binary}" ] ++ args
              );
              Restart = "on-failure";
              RestartSec = "5s";
              KillMode = "process";
              NoNewPrivileges = true;
              RestrictRealtime = true;
            }
            // lib.optionalAttrs (stopArgs != [ ]) {
              ExecStop = lib.concatStringsSep " " (
                [ "${package}/bin/${binary}" ] ++ stopArgs
              );
            };
          Install.WantedBy = [ "graphical-session.target" ];
        };

      nextcloudPrefill =
        cfg.nextcloud.serverUrl != "" || cfg.nextcloud.localFolder != "";
    in
    {
      config = lib.mkIf cfg.enable {
        services.gnome-keyring.enable = lib.mkIf cfg.keyring true;

        home.packages =
          lib.optional (cfg.provider == "nextcloud") cfg.nextcloud.package
          ++ lib.optional (cfg.provider == "owncloud") cfg.owncloud.package
          ++ lib.optional (cfg.provider == "opencloud") cfg.opencloud.package
          ++ lib.optional (cfg.provider == "seafile") cfg.seafile.package;

        services.nextcloud-client = lib.mkIf (cfg.provider == "nextcloud") {
          enable = true;
          package = cfg.nextcloud.package;
          startInBackground = cfg.nextcloud.startInBackground;
        };

        services.owncloud-client = lib.mkIf (cfg.provider == "owncloud") {
          enable = true;
          package = cfg.owncloud.package;
        };

        systemd.user.services = lib.mkMerge [
          (lib.mkIf (cfg.provider == "nextcloud" && nextcloudPrefill) {
            nextcloud-client.Service.ExecStart = lib.mkForce (
              lib.concatStringsSep " " (
                [ "${cfg.nextcloud.package}/bin/nextcloud" ]
                ++ lib.optional cfg.nextcloud.startInBackground "--background"
                ++ lib.optionals (cfg.nextcloud.serverUrl != "") [
                  "--overrideserverurl"
                  (lib.escapeShellArg cfg.nextcloud.serverUrl)
                ]
                ++ lib.optionals (cfg.nextcloud.localFolder != "") [
                  "--overridelocaldir"
                  (lib.escapeShellArg cfg.nextcloud.localFolder)
                ]
              )
            );
          })

          (lib.optionalAttrs (cfg.provider == "opencloud") {
            opencloud-client = mkClientUnit {
              description = "OpenCloud Client";
              package = cfg.opencloud.package;
              binary = "opencloud";
              args = lib.optional cfg.opencloud.showOnStart "--show";
              stopArgs = [ "--quit" ];
            };
          })

          (lib.optionalAttrs (cfg.provider == "seafile") {
            seafile-client = mkClientUnit {
              description = "Seafile Client";
              package = cfg.seafile.package;
              binary = "seafile-applet";
              stopArgs = [ "-K" ];
            };
          })
        ];
      };
    };
}
