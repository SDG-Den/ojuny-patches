/*
  @menu
  displayname = "RetroArch";
  icon = "applications-games-symbolic";
  order = 150;
  description = "RetroArch with libretro cores";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }: {

  flake.modules.nixos.patch-retroarch =
    { config, lib, ... }:
    {
      options.ojuny.patch.retroarch.enable = lib.mkEnableOption "the RetroArch patch";

      # @option widget = "switch"; label = "RetroArch"; group = "RetroArch";
      config.ojuny.patch.retroarch.enable = false;

      config.home-manager.sharedModules = lib.mkIf (
        config.ojuny.patch.retroarch.enable && (config.ojuny.patches or true)
      ) [ self.modules.homeManager.retroarch-backend ];
    };

  flake.modules.homeManager.retroarch-backend =
    {
      lib,
      pkgs,
      osConfig,
      ...
    }:
    let
      cfg = osConfig.ojuny.patch.retroarch;
    in
    {
      config = lib.mkIf (cfg.enable && (osConfig.ojuny.patches or true)) {
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
      };
    };
}
