/*
  @menu
  displayname = "Kernel parameters";
  icon = "preferences-system-symbolic";
  order = 205;
  description = "Validated kernel command-line parameters, merged with the Intel graphics parameters";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }: {

  flake.modules.nixos.patch-kernel-config =
    { config, lib, ... }:
    {
      options.ojuny.patch.kernel-config.enable = lib.mkEnableOption "the kernel parameters patch";

      # @option widget = "switch"; label = "Kernel parameters"; group = "Kernel parameters"; groupOrder = 10; order = 10; description = "Enable validated extra kernel command-line parameters.";
      config.ojuny.patch.kernel-config.enable = false;

      imports = [ self.modules.nixos.kernel-config-backend ];
    };

  flake.modules.nixos.kernel-config-backend =
    { config, lib, ... }:
    let
      cfg = config.ojuny.patch.kernel-config // {
        enable = active;
      };
      active = config.ojuny.patch.kernel-config.enable && (config.ojuny.patches or true);
      params = config.ojuny.kernel.params;

      paramPattern = "[A-Za-z0-9_][A-Za-z0-9_.-]*(=[A-Za-z0-9_.,:/@%+~=-]*)?";

      invalidParams = builtins.filter (param: builtins.match paramPattern param == null) params;

      riskyPrefixes = [
        "init="
        "root="
        "resume="
      ];
      riskyParams = builtins.filter (
        param: builtins.any (prefix: lib.hasPrefix prefix param) riskyPrefixes
      ) params;

      commandLine = lib.concatStringsSep " " config.boot.kernelParams;

      invalidMessage =
        "ojuny.kernel.params contains invalid kernel parameters: "
        + lib.concatMapStringsSep ", " (param: "'${param}'") invalidParams
        + ". Expected name or name=value, using only A-Z a-z 0-9 _ . - in the name "
        + "and A-Z a-z 0-9 _ . , : / @ % + ~ = - in the value.";
    in
    {
      options.ojuny = {
        kernel.params = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "iommu=pt"
            "mem_sleep_default=s2idle"
          ];
          description = "Extra kernel command-line parameters. Each entry must be name or name=value.";
        };

        kernel.invalidParams = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = invalidParams;
          internal = true;
          readOnly = true;
        };

        kernel.commandLine = lib.mkOption {
          type = lib.types.str;
          default = commandLine;
          internal = true;
          readOnly = true;
        };
      };

      config = {
        # @option widget = "list"; label = "Extra parameters"; group = "Kernel parameters"; groupOrder = 10; order = 20; itemLabel = "Parameter"; addLabel = "Add parameter"; visibleWhen.path = "ojuny.patch.kernel-config.enable"; visibleWhen.equals = true; description = "One parameter per row, for example iommu=pt or mem_sleep_default=s2idle. Names use letters, digits, underscore, dot and hyphen. Values also allow comma, colon, slash, at, percent, plus, tilde and equals.";
        ojuny.kernel.params = [ ];

        assertions = lib.mkIf cfg.enable [
          {
            assertion = invalidParams == [ ];
            message = invalidMessage;
          }
        ];

        warnings = lib.mkIf cfg.enable (
          lib.optional (riskyParams != [ ]) (
            "ojuny.kernel.params adds boot-critical parameters: "
            + lib.concatStringsSep ", " riskyParams
            + ". Keep an older generation available."
          )
        );

        boot.kernelParams = lib.mkIf cfg.enable (lib.mkAfter params);

        environment.etc = lib.mkIf cfg.enable {
          "ojuny/kernel-params".text = commandLine + "\n";
        };

        system.build.ojunyKernelCommandLine = lib.mkIf cfg.enable commandLine;
      };
    };
}
