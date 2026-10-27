/*
  @menu
  displayname = "Flatpak";
  icon = "system-software-install-symbolic";
  order = 20;
  description = "Sandboxed application distribution via flathub";
  category = "Patches";
  systems = [ "all" ];
*/

{ ... }:

{

  flake.modules.nixos."patch-flatpak" =
    { config, lib, pkgs, ... }:
    let
      cfg = config.ojuny.patch.flatpak;
    in
    {
      options.ojuny.patch.flatpak.enable = lib.mkEnableOption "the Flatpak patch";

      config = lib.mkMerge [
        {
          # @option widget = "switch"; label = "Flatpak patch"; group = "Patches"; description = "Enable Flatpak and the Bazaar application store.";
          ojuny.patch.flatpak.enable = false;
        }

        (lib.mkIf cfg.enable {
          # @option widget = "switch"; label = "Flatpak service"; group = "Flatpak"; description = "Enable the Flatpak service and its xdg portal integration.";
          services.flatpak.enable = true;

          environment.systemPackages = lib.mkIf config.services.flatpak.enable [ pkgs.bazaar ];
        })
      ];
    };

}
