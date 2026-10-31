/*
  @menu
  displayname = "Auxiliary hardware";
  icon = "preferences-system-symbolic";
  order = 190;
  description = "OpenTabletDriver tablet support";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }: {

  flake.modules.nixos.patch-aux-hardware =
    { config, lib, ... }:
    {
      options.ojuny.patch.aux-hardware.enable = lib.mkEnableOption "the auxiliary hardware patch";

      imports = [ self.modules.nixos.aux-hardware-backend ];

      config = {
        # @option widget = "switch"; label = "Auxiliary hardware"; group = "Auxiliary hardware";
        ojuny.patch.aux-hardware.enable = false;

        # @option widget = "switch"; label = "Tablet"; group = "Auxiliary hardware"; visibleWhen.path = "ojuny.patch.aux-hardware.enable"; visibleWhen.equals = true;
        ojuny.patch.aux-hardware.tablet = false;
      };
    };

  flake.modules.nixos.aux-hardware-backend =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.ojuny.patch.aux-hardware // {
        enable = active;
      };
      active = config.ojuny.patch.aux-hardware.enable && (config.ojuny.patches or true);
    in
    {

      options.ojuny.patch.aux-hardware = {
        tablet = lib.mkEnableOption "OpenTabletDriver";
      };

      config = lib.mkIf active {
          hardware.opentabletdriver.enable = cfg.tablet;
          hardware.uinput.enable = cfg.tablet;
      };
    };
}
