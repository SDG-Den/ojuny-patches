/*
  @menu
  displayname = "RetroArch";
  icon = "applications-games-symbolic";
  order = 150;
  description = "RetroArch with libretro cores";
  category = "Patches";
  systems = [ "all" ];
*/

{ ... }: {

  flake.modules.homeManager.patch-retroarch =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {

      options.ojuny.patch.retroarch.enable = lib.mkEnableOption "the RetroArch patch";

      config = lib.mkMerge [
        {
          # @option widget = "switch"; label = "RetroArch"; group = "RetroArch";
          ojuny.patch.retroarch.enable = false;
        }
        (lib.mkIf config.ojuny.patch.retroarch.enable {
          home.packages = with pkgs; [
            retroarch
            retroarch-assets
            libretro-core-info
            retroarch-joypad-autoconfig
            libretro.mgba
            libretro.snes9x
            libretro.gambatte
            libretro.genesis-plus-gx
            libretro.nestopia
            libretro.beetle-psx
            libretro.mupen64plus
            libretro.ppsspp
            libretro.dolphin
            libretro.flycast
            libretro.mame
          ];

          home.file."Games/roms/.keep".text = "";
          home.file."Games/bios/.keep".text = "";

          xdg.configFile."retroarch/retroarch.cfg".text = ''
            video_driver = "vulkan"
            menu_driver = "xmb"
            libretro_directory = "${pkgs.retroarch}/lib/libretro"
            libretro_info_path = "${pkgs.libretro-core-info}/share/libretro/info"
            rgui_browser_directory = "~/Games/roms"
            system_directory = "~/Games/bios"
          '';
        })
      ];
    };
}
