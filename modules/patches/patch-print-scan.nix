/*
  @menu
  displayname = "Printing and Scanning";
  icon = "printer-symbolic";
  order = 210;
  description = "CUPS printing with Avahi discovery and optional SANE scanning";
  category = "Patches";
  systems = [ "all" ];
*/

{ ... }: {

  flake.modules.nixos.patch-print-scan =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.ojuny.patch.print-scan;

      discovery =
        cfg.enable
        && cfg.networkDiscovery
        && (cfg.printing.enable || cfg.scanning.enable);
    in
    {
      options.ojuny.patch.print-scan = {
        enable = lib.mkEnableOption "printing and scanning support";

        networkDiscovery = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable Avahi and nssmdns4 for network printer and scanner discovery.";
        };

        printing = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable CUPS printing.";
          };

          drivers = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ pkgs.gutenprint pkgs.hplip ];
            description = "Extra CUPS drivers. Driverless IPP Everywhere printers do not need an entry.";
          };

          browsed = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable cups-browsed for legacy CUPS browse protocols. Requires network discovery.";
          };

          openFirewall = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Open the CUPS listen ports. With the default localhost listener this opens nothing.";
          };
        };

        scanning = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable SANE scanning and install a scanner application.";
          };

          app = lib.mkOption {
            type = lib.types.package;
            default = pkgs.simple-scan;
            description = "Graphical scanner application.";
          };

          extraBackends = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ pkgs.sane-airscan ];
            description = "Extra SANE backends. sane-airscan covers eSCL and AirScan devices.";
          };

          openFirewall = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Open SANE discovery ports for protocols such as Canon BJNP.";
          };
        };
      };

      config = {
        # @option widget = "switch"; label = "Printing and scanning patch"; group = "Patch"; description = "Enable CUPS printing with optional SANE scanning.";
        ojuny.patch.print-scan.enable = false;

        # @option widget = "switch"; label = "Printing"; group = "Printing"; description = "Enable CUPS and the common printer drivers."; visibleWhen.path = "ojuny.patch.print-scan.enable"; visibleWhen.equals = true;
        ojuny.patch.print-scan.printing.enable = true;

        # @option widget = "packages"; label = "Printer drivers"; group = "Printing"; description = "Extra CUPS drivers. Driverless IPP Everywhere printers do not need an entry."; visibleWhen.path = "ojuny.patch.print-scan.printing.enable"; visibleWhen.equals = true;
        ojuny.patch.print-scan.printing.drivers = [ pkgs.gutenprint pkgs.hplip ];

        # @option widget = "switch"; label = "Network discovery"; group = "Discovery"; description = "Enable Avahi and nssmdns4 for network printers and scanners. Opens UDP 5353."; visibleWhen.path = "ojuny.patch.print-scan.enable"; visibleWhen.equals = true;
        ojuny.patch.print-scan.networkDiscovery = true;

        # @option widget = "switch"; label = "Legacy CUPS browsing"; group = "Printing"; description = "Enable cups-browsed. Only needed for older CUPS browse protocols."; advanced = true; visibleWhen.path = "ojuny.patch.print-scan.printing.enable"; visibleWhen.equals = true;
        ojuny.patch.print-scan.printing.browsed = false;

        # @option widget = "switch"; label = "Open printing firewall"; group = "Advanced"; description = "Open the CUPS listen ports. Only useful when CUPS listens beyond localhost."; hidden = true; visibleWhen.path = "ojuny.patch.print-scan.printing.enable"; visibleWhen.equals = true;
        ojuny.patch.print-scan.printing.openFirewall = false;

        # @option widget = "switch"; label = "Scanning"; group = "Scanning"; description = "Enable SANE and install a scanner application."; visibleWhen.path = "ojuny.patch.print-scan.enable"; visibleWhen.equals = true;
        ojuny.patch.print-scan.scanning.enable = false;

        # @option widget = "package"; label = "Scanner application"; group = "Scanning"; description = "Graphical application used for scanning."; visibleWhen.path = "ojuny.patch.print-scan.scanning.enable"; visibleWhen.equals = true;
        ojuny.patch.print-scan.scanning.app = pkgs.simple-scan;

        # @option widget = "packages"; label = "SANE backends"; group = "Scanning"; description = "Extra SANE backends. sane-airscan covers eSCL and AirScan devices."; visibleWhen.path = "ojuny.patch.print-scan.scanning.enable"; visibleWhen.equals = true;
        ojuny.patch.print-scan.scanning.extraBackends = [ pkgs.sane-airscan ];

        # @option widget = "switch"; label = "Open scanning firewall"; group = "Advanced"; description = "Open SANE discovery ports for protocols such as Canon BJNP."; hidden = true; visibleWhen.path = "ojuny.patch.print-scan.scanning.enable"; visibleWhen.equals = true;
        ojuny.patch.print-scan.scanning.openFirewall = false;

        services.printing.enable = lib.mkIf (cfg.enable && cfg.printing.enable) true;
        services.printing.drivers = lib.mkIf (cfg.enable && cfg.printing.enable) cfg.printing.drivers;
        services.printing.openFirewall = lib.mkIf (cfg.enable && cfg.printing.enable) cfg.printing.openFirewall;

        # Force a real false when the patch is on but printing or discovery is off.
        # Otherwise the NixOS default would inherit config.services.avahi.enable.
        services.printing.browsed.enable = lib.mkIf cfg.enable (
          cfg.printing.enable && cfg.printing.browsed && cfg.networkDiscovery
        );

        services.avahi.enable = lib.mkIf discovery true;
        services.avahi.nssmdns4 = lib.mkIf discovery true;

        hardware.sane.enable = lib.mkIf (cfg.enable && cfg.scanning.enable) true;
        hardware.sane.extraBackends = lib.mkIf (cfg.enable && cfg.scanning.enable) cfg.scanning.extraBackends;
        hardware.sane.openFirewall = lib.mkIf (cfg.enable && cfg.scanning.enable) cfg.scanning.openFirewall;

        environment.systemPackages = lib.mkIf (cfg.enable && cfg.scanning.enable) [
          cfg.scanning.app
        ];
      };
    };
}
