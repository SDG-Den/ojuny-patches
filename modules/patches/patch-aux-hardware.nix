/*
  @menu
  displayname = "Auxiliary hardware";
  icon = "preferences-system-symbolic";
  order = 190;
  description = "OpenTabletDriver tablet support";
  category = "Patches";
  systems = [ "all" ];
*/

{ ... }: {

  flake.modules.nixos.patch-aux-hardware =
    {
      config,
      lib,
      ...
    }:
    {

      options.ojuny.patch.aux-hardware = {
        enable = lib.mkEnableOption "the auxiliary hardware patch";
        tablet = lib.mkEnableOption "OpenTabletDriver";
      };

      config = lib.mkMerge [
        {
          # @option widget = "switch"; label = "Auxiliary hardware"; group = "Auxiliary hardware";
          ojuny.patch.aux-hardware.enable = false;

          # @option widget = "switch"; label = "Tablet"; group = "Auxiliary hardware"; visibleWhen.path = "ojuny.patch.aux-hardware.enable"; visibleWhen.equals = true;
          ojuny.patch.aux-hardware.tablet = false;
        }
        (lib.mkIf config.ojuny.patch.aux-hardware.enable {
          hardware.opentabletdriver.enable = config.ojuny.patch.aux-hardware.tablet;
          hardware.uinput.enable = config.ojuny.patch.aux-hardware.tablet;
        })
      ];
    };
}
