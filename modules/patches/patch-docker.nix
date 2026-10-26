/*
  @menu
  displayname = "Docker";
  icon = "applications-system-symbolic";
  order = 30;
  description = "Docker daemon, pruning and declarative containers";
  category = "Patches";
  systems = [ "all" ];
*/

/*
  @snippet
  name = "container";
  label = "Add container";
  snippet = ''
    # @option widget = "text"; label = "%%name%% image"; group = "Containers"; description = "OCI image with tag, e.g. nginx:latest.";
    virtualisation.oci-containers.containers."%%name%%".image = "%%image%%";
    # @option widget = "list"; label = "%%name%% ports"; group = "Containers"; description = "Published ports, e.g. 127.0.0.1:8080:8080.";
    virtualisation.oci-containers.containers."%%name%%".ports = [ ];
    # @option widget = "list"; label = "%%name%% volumes"; group = "Containers"; description = "Host:container mounts, e.g. nginx-html:/usr/share/nginx/html.";
    virtualisation.oci-containers.containers."%%name%%".volumes = [ ];
    # @option widget = "raw"; label = "%%name%% environment"; group = "Containers"; rows = 4; description = "Environment variables as a Nix attrset.";
    virtualisation.oci-containers.containers."%%name%%".environment = { };
    # @option widget = "switch"; label = "%%name%% start at boot"; group = "Containers"; description = "Start the container with systemd on boot.";
    virtualisation.oci-containers.containers."%%name%%".autoStart = true;
  '';
  placeholders.name.label = "Container name";
  placeholders.name.default = "nginx";
  placeholders.image.label = "Image";
  placeholders.image.default = "nginx:latest";
*/

{ self, inputs, ... }:

{

  flake.modules.nixos.patch-docker = { config, lib, ... }: {
    options.ojuny.patch.docker.enable = lib.mkEnableOption "the docker patch";
    # @option widget = "switch"; label = "Docker patch"; group = "Patches"; description = "Enable the docker patch.";
    config.ojuny.patch.docker.enable = false;

    imports = [
      ((import ./_gate.nix { inherit lib; })
        (args: args.config.ojuny.patches && args.config.ojuny.patch.docker.enable)
        self.modules.nixos.docker-backend)
    ];

  };

  flake.modules.nixos.docker-backend =
    { config, lib, ... }:
    {

      # @option widget = "switch"; label = "Docker"; group = "Docker"; description = "Run the dockerd daemon. Members of the docker group can control it without sudo.";
      virtualisation.docker.enable = true;

      # @option widget = "switch"; label = "Start on boot"; group = "Docker"; visibleWhen.path = "virtualisation.docker.enable"; visibleWhen.equals = true; description = "Start dockerd at boot. Required for containers using --restart=always.";
      virtualisation.docker.enableOnBoot =  true;

      # @option widget = "switch"; label = "Automatic pruning"; group = "Docker"; visibleWhen.path = "virtualisation.docker.enable"; visibleWhen.equals = true; description = "Run docker system prune on a schedule.";
      virtualisation.docker.autoPrune.enable =  false;

      # @option widget = "text"; label = "Prune schedule"; group = "Docker"; visibleWhen.path = "virtualisation.docker.autoPrune.enable"; visibleWhen.equals = true; description = "systemd calendar spec, e.g. weekly or daily 03:00.";
      virtualisation.docker.autoPrune.dates =  "weekly";

      # @option widget = "list"; label = "Prune flags"; group = "Docker"; visibleWhen.path = "virtualisation.docker.autoPrune.enable"; visibleWhen.equals = true; hidden = true; description = "Extra arguments for docker system prune, e.g. --volumes.";
      virtualisation.docker.autoPrune.flags =  [ ];

      # @option widget = "switch"; label = "Prune volumes"; group = "Docker"; visibleWhen.path = "virtualisation.docker.autoPrune.enable"; visibleWhen.equals = true; hidden = true; description = "Also run docker volume prune --force --all.";
      virtualisation.docker.autoPrune.allVolumes.enable = false;

      # @option widget = "switch"; label = "Rootless mode"; group = "Advanced"; hidden = true; description = "Run the daemon as an unprivileged user instead of the system service.";
      virtualisation.docker.rootless.enable = false;

      # @option widget = "switch"; label = "Rootless DOCKER_HOST"; group = "Advanced"; visibleWhen.path = "virtualisation.docker.rootless.enable"; visibleWhen.equals = true; hidden = true; description = "Export DOCKER_HOST to the rootless socket in the user session.";
      virtualisation.docker.rootless.setSocketVariable = true;

      # @option widget = "raw"; label = "Daemon settings"; group = "Advanced"; rows = 6; hidden = true; description = "dockerd configuration written to daemon.json, e.g. dns, log-driver, storage-driver.";
      virtualisation.docker.daemon.settings =  { };

      # @option widget = "dropdown"; label = "Container engine"; group = "Containers"; visibleWhen.path = "virtualisation.docker.enable"; visibleWhen.equals = true; choices = [ "docker" "podman" ]; description = "Backend that runs the declarative containers below.";
      virtualisation.oci-containers.backend =  "docker";

      /*
        @insert
        name = "container";
        group = "Containers";
        order = 10;
      */

    };

}
