/*
  @menu
  displayname = "Prism Launcher";
  icon = "minecraft-symbolic";
  order = 180;
  description = "Prism Launcher with per-instance Java and modloaders for Minecraft";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }: {

  flake.modules.nixos.patch-prismlauncher =
    { config, lib, ... }:
    {
      options.ojuny.patch.prismlauncher.enable = lib.mkEnableOption "the Prism Launcher patch";

      # @option widget = "switch"; label = "Prism Launcher"; group = "Minecraft"; description = "Install Prism Launcher. Instances, Java, and modloaders are managed inside Prism.";
      config.ojuny.patch.prismlauncher.enable = false;

      imports = [ self.modules.nixos.prismlauncher-backend ];
    };

  flake.modules.nixos.prismlauncher-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.ojuny.patch.prismlauncher // {
        enable = active;
      };
      active = config.ojuny.patch.prismlauncher.enable && (config.ojuny.patches or true);

      prismlauncherPackage = pkgs.prismlauncher.override {
        inherit (cfg) msaClientID;
        jdks = [
          pkgs.jdk25
          pkgs.jdk21
          pkgs.jdk17
          pkgs.jdk8
        ]
        ++ cfg.extraJdks;
      };
    in
    {
      options.ojuny.patch.prismlauncher = {
        extraJdks = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "Additional Java runtimes for Prism's per-instance Java list. JDK 8, 17, 21, and 25 are always included.";
        };

        msaClientID = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Microsoft OAuth client ID. Null uses Prism's built-in ID. Non-null values rebuild Prism from source.";
        };
      };

      config = {
        # @option widget = "packages"; label = "Extra Java runtimes"; group = "Java"; description = "Add Java runtimes to Prism's per-instance Java list. JDK 8, 17, 21, and 25 are bundled."; advanced = true; visibleWhen.path = "ojuny.patch.prismlauncher.enable"; visibleWhen.equals = true;
        ojuny.patch.prismlauncher.extraJdks = [ ];

        # @option widget = "text"; label = "Microsoft client ID"; group = "Accounts"; description = "Optional OAuth client ID. Leave unset to use Prism's built-in ID. Changing this triggers a full Prism rebuild."; placeholder = "Use Prism's built-in ID"; nullable = true; advanced = true; visibleWhen.path = "ojuny.patch.prismlauncher.enable"; visibleWhen.equals = true;
        ojuny.patch.prismlauncher.msaClientID = null;

        environment.systemPackages = lib.mkIf cfg.enable [
          prismlauncherPackage
        ];
      };
    };
}
