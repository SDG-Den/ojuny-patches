/*
  @menu
  displayname = "Secondary desktop";
  icon = "view-dual-symbolic";
  order = 165;
  description = "KDE Plasma, GNOME, XFCE, COSMIC and Cinnamon session toggles";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }:

{
  flake.modules.nixos.patch-secondary-desktop =
    {
      config,
      lib,
      ...
    }:
    {
      options.ojuny.patch.secondary-desktop.enable = lib.mkEnableOption "the secondary desktop patch";

      # @option widget = "switch"; label = "Secondary desktop"; group = "Patches"; description = "Expose optional desktop sessions without changing the Mango/DMS session.";
      config.ojuny.patch.secondary-desktop.enable = false;

      imports = [ self.modules.nixos.secondary-desktop-backend ];
    };

  flake.modules.nixos.secondary-desktop-backend =
    {
      config,
      lib,
      ...
    }:
    let
      active = config.ojuny.patch.secondary-desktop.enable && (config.ojuny.patches or true);
      cfg = config.ojuny.patch.secondary-desktop // {
        enable = active;
      };
    in
    {
      options.ojuny.patch.secondary-desktop = {
        plasma = lib.mkEnableOption "the KDE Plasma 6 session";

        gnome = lib.mkEnableOption "the GNOME session";

        xfce = lib.mkEnableOption "the XFCE session";

        cosmic = lib.mkEnableOption "the COSMIC session";

        cinnamon = lib.mkEnableOption "the Cinnamon session";
      };

      config = lib.mkMerge [
        {
          # @option widget = "switch"; label = "KDE Plasma 6"; group = "Desktops"; visibleWhen.path = "ojuny.patch.secondary-desktop.enable"; visibleWhen.equals = true; description = "Add KDE Plasma 6 as a login session. Configure it from Plasma's own settings.";
          ojuny.patch.secondary-desktop.plasma = false;

          # @option widget = "switch"; label = "GNOME"; group = "Desktops"; visibleWhen.path = "ojuny.patch.secondary-desktop.enable"; visibleWhen.equals = true; description = "Add GNOME as a login session. Configure it from GNOME's own settings.";
          ojuny.patch.secondary-desktop.gnome = false;

          # @option widget = "switch"; label = "XFCE"; group = "Desktops"; visibleWhen.path = "ojuny.patch.secondary-desktop.enable"; visibleWhen.equals = true; description = "Add XFCE as a login session. Configure it from XFCE's own settings.";
          ojuny.patch.secondary-desktop.xfce = false;

          # @option widget = "switch"; label = "COSMIC"; group = "Desktops"; visibleWhen.path = "ojuny.patch.secondary-desktop.enable"; visibleWhen.equals = true; description = "Add COSMIC as a login session. Configure it from COSMIC's own settings.";
          ojuny.patch.secondary-desktop.cosmic = false;

          # @option widget = "switch"; label = "Cinnamon"; group = "Desktops"; visibleWhen.path = "ojuny.patch.secondary-desktop.enable"; visibleWhen.equals = true; description = "Add Cinnamon as a login session. Configure it from Cinnamon's own settings.";
          ojuny.patch.secondary-desktop.cinnamon = false;
        }

        (lib.mkIf cfg.enable {
          services.desktopManager.plasma6.enable = lib.mkIf cfg.plasma true;
          services.desktopManager.gnome.enable = lib.mkIf cfg.gnome true;
          services.desktopManager.cosmic.enable = lib.mkIf cfg.cosmic true;

          services.xserver.desktopManager.xfce.enable = lib.mkIf cfg.xfce true;
          services.xserver.desktopManager.cinnamon.enable = lib.mkIf cfg.cinnamon true;
          services.xserver.enable = lib.mkIf (cfg.xfce || cfg.cinnamon) true;

          services.displayManager.defaultSession = lib.mkForce "ojuny";
        })
      ];
    };
}
