/*
  @menu
  displayname = "Multi-kernel";
  icon = "applications-system-symbolic";
  order = 210;
  description = "Install and select multiple Linux kernels at boot";
  category = "Patches";
  systems = [ "all" ];
*/

{ ... }:

{
  flake.modules.nixos.patch-multi-kernel =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.ojuny.patch.multi-kernel;

      ltsAttempt = builtins.tryEval (pkgs.linuxPackages_lts or null);
      ltsPackages =
        if ltsAttempt.success && ltsAttempt.value != null then
          ltsAttempt.value
        else
          pkgs.linuxPackages_6_12;

      hardenedAttempt = builtins.tryEval (pkgs.linuxPackages_hardened or null);
      hasHardened = hardenedAttempt.success && hardenedAttempt.value != null;

      kernelSets =
        {
          default = pkgs.linuxPackages;
          latest = pkgs.linuxPackages_latest;
          lts = ltsPackages;
          zen = pkgs.linuxPackages_zen;
        }
        // lib.optionalAttrs hasHardened {
          hardened = hardenedAttempt.value;
        };

      available =
        [
          "default"
          "latest"
          "lts"
          "zen"
        ]
        ++ lib.optional hasHardened "hardened";

      extras = lib.filter (name: builtins.hasAttr name cfg.kernelPackages) (
        lib.subtractLists [ cfg.selected ] cfg.kernels
      );

      selectedPackages = cfg.kernelPackages.${cfg.selected} or pkgs.linuxPackages;

      extraSpecialisations = lib.listToAttrs (
        map (name: {
          name = "kernel-${name}";
          value.configuration.ojuny.patch.multi-kernel.selected = lib.mkForce name;
        }) extras
      );
    in
    {
      options.ojuny.patch.multi-kernel = {
        enable = lib.mkEnableOption "the multi-kernel patch";

        selected = lib.mkOption {
          type = lib.types.enum available;
          default = "default";
          description = "Kernel package set for the generation that boots by default. Takes effect after a rebuild and reboot.";
        };

        multiBoot = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Build specialisations for additional kernels so the boot menu lists more than one kernel.";
        };

        kernels = lib.mkOption {
          type = lib.types.listOf (lib.types.enum available);
          default = [
            "default"
            "latest"
          ];
          description = "Kernel package sets to expose when multiBoot is enabled. The selected kernel is always the base generation and is not duplicated.";
        };

        generationLimit = lib.mkOption {
          type = lib.types.int;
          default = 5;
          description = "Boot menu generations to keep when multiBoot is enabled. Lower this on small EFI partitions.";
        };

        kernelPackages = lib.mkOption {
          type = lib.types.attrsOf lib.types.raw;
          default = kernelSets;
          description = "Kernel package sets keyed by selector name. Override a value to replace the kernel behind a name; the keys must match the selector enum.";
        };
      };

      config = {
        # @option widget = "switch"; label = "Multi-kernel patch"; group = "Patches"; description = "Enable installing and selecting multiple Linux kernels.";
        ojuny.patch.multi-kernel.enable = false;

        # @option widget = "dropdown"; label = "Default kernel"; group = "Kernel"; choices = [ "default" "latest" "lts" "zen" ]; visibleWhen.path = "ojuny.patch.multi-kernel.enable"; visibleWhen.equals = true; description = "Kernel used by the next generation. Save and rebuild, then reboot; this does not switch the running kernel.";
        ojuny.patch.multi-kernel.selected = "default";

        # @option widget = "switch"; label = "Additional boot entries"; group = "Kernel"; visibleWhen.path = "ojuny.patch.multi-kernel.enable"; visibleWhen.equals = true; description = "Build kernel specialisations so the boot menu lists more than one kernel.";
        ojuny.patch.multi-kernel.multiBoot = false;

        # @option widget = "list"; label = "Kernels"; group = "Kernel"; visibleWhen.path = "ojuny.patch.multi-kernel.multiBoot"; visibleWhen.equals = true; description = "Kernel package sets to add as boot entries. The default kernel is always present.";
        ojuny.patch.multi-kernel.kernels = [
          "default"
          "latest"
        ];

        # @option widget = "spin"; label = "Generations kept"; group = "Kernel"; min = 1; max = 50; visibleWhen.path = "ojuny.patch.multi-kernel.multiBoot"; visibleWhen.equals = true; description = "Boot menu generations to keep. Lower this if /boot is small.";
        ojuny.patch.multi-kernel.generationLimit = 5;

        assertions =
          if cfg.enable then
            [
              {
                assertion = builtins.hasAttr cfg.selected cfg.kernelPackages;
                message = "patch-multi-kernel: selected kernel '${cfg.selected}' is missing from kernelPackages";
              }
              {
                assertion = lib.all (name: builtins.hasAttr name cfg.kernelPackages) cfg.kernels;
                message = "patch-multi-kernel: every entry in kernels must exist in kernelPackages";
              }
              {
                assertion = builtins.length cfg.kernels == builtins.length (lib.unique cfg.kernels);
                message = "patch-multi-kernel: kernels must not contain duplicates";
              }
              {
                assertion = cfg.generationLimit >= 1;
                message = "patch-multi-kernel: generationLimit must be at least 1";
              }
            ]
          else
            [ ];

        boot.kernelPackages = lib.mkIf cfg.enable (lib.mkForce selectedPackages);

        specialisation = lib.mkIf cfg.enable (if cfg.multiBoot then extraSpecialisations else { });

        boot.loader.systemd-boot.configurationLimit = lib.mkIf (
          cfg.enable && cfg.multiBoot && config.boot.loader.systemd-boot.enable
        ) (lib.mkDefault cfg.generationLimit);

        boot.loader.grub.configurationLimit = lib.mkIf (
          cfg.enable && cfg.multiBoot && config.boot.loader.grub.enable
        ) (lib.mkDefault cfg.generationLimit);
      };
    };
}
