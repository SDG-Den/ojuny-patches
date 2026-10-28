/*
  @menu
  displayname = "Custom Fastfetch";
  icon = "utilities-terminal-symbolic";
  order = 60;
  description = "Fully configurable fastfetch settings through a raw GUI option";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }:

{
  flake.modules.nixos.patch-custom-fastfetch =
    { config, lib, ... }:
    {
      options.ojuny.patch.custom-fastfetch.enable = lib.mkEnableOption "the custom fastfetch patch";

      # @option widget = "switch"; label = "Custom fastfetch"; group = "Fastfetch"; description = "Replace the template fastfetch settings with the raw configuration below.";
      config.ojuny.patch.custom-fastfetch.enable = false;

      imports = [ self.modules.nixos.custom-fastfetch-backend ];

      config.home-manager.sharedModules = lib.mkIf (
        config.ojuny.patch.custom-fastfetch.enable && (config.ojuny.patches or true)
      ) [ self.modules.homeManager.custom-fastfetch-backend ];
    };

  flake.modules.nixos.custom-fastfetch-backend =
    { lib, ... }:
    {
      options.ojuny.patch.custom-fastfetch.settings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Complete programs.fastfetch.settings value. An empty set keeps the template defaults.";
      };

      config = {
        # @option widget = "raw"; label = "Fastfetch settings"; group = "Fastfetch"; rows = 16; visibleWhen.path = "ojuny.patch.custom-fastfetch.enable"; visibleWhen.equals = true; description = "Complete programs.fastfetch.settings value. An empty set keeps the template defaults; a non-empty set replaces them.";
        ojuny.patch.custom-fastfetch.settings = { };
      };
    };

  flake.modules.homeManager.custom-fastfetch-backend =
    {
      lib,
      osConfig ? { },
      ...
    }:
    let
      active =
        (osConfig.ojuny.patch.custom-fastfetch.enable or false) && (osConfig.ojuny.patches or true);
      settings = osConfig.ojuny.patch.custom-fastfetch.settings or { };
    in
    {
      config = lib.mkIf (active && settings != { }) {
        programs.fastfetch.settings = lib.mkForce settings;
      };
    };
}
