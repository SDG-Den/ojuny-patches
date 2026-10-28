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
      pkgs,
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

        appindicator = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install the AppIndicator extension and enable it for the GNOME shell.";
        };

        games = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the GNOME games collection.";
        };

        excludePackages = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Exclude the GNOME tour and user documentation packages.";
        };

        gcrSshAgent = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the GCR SSH agent for any secondary desktop session.";
        };
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

          # @option widget = "switch"; label = "AppIndicator"; group = "GNOME"; visibleWhen.path = "ojuny.patch.secondary-desktop.gnome"; visibleWhen.equals = true; description = "Install the AppIndicator extension and enable it. Provides a status notifier watcher for tray applications.";
          ojuny.patch.secondary-desktop.appindicator = true;

          # @option widget = "switch"; label = "GNOME games"; group = "GNOME"; visibleWhen.path = "ojuny.patch.secondary-desktop.gnome"; visibleWhen.equals = true; description = "Install the GNOME games collection.";
          ojuny.patch.secondary-desktop.games = false;

          # @option widget = "switch"; label = "Exclude GNOME extras"; group = "GNOME"; visibleWhen.path = "ojuny.patch.secondary-desktop.gnome"; visibleWhen.equals = true; description = "Exclude gnome-tour and gnome-user-docs from the GNOME session.";
          ojuny.patch.secondary-desktop.excludePackages = true;

          # @option widget = "switch"; label = "GCR SSH agent"; group = "Desktops"; visibleWhen.path = "ojuny.patch.secondary-desktop.enable"; visibleWhen.equals = true; description = "Enable the GCR SSH agent. Available with GNOME, XFCE, and the other secondary sessions.";
          ojuny.patch.secondary-desktop.gcrSshAgent = true;
        }

        (lib.mkIf cfg.enable {
          services.desktopManager.plasma6.enable = lib.mkIf cfg.plasma true;
          services.desktopManager.gnome.enable = lib.mkIf cfg.gnome true;
          services.desktopManager.cosmic.enable = lib.mkIf cfg.cosmic true;

          services.xserver.desktopManager.xfce.enable = lib.mkIf cfg.xfce true;
          services.xserver.desktopManager.cinnamon.enable = lib.mkIf cfg.cinnamon true;
          services.xserver.enable = lib.mkIf (cfg.xfce || cfg.cinnamon) true;

          services.gnome.gcr-ssh-agent.enable = cfg.gcrSshAgent;

          services.gnome.games.enable = lib.mkIf (cfg.gnome && cfg.games) true;

          environment.gnome.excludePackages = lib.mkIf (cfg.gnome && cfg.excludePackages) (
            with pkgs;
            [
              gnome-tour
              gnome-user-docs
            ]
          );

          environment.systemPackages = lib.mkIf (cfg.gnome && cfg.appindicator) [
            pkgs.gnomeExtensions.appindicator
          ];

          programs.dconf.profiles.user.databases = lib.mkIf (cfg.gnome && cfg.appindicator) [
            {
              settings."org/gnome/shell" = {
                enabled-extensions = [ pkgs.gnomeExtensions.appindicator.extensionUuid ];
                disable-user-extensions = false;
              };
            }
          ];

          services.displayManager.defaultSession = lib.mkForce "ojuny";
        })
      ];
    };
}
