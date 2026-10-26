/*
  @menu
  displayname = "Prism Launcher";
  icon = "minecraft-symbolic";
  order = 180;
  description = "Prism Launcher with per-instance Minecraft setups";
  category = "Patches";
  systems = [ "all" ];
*/

{ ... }: {

  flake.modules.nixos.patch-prismlauncher =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {

      options.ojuny.patch.prismlauncher.enable = lib.mkEnableOption "the Prism Launcher patch";

      config = {
        # @option widget = "switch"; label = "Prism Launcher"; group = "Minecraft";
        ojuny.patch.prismlauncher.enable = false;

        environment.systemPackages = lib.mkIf config.ojuny.patch.prismlauncher.enable [
          pkgs.prismlauncher
        ];
      };
    };
}
