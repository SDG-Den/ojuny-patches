/*
  @menu
  displayname = "Signal";
  icon = "internet-chat-symbolic";
  order = 45;
  description = "Signal Desktop with sgnl:// link handling";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }:

{
  flake.modules.nixos.patch-signal =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.ojuny.patch.signal.enable = lib.mkEnableOption "the Signal Desktop patch";

      imports = [ self.modules.nixos.signal-backend ];

      config = {
        # @option widget = "switch"; label = "Signal Desktop patch"; group = "Patches"; description = "Enable the Signal Desktop patch.";
        ojuny.patch.signal.enable = false;

        # @option widget = "switch"; label = "Handle sgnl:// links"; group = "Signal"; visibleWhen.path = "ojuny.patch.signal.enable"; visibleWhen.equals = true; description = "Set Signal as the default handler for sgnl:// and signalcaptcha:// links.";
        ojuny.patch.signal.setDefaultUriHandler = true;

        # @option widget = "switch"; label = "Add to launcher defaults"; group = "Signal"; visibleWhen.path = "ojuny.patch.signal.enable"; visibleWhen.equals = true; description = "Expose Signal to desktop.ojuny.defaultApps.";
        ojuny.patch.signal.addToDefaultApps = true;

        # @option widget = "package"; label = "Signal package"; group = "Advanced"; hidden = true; visibleWhen.path = "ojuny.patch.signal.enable"; visibleWhen.equals = true; description = "Override the Signal package, for example with a newer nixpkgs if the host package is expired.";
        ojuny.patch.signal.package = pkgs.signal-desktop;

        # @option widget = "list"; label = "Extra launch flags"; group = "Advanced"; hidden = true; visibleWhen.path = "ojuny.patch.signal.enable"; visibleWhen.equals = true; description = "Extra arguments for signal-desktop, for example --ozone-platform=x11.";
        ojuny.patch.signal.extraFlags = [ ];
      };
    };

  flake.modules.nixos.signal-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      active = config.ojuny.patch.signal.enable && (config.ojuny.patches or true);
      cfg = config.ojuny.patch.signal // {
        enable = active;
      };

      launchFlags = lib.filter (flag: flag != "") cfg.extraFlags;

      defaultDesktopFile =
        if lib.versionOlder cfg.package.version "8.0.0" then "signal-desktop.desktop" else "signal.desktop";

      signalPackage =
        if launchFlags == [ ] then
          cfg.package
        else
          pkgs.symlinkJoin {
            name = "signal-desktop-${cfg.package.version}";
            paths = [ cfg.package ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/signal-desktop ${
                lib.concatMapStringsSep " " (flag: "--add-flags ${lib.escapeShellArg flag}") launchFlags
              }
            '';
          };
    in
    {
      options.ojuny.patch.signal = {
        setDefaultUriHandler = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Set the selected desktop file as the default handler for sgnl:// and signalcaptcha:// links.";
        };

        addToDefaultApps = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Add Signal to desktop.ojuny.defaultApps so launcher and default-app actions resolve it.";
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.signal-desktop;
          description = "Signal Desktop package. Override with a newer nixpkgs if the host package is expired.";
        };

        desktopFile = lib.mkOption {
          type = lib.types.str;
          default = defaultDesktopFile;
          description = "Desktop file ID used for URI defaults. nixpkgs 7.x ships signal-desktop.desktop; 8.x ships signal.desktop.";
        };

        extraFlags = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra flags passed to signal-desktop. Use --ozone-platform=x11 only for Wayland troubleshooting.";
        };
      };

      config = lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = lib.hasSuffix ".desktop" cfg.desktopFile;
              message = "ojuny.patch.signal.desktopFile must end in .desktop";
            }
          ];

          environment.systemPackages = [ signalPackage ];

          desktop.ojuny.defaultApps = lib.optional cfg.addToDefaultApps signalPackage;

          xdg.mime.defaultApplications = lib.mkIf cfg.setDefaultUriHandler {
            "x-scheme-handler/sgnl" = cfg.desktopFile;
            "x-scheme-handler/signalcaptcha" = cfg.desktopFile;
          };
      };
    };
}
