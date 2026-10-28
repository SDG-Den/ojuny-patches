/*
  @menu
  displayname = "Flatpak";
  icon = "system-software-install-symbolic";
  order = 20;
  description = "Sandboxed application distribution via flathub";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }:

{

  flake.modules.nixos."patch-flatpak" =
    { config, lib, ... }:
    {
      options.ojuny.patch.flatpak.enable = lib.mkEnableOption "the Flatpak patch";

      # @option widget = "switch"; label = "Flatpak patch"; group = "Patches"; description = "Enable Flatpak and the Bazaar application store.";
      config.ojuny.patch.flatpak.enable = false;

      imports = [ self.modules.nixos.flatpak-backend ];
    };

  flake.modules.nixos.flatpak-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      active = config.ojuny.patch.flatpak.enable && (config.ojuny.patches or true);
      cfg = config.ojuny.patch.flatpak // {
        enable = active;
      };
    in
    {
      config = lib.mkIf cfg.enable {
        # @option widget = "switch"; label = "Flatpak service"; group = "Flatpak"; description = "Enable the Flatpak service and its xdg portal integration.";
        services.flatpak.enable = true;

        environment.systemPackages = lib.mkIf config.services.flatpak.enable [ pkgs.bazaar ];
      };
    };

}
