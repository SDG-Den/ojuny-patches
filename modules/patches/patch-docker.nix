/*
  @menu
  displayname = "Docker";
  icon = "applications-system-symbolic";
  order = 30;
  description = "Docker daemon, rootless mode, pruning and declarative containers";
  category = "Patches";
  systems = [ "all" ];
*/

/*
  @snippet
  name = "container";
  label = "Add container";
  snippet = ''
    # @option widget = "text"; label = "%%name%% image"; group = "Containers"; visibleWhen.path = "ojuny.patch.docker.mode"; visibleWhen.equals = "system"; description = "OCI image with tag, e.g. nginx:latest.";
    ojuny.patch.docker.containers."%%name%%".image = "%%image%%";
    # @option widget = "list"; label = "%%name%% ports"; group = "Containers"; visibleWhen.path = "ojuny.patch.docker.mode"; visibleWhen.equals = "system"; description = "Published ports, e.g. 127.0.0.1:8080:8080. A loopback address keeps the port off the network.";
    ojuny.patch.docker.containers."%%name%%".ports = [ ];
    # @option widget = "list"; label = "%%name%% volumes"; group = "Containers"; visibleWhen.path = "ojuny.patch.docker.mode"; visibleWhen.equals = "system"; description = "Host:container or named volume mounts, e.g. nginx-html:/usr/share/nginx/html.";
    ojuny.patch.docker.containers."%%name%%".volumes = [ ];
    # @option widget = "raw"; label = "%%name%% environment"; group = "Containers"; rows = 4; visibleWhen.path = "ojuny.patch.docker.mode"; visibleWhen.equals = "system"; description = "Environment variables as a Nix attrset.";
    ojuny.patch.docker.containers."%%name%%".environment = { };
    # @option widget = "switch"; label = "%%name%% start at boot"; group = "Containers"; visibleWhen.path = "ojuny.patch.docker.mode"; visibleWhen.equals = "system"; description = "Start the container with systemd on boot. Only used in system mode.";
    ojuny.patch.docker.containers."%%name%%".autoStart = true;
  '';
  placeholders.name.label = "Container name";
  placeholders.name.default = "nginx";
  placeholders.image.label = "Image";
  placeholders.image.default = "nginx:latest";
*/

{ self, ... }:

