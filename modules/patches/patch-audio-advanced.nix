/*
  @menu
  displayname = "Advanced audio";
  icon = "audio-card-symbolic";
  order = 210;
  description = "EasyEffects, Carla, Ardour, JACK and WineASIO with optional low-latency tuning";
  category = "Patches";
  systems = [ "all" ];
*/

{ ... }:

{

  flake.modules.nixos.patch-audio-advanced =
    { config, lib, pkgs, ... }:
    let
      cfg = config.ojuny.patch.audio-advanced;

      jackEnabled = cfg.jack || cfg.wineasio;

      lowLatencyDropIn = {
        "context.properties" = {
          "default.clock.rate" = cfg.sampleRate;
          "default.clock.allowed-rates" = [ cfg.sampleRate ];
          "default.clock.quantum" = cfg.quantum;
          "default.clock.min-quantum" = cfg.quantum;
          "default.clock.max-quantum" = cfg.quantum;
        };
      };
    in
    {
      options.ojuny.patch.audio-advanced = {
        enable = lib.mkEnableOption "the advanced audio patch";
        easyeffects = lib.mkEnableOption "EasyEffects";
        easyeffectsAutostart = lib.mkEnableOption "EasyEffects at user login";
        carla = lib.mkEnableOption "Carla";
        ardour = lib.mkEnableOption "Ardour";
        jack = lib.mkEnableOption "PipeWire JACK compatibility and JACK tools";
        wineasio = lib.mkEnableOption "WineASIO";
        plugins = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Install LSP, Calf, x42, Zam and MDA plugin bundles.";
        };
        lowLatency = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Apply a fixed PipeWire rate and quantum. System-wide tradeoff.";
        };
        sampleRate = lib.mkOption {
          type = lib.types.enum [ 44100 48000 88200 96000 ];
          default = 48000;
          description = "Default PipeWire clock rate used when low latency is enabled.";
        };
        quantum = lib.mkOption {
          type = lib.types.ints.between 32 2048;
          default = 128;
          description = "Fixed PipeWire quantum used when low latency is enabled.";
        };
        realtimeGroupMembers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Users to add to the realtime group with rtprio and memlock limits.";
        };
      };

      config = lib.mkMerge [
        {
          # @option widget = "switch"; label = "Advanced audio"; group = "Advanced audio"; groupOrder = 10; order = 10; description = "Enable the optional advanced audio stack. The core PipeWire module must already be enabled."
          ojuny.patch.audio-advanced.enable = false;

          # @option widget = "switch"; label = "EasyEffects"; group = "Effects"; groupOrder = 20; order = 10; visibleWhen.path = "ojuny.patch.audio-advanced.enable"; visibleWhen.equals = true; description = "Install EasyEffects and its PipeWire effects chain."
          ojuny.patch.audio-advanced.easyeffects = true;

          # @option widget = "switch"; label = "Start EasyEffects at login"; group = "Effects"; groupOrder = 20; order = 20; visibleWhen.path = "ojuny.patch.audio-advanced.easyeffects"; visibleWhen.equals = true; description = "Run EasyEffects as a systemd user service. Disable this if EasyEffects is started from its own autostart setting."
          ojuny.patch.audio-advanced.easyeffectsAutostart = true;

          # @option widget = "switch"; label = "Carla"; group = "Hosts"; groupOrder = 30; order = 10; visibleWhen.path = "ojuny.patch.audio-advanced.enable"; visibleWhen.equals = true; description = "Install the Carla plugin host. It connects to PipeWire or JACK."
          ojuny.patch.audio-advanced.carla = false;

          # @option widget = "switch"; label = "Ardour"; group = "Hosts"; groupOrder = 30; order = 20; visibleWhen.path = "ojuny.patch.audio-advanced.enable"; visibleWhen.equals = true; description = "Install the Ardour digital audio workstation."
          ojuny.patch.audio-advanced.ardour = false;

          # @option widget = "switch"; label = "Plugin bundles"; group = "Hosts"; groupOrder = 30; order = 30; advanced = true; visibleWhen.path = "ojuny.patch.audio-advanced.enable"; visibleWhen.equals = true; description = "Install LSP, Calf, x42, Zam and MDA LV2 plugin bundles."
          ojuny.patch.audio-advanced.plugins = false;

          # @option widget = "switch"; label = "JACK compatibility"; group = "JACK and Windows audio"; groupOrder = 40; order = 10; visibleWhen.path = "ojuny.patch.audio-advanced.enable"; visibleWhen.equals = true; description = "Enable PipeWire JACK emulation and install qjackctl, qpwgraph and jack2 tools. Do not combine with the jackd service."
          ojuny.patch.audio-advanced.jack = false;

          # @option widget = "switch"; label = "WineASIO"; group = "JACK and Windows audio"; groupOrder = 40; order = 20; visibleWhen.path = "ojuny.patch.audio-advanced.enable"; visibleWhen.equals = true; description = "Install the 64-bit WineASIO bridge and Wine. This turns on JACK compatibility. Register the driver in each Wine prefix with wineasio-settings."
          ojuny.patch.audio-advanced.wineasio = false;

          # @option widget = "switch"; label = "Low-latency profile"; group = "Low latency"; groupOrder = 50; order = 10; visibleWhen.path = "ojuny.patch.audio-advanced.enable"; visibleWhen.equals = true; description = "Apply a fixed PipeWire sample rate and quantum system-wide. Higher CPU use and possible xruns."
          ojuny.patch.audio-advanced.lowLatency = false;

          # @option widget = "dropdown"; label = "Sample rate"; group = "Low latency"; groupOrder = 50; order = 20; choices = [ "44100" "48000" "88200" "96000" ]; visibleWhen.path = "ojuny.patch.audio-advanced.lowLatency"; visibleWhen.equals = true; description = "PipeWire default clock rate while the low-latency profile is active."
          ojuny.patch.audio-advanced.sampleRate = 48000;

          # @option widget = "spin"; label = "Quantum"; group = "Low latency"; groupOrder = 50; order = 30; min = 32; max = 2048; step = 32; visibleWhen.path = "ojuny.patch.audio-advanced.lowLatency"; visibleWhen.equals = true; description = "Fixed PipeWire buffer size in frames. Lower values reduce latency and increase xrun risk."
          ojuny.patch.audio-advanced.quantum = 128;

          # @option widget = "list"; label = "Realtime users"; group = "Low latency"; groupOrder = 50; order = 40; advanced = true; visibleWhen.path = "ojuny.patch.audio-advanced.enable"; visibleWhen.equals = true; description = "Users added to the realtime group with rtprio 95 and unlimited memlock. Leave empty to rely on rtkit only."
          ojuny.patch.audio-advanced.realtimeGroupMembers = [ ];
        }
        (lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = config.services.pipewire.enable;
              message = "patch-audio-advanced requires the core audio module to set services.pipewire.enable = true";
            }
            {
              assertion = !config.services.pulseaudio.enable;
              message = "patch-audio-advanced requires PipeWire as the sound server; disable services.pulseaudio";
            }
            {
              assertion = !jackEnabled || !config.services.jack.jackd.enable;
              message = "patch-audio-advanced uses PipeWire JACK emulation; disable services.jack.jackd";
            }
            {
              assertion = !cfg.wineasio || pkgs.stdenv.hostPlatform.isx86_64;
              message = "WineASIO is only packaged for x86_64-linux";
            }
          ];

          environment.systemPackages =
            lib.optionals cfg.easyeffects [ pkgs.easyeffects ]
            ++ lib.optionals cfg.carla [ pkgs.carla ]
            ++ lib.optionals cfg.ardour [ pkgs.ardour ]
            ++ lib.optionals cfg.plugins [
              pkgs.calf
              pkgs.lsp-plugins
              pkgs.mda_lv2
              pkgs.x42-plugins
              pkgs.zam-plugins
            ]
            ++ lib.optionals jackEnabled [
              pkgs.jack2
              pkgs.qjackctl
              pkgs.qpwgraph
            ]
            ++ lib.optionals (cfg.wineasio && pkgs.stdenv.hostPlatform.isx86_64) [
              pkgs.wineWow64Packages.stable
              pkgs.wineasio
            ];

          security.rtkit.enable = true;

          services.pipewire.jack.enable = lib.mkIf jackEnabled true;

          services.pipewire.extraConfig.pipewire = lib.mkIf cfg.lowLatency {
            "90-ojuny-audio-advanced" = lowLatencyDropIn;
          };

          users.groups.realtime = lib.mkIf (cfg.realtimeGroupMembers != [ ]) {
            members = cfg.realtimeGroupMembers;
          };

          security.pam.loginLimits = lib.mkIf (cfg.realtimeGroupMembers != [ ]) [
            {
              domain = "@realtime";
              item = "rtprio";
              type = "-";
              value = "95";
            }
            {
              domain = "@realtime";
              item = "memlock";
              type = "-";
              value = "unlimited";
            }
          ];

          systemd.user.services.easyeffects = lib.mkIf (cfg.easyeffects && cfg.easyeffectsAutostart) {
            description = "EasyEffects audio effects service";
            wantedBy = [ "default.target" ];
            unitConfig = {
              After = [ "pipewire.service" "wireplumber.service" ];
              PartOf = [ "pipewire.service" "wireplumber.service" ];
            };
            serviceConfig = {
              Type = "simple";
              ExecStart = "${pkgs.easyeffects}/bin/easyeffects --hide-window --service-mode";
              ExecStop = "${pkgs.easyeffects}/bin/easyeffects --quit";
              Restart = "on-failure";
              RestartSec = 2;
            };
          };
        })
      ];
    };
}
