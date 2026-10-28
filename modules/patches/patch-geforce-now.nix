/*
  @menu
  displayname = "GeForce NOW";
  icon = "applications-games-symbolic";
  order = 160;
  description = "NVIDIA GeForce NOW native Flatpak client";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }: {

  flake.modules.nixos.patch-geforce-now =
    { config, lib, ... }:
    {
      options.ojuny.patch.geforce-now.enable = lib.mkEnableOption "the GeForce NOW patch";

      # @option widget = "switch"; label = "GeForce NOW"; group = "GeForce NOW";
      config.ojuny.patch.geforce-now.enable = false;

      imports = [ self.modules.nixos.geforce-now-backend ];
    };

  flake.modules.nixos.geforce-now-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      active = config.ojuny.patch.geforce-now.enable && (config.ojuny.patches or true);
      cfg = config.ojuny.patch.geforce-now // {
        enable = active;
      };
    in
    {
      config = lib.mkIf cfg.enable {
        services.flatpak.enable = true;

        systemd.services.ojuny-geforce-now = {
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          serviceConfig.Type = "oneshot";
          unitConfig.ConditionPathExists = "!/var/lib/flatpak/app/com.nvidia.geforcenow";
          script = ''
            ${pkgs.flatpak}/bin/flatpak remote-add --system --if-not-exists \
              GeForceNOW https://international.download.nvidia.com/GFNLinux/flatpak/geforcenow.flatpakrepo
            ${pkgs.flatpak}/bin/flatpak install --system -y --noninteractive \
              GeForceNOW com.nvidia.geforcenow
          '';
        };
      };
    };
}
