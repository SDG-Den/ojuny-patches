/*
  @menu
  displayname = "Zed";
  icon = "applications-development-symbolic";
  order = 32;
  description = "Zed editor with Stylix theming and extensions";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }:

{
  flake.modules.nixos.patch-zed =
    {
      config,
      lib,
      ...
    }:
    {
      options.ojuny.patch.zed.enable = lib.mkEnableOption "the Zed patch";

      # @option widget = "switch"; label = "Zed"; group = "Zed"; groupOrder = 10; order = 10; description = "Install and configure Zed with Stylix theming and extensions."
      config.ojuny.patch.zed.enable = false;

      imports = [ self.modules.nixos.zed-backend ];

      config.home-manager.sharedModules = lib.mkIf (
        config.ojuny.patch.zed.enable && (config.ojuny.patches or true)
      ) [ self.modules.homeManager.zed-backend ];
    };

  flake.modules.nixos.zed-backend =
    { lib, ... }:
    {
      options.ojuny.patch.zed = {
        defaultEditor = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Set EDITOR and VISUAL to zeditor --wait.";
        };

        userSettings = lib.mkOption {
          type = lib.types.attrs;
          default = {
            telemetry.metrics = false;
            vim_mode = false;
          };
          description = "Zed settings.json contents. The theme is owned by Stylix.";
        };

        extensions = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "nix" ];
          description = "Zed extensions to install on startup.";
        };

        extraPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "Additional packages made available to Zed.";
        };
      };

      config = {
        # @option widget = "switch"; label = "Default editor"; group = "Integration"; groupOrder = 20; order = 10; visibleWhen.path = "ojuny.patch.zed.enable"; visibleWhen.equals = true; description = "Set EDITOR and VISUAL to zeditor --wait. Turn this off if another editor patch or your shell config already owns them."
        ojuny.patch.zed.defaultEditor = false;

        # @option widget = "raw"; rows = 10; label = "Settings"; group = "Settings"; groupOrder = 30; order = 10; visibleWhen.path = "ojuny.patch.zed.enable"; visibleWhen.equals = true; description = "Zed settings.json contents. The theme key is owned by Stylix."
        ojuny.patch.zed.userSettings = {
          telemetry.metrics = false;
          vim_mode = false;
        };

        # @option widget = "list"; label = "Extensions"; group = "Extensions"; groupOrder = 40; order = 10; visibleWhen.path = "ojuny.patch.zed.enable"; visibleWhen.equals = true; description = "Zed extensions to install on startup, by extension repository name."
        ojuny.patch.zed.extensions = [ "nix" ];

        # @option widget = "packages"; label = "Extra packages"; group = "Extra packages"; groupOrder = 50; order = 10; visibleWhen.path = "ojuny.patch.zed.enable"; visibleWhen.equals = true; description = "Additional packages made available to Zed, for example language servers."
        ojuny.patch.zed.extraPackages = [ ];
      };
    };

  flake.modules.homeManager.zed-backend =
    {
      lib,
      pkgs,
      osConfig ? { },
      ...
    }:
    let
      cfg =
        (osConfig.ojuny.patch.zed or {
          enable = false;
          defaultEditor = false;
          userSettings = { };
          extensions = [ ];
          extraPackages = [ ];
        }
        )
        // {
          enable = (osConfig.ojuny.patch.zed.enable or false) && (osConfig.ojuny.patches or true);
        };

      extensionPackages = lib.optionals (builtins.elem "nix" cfg.extensions) [ pkgs.nixd ];
    in
    {
      config = lib.mkIf cfg.enable {
        programs.zed-editor = {
          enable = true;
          defaultEditor = cfg.defaultEditor;
          userSettings = cfg.userSettings;
          extensions = cfg.extensions;
          extraPackages = extensionPackages ++ cfg.extraPackages;
        };

        stylix.targets.zed.enable = lib.mkDefault true;
      };
    };
}
