/*
  @menu
  displayname = "Advanced hardware";
  icon = "preferences-system-symbolic";
  order = 210;
  description = "CPU scaling, touchpad haptics and thermal control";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }:

{
  flake.modules.nixos.patch-advanced-hardware-tools =
    { config, lib, ... }:
    {
      options.ojuny.patch.advanced-hardware-tools.enable =
        lib.mkEnableOption "the advanced hardware tools patch";

      # @option widget = "switch"; label = "Advanced hardware tools"; group = "Advanced hardware"; description = "Enable CPU scaling, touchpad haptics and thermal control independently.";
      config.ojuny.patch.advanced-hardware-tools.enable = false;

      imports = [ self.modules.nixos.advanced-hardware-tools-backend ];
    };

  flake.modules.nixos.advanced-hardware-tools-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.ojuny.patch.advanced-hardware-tools // {
        enable = active;
      };
      active = config.ojuny.patch.advanced-hardware-tools.enable && (config.ojuny.patches or true);

      facter = config.hardware.facter.report;
      facterCpus = facter.hardware.cpu or [ ];
      facterCpu = if facterCpus == [ ] then { } else lib.head facterCpus;
      facterSystem = facter.smbios.system or { };
      cpuVendor = facterCpu.vendor_name or "";
      product = facterSystem.product or "";

      isIntel = cpuVendor == "GenuineIntel";
      fanDetected = facter == { } || isIntel;

      hapticsDevice =
        if cfg.haptics.device != "auto" then
          cfg.haptics.device
        else if lib.hasInfix "xps" (lib.toLower product) then
          "dell-xps"
        else if lib.hasInfix "h7407ba" (lib.toLower product) then
          "asus-proart-p14"
        else
          "none";

      hapticsReady =
        hapticsDevice == "asus-proart-p14" || (hapticsDevice == "dell-xps" && cfg.haptics.package != null);

      hapticsStrength =
        {
          low = 10;
          mid = 50;
          high = 100;
        }
        .${cfg.haptics.strength};

      fanGate = pkgs.writeShellScript "ojuny-thermald-gate" ''
        set -eu
        ${pkgs.gnugrep}/bin/grep -q GenuineIntel /proc/cpuinfo || exit 1
        for supply in /sys/class/power_supply/*; do
          [ -r "$supply/type" ] || continue
          [ "$(${pkgs.coreutils}/bin/cat "$supply/type")" = "Battery" ] || continue
          if [ -r "$supply/scope" ] && [ "$(${pkgs.coreutils}/bin/cat "$supply/scope")" = "Device" ]; then
            continue
          fi
          exit 0
        done
        exit 1
      '';
    in
    {
      options.ojuny.patch.advanced-hardware-tools = {
        cpu = {
          enable = lib.mkEnableOption "CPU governor and energy preference control";

          governor = lib.mkOption {
            type = lib.types.enum [
              "kernel"
              "schedutil"
              "powersave"
              "performance"
              "ondemand"
              "conservative"
            ];
            default = "schedutil";
            description = "CPU frequency governor. kernel leaves powerManagement.cpuFreqGovernor at null.";
          };

          epp = lib.mkOption {
            type = lib.types.enum [
              "default"
              "performance"
              "balance_performance"
              "balance_power"
              "power"
            ];
            default = "default";
            description = "Energy performance preference. default disables the writer.";
          };
        };

        haptics = {
          enable = lib.mkEnableOption "touchpad haptics support";

          device = lib.mkOption {
            type = lib.types.enum [
              "auto"
              "dell-xps"
              "asus-proart-p14"
              "none"
            ];
            default = "auto";
            description = "Touchpad model. auto uses the facter DMI report.";
          };

          package = lib.mkOption {
            type = lib.types.nullOr lib.types.package;
            default = null;
            example = lib.literalExpression "pkgs.dell-xps-touchpad-haptics";
            description = "Optional Dell XPS actuator package providing bin/dell-xps-touchpad-haptics-daemon.";
          };

          strength = lib.mkOption {
            type = lib.types.enum [
              "low"
              "mid"
              "high"
            ];
            default = "mid";
            description = "Dell XPS click strength, written as INTENSITY=10, 50 or 100.";
          };

          detected = lib.mkOption {
            type = lib.types.enum [
              "none"
              "dell-xps"
              "asus-proart-p14"
            ];
            default = "none";
            internal = true;
            description = "Computed touchpad model.";
          };

          ready = lib.mkOption {
            type = lib.types.bool;
            default = false;
            internal = true;
            description = "Whether the selected touchpad path has everything it needs.";
          };
        };

        fan = {
          enable = lib.mkEnableOption "thermal and fan control";

          mode = lib.mkOption {
            type = lib.types.enum [
              "thermald"
              "fancontrol"
            ];
            default = "thermald";
            description = "Thermal daemon or explicit fan curve.";
          };

          ignoreCpuidCheck = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Pass through to services.thermald.ignoreCpuidCheck.";
          };

          fancontrolConfig = lib.mkOption {
            type = lib.types.lines;
            default = "";
            example = ''
              INTERVAL=10
              FCTEMPS=hwmon3/pwm1=hwmon3/temp1_input
              FCFANS=hwmon3/pwm1=hwmon3/fan1_input
              MINTEMP=hwmon3/pwm1=35
              MAXTEMP=hwmon3/pwm1=65
              MINSTART=hwmon3/pwm1=150
              MINSTOP=hwmon3/pwm1=0
            '';
            description = "Required fancontrol configuration when mode is fancontrol.";
          };

          detected = lib.mkOption {
            type = lib.types.bool;
            default = false;
            internal = true;
            description = "True for Intel CPUs, or when no facter report is available.";
          };
        };
      };

      config = lib.mkMerge [
        {
          # @option widget = "switch"; label = "CPU scaling"; group = "CPU"; visibleWhen.path = "ojuny.patch.advanced-hardware-tools.enable"; visibleWhen.equals = true; description = "Set the CPU frequency governor and, optionally, the energy performance preference.";
          ojuny.patch.advanced-hardware-tools.cpu.enable = false;

          # @option widget = "dropdown"; label = "Governor"; group = "CPU"; choices = [ "kernel" "schedutil" "powersave" "performance" "ondemand" "conservative" ]; visibleWhen.path = "ojuny.patch.advanced-hardware-tools.cpu.enable"; visibleWhen.equals = true; description = "kernel leaves the kernel default untouched. schedutil is the normal modern default.";
          ojuny.patch.advanced-hardware-tools.cpu.governor = "schedutil";

          # @option widget = "dropdown"; label = "Energy performance preference"; group = "CPU"; choices = [ "default" "performance" "balance_performance" "balance_power" "power" ]; visibleWhen.path = "ojuny.patch.advanced-hardware-tools.cpu.enable"; visibleWhen.equals = true; description = "default disables the EPP writer. Other values are written to every writable cpufreq policy.";
          ojuny.patch.advanced-hardware-tools.cpu.epp = "default";

          # @option widget = "dropdown"; label = "Touchpad"; group = "Haptics"; choices = [ "auto" "dell-xps" "asus-proart-p14" "none" ]; visibleWhen.path = "ojuny.patch.advanced-hardware-tools.enable"; visibleWhen.equals = true; description = "auto uses the facter DMI report. Select a model explicitly when no report is available.";
          ojuny.patch.advanced-hardware-tools.haptics.device = "auto";

          # @option widget = "package"; label = "Dell haptics package"; group = "Haptics"; nullable = true; visibleWhen.path = "ojuny.patch.advanced-hardware-tools.haptics.detected"; visibleWhen.equals = "dell-xps"; description = "Optional package providing bin/dell-xps-touchpad-haptics-daemon. The vendor daemon is not vendored by this patch.";
          ojuny.patch.advanced-hardware-tools.haptics.package = null;

          # @option widget = "dropdown"; label = "Click strength"; group = "Haptics"; choices = [ "low" "mid" "high" ]; visibleWhen.path = "ojuny.patch.advanced-hardware-tools.haptics.detected"; visibleWhen.equals = "dell-xps"; description = "Written as INTENSITY=10, 50 or 100 for the Dell daemon.";
          ojuny.patch.advanced-hardware-tools.haptics.strength = "mid";

          # @option widget = "dropdown"; label = "Detected touchpad"; group = "Haptics"; choices = [ "none" "dell-xps" "asus-proart-p14" ]; readonly = true; advanced = true; description = "Computed from facter smbios.system.product or the explicit Touchpad selection.";
          ojuny.patch.advanced-hardware-tools.haptics.detected = hapticsDevice;

          # @option widget = "switch"; label = "Ready to enable"; group = "Haptics"; readonly = true; advanced = true; description = "True when the selected device has a self-contained quirk or a Dell package is set.";
          ojuny.patch.advanced-hardware-tools.haptics.ready = hapticsReady;

          # @option widget = "switch"; label = "Enable haptics"; group = "Haptics"; visibleWhen.path = "ojuny.patch.advanced-hardware-tools.haptics.ready"; visibleWhen.equals = true; description = "Apply the selected touchpad path. Unsupported devices never show this switch.";
          ojuny.patch.advanced-hardware-tools.haptics.enable = false;

          # @option widget = "switch"; label = "Fan and thermal control"; group = "Fan"; visibleWhen.path = "ojuny.patch.advanced-hardware-tools.enable"; visibleWhen.equals = true; description = "Enable thermald on supported Intel laptops, or an explicit fancontrol configuration.";
          ojuny.patch.advanced-hardware-tools.fan.enable = false;

          # @option widget = "dropdown"; label = "Mode"; group = "Fan"; choices = [ "thermald" "fancontrol" ]; visibleWhen.path = "ojuny.patch.advanced-hardware-tools.fan.enable"; visibleWhen.equals = true; description = "thermald is the safe thermal daemon. fancontrol applies a user-supplied fan curve.";
          ojuny.patch.advanced-hardware-tools.fan.mode = "thermald";

          # @option widget = "switch"; label = "Ignore CPUID check"; group = "Fan"; advanced = true; visibleWhen.path = "ojuny.patch.advanced-hardware-tools.fan.mode"; visibleWhen.equals = "thermald"; description = "Pass through to services.thermald.ignoreCpuidCheck. Only use on hardware known to work.";
          ojuny.patch.advanced-hardware-tools.fan.ignoreCpuidCheck = false;

          # @option widget = "raw"; label = "fancontrol configuration"; group = "Fan"; rows = 12; advanced = true; visibleWhen.path = "ojuny.patch.advanced-hardware-tools.fan.mode"; visibleWhen.equals = "fancontrol"; description = "Required pwmconfig style configuration. Wrong values can overheat or damage hardware.";
          ojuny.patch.advanced-hardware-tools.fan.fancontrolConfig = "";

          # @option widget = "switch"; label = "Thermal control detected"; group = "Fan"; readonly = true; advanced = true; description = "True when facter identifies Intel, or when no facter report is available and the runtime ExecCondition decides.";
          ojuny.patch.advanced-hardware-tools.fan.detected = fanDetected;
        }
        {
          assertions = [
            {
              assertion =
                !(
                  cfg.enable
                  && cfg.cpu.enable
                  && (
                    config.services.power-profiles-daemon.enable
                    || config.services.auto-cpufreq.enable
                    || config.services.tlp.enable
                  )
                );
              message = "patch-advanced-hardware-tools: CPU scaling conflicts with power-profiles-daemon, auto-cpufreq, and TLP. Disable one owner.";
            }
            {
              assertion = !(cfg.enable && cfg.haptics.enable) || hapticsReady;
              message = "patch-advanced-hardware-tools: haptics.enable requires a detected or explicitly selected supported touchpad, and a package for Dell XPS.";
            }
            {
              assertion =
                !(cfg.enable && cfg.fan.enable && cfg.fan.mode == "fancontrol" && cfg.fan.fancontrolConfig == "");
              message = "patch-advanced-hardware-tools: fan.mode = fancontrol requires fan.fancontrolConfig.";
            }
            {
              assertion = !(cfg.enable && cfg.fan.enable && cfg.fan.mode == "thermald" && !fanDetected);
              message = "patch-advanced-hardware-tools: fan.mode = thermald requires an Intel CPU. Use fancontrol for an explicit custom curve.";
            }
          ];
        }
        (lib.mkIf (cfg.enable && cfg.cpu.enable) {
          powerManagement.cpuFreqGovernor = if cfg.cpu.governor == "kernel" then null else cfg.cpu.governor;

          systemd.services.ojuny-cpu-epp = lib.mkIf (cfg.cpu.epp != "default") {
            description = "Set CPU energy performance preference";
            wantedBy = [ "multi-user.target" ];
            after = [ "cpufreq.service" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              set -eu
              for preference in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do
                [ -w "$preference" ] || continue
                printf '%s\n' "${cfg.cpu.epp}" > "$preference" || true
              done
            '';
          };
        })
        (lib.mkIf (cfg.enable && cfg.haptics.enable) {
          environment.etc =
            lib.optionalAttrs (hapticsDevice == "asus-proart-p14") {
              "libinput/local-overrides.quirks".text = lib.mkAfter ''
                [ASUS ProArt P14 Touchpad]
                MatchBus=i2c
                MatchUdevType=touchpad
                MatchVendor=0x093A
                MatchProduct=0x4F02
                MatchDMIModalias=dmi:*svnASUS*:pn*H7407BA*
                AttrInputProp=+INPUT_PROP_PRESSUREPAD
              '';
            }
            // lib.optionalAttrs (hapticsDevice == "dell-xps") {
              "ojuny-dell-haptic.conf".text = "INTENSITY=${toString hapticsStrength}\n";
            };

          services.udev.extraRules = lib.mkIf (hapticsDevice == "dell-xps" && cfg.haptics.package != null) ''
            ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:00:19.0", ATTR{power/control}="on"
            ACTION=="add", SUBSYSTEM=="platform", KERNEL=="i2c_designware.0", ATTR{power/control}="on"
          '';

          systemd.tmpfiles.rules = lib.mkIf (hapticsDevice == "dell-xps" && cfg.haptics.package != null) [
            "d /var/lib/ojuny-haptics/.config/omarchy 0755 root root -"
            "L+ /var/lib/ojuny-haptics/.config/omarchy/dell-haptic.conf - - - - /etc/ojuny-dell-haptic.conf"
          ];

          systemd.services.ojuny-haptics =
            lib.mkIf (hapticsDevice == "dell-xps" && cfg.haptics.package != null)
              {
                description = "Dell XPS touchpad haptics";
                wantedBy = [ "multi-user.target" ];
                after = [ "systemd-udev-settle.service" ];
                unitConfig.ConditionPathExists = "/sys/bus/i2c/devices/i2c-VEN_06CB:00";
                environment.DELL_XPS_TOUCHPAD_HAPTICS_HOME = "/var/lib/ojuny-haptics";
                restartTriggers = [ config.environment.etc."ojuny-dell-haptic.conf".source ];
                serviceConfig = {
                  ExecStart = "${cfg.haptics.package}/bin/dell-xps-touchpad-haptics-daemon";
                  Restart = "on-failure";
                  RestartSec = 2;
                };
              };
        })
        (lib.mkIf (cfg.enable && cfg.fan.enable) {
          services.thermald = lib.mkIf (cfg.fan.mode == "thermald" && fanDetected) {
            enable = true;
            ignoreCpuidCheck = cfg.fan.ignoreCpuidCheck;
          };

          systemd.services.thermald.serviceConfig.ExecCondition = lib.mkIf (
            cfg.fan.mode == "thermald" && fanDetected
          ) fanGate;

          hardware.fancontrol = lib.mkIf (cfg.fan.mode == "fancontrol") {
            enable = true;
            config = cfg.fan.fancontrolConfig;
          };
        })
      ];
    };
}
