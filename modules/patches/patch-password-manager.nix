/*
  @menu
  displayname = "Password manager";
  icon = "dialog-password-symbolic";
  order = 212;
  description = "KeePassXC vaults with an optional pass or gopass CLI store";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }:

{
  flake.modules.nixos.patch-password-manager =
    {
      config,
      lib,
      ...
    }:
    {
      options.ojuny.patch.password-manager.enable = lib.mkEnableOption "the password manager patch";

      imports = [ self.modules.nixos.password-manager-backend ];

      config = {
        # @option widget = "switch"; label = "Password manager"; group = "Password manager"; description = "Install KeePassXC and open .kdbx vaults with it. Keep the vault in your home directory and the key outside the repository.";
        ojuny.patch.password-manager.enable = false;

        # @option widget = "switch"; label = "KeePassXC"; group = "Password manager"; visibleWhen.path = "ojuny.patch.password-manager.enable"; visibleWhen.equals = true; description = "Install the KeePassXC GUI and keepassxc-cli. The package owns the desktop entry and the .kdbx MIME association.";
        ojuny.patch.password-manager.keepassxc.enable = true;

        # @option widget = "dropdown"; label = "CLI alternative"; group = "Advanced"; choices = [ "none" "pass" "gopass" ]; visibleWhen.path = "ojuny.patch.password-manager.enable"; visibleWhen.equals = true; description = "Optional text- and Git-friendly password store. KeePassXC remains the GUI default.";
        ojuny.patch.password-manager.cli = "none";

        # @option widget = "switch"; label = "Browser integration"; group = "Browser"; visibleWhen.path = "ojuny.patch.password-manager.keepassxc.enable"; visibleWhen.equals = true; description = "Register the KeePassXC native-messaging manifest with Firefox and Chromium. The KeePassXC-Browser extension is still required in the browser.";
        ojuny.patch.password-manager.browserIntegration = false;

        home-manager.sharedModules = lib.mkIf (
          config.ojuny.patch.password-manager.enable && (config.ojuny.patches or true)
        ) [ self.modules.homeManager.password-manager-backend ];
      };
    };

  flake.modules.nixos.password-manager-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      active = config.ojuny.patch.password-manager.enable && (config.ojuny.patches or true);
      cfg = config.ojuny.patch.password-manager // {
        enable = active;
      };
    in
    {
      options.ojuny.patch.password-manager = {
        keepassxc.enable = lib.mkEnableOption "KeePassXC";

        cli = lib.mkOption {
          type = lib.types.enum [
            "none"
            "pass"
            "gopass"
          ];
          default = "none";
          description = "Optional CLI password store. none leaves KeePassXC as the only manager.";
        };

        browserIntegration = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Register the KeePassXC native-messaging manifest with Firefox and Chromium. The browser extension is not installed.";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.keepassxc.enable || cfg.cli != "none";
            message = "patch-password-manager is enabled but KeePassXC and the CLI alternative are both off";
          }
          {
            assertion = !cfg.browserIntegration || cfg.keepassxc.enable;
            message = "ojuny.patch.password-manager.browserIntegration requires KeePassXC to be enabled";
          }
        ];

        environment.systemPackages =
          lib.optional cfg.keepassxc.enable pkgs.keepassxc
          ++ lib.optional (cfg.cli == "pass") pkgs.pass
          ++ lib.optional (cfg.cli == "gopass") pkgs.gopass;

        desktop.ojuny.defaultApps = lib.optional cfg.keepassxc.enable pkgs.keepassxc;

        xdg.mime.enable = lib.mkDefault true;

        xdg.mime.defaultApplications = lib.mkIf cfg.keepassxc.enable {
          "application/x-keepass2" = "org.keepassxc.KeePassXC.desktop";
        };
      };
    };

  flake.modules.homeManager.password-manager-backend =
    {
      lib,
      pkgs,
      osConfig,
      ...
    }:
    let
      cfg = osConfig.ojuny.patch.password-manager;
    in
    {
      config = lib.mkIf (cfg.browserIntegration && (osConfig.ojuny.patches or true)) {
        programs.firefox.nativeMessagingHosts = lib.mkIf (osConfig.programs.firefox.enable or false) [
          pkgs.keepassxc
        ];

        programs.chromium.nativeMessagingHosts = lib.mkIf (osConfig.programs.chromium.enable or false) [
          pkgs.keepassxc
        ];
      };
    };
}