{
  flake.modules.nixos.patch-docker =
    { config, lib, ... }:
    {
      options.ojuny.patch.docker.enable = lib.mkEnableOption "the Docker patch";

      # @option widget = "switch"; label = "Docker patch"; group = "Patches"; description = "Enable Docker, rootless mode, pruning and declarative containers.";
      config.ojuny.patch.docker.enable = lib.mkDefault false;

      imports = [ self.modules.nixos.docker-backend ];
    };

  flake.modules.nixos.docker-backend =
    { config, lib, ... }:
    let
      active = config.ojuny.patch.docker.enable && (config.ojuny.patches or true);
      cfg = config.ojuny.patch.docker // {
        enable = active;
      };
    in
    {
      options.ojuny.patch.docker = {
        mode = lib.mkOption {
          type = lib.types.enum [
            "system"
            "rootless"
          ];
          default = "system";
          description = "Run the root-owned system daemon or a per-user rootless daemon.";
        };

        enableOnBoot = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Start the system daemon at boot. Ignored in rootless mode.";
        };

        daemonSettings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "dockerd daemon.json settings, applied to the active mode.";
        };

        autoPrune = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Run docker system prune on a schedule. System mode only.";
          };
          dates = lib.mkOption {
            type = lib.types.str;
            default = "weekly";
            description = "systemd calendar spec for the prune timer.";
          };
          flags = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Extra arguments for docker system prune.";
          };
          allVolumes = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Also run docker volume prune --force --all. This deletes data in unused volumes.";
          };
        };

        containers = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                image = lib.mkOption {
                  type = lib.types.str;
                  description = "OCI image with tag.";
                };
                ports = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Published ports. Prefer 127.0.0.1:host:container.";
                };
                volumes = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Host:container or named volume mounts.";
                };
                environment = lib.mkOption {
                  type = lib.types.attrsOf lib.types.str;
                  default = { };
                  description = "Environment variables.";
                };
                autoStart = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Start the container at boot.";
                };
              };
            }
          );
          default = { };
          description = "Declarative containers managed through virtualisation.oci-containers.";
        };
      };

      config = {
        # @option widget = "dropdown"; label = "Docker mode"; group = "Docker"; choices = [ "system" "rootless" ]; visibleWhen.path = "ojuny.patch.docker.enable"; visibleWhen.equals = true; description = "System runs a root-owned daemon. Rootless runs a per-user daemon; declarative containers are unavailable in rootless mode.";
        ojuny.patch.docker.mode = lib.mkDefault "system";

        # @option widget = "switch"; label = "Start on boot"; group = "Docker"; visibleWhen.path = "ojuny.patch.docker.mode"; visibleWhen.equals = "system"; description = "Start the system daemon at boot. Ignored in rootless mode.";
        ojuny.patch.docker.enableOnBoot = lib.mkDefault true;

        # @option widget = "switch"; label = "Automatic pruning"; group = "Pruning"; visibleWhen.path = "ojuny.patch.docker.mode"; visibleWhen.equals = "system"; description = "Run docker system prune on a schedule. System mode only.";
        ojuny.patch.docker.autoPrune.enable = lib.mkDefault false;

        # @option widget = "text"; label = "Prune schedule"; group = "Pruning"; visibleWhen.path = "ojuny.patch.docker.autoPrune.enable"; visibleWhen.equals = true; description = "systemd calendar spec, e.g. weekly or daily 03:00.";
        ojuny.patch.docker.autoPrune.dates = lib.mkDefault "weekly";

        # @option widget = "list"; label = "Prune flags"; group = "Pruning"; visibleWhen.path = "ojuny.patch.docker.autoPrune.enable"; visibleWhen.equals = true; hidden = true; description = "Extra arguments for docker system prune.";
        ojuny.patch.docker.autoPrune.flags = lib.mkDefault [ ];

        # @option widget = "switch"; label = "Prune volumes"; group = "Pruning"; visibleWhen.path = "ojuny.patch.docker.autoPrune.enable"; visibleWhen.equals = true; hidden = true; description = "Also prune all volumes. This deletes data in unused volumes.";
        ojuny.patch.docker.autoPrune.allVolumes = lib.mkDefault false;

        ojuny.patch.docker.containers = lib.mkDefault { };

        /*
          @insert
          name = "container";
          group = "Containers";
          order = 10;
        */

        # @option widget = "raw"; label = "Daemon settings"; group = "Advanced"; rows = 6; hidden = true; visibleWhen.path = "ojuny.patch.docker.enable"; visibleWhen.equals = true; description = "dockerd daemon.json settings for the active mode, for example DNS servers or the log driver.";
        ojuny.patch.docker.daemonSettings = lib.mkDefault { };

        virtualisation.docker.enable = lib.mkIf (cfg.enable && cfg.mode == "system") true;
        virtualisation.docker.enableOnBoot = lib.mkIf (cfg.enable && cfg.mode == "system") cfg.enableOnBoot;
        virtualisation.docker.daemon.settings = lib.mkIf (
          cfg.enable && cfg.mode == "system"
        ) cfg.daemonSettings;
        virtualisation.docker.autoPrune.enable = lib.mkIf (
          cfg.enable && cfg.mode == "system"
        ) cfg.autoPrune.enable;
        virtualisation.docker.autoPrune.dates = lib.mkIf (
          cfg.enable && cfg.mode == "system"
        ) cfg.autoPrune.dates;
        virtualisation.docker.autoPrune.flags = lib.mkIf (
          cfg.enable && cfg.mode == "system"
        ) cfg.autoPrune.flags;
        virtualisation.docker.autoPrune.allVolumes.enable = lib.mkIf (cfg.enable && cfg.mode == "system") (
          cfg.autoPrune.enable && cfg.autoPrune.allVolumes
        );

        virtualisation.docker.rootless.enable = lib.mkIf (cfg.enable && cfg.mode == "rootless") true;
        virtualisation.docker.rootless.setSocketVariable = lib.mkIf (
          cfg.enable && cfg.mode == "rootless"
        ) true;
        virtualisation.docker.rootless.daemon.settings = lib.mkIf (
          cfg.enable && cfg.mode == "rootless"
        ) cfg.daemonSettings;

        virtualisation.oci-containers.backend = lib.mkIf (
          cfg.enable && cfg.mode == "system" && cfg.containers != { }
        ) "docker";
        virtualisation.oci-containers.containers = lib.mkIf (cfg.enable && cfg.mode == "system") (
          lib.mapAttrs (_: container: {
            inherit (container)
              image
              ports
              volumes
              environment
              autoStart
              ;
          }) cfg.containers
        );

        assertions = lib.mkIf (cfg.enable && cfg.mode == "rootless") [
          {
            assertion = cfg.containers == { };
            message = "patch-docker: declarative containers are not supported in rootless mode";
          }
        ];
      };
    };
}
