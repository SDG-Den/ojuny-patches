/*
  @menu
  displayname = "Screen recording";
  icon = "media-record-symbolic";
  order = 220;
  description = "GPU screen recording, replay buffer, audio and webcam overlay";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }:

{
  flake.modules.nixos.patch-screenrecord =
    { config, lib, ... }:
    {
      options.ojuny.patch.screenrecord.enable = lib.mkEnableOption "the screen recording patch";

      # @option widget = "switch"; label = "Screen recording"; group = "Screen recording"; groupOrder = 10; order = 10; description = "Install the GPU screen recorder, replay buffer, webcam overlay and recording indicator."
      config.ojuny.patch.screenrecord.enable = false;

      imports = [ self.modules.nixos.screenrecord-backend ];
    };

  flake.modules.nixos.screenrecord-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.ojuny.patch.screenrecord // {
        enable = active;
      };
      active = config.ojuny.patch.screenrecord.enable && (config.ojuny.patches or true);

      gpuRecorder = lib.optional (lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.gpu-screen-recorder) pkgs.gpu-screen-recorder;

      wrapper = pkgs.writeShellApplication {
        name = "ojuny-screenrecord";
        runtimeInputs =
          with pkgs;
          [
            coreutils
            gnugrep
            gnused
            findutils
            jq
            slurp
            pulseaudio
            libnotify
            v4l-utils
            mpv
            util-linux
          ]
          ++ gpuRecorder
          ++ [ pkgs.wf-recorder ]
          ++ lib.optionals cfg.audio.levelMeter [
            pkgs.cava
            pkgs.pavucontrol
          ];

        text = ''
          state_dir="''${XDG_RUNTIME_DIR:-$HOME/.local/state}/ojuny/screenrecord"
          mkdir -p "$state_dir"

          supervisor_file="$state_dir/supervisor.pid"
          child_file="$state_dir/recorder.pid"
          kind_file="$state_dir/kind"
          backend_file="$state_dir/backend"
          file_file="$state_dir/file"
          since_file="$state_dir/since"
          region_file="$state_dir/region"
          webcam_file="$state_dir/webcam.pid"
          pa_file="$state_dir/pa-modules"
          log_file="$state_dir/recorder.log"

          output_dir=${lib.escapeShellArg cfg.outputDir}
          case "$output_dir" in
            "~"/*) output_dir="$HOME/''${output_dir#\~/}" ;;
          esac

          backend_pref=${lib.escapeShellArg cfg.backend}
          target=${lib.escapeShellArg cfg.target}
          frame_rate=${lib.escapeShellArg (toString cfg.frameRate)}
          resolution=${lib.escapeShellArg cfg.resolution}
          desktop_audio=${lib.escapeShellArg (if cfg.audio.desktop.enable then "true" else "false")}
          desktop_sink=${lib.escapeShellArg cfg.audio.desktop.sink}
          desktop_mute=${lib.escapeShellArg (if cfg.audio.desktop.mute then "true" else "false")}
          microphone_audio=${lib.escapeShellArg (if cfg.audio.microphone.enable then "true" else "false")}
          microphone_source_opt=${lib.escapeShellArg cfg.audio.microphone.source}
          microphone_mute=${lib.escapeShellArg (if cfg.audio.microphone.mute then "true" else "false")}
          webcam_enabled=${lib.escapeShellArg (if cfg.webcam.enable then "true" else "false")}
          webcam_device=${lib.escapeShellArg cfg.webcam.device}
          webcam_size=${lib.escapeShellArg cfg.webcam.size}
          webcam_position=${lib.escapeShellArg cfg.webcam.position}
          webcam_crop=${lib.escapeShellArg cfg.webcam.crop}
          buffer_enabled=${lib.escapeShellArg (if cfg.buffer.enable then "true" else "false")}
          buffer_seconds=${lib.escapeShellArg (toString cfg.buffer.seconds)}

          notify() {
            notify-send -a "Screen recording" "$@" 2>/dev/null || true
          }

          is_active() {
            [ -f "$supervisor_file" ] && kill -0 "$(cat "$supervisor_file")" 2>/dev/null
          }

          fmt_duration() {
            local total="$1"
            printf '%02d:%02d\n' "$((total / 60))" "$((total % 60))"
          }

          cleanup_audio() {
            [ -f "$pa_file" ] || return 0
            tac "$pa_file" | while read -r module; do
              [ -n "$module" ] && pactl unload-module "$module" 2>/dev/null || true
            done
            rm -f "$pa_file"
          }

          cleanup() {
            if [ -f "$webcam_file" ]; then
              kill "$(cat "$webcam_file")" 2>/dev/null || true
              rm -f "$webcam_file"
            fi
            cleanup_audio
            rm -f "$child_file" "$supervisor_file" "$kind_file" "$backend_file" \
              "$file_file" "$since_file" "$region_file"
          }

          stop_child() {
            [ -f "$child_file" ] || return 0
            local pid
            pid=$(cat "$child_file")
            kill -INT "$pid" 2>/dev/null || true
            for _ in $(seq 1 50); do
              kill -0 "$pid" 2>/dev/null || break
              sleep 0.1
            done
            kill -KILL "$pid" 2>/dev/null || true
          }

          capture_target() {
            if [ "$target" = "region" ]; then
              local region xy size x y w h
              region=$(slurp -d) || return 1
              printf '%s\n' "$region" > "$region_file"
              xy="''${region%% *}"
              size="''${region#* }"
              x="''${xy%,*}"
              y="''${xy#*,}"
              w="''${size%x*}"
              h="''${size#*x}"
              printf 'region:%sx%s+%s+%s\n' "$w" "$h" "$x" "$y"
            else
              local monitor
              monitor=$(mmsg get all-monitors | jq -r '.monitors[] | select(.active) | .name' | head -n1)
              [ -n "$monitor" ] || return 1
              printf 'monitor:%s\n' "$monitor"
            fi
          }

          desktop_source() {
            local sink="$desktop_sink"
            [ -n "$sink" ] || sink=$(pactl get-default-sink)
            printf '%s.monitor\n' "$sink"
          }

          microphone_source() {
            local source="$microphone_source_opt"
            [ -n "$source" ] || source=$(pactl get-default-source)
            printf '%s\n' "$source"
          }

          gsr_audio_args() {
            local desktop="" mic="" audio=""
            if [ "$desktop_audio" = "true" ] && [ "$desktop_mute" != "true" ]; then
              if [ -n "$desktop_sink" ]; then desktop="$desktop_sink"; else desktop="default_output"; fi
            fi
            if [ "$microphone_audio" = "true" ] && [ "$microphone_mute" != "true" ]; then
              if [ -n "$microphone_source_opt" ]; then mic="$microphone_source_opt"; else mic="default_input"; fi
            fi
            [ -n "$desktop" ] && audio="$desktop"
            if [ -n "$mic" ]; then
              if [ -n "$audio" ]; then audio="$audio|$mic"; else audio="$mic"; fi
            fi
            [ -n "$audio" ] && printf '%s\n' "-a" "$audio" "-ac" "aac"
          }

          wf_audio_device() {
            local sink="" source="" module=""
            if [ "$desktop_audio" = "true" ] && [ "$desktop_mute" != "true" ]; then
              sink=$(desktop_source)
            fi
            if [ "$microphone_audio" = "true" ] && [ "$microphone_mute" != "true" ]; then
              source=$(microphone_source)
            fi

            if [ -n "$sink" ] && [ -n "$source" ]; then
              if module=$(pactl load-module module-null-sink sink_name=ojuny_screenrecord sink_properties=device.description=ojuny_screenrecord 2>/dev/null); then
                printf '%s\n' "$module" > "$pa_file"
                if module=$(pactl load-module module-loopback source="$sink" sink=ojuny_screenrecord latency_msec=20 2>/dev/null); then
                  printf '%s\n' "$module" >> "$pa_file"
                else
                  sink=""
                fi
                if module=$(pactl load-module module-loopback source="$source" sink=ojuny_screenrecord latency_msec=20 2>/dev/null); then
                  printf '%s\n' "$module" >> "$pa_file"
                else
                  source=""
                fi
                if [ -n "$sink" ] && [ -n "$source" ]; then
                  printf 'ojuny_screenrecord.monitor\n'
                  return 0
                fi
                cleanup_audio
              else
                source=""
              fi
            fi

            if [ -n "$sink" ]; then
              printf '%s\n' "$sink"
            elif [ -n "$source" ]; then
              printf '%s\n' "$source"
            fi
          }

          start_gsr() {
            local capture="$1" file="$2"
            local args=(-w "$capture" -k auto -f "$frame_rate" -fm cfr -fallback-cpu-encoding yes -o "$file")
            [ -n "$resolution" ] && args+=(-s "$resolution")
            [ "$buffer_enabled" = "true" ] && args+=(-r "$buffer_seconds")

            local audio_args=()
            mapfile -t audio_args < <(gsr_audio_args)
            gpu-screen-recorder "''${args[@]}" "''${audio_args[@]}" >/dev/null 2>>"$log_file" &
            echo $! > "$child_file"

            if [ "$buffer_enabled" = "true" ]; then
              sleep 1
              kill -0 "$(cat "$child_file")" 2>/dev/null
              return
            fi

            local ticks=0
            while kill -0 "$(cat "$child_file")" 2>/dev/null && [ ! -s "$file" ]; do
              if [ "$ticks" -ge 75 ]; then
                stop_child
                return 1
              fi
              ticks=$((ticks + 1))
              sleep 0.2
            done
            [ -s "$file" ]
          }

          start_wf() {
            local capture="$1" file="$2"
            local args=(-r 60 -R 48000 -f "$file")
            case "$capture" in
              monitor:*)
                args=(-o "''${capture#monitor:}" "''${args[@]}")
                ;;
              region:*)
                local region="''${capture#region:}"
                if [[ "$region" =~ ^([0-9]+)x([0-9]+)\+(-?[0-9]+)\+(-?[0-9]+)$ ]]; then
                  args=(-g "''${BASH_REMATCH[3]},''${BASH_REMATCH[4]} ''${BASH_REMATCH[1]}x''${BASH_REMATCH[2]}" "''${args[@]}")
                else
                  return 1
                fi
                ;;
              *)
                return 1
                ;;
            esac

            local device
            device=$(wf_audio_device)
            [ -n "$device" ] && args+=(--audio="$device")

            wf-recorder "''${args[@]}" >/dev/null 2>>"$log_file" &
            echo $! > "$child_file"

            local ticks=0
            while kill -0 "$(cat "$child_file")" 2>/dev/null && [ ! -s "$file" ]; do
              if [ "$ticks" -ge 75 ]; then
                stop_child
                return 1
              fi
              ticks=$((ticks + 1))
              sleep 0.2
            done
            [ -s "$file" ]
          }

          start_backend() {
            local capture="$1" file="$2" backend="$3"
            if [ "$backend" = "gpu-screen-recorder" ]; then
              start_gsr "$capture" "$file"
            else
              start_wf "$capture" "$file"
            fi
          }

          overlay_geometry() {
            if [ -s "$region_file" ]; then
              local region xy size x y w h
              region=$(cat "$region_file")
              xy="''${region%% *}"
              size="''${region#* }"
              x="''${xy%,*}"
              y="''${xy#*,}"
              w="''${size%x*}"
              h="''${size#*x}"
              printf '%s %s %s %s\n' "$x" "$y" "$w" "$h"
            else
              mmsg get all-monitors \
                | jq -r '.monitors[] | select(.active) | "\(.x) \(.y) \(.width) \(.height)"' \
                | head -n1
            fi
          }

          overlay_position() {
            local width="$1" height="$2" margin=24
            local gx gy gw gh
            read -r gx gy gw gh <<< "$(overlay_geometry)"
            case "$webcam_position" in
              top-left)
                printf '%s %s\n' "$((gx + margin))" "$((gy + margin))"
                ;;
              top-right)
                printf '%s %s\n' "$((gx + gw - width - margin))" "$((gy + margin))"
                ;;
              bottom-left)
                printf '%s %s\n' "$((gx + margin))" "$((gy + gh - height - margin))"
                ;;
              bottom-right)
                printf '%s %s\n' "$((gx + gw - width - margin))" "$((gy + gh - height - margin))"
                ;;
            esac
          }

          overlay_resize() {
            local size="''${1:-$webcam_size}" height width id previous x y
            case "$size" in
              small) height=270 ;;
              medium) height=405 ;;
              large) height=540 ;;
              *) height=405 ;;
            esac
            case "$webcam_crop" in
              "8:9") width=$((height * 8 / 9)) ;;
              "1:1") width=$height ;;
              "16:9") width=$((height * 16 / 9)) ;;
              *) width=$((height * 8 / 9)) ;;
            esac

            id=$(mmsg get all-clients | jq -r '.clients[] | select(.appid == "WebcamOverlay") | .id' | head -n1)
            [ -n "$id" ] || return 1

            previous=$(mmsg get focusing-client 2>/dev/null | jq -r '.id' 2>/dev/null || true)
            mmsg dispatch focusid client,"$id" >/dev/null 2>&1 || true
            mmsg dispatch resizewin,"$width","$height" >/dev/null 2>&1 || true
            read -r x y <<< "$(overlay_position "$width" "$height")"
            mmsg dispatch movewin,"$x","$y" >/dev/null 2>&1 || true
            [ -n "$previous" ] && mmsg dispatch focusid client,"$previous" >/dev/null 2>&1 || true
          }

          webcam_start() {
            is_active || { notify "Start a recording first"; exit 1; }
            [ -f "$webcam_file" ] && return 0

            local device="$webcam_device"
            [ -n "$device" ] || device=$(v4l2-ctl --list-devices | awk '/^[[:space:]]*\/dev\/video/{print $1; exit}')
            [ -n "$device" ] || { notify "No webcam found"; exit 1; }

            local crop_filter=""
            case "$webcam_crop" in
              "8:9") crop_filter="--vf=lavfi=[crop=ih*8/9:ih]" ;;
              "1:1") crop_filter="--vf=lavfi=[crop=ih:ih]" ;;
              "16:9") crop_filter="" ;;
            esac

            mpv "av://v4l2:$device" \
              --profile=low-latency --untimed --no-cache \
              --demuxer-lavf-o=framerate=30 \
              $crop_filter \
              --title=WebcamOverlay --wayland-app-id=WebcamOverlay \
              --no-border --no-audio --no-osc --osd-level=0 --really-quiet \
              >/dev/null 2>&1 &
            echo $! > "$webcam_file"
            sleep 0.5
            overlay_resize "$webcam_size" || true
          }

          webcam_stop() {
            [ -f "$webcam_file" ] || return 0
            kill "$(cat "$webcam_file")" 2>/dev/null || true
            rm -f "$webcam_file"
          }

          start_recording() {
            is_active && { notify "Already recording"; exit 0; }
            mkdir -p "$output_dir"
            rm -f "$state_dir"/*.pid "$kind_file" "$backend_file" "$file_file" "$since_file" "$region_file" "$pa_file"

            local capture
            capture=$(capture_target) || exit 0
            local file="$output_dir/screenrecording-$(date +%Y-%m-%d_%H-%M-%S).mp4"

            echo "$$" > "$supervisor_file"
            echo "$file" > "$file_file"
            date +%s > "$since_file"
            trap 'stop_child; cleanup; exit 0' INT TERM

            [ "$webcam_enabled" = "true" ] && webcam_start

            local candidates=()
            case "$backend_pref" in
              gpu-screen-recorder) candidates=(gpu-screen-recorder) ;;
              wf-recorder) candidates=(wf-recorder) ;;
              auto) candidates=(gpu-screen-recorder wf-recorder) ;;
            esac
            [ "$buffer_enabled" = "true" ] && candidates=(gpu-screen-recorder)

            local backend started=false
            for backend in "''${candidates[@]}"; do
              command -v "$backend" >/dev/null 2>&1 || continue
              rm -f "$file"
              if start_backend "$capture" "$file" "$backend"; then
                echo "$backend" > "$backend_file"
                started=true
                break
              fi
              stop_child
              cleanup_audio
              rm -f "$file"
            done

            if [ "$started" != "true" ]; then
              notify "Could not start recording"
              cleanup
              exit 1
            fi

            echo "recording" > "$kind_file"
            notify "Recording started"
            wait "$(cat "$child_file")"
            cleanup
          }

          start_replay() {
            is_active && { notify "Already recording"; exit 0; }
            command -v gpu-screen-recorder >/dev/null 2>&1 || {
              notify "Replay buffer requires gpu-screen-recorder"
              exit 1
            }

            mkdir -p "$output_dir"
            rm -f "$state_dir"/*.pid "$kind_file" "$backend_file" "$file_file" "$since_file" "$region_file" "$pa_file"

            local capture
            capture=$(capture_target) || exit 0
            local file="$output_dir/replay.mp4"

            echo "$$" > "$supervisor_file"
            echo "$file" > "$file_file"
            date +%s > "$since_file"
            buffer_enabled=true
            trap 'stop_child; cleanup; exit 0' INT TERM

            [ "$webcam_enabled" = "true" ] && webcam_start

            if ! start_backend "$capture" "$file" "gpu-screen-recorder"; then
              notify "Could not start replay buffer"
              cleanup
              exit 1
            fi

            echo "replay" > "$kind_file"
            echo "gpu-screen-recorder" > "$backend_file"
            notify "Replay buffer started"
            wait "$(cat "$child_file")"
            cleanup
          }

          stop_recording() {
            if ! is_active; then
              cleanup
              notify "No recording is active"
              exit 0
            fi
            kill -INT "$(cat "$supervisor_file")" 2>/dev/null || true
            for _ in $(seq 1 50); do
              kill -0 "$(cat "$supervisor_file")" 2>/dev/null || break
              sleep 0.1
            done
            cleanup
            notify "Recording saved"
          }

          replay_save() {
            is_active || { notify "No replay buffer is active"; exit 1; }
            [ "$(cat "$kind_file" 2>/dev/null || true)" = "replay" ] || {
              notify "The active recording is not a replay buffer"
              exit 1
            }

            local pid source destination size last=0
            pid=$(cat "$child_file")
            source=$(cat "$file_file")
            kill -USR1 "$pid" 2>/dev/null || { notify "Replay save failed"; exit 1; }

            for _ in $(seq 1 60); do
              size=$(stat -c%s "$source" 2>/dev/null || echo 0)
              if [ "$size" -gt 0 ] && [ "$size" = "$last" ]; then break; fi
              last=$size
              sleep 0.5
            done

            destination="$output_dir/screenrecording-replay-$(date +%Y-%m-%d_%H-%M-%S).mp4"
            cp --reflink=auto "$source" "$destination" 2>/dev/null || cp "$source" "$destination"
            notify "Replay saved" "$destination"
          }

          replay_toggle() {
            if is_active; then
              if [ "$(cat "$kind_file" 2>/dev/null || true)" = "replay" ]; then
                stop_recording
              else
                notify "A normal recording is active"
                exit 1
              fi
            else
              start_replay
            fi
          }

          status() {
            local active=false kind="" backend="" file="" duration="" since=0
            if is_active; then
              active=true
              kind=$(cat "$kind_file" 2>/dev/null || true)
              backend=$(cat "$backend_file" 2>/dev/null || true)
              file=$(cat "$file_file" 2>/dev/null || true)
              since=$(cat "$since_file" 2>/dev/null || echo 0)
              duration=$(fmt_duration "$(( $(date +%s) - since ))")
            fi

            if [ "''${1:-}" = "--json" ]; then
              jq -n \
                --argjson active "$active" \
                --arg kind "$kind" \
                --arg backend "$backend" \
                --arg file "$file" \
                --arg duration "$duration" \
                '{active:$active,kind:$kind,backend:$backend,file:$file,duration:$duration}'
            elif [ "$active" = "true" ]; then
              printf '%s %s %s\n' "$kind" "$duration" "$file"
            else
              printf 'inactive\n'
            fi
          }

          level_meter() {
            command -v cava >/dev/null 2>&1 || {
              echo "cava is not installed. Enable audio.levelMeter." >&2
              exit 1
            }
            local source config
            if [ "''${1:-microphone}" = "desktop" ]; then
              source=$(desktop_source)
            else
              source=$(microphone_source)
            fi
            config=$(mktemp)
            cat > "$config" <<EOF
          [general]
          bars = 24
          [input]
          method = pulse
          source = $source
          [output]
          method = noncurses
          EOF
            cava -p "$config"
            rm -f "$config"
          }

          case "''${1:-status}" in
            start) start_recording ;;
            stop) stop_recording ;;
            toggle)
              if is_active; then stop_recording; else start_recording; fi
              ;;
            status) status "''${2:-}" ;;
            replay-start) start_replay ;;
            replay-save) replay_save ;;
            replay-stop) stop_recording ;;
            replay-toggle) replay_toggle ;;
            webcam-start) webcam_start ;;
            webcam-stop) webcam_stop ;;
            webcam-toggle)
              if [ -f "$webcam_file" ]; then webcam_stop; else webcam_start; fi
              ;;
            overlay-resize) overlay_resize "''${2:-$webcam_size}" ;;
            list-devices) v4l2-ctl --list-devices ;;
            list-sinks) pactl list short sinks ;;
            list-sources) pactl list short sources ;;
            level) level_meter "''${2:-microphone}" ;;
            cleanup) cleanup ;;
            *)
              echo "usage: ojuny-screenrecord {start|stop|toggle|status|replay-start|replay-save|replay-stop|replay-toggle|webcam-start|webcam-stop|webcam-toggle|overlay-resize|list-devices|list-sinks|list-sources|level|cleanup}" >&2
              exit 2
              ;;
          esac
        '';
      };

      pluginJson = pkgs.writeText "plugin.json" (
        builtins.toJSON {
          id = "ojunyScreenrecord";
          name = "Screen recording";
          description = "Recording indicator and stop control";
          version = "1.0.0";
          license = "MIT";
          author = "ojuny";
          icon = "fiber_manual_record";
          type = "composite";
          capabilities = [ "dankbar-widget" ];
          components = {
            widget = "./ScreenrecordWidget.qml";
          };
          requires_dms = ">=1.5.0";
          compositors = [ "mango" ];
          permissions = [ "process" ];
        }
      );

      pluginQml = pkgs.writeText "ScreenrecordWidget.qml" ''
        import QtQuick
        import Quickshell
        import Quickshell.Io
        import qs.Common
        import qs.Widgets
        import qs.Modules.Plugins

        PluginComponent {
            id: root

            property bool recording: false
            property string duration: ""
            property string file: ""

            Process {
                id: statusProcess
                command: [ "${wrapper}/bin/ojuny-screenrecord", "status", "--json" ]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            const state = JSON.parse(text);
                            root.recording = state.active === true;
                            root.duration = state.duration || "";
                            root.file = state.file || "";
                        } catch (error) {
                            root.recording = false;
                        }
                    }
                }
            }

            Process {
                id: stopProcess
                command: [ "${wrapper}/bin/ojuny-screenrecord", "stop" ]
                running: false
            }

            Timer {
                interval: 1000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    if (!statusProcess.running)
                        statusProcess.running = true;
                }
            }

            pillClickAction: () => {
                if (root.recording && !stopProcess.running)
                    stopProcess.running = true;
            }

            horizontalBarPill: Component {
                StyledRect {
                    visible: root.recording
                    width: root.recording ? parent.widgetThickness + durationText.implicitWidth + 12 : 0
                    height: root.recording ? parent.widgetThickness : 0
                    radius: Theme.cornerRadius
                    color: Theme.errorContainer

                    Row {
                        anchors.centerIn: parent
                        spacing: 4

                        DankIcon {
                            name: "fiber_manual_record"
                            size: root.iconSize
                            color: Theme.error
                        }

                        StyledText {
                            id: durationText
                            text: root.duration
                            color: Theme.error
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }
            }

            verticalBarPill: Component {
                StyledRect {
                    visible: root.recording
                    width: root.recording ? parent.widgetThickness : 0
                    height: root.recording ? parent.widgetThickness : 0
                    radius: Theme.cornerRadius
                    color: Theme.errorContainer

                    DankIcon {
                        anchors.centerIn: parent
                        name: "fiber_manual_record"
                        size: root.iconSize
                        color: Theme.error
                    }
                }
            }
        }
      '';

      pluginSrc = pkgs.runCommandLocal "ojuny-screenrecord-plugin" { } ''
        mkdir -p $out
        cp ${pluginJson} $out/plugin.json
        cp ${pluginQml} $out/ScreenrecordWidget.qml
      '';

      overlayRule = {
        app_id = "WebcamOverlay";
        is_unmanaged_global = 1;
        is_floating = 1;
        is_overlay = 1;
        no_border = 1;
        no_shadow = 1;
        no_radius = 1;
        no_animation = 1;
      };

      obsRules = [
        {
          app_id = "com.obsproject.Studio";
          global_key_binding = "super+alt+o";
        }
        {
          app_id = "com.obsproject.Studio";
          global_key_binding = "super+alt+p";
        }
      ];
    in
    {
      options.ojuny.patch.screenrecord = {
        backend = lib.mkOption {
          type = lib.types.enum [
            "auto"
            "gpu-screen-recorder"
            "wf-recorder"
          ];
          default = "auto";
          description = "Recorder backend. auto prefers gpu-screen-recorder and falls back to wf-recorder.";
        };

        target = lib.mkOption {
          type = lib.types.enum [
            "region"
            "fullscreen"
          ];
          default = "region";
          description = "Capture target. region opens the slurp picker.";
        };

        outputDir = lib.mkOption {
          type = lib.types.str;
          default = "~/Videos";
          description = "Recording output directory. A leading ~ expands to the user home.";
        };

        frameRate = lib.mkOption {
          type = lib.types.ints.between 15 240;
          default = 60;
          description = "Capture frame rate.";
        };

        resolution = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Optional WxH for gpu-screen-recorder. Empty means native.";
        };

        audio = {
          desktop = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Record desktop audio.";
            };
            sink = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Sink name. Empty follows the default sink.";
            };
            mute = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Omit desktop audio at start.";
            };
          };

          microphone = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Record microphone audio.";
            };
            source = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Source name. Empty follows the default source.";
            };
            mute = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Omit microphone audio at start.";
            };
          };

          levelMeter = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Install cava and pavucontrol and expose the level command.";
          };
        };

        webcam = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Start the webcam overlay with a recording.";
          };
          device = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "V4L2 device. Empty selects the first capture device.";
          };
          size = lib.mkOption {
            type = lib.types.enum [
              "small"
              "medium"
              "large"
            ];
            default = "medium";
            description = "Overlay height preset.";
          };
          position = lib.mkOption {
            type = lib.types.enum [
              "top-left"
              "top-right"
              "bottom-left"
              "bottom-right"
            ];
            default = "bottom-right";
            description = "Overlay position inside the recorded region or active monitor.";
          };
          crop = lib.mkOption {
            type = lib.types.enum [
              "8:9"
              "1:1"
              "16:9"
            ];
            default = "8:9";
            description = "Camera crop shape.";
          };
        };

        buffer = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable the replay buffer commands and binds.";
          };
          seconds = lib.mkOption {
            type = lib.types.ints.between 10 300;
            default = 30;
            description = "Replay buffer length in seconds.";
          };
        };

        indicator = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Install the DMS recording indicator.";
          };
          style = lib.mkOption {
            type = lib.types.enum [
              "plugin"
              "privacy"
            ];
            default = "plugin";
            description = "plugin installs the dedicated recording pill. privacy relies on the existing DMS privacy indicator.";
          };
          barId = lib.mkOption {
            type = lib.types.str;
            default = "default";
            description = "DMS bar configuration that receives the widget.";
          };
        };

        obs = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Install OBS Studio and optional global binds.";
          };
          globalBinds = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Add Mango global-key rules for OBS.";
          };
        };

        binds = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Add the Mango recording binds.";
          };
        };
      };

      config = lib.mkMerge [
        {
          # @option widget = "dropdown"; label = "Backend"; group = "Capture"; groupOrder = 20; order = 10; choices = [ "auto" "gpu-screen-recorder" "wf-recorder" ]; visibleWhen.path = "ojuny.patch.screenrecord.enable"; visibleWhen.equals = true; description = "auto prefers gpu-screen-recorder and falls back to wf-recorder. wf-recorder uses CPU encoding and has no replay buffer."
          ojuny.patch.screenrecord.backend = "auto";

          # @option widget = "dropdown"; label = "Capture target"; group = "Capture"; groupOrder = 20; order = 20; choices = [ "region" "fullscreen" ]; visibleWhen.path = "ojuny.patch.screenrecord.enable"; visibleWhen.equals = true; description = "region opens the slurp picker. fullscreen records the active monitor."
          ojuny.patch.screenrecord.target = "region";

          # @option widget = "text"; label = "Output directory"; group = "Capture"; groupOrder = 20; order = 30; visibleWhen.path = "ojuny.patch.screenrecord.enable"; visibleWhen.equals = true; description = "Directory for recordings. ~ expands to the user home."
          ojuny.patch.screenrecord.outputDir = "~/Videos";

          # @option widget = "spin"; label = "Frame rate"; group = "Capture"; groupOrder = 20; order = 40; min = 15; max = 240; step = 5; unit = "fps"; visibleWhen.path = "ojuny.patch.screenrecord.enable"; visibleWhen.equals = true; description = "Capture frame rate. 60 is the default. Lower values reduce file size and CPU fallback load."
          ojuny.patch.screenrecord.frameRate = 60;

          # @option widget = "text"; label = "Resolution"; group = "Capture"; groupOrder = 20; order = 50; advanced = true; visibleWhen.path = "ojuny.patch.screenrecord.enable"; visibleWhen.equals = true; description = "Optional WxH for gpu-screen-recorder, for example 1920x1080. Empty means native resolution. Ignored by wf-recorder."
          ojuny.patch.screenrecord.resolution = "";

          # @option widget = "switch"; label = "Desktop audio"; group = "Audio"; groupOrder = 30; order = 10; visibleWhen.path = "ojuny.patch.screenrecord.enable"; visibleWhen.equals = true; description = "Record the selected sink monitor source."
          ojuny.patch.screenrecord.audio.desktop.enable = true;

          # @option widget = "text"; label = "Desktop sink"; group = "Audio"; groupOrder = 30; order = 20; advanced = true; visibleWhen.path = "ojuny.patch.screenrecord.audio.desktop.enable"; visibleWhen.equals = true; description = "Sink name. Empty follows the current default sink. Use ojuny-screenrecord list-sinks to list names."
          ojuny.patch.screenrecord.audio.desktop.sink = "";

          # @option widget = "switch"; label = "Mute desktop at start"; group = "Audio"; groupOrder = 30; order = 30; visibleWhen.path = "ojuny.patch.screenrecord.audio.desktop.enable"; visibleWhen.equals = true; description = "Omit desktop audio from this recording. This does not change the global sink mute."
          ojuny.patch.screenrecord.audio.desktop.mute = false;

          # @option widget = "switch"; label = "Microphone"; group = "Audio"; groupOrder = 30; order = 40; visibleWhen.path = "ojuny.patch.screenrecord.enable"; visibleWhen.equals = true; description = "Record the selected microphone source. Off by default so a global recording bind does not silently open the microphone."
          ojuny.patch.screenrecord.audio.microphone.enable = false;

          # @option widget = "text"; label = "Microphone source"; group = "Audio"; groupOrder = 30; order = 50; advanced = true; visibleWhen.path = "ojuny.patch.screenrecord.audio.microphone.enable"; visibleWhen.equals = true; description = "Source name. Empty follows the current default source. Use ojuny-screenrecord list-sources to list names."
          ojuny.patch.screenrecord.audio.microphone.source = "";

          # @option widget = "switch"; label = "Mute microphone at start"; group = "Audio"; groupOrder = 30; order = 60; visibleWhen.path = "ojuny.patch.screenrecord.audio.microphone.enable"; visibleWhen.equals = true; description = "Omit microphone audio from this recording. This does not change the global source mute."
          ojuny.patch.screenrecord.audio.microphone.mute = false;

          # @option widget = "switch"; label = "Level meter"; group = "Audio"; groupOrder = 30; order = 70; advanced = true; visibleWhen.path = "ojuny.patch.screenrecord.enable"; visibleWhen.equals = true; description = "Install cava and pavucontrol and expose ojuny-screenrecord level. The meter runs only on demand."
          ojuny.patch.screenrecord.audio.levelMeter = false;

          # @option widget = "switch"; label = "Webcam overlay"; group = "Webcam"; groupOrder = 40; order = 10; visibleWhen.path = "ojuny.patch.screenrecord.enable"; visibleWhen.equals = true; description = "Start the webcam overlay with a recording and include it in the captured region."
          ojuny.patch.screenrecord.webcam.enable = false;

          # @option widget = "text"; label = "Camera device"; group = "Webcam"; groupOrder = 40; order = 20; advanced = true; visibleWhen.path = "ojuny.patch.screenrecord.webcam.enable"; visibleWhen.equals = true; description = "V4L2 device such as /dev/video0. Empty selects the first capture device. Use ojuny-screenrecord list-devices to list devices."
          ojuny.patch.screenrecord.webcam.device = "";

          # @option widget = "dropdown"; label = "Overlay size"; group = "Webcam"; groupOrder = 40; order = 30; choices = [ "small" "medium" "large" ]; visibleWhen.path = "ojuny.patch.screenrecord.webcam.enable"; visibleWhen.equals = true; description = "Overlay height preset: 270, 405, or 540 pixels."
          ojuny.patch.screenrecord.webcam.size = "medium";

          # @option widget = "dropdown"; label = "Overlay position"; group = "Webcam"; groupOrder = 40; order = 40; choices = [ "top-left" "top-right" "bottom-left" "bottom-right" ]; visibleWhen.path = "ojuny.patch.screenrecord.webcam.enable"; visibleWhen.equals = true; description = "Position inside the recorded region, or inside the active monitor for fullscreen recordings."
          ojuny.patch.screenrecord.webcam.position = "bottom-right";

          # @option widget = "dropdown"; label = "Overlay shape"; group = "Webcam"; groupOrder = 40; order = 50; choices = [ "8:9" "1:1" "16:9" ]; visibleWhen.path = "ojuny.patch.screenrecord.webcam.enable"; visibleWhen.equals = true; description = "Crop applied to the camera feed. 8:9 matches the Omarchy portrait overlay."
          ojuny.patch.screenrecord.webcam.crop = "8:9";

          # @option widget = "switch"; label = "Replay buffer"; group = "Replay buffer"; groupOrder = 50; order = 10; visibleWhen.path = "ojuny.patch.screenrecord.enable"; visibleWhen.equals = true; description = "Enable the last-minute buffer and its Mango binds. Requires gpu-screen-recorder."
          ojuny.patch.screenrecord.buffer.enable = false;

          # @option widget = "spin"; label = "Buffer length"; group = "Replay buffer"; groupOrder = 50; order = 20; min = 10; max = 300; step = 5; unit = "s"; visibleWhen.path = "ojuny.patch.screenrecord.buffer.enable"; visibleWhen.equals = true; description = "Seconds kept in memory. Memory cost grows with bitrate and length."
          ojuny.patch.screenrecord.buffer.seconds = 30;

          # @option widget = "switch"; label = "Recording indicator"; group = "Indicator"; groupOrder = 60; order = 10; visibleWhen.path = "ojuny.patch.screenrecord.enable"; visibleWhen.equals = true; description = "Install the DMS recording pill. It shows the duration and stops the recording on click."
          ojuny.patch.screenrecord.indicator.enable = true;

          # @option widget = "dropdown"; label = "Indicator style"; group = "Indicator"; groupOrder = 60; order = 20; choices = [ "plugin" "privacy" ]; visibleWhen.path = "ojuny.patch.screenrecord.indicator.enable"; visibleWhen.equals = true; description = "plugin installs the dedicated recording pill. privacy relies only on the existing DMS privacy indicator."
          ojuny.patch.screenrecord.indicator.style = "plugin";

          # @option widget = "text"; label = "Bar ID"; group = "Indicator"; groupOrder = 60; order = 30; advanced = true; visibleWhen.path = "ojuny.patch.screenrecord.indicator.style"; visibleWhen.equals = "plugin"; description = "DMS bar configuration that receives the widget. The default bar is named default."
          ojuny.patch.screenrecord.indicator.barId = "default";

          # @option widget = "switch"; label = "OBS Studio"; group = "OBS"; groupOrder = 70; order = 10; visibleWhen.path = "ojuny.patch.screenrecord.enable"; visibleWhen.equals = true; description = "Install OBS for scenes and streaming. OBS is not driven by ojuny-screenrecord in v1."
          ojuny.patch.screenrecord.obs.enable = false;

          # @option widget = "switch"; label = "OBS global binds"; group = "OBS"; groupOrder = 70; order = 20; visibleWhen.path = "ojuny.patch.screenrecord.obs.enable"; visibleWhen.equals = true; description = "Add Mango global_key_binding rules for super+alt+o and super+alt+p. Configure the matching OBS hotkeys."
          ojuny.patch.screenrecord.obs.globalBinds = true;

          # @option widget = "switch"; label = "Mango keybinds"; group = "Keybinds"; groupOrder = 80; order = 10; visibleWhen.path = "ojuny.patch.screenrecord.enable"; visibleWhen.equals = true; description = "Add the recording, replay and webcam binds. Chords are SUPER+ALT+R, B, S and W."
          ojuny.patch.screenrecord.binds.enable = true;
        }
        (lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = config.services.pipewire.enable;
              message = "patch-screenrecord requires PipeWire. Enable the core audio module.";
            }
            {
              assertion = !(cfg.buffer.enable && cfg.backend == "wf-recorder");
              message = "patch-screenrecord replay buffer requires gpu-screen-recorder. Set backend to auto or gpu-screen-recorder.";
            }
            {
              assertion = cfg.outputDir != "";
              message = "patch-screenrecord requires a non-empty outputDir.";
            }
          ];

          environment.systemPackages = [ wrapper ] ++ lib.optionals cfg.obs.enable [ pkgs.obs-studio ];

          desktop.ojuny.mango.binds.common = lib.mkIf cfg.binds.enable {
            ojunyScreenrecordToggle = {
              modifier = [
                "SUPER"
                "ALT"
              ];
              keys = [ "R" ];
              dispatcher = "spawn";
              args = "${wrapper}/bin/ojuny-screenrecord toggle";
              description = "Start or stop screen recording";
              group = "System";
              subcat = "Capture";
            };

            ojunyScreenrecordReplayToggle = lib.mkIf cfg.buffer.enable {
              modifier = [
                "SUPER"
                "ALT"
              ];
              keys = [ "B" ];
              dispatcher = "spawn";
              args = "${wrapper}/bin/ojuny-screenrecord replay-toggle";
              description = "Start or stop the replay buffer";
              group = "System";
              subcat = "Capture";
            };

            ojunyScreenrecordReplaySave = lib.mkIf cfg.buffer.enable {
              modifier = [
                "SUPER"
                "ALT"
              ];
              keys = [ "S" ];
              dispatcher = "spawn";
              args = "${wrapper}/bin/ojuny-screenrecord replay-save";
              description = "Save the last-minute replay clip";
              group = "System";
              subcat = "Capture";
            };

            ojunyScreenrecordWebcam = lib.mkIf cfg.webcam.enable {
              modifier = [
                "SUPER"
                "ALT"
              ];
              keys = [ "W" ];
              dispatcher = "spawn";
              args = "${wrapper}/bin/ojuny-screenrecord webcam-toggle";
              description = "Start or stop the webcam overlay";
              group = "System";
              subcat = "Capture";
            };
          };

          desktop.ojuny.mango.rules.window_rule = lib.mkAfter (
            [ overlayRule ] ++ lib.optionals (cfg.obs.enable && cfg.obs.globalBinds) obsRules
          );

          desktop.ojuny.dms.plugins.ojunyScreenrecord =
            lib.mkIf (cfg.indicator.enable && cfg.indicator.style == "plugin")
              {
                enable = true;
                src = pluginSrc;
              };

          desktop.ojuny.dms.barConfigs.${cfg.indicator.barId}.rightWidgets.ojunyScreenrecord =
            lib.mkIf (cfg.indicator.enable && cfg.indicator.style == "plugin")
              {
                enabled = true;
                _order = 70;
              };
        })
      ];
    };
}
