/*
  @menu
  displayname = "Distrobox";
  icon = "application-x-executable-symbolic";
  order = 32;
  description = "Container-based distro environments backed by Podman";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }:

{

  flake.modules.nixos.patch-distrobox =
    { config, lib, ... }:
    {
      options.ojuny.patch.distrobox.enable = lib.mkEnableOption "the Distrobox patch";

      # @option widget = "switch"; label = "Distrobox patch"; group = "Patches"; description = "Enable Podman and install Distrobox.";
      config.ojuny.patch.distrobox.enable = false;

      imports = [ self.modules.nixos.distrobox-backend ];
    };

  flake.modules.nixos.distrobox-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      active = config.ojuny.patch.distrobox.enable && (config.ojuny.patches or true);
      cfg = config.ojuny.patch.distrobox // {
        enable = active;
      };
    in
    {
      options.ojuny.patch.distrobox.dockerCompat = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Provide a Docker-compatible Podman socket.";
      };

      config = lib.mkIf cfg.enable {
        # @option widget = "switch"; label = "Docker compatibility"; group = "Distrobox"; visibleWhen.path = "ojuny.patch.distrobox.enable"; visibleWhen.equals = true; description = "Provide a Docker-compatible Podman socket.";
        ojuny.patch.distrobox.dockerCompat = lib.mkDefault true;

        virtualisation.podman.enable = true;
        virtualisation.podman.dockerCompat = cfg.dockerCompat;

        environment.systemPackages = [ pkgs.distrobox ];
      };
    };

}
