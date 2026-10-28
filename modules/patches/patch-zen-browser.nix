/*
  @menu
  displayname = "Zen Browser";
  icon = "web-browser-symbolic";
  order = 55;
  description = "Zen Browser with optional default-browser registration";
  category = "Patches";
  systems = [ "all" ];
*/

# @inputs name = "zen-browser"; url = "github:youwen5/zen-browser-flake";

{ self, inputs, ... }:
let
  hasZen = inputs ? zen-browser;
in
{
  flake.modules.nixos.patch-zen-browser =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.ojuny.patch.zen-browser;
      zenPackage =
        if hasZen then inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default else null;
      browserDesktop = "zen.desktop";
      browserAssociations = {
        "text/html" = browserDesktop;
        "application/xhtml+xml" = browserDesktop;
        "x-scheme-handler/http" = browserDesktop;
        "x-scheme-handler/https" = browserDesktop;
        "application/pdf" = browserDesktop;
        "x-scheme-handler/mailto" = browserDesktop;
      };
    in
    {
      options.ojuny.patch.zen-browser = {
        enable = lib.mkEnableOption "Zen Browser";

        defaultBrowser = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Register Zen as the default browser for web, PDF, and mail links.";
        };

        browserBind = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Point the Mango browser keybind at Zen instead of Firefox.";
        };
      };

      config = lib.mkMerge [
        {
          # @option widget = "switch"; label = "Zen Browser"; group = "Zen Browser"; description = "Install Zen Browser.";
          ojuny.patch.zen-browser.enable = false;

          # @option widget = "switch"; label = "Default browser"; group = "Zen Browser"; visibleWhen.path = "ojuny.patch.zen-browser.enable"; visibleWhen.equals = true; description = "Register Zen for web, PDF, and mail links.";
          ojuny.patch.zen-browser.defaultBrowser = true;

          # @option widget = "switch"; label = "Browser keybind"; group = "Zen Browser"; visibleWhen.path = "ojuny.patch.zen-browser.enable"; visibleWhen.equals = true; description = "Point the Mango browser keybind at Zen.";
          ojuny.patch.zen-browser.browserBind = true;
        }
        (lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = hasZen;
              message = "ojuny.patch.zen-browser requires inputs.zen-browser. Add github:youwen5/zen-browser-flake to the host flake.";
            }
          ];

          environment.systemPackages = lib.optional hasZen zenPackage;

          desktop.ojuny.defaultApps = lib.optional hasZen zenPackage;

          desktop.ojuny.mango.binds.common.browser = lib.mkIf cfg.browserBind {
            args = lib.mkForce "zen --new-window";
          };

          xdg.mime.enable = lib.mkDefault true;

          xdg.mime.defaultApplications = lib.mkIf cfg.defaultBrowser (
            lib.mapAttrs (_: desktop: lib.mkForce desktop) browserAssociations
          );

          xdg.mime.addedAssociations = lib.mkIf cfg.defaultBrowser (
            lib.mapAttrs (_: desktop: lib.mkForce [ desktop ]) browserAssociations
          );
        })
      ];
    };
}
