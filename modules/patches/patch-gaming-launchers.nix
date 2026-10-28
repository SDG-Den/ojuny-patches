/*
  @menu
  displayname = "Gaming launchers";
  icon = "applications-games-symbolic";
  order = 185;
  description = "Lutris and Heroic with Wine and Proton";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }: {

  flake.modules.nixos.patch-gaming-launchers =
    { config, lib, ... }:
    {
      options.ojuny.patch.gaming-launchers.enable =
        lib.mkEnableOption "the Lutris and Heroic gaming launchers patch";

      # @option widget = "switch"; label = "Gaming launchers"; group = "Gaming launchers"; description = "Install Lutris and Heroic with Wine and Proton.";
      config.ojuny.patch.gaming-launchers.enable = false;

      imports = [ self.modules.nixos.gaming-launchers-backend ];
    };

  flake.modules.nixos.gaming-launchers-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      active = config.ojuny.patch.gaming-launchers.enable && (config.ojuny.patches or true);
      cfg = config.ojuny.patch.gaming-launchers // {
        enable = active;
      };

      launcherEnabled = cfg.lutris.enable || cfg.heroic.enable;

      launcherPackages =
        lib.optionals cfg.lutris.enable [ pkgs.lutris ] ++ lib.optionals cfg.heroic.enable [ pkgs.heroic ];

      wineTools =
        lib.optionals cfg.wine.winetricks [ pkgs.winetricks ]
        ++ lib.optionals cfg.wine.protontricks [ pkgs.protontricks ];

      sharedPackages = [
        pkgs.umu-launcher
        cfg.wine.package
      ]
      ++ wineTools;
    in
    {
      options.ojuny.patch.gaming-launchers = {
        lutris.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install Lutris and its Wine, DXVK and VKD3D tooling.";
        };

        heroic.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install Heroic Games Launcher for Epic, GOG and Amazon games.";
        };

        wine = {
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.wineWow64Packages.stable;
            description = "System Wine build. Use wineWow64Packages.staging for staging patches, or stableFull to embed Mono and Gecko.";
          };

          winetricks = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Install winetricks for Windows runtime components in a Wine prefix.";
          };

          protontricks = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Install protontricks for Steam Proton prefixes. It needs Steam's runtime.";
          };
        };

        protonGE = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Offer Proton GE to Steam Play when Steam is enabled. Lutris and Heroic download their own runtimes.";
        };
      };

      config = lib.mkMerge [
        {
          # @option widget = "switch"; label = "Lutris"; group = "Launchers"; description = "Install Lutris. It fetches DXVK and VKD3D on first launch."; visibleWhen.path = "ojuny.patch.gaming-launchers.enable"; visibleWhen.equals = true;
          ojuny.patch.gaming-launchers.lutris.enable = true;

          # @option widget = "switch"; label = "Heroic"; group = "Launchers"; description = "Install Heroic for Epic, GOG and Amazon games. It fetches its Wine and Proton runtimes on demand."; visibleWhen.path = "ojuny.patch.gaming-launchers.enable"; visibleWhen.equals = true;
          ojuny.patch.gaming-launchers.heroic.enable = true;

          # @option widget = "package"; label = "Wine package"; group = "Wine and Proton"; description = "System Wine build. wineWow64Packages.stable is the default; staging or stableFull are alternatives."; visibleWhen.path = "ojuny.patch.gaming-launchers.enable"; visibleWhen.equals = true;
          ojuny.patch.gaming-launchers.wine.package = pkgs.wineWow64Packages.stable;

          # @option widget = "switch"; label = "Winetricks"; group = "Wine and Proton"; description = "Install winetricks to add Windows runtime components to a Wine prefix."; visibleWhen.path = "ojuny.patch.gaming-launchers.enable"; visibleWhen.equals = true;
          ojuny.patch.gaming-launchers.wine.winetricks = true;

          # @option widget = "switch"; label = "Protontricks"; group = "Wine and Proton"; description = "Install protontricks for Steam Proton prefixes. Requires Steam and its runtime."; visibleWhen.path = "ojuny.patch.gaming-launchers.enable"; visibleWhen.equals = true;
          ojuny.patch.gaming-launchers.wine.protontricks = false;

          # @option widget = "switch"; label = "Proton GE for Steam"; group = "Wine and Proton"; description = "Add Proton GE to Steam Play when Steam is enabled. It is not added to system packages."; visibleWhen.path = "ojuny.patch.gaming-launchers.enable"; visibleWhen.equals = true;
          ojuny.patch.gaming-launchers.protonGE = true;
        }
        (lib.mkIf cfg.enable {
          environment.systemPackages = lib.optionals launcherEnabled (launcherPackages ++ sharedPackages);

          hardware.graphics.enable = lib.mkIf launcherEnabled true;

          programs.steam.extraCompatPackages = lib.mkIf (cfg.protonGE && config.programs.steam.enable) [
            pkgs.proton-ge-bin
          ];
        })
      ];
    };
}
