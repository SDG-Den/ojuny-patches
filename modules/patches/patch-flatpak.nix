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
    {

      # @option widget = "switch"; label = "Flatpak"; group = "Flatpak"; description = "Enable the Flatpak service and its xdg portal integration.";
      services.flatpak.enable = true;

      environment.systemPackages = lib.mkIf config.services.flatpak.enable [ pkgs.bazaar ];

    };

}
