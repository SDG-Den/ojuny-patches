/*
  @menu
  displayname = "Dictation";
  icon = "audio-input-microphone-symbolic";
  order = 195;
  description = "Speech-to-text with Voxtype, a Superwhisper adapter, a hotkey, and a microphone indicator";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }:

{

  flake.modules.nixos.patch-dictation =
    { config, lib, ... }:
    {
      options.ojuny.patch.dictation.enable = lib.mkEnableOption "the dictation patch";

      # @option widget = "switch"; label = "Dictation"; group = "Patch"; groupOrder = 10; order = 10; description = "Enable speech-to-text, the hotkey, and the microphone indicator.";
      config.ojuny.patch.dictation.enable = false;

      imports = [ self.modules.nixos.dictation-backend ];
    };

  flake.modules.nixos.dictation-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.ojuny.patch.dictation // {
        enable = active;
      };
      active = config.ojuny.patch.dictation.enable && (config.ojuny.patches or true);

      backendType = lib.types.submodule {
        options = {
          packages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
            description = "Packages added to the system and to the wrapper PATH.";
          };
          start = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "argv for start. Empty falls back to ojuny-dictation-<name> start.";
          };
          stop = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "argv for stop. Empty falls back to ojuny-dictation-<name> stop.";
          };
          toggle = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "argv for toggle. Empty falls back to ojuny-dictation-<name> toggle.";
          };
          status = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "argv that prints idle, recording, transcribing, or error.";
          };
          available = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "argv that exits zero when the backend can run.";
          };
        };
      };

      modelValue = if cfg.voxtype.modelFile != null then cfg.voxtype.modelFile else cfg.voxtype.model;

      voxtypeConfig = pkgs.writeText "ojuny-voxtype-config.toml" ''
        state_file = "auto"

        [hotkey]
        enabled = false

        [audio]
        device = ${builtins.toJSON cfg.voxtype.device}
        sample_rate = 16000
        max_duration_secs = ${toString cfg.voxtype.maxDurationSecs}
        pause_media = ${lib.boolToString cfg.voxtype.pauseMedia}

        [whisper]
        model = ${builtins.toJSON modelValue}
        language = ${builtins.toJSON cfg.voxtype.language}
        translate = false

        [output]
        mode = ${builtins.toJSON cfg.voxtype.outputMode}
        fallback_to_clipboard = true
        type_delay_ms = 1

        [output.notification]
        on_recording_start = false
        on_recording_stop = false
        on_transcription = false
      '';

      builtinBackends = {
        voxtype = {
          packages = [ cfg.voxtype.package ];
          start = [
            "${cfg.voxtype.package}/bin/voxtype"
            "--config"
            "${voxtypeConfig}"
            "record"
            "start"
          ];
          stop = [
            "${cfg.voxtype.package}/bin/voxtype"
            "--config"
            "${voxtypeConfig}"
            "record"
            "stop"
          ];
          toggle = [
            "${cfg.voxtype.package}/bin/voxtype"
            "--config"
            "${voxtypeConfig}"
            "record"
            "toggle"
          ];
          status = [ ];
          available = [ ];
        };

        superwhisper = {
          packages = lib.optional (cfg.superwhisper.package != null) cfg.superwhisper.package;
          start = [
            "superwhisper"
            "start"
          ];
          stop = [
            "superwhisper"
            "stop"
          ];
          toggle = [
            "superwhisper"
            "record"
          ];
          status = [ ];
          available = [ ];
        };
      };

      allBackends = lib.recursiveUpdate builtinBackends cfg.backends;
      selected =
        allBackends.${cfg.backend}
          or (throw "patch-dictation: unknown backend '${cfg.backend}'; add it to ojuny.patch.dictation.backends");

      adapter = "ojuny-dictation-${cfg.backend}";

      commandOrAdapter =
        verb: commands:
        if commands != [ ] then
          lib.escapeShellArgs commands
        else
          lib.escapeShellArgs [
            adapter
            verb
          ];

      startCommand = commandOrAdapter "start" selected.start;
      stopCommand = commandOrAdapter "stop" selected.stop;
      toggleCommand = commandOrAdapter "toggle" selected.toggle;

      statusCommand = if selected.status != [ ] then lib.escapeShellArgs selected.status else "";

      availableCommand =
        if selected.available != [ ] then
          lib.escapeShellArgs selected.available
        else if selected.start != [ ] then
          let
            first = lib.escapeShellArg (builtins.head selected.start);
          in
          "command -v ${first} >/dev/null 2>&1 || [ -x ${first} ]"
        else
          "false";

      dictation = pkgs.writeShellApplication {
        name = "ojuny-dictation";
        runtimeInputs = [
          pkgs.bash
          pkgs.coreutils
          pkgs.libnotify
        ]
        ++ selected.packages;

        text = ''
          set -euo pipefail

          state_dir="''${XDG_RUNTIME_DIR:-/tmp}/ojuny-dictation"
          state_file="$state_dir/state"
          backend=${lib.escapeShellArg cfg.backend}
          mkdir -p "$state_dir"

          export OJUNY_DICTATION_BACKEND="$backend"
          export OJUNY_DICTATION_STATE_FILE="$state_file"
          export OJUNY_DICTATION_SELECTED=1

          write_state() {
            printf '%s\n' "$1" > "$state_file.tmp"
            mv "$state_file.tmp" "$state_file"
          }

          read_state() {
            if [ "$backend" = voxtype ] && [ -r "''${XDG_RUNTIME_DIR:-/tmp}/voxtype/state" ]; then
              cat "''${XDG_RUNTIME_DIR:-/tmp}/voxtype/state"
            elif [ -r "$state_file" ]; then
              cat "$state_file"
            else
              echo idle
            fi
          }

          notify() {
            notify-send \
              -a Dictation \
              -h string:x-canonical-private-synchronous:ojuny-dictation \
              "$@" 2>/dev/null || true
          }

          is_available() {
            ${availableCommand}
          }

          backend_error() {
            write_state error
            ${lib.optionalString cfg.indicator.notifyError ''
              notify -u critical -t 5000 "Dictation" "Backend '$backend' is not available. Run: ojuny-dictation doctor"
            ''}
            printf 'ojuny-dictation: backend %s is not available\n' "$backend" >&2
            exit 1
          }

          do_start() {
            is_available || backend_error
            ${startCommand}
            write_state recording
            ${lib.optionalString cfg.indicator.notifyStart ''
              notify -u low -t 1500 "Dictation" "Recording. Toggle again to stop."
            ''}
          }

          do_stop() {
            if [ "$(read_state)" = idle ]; then
              exit 0
            fi
            ${stopCommand}
            write_state transcribing
            ${lib.optionalString cfg.indicator.notifyStop ''
              notify -u low -t 1500 "Dictation" "Transcribing..."
            ''}
          }

          case "''${1:-}" in
            start)
              do_start
              ;;
            stop)
              do_stop
              ;;
            toggle)
              is_available || backend_error
              before="$(read_state)"
              ${toggleCommand}
              case "$before" in
                recording)
                  write_state transcribing
                  ${lib.optionalString cfg.indicator.notifyStop ''
                    notify -u low -t 1500 "Dictation" "Transcribing..."
                  ''}
                  ;;
                *)
                  write_state recording
                  ${lib.optionalString cfg.indicator.notifyStart ''
                    notify -u low -t 1500 "Dictation" "Recording. Toggle again to stop."
                  ''}
                  ;;
              esac
              ;;
            status)
              if [ -n ${lib.escapeShellArg statusCommand} ]; then
                ${statusCommand}
              else
                read_state
              fi
              ;;
            available)
              is_available
              ;;
            backend)
              printf '%s\n' "$backend"
              ;;
            list-backends)
              printf '%s\n' ${lib.escapeShellArgs (lib.attrNames allBackends)}
              ;;
            doctor)
              printf 'backend: %s\n' "$backend"
              printf 'state: %s\n' "$(read_state)"
              printf 'state file: %s\n' "$state_file"
              printf 'available: '
              if is_available; then echo yes; else echo no; fi
              printf 'start: %s\n' ${lib.escapeShellArg startCommand}
              printf 'stop: %s\n' ${lib.escapeShellArg stopCommand}
              printf 'toggle: %s\n' ${lib.escapeShellArg toggleCommand}
              ;;
            *)
              printf 'usage: ojuny-dictation <start|stop|toggle|status|available|backend|list-backends|doctor>\n' >&2
              exit 2
              ;;
          esac
        '';
      };
    in
    {
      options.ojuny.patch.dictation = {
        backend = lib.mkOption {
          type = lib.types.str;
          default = "voxtype";
          description = "Selected backend name. It must exist in the effective backend table.";
        };

        backends = lib.mkOption {
          type = lib.types.attrsOf backendType;
          default = { };
          description = "Additional or overriding backends keyed by backend name.";
        };

        hotkey = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Add the Mango key binding.";
          };
          modifier = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "SUPER"
              "CTRL"
            ];
            description = "Mango modifiers for the dictation toggle.";
          };
          keys = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "X" ];
            description = "Mango keys for the dictation toggle.";
          };
        };

        indicator = {
          barWidget = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Add the DMS privacy indicator to the default bar.";
          };
          notifyStart = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Notify when recording starts.";
          };
          notifyStop = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Notify when recording stops and transcription begins.";
          };
          notifyError = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Notify when the backend is missing or a command fails.";
          };
        };

        voxtype = {
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.voxtype;
            description = "Voxtype package. Use pkgs.voxtype-vulkan for the Vulkan build.";
          };
          device = lib.mkOption {
            type = lib.types.str;
            default = "default";
            description = "PipeWire or PulseAudio source name.";
          };
          model = lib.mkOption {
            type = lib.types.str;
            default = "base.en";
            description = "Voxtype model name when no model file is set.";
          };
          modelFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Absolute path to an existing model. Skips the download step.";
          };
          downloadModel = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Run voxtype setup --download before the service starts.";
          };
          language = lib.mkOption {
            type = lib.types.str;
            default = "en";
            description = "Whisper language code, or auto.";
          };
          outputMode = lib.mkOption {
            type = lib.types.enum [
              "type"
              "clipboard"
              "paste"
            ];
            default = "type";
            description = "How transcribed text is delivered.";
          };
          maxDurationSecs = lib.mkOption {
            type = lib.types.ints.between 5 600;
            default = 60;
            description = "Maximum recording duration in seconds.";
          };
          pauseMedia = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Pause MPRIS media players while recording.";
          };
        };

        superwhisper.package = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = "External Superwhisper package. The patch does not provide one.";
        };
      };

      config = lib.mkMerge [
        {
          # @option widget = "dropdown"; label = "Backend"; group = "Backend"; groupOrder = 20; order = 10; choices = [ "voxtype" "superwhisper" ]; visibleWhen.path = "ojuny.patch.dictation.enable"; visibleWhen.equals = true; description = "Voxtype is local and installed by this patch. Superwhisper is external and needs a package.";
          ojuny.patch.dictation.backend = "voxtype";

          # @option widget = "package"; label = "Voxtype package"; group = "Voxtype"; groupOrder = 30; order = 10; visibleWhen.path = "ojuny.patch.dictation.backend"; visibleWhen.equals = "voxtype"; description = "The nixpkgs Voxtype build. Use pkgs.voxtype-vulkan for the Vulkan variant.";
          ojuny.patch.dictation.voxtype.package = pkgs.voxtype;

          # @option widget = "text"; label = "Audio device"; group = "Voxtype"; groupOrder = 30; order = 20; visibleWhen.path = "ojuny.patch.dictation.backend"; visibleWhen.equals = "voxtype"; description = "PipeWire or PulseAudio source name. Use default for the system default microphone.";
          ojuny.patch.dictation.voxtype.device = "default";

          # @option widget = "dropdown"; label = "Model"; group = "Voxtype"; groupOrder = 30; order = 30; choices = [ "tiny.en" "base.en" "small.en" "medium" "large-v3-turbo" ]; visibleWhen.path = "ojuny.patch.dictation.backend"; visibleWhen.equals = "voxtype"; description = "Whisper model name. Larger models are slower and use more memory.";
          ojuny.patch.dictation.voxtype.model = "base.en";

          # @option widget = "text"; label = "Model file"; group = "Voxtype"; groupOrder = 30; order = 40; advanced = true; visibleWhen.path = "ojuny.patch.dictation.backend"; visibleWhen.equals = "voxtype"; description = "Absolute path to an existing model. When set, the download step is skipped.";
          ojuny.patch.dictation.voxtype.modelFile = null;

          # @option widget = "switch"; label = "Download model at service start"; group = "Voxtype"; groupOrder = 30; order = 50; visibleWhen.path = "ojuny.patch.dictation.backend"; visibleWhen.equals = "voxtype"; description = "Run voxtype setup --download before the daemon starts. It is a no-op when the model already exists.";
          ojuny.patch.dictation.voxtype.downloadModel = true;

          # @option widget = "text"; label = "Language"; group = "Voxtype"; groupOrder = 30; order = 60; visibleWhen.path = "ojuny.patch.dictation.backend"; visibleWhen.equals = "voxtype"; description = "Whisper language code, or auto for detection.";
          ojuny.patch.dictation.voxtype.language = "en";

          # @option widget = "dropdown"; label = "Output mode"; group = "Voxtype"; groupOrder = 30; order = 70; choices = [ "type" "clipboard" "paste" ]; visibleWhen.path = "ojuny.patch.dictation.backend"; visibleWhen.equals = "voxtype"; description = "Type at the cursor, copy to the clipboard, or paste through the clipboard.";
          ojuny.patch.dictation.voxtype.outputMode = "type";

          # @option widget = "spin"; label = "Maximum recording seconds"; group = "Voxtype"; groupOrder = 30; order = 80; min = 5; max = 600; unit = "s"; visibleWhen.path = "ojuny.patch.dictation.backend"; visibleWhen.equals = "voxtype"; description = "Safety limit on one recording.";
          ojuny.patch.dictation.voxtype.maxDurationSecs = 60;

          # @option widget = "switch"; label = "Pause media while recording"; group = "Voxtype"; groupOrder = 30; order = 90; advanced = true; visibleWhen.path = "ojuny.patch.dictation.backend"; visibleWhen.equals = "voxtype"; description = "Pause MPRIS players during recording.";
          ojuny.patch.dictation.voxtype.pauseMedia = true;

          # @option widget = "package"; label = "Superwhisper package"; group = "Superwhisper"; groupOrder = 40; order = 10; visibleWhen.path = "ojuny.patch.dictation.backend"; visibleWhen.equals = "superwhisper"; description = "External package that provides the superwhisper command. The patch does not vendor or fetch it.";
          ojuny.patch.dictation.superwhisper.package = null;

          # @option widget = "switch"; label = "Hotkey"; group = "Hotkey"; groupOrder = 50; order = 10; visibleWhen.path = "ojuny.patch.dictation.enable"; visibleWhen.equals = true; description = "Add the Mango key binding.";
          ojuny.patch.dictation.hotkey.enable = true;

          # @option widget = "list"; label = "Hotkey modifiers"; group = "Hotkey"; groupOrder = 50; order = 20; visibleWhen.path = "ojuny.patch.dictation.hotkey.enable"; visibleWhen.equals = true; description = "Mango modifier names.";
          ojuny.patch.dictation.hotkey.modifier = [
            "SUPER"
            "CTRL"
          ];

          # @option widget = "list"; label = "Hotkey keys"; group = "Hotkey"; groupOrder = 50; order = 30; visibleWhen.path = "ojuny.patch.dictation.hotkey.enable"; visibleWhen.equals = true; description = "Mango key names.";
          ojuny.patch.dictation.hotkey.keys = [ "X" ];

          # @option widget = "switch"; label = "Microphone indicator"; group = "Indicator"; groupOrder = 60; order = 10; visibleWhen.path = "ojuny.patch.dictation.enable"; visibleWhen.equals = true; description = "Add the DMS privacy indicator to the default bar and enable its microphone icon.";
          ojuny.patch.dictation.indicator.barWidget = true;

          # @option widget = "switch"; label = "Start notification"; group = "Indicator"; groupOrder = 60; order = 20; visibleWhen.path = "ojuny.patch.dictation.enable"; visibleWhen.equals = true; description = "Show a short notification when recording starts.";
          ojuny.patch.dictation.indicator.notifyStart = true;

          # @option widget = "switch"; label = "Stop notification"; group = "Indicator"; groupOrder = 60; order = 30; visibleWhen.path = "ojuny.patch.dictation.enable"; visibleWhen.equals = true; description = "Show a short notification when recording stops and transcription begins.";
          ojuny.patch.dictation.indicator.notifyStop = true;

          # @option widget = "switch"; label = "Error notification"; group = "Indicator"; groupOrder = 60; order = 40; visibleWhen.path = "ojuny.patch.dictation.enable"; visibleWhen.equals = true; description = "Show a critical notification when the backend is missing or a command fails.";
          ojuny.patch.dictation.indicator.notifyError = true;
        }

        (lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = allBackends ? ${cfg.backend};
              message = "patch-dictation: backend '${cfg.backend}' is not defined. Add it to ojuny.patch.dictation.backends.";
            }
            {
              assertion = cfg.hotkey.modifier != [ ] || cfg.hotkey.keys != [ ];
              message = "patch-dictation: the hotkey needs at least one modifier or key.";
            }
          ];

          environment.systemPackages = [
            dictation
            pkgs.wl-clipboard
            pkgs.ydotool
          ]
          ++ selected.packages;

          desktop.ojuny.mango.binds.common.ojunyDictation = lib.mkIf cfg.hotkey.enable {
            modifier = cfg.hotkey.modifier;
            keys = cfg.hotkey.keys;
            dispatcher = "spawn_shell";
            args = "${dictation}/bin/ojuny-dictation toggle";
            description = "Toggle dictation";
            group = "Applications";
            subcat = "Dictation";
          };

          desktop.ojuny.dux.barConfigs.default.rightWidgets.privacyIndicator =
            lib.mkIf cfg.indicator.barWidget
              {
                enabled = true;
                privacyShowMicIcon = true;
                privacyShowCameraIcon = false;
                privacyShowScreenShareIcon = false;
                _order = 65;
              };

          systemd.user.services.voxtype = lib.mkIf (cfg.backend == "voxtype") {
            description = "Voxtype dictation daemon";
            wantedBy = [ "mango-session.target" ];
            after = [
              "pipewire.service"
              "wireplumber.service"
              "mango-session.target"
            ];
            partOf = [ "mango-session.target" ];
            serviceConfig = {
              Type = "simple";
              ExecStart = "${cfg.voxtype.package}/bin/voxtype --config ${voxtypeConfig} daemon";
              ExecStartPre = lib.optional cfg.voxtype.downloadModel "-${cfg.voxtype.package}/bin/voxtype --config ${voxtypeConfig} setup --download --no-post-install";
              Restart = "on-failure";
              RestartSec = 5;
            };
          };
        })
      ];
    };

}
