/*
  @menu
  displayname = "Transcoding";
  icon = "movie-edit-symbolic";
  order = 205;
  description = "One-command image, video, and image-to-text conversion";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }:

{
  flake.modules.nixos.patch-transcoding =
    {
      config,
      lib,
      ...
    }:
    {
      options.ojuny.patch.transcoding.enable = lib.mkEnableOption "the transcoding patch";

      # @option widget = "switch"; label = "Transcoding"; group = "Patches"; description = "Install ojuny-transcode and add it to the Ojuny menu.";
      config.ojuny.patch.transcoding.enable = false;

      imports = [ self.modules.nixos.transcoding-backend ];
    };

  flake.modules.nixos.transcoding-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      active = config.ojuny.patch.transcoding.enable && (config.ojuny.patches or true);
      cfg = config.ojuny.patch.transcoding // {
        enable = active;
      };

      transcode = pkgs.writeShellApplication {
        name = "ojuny-transcode";
        runtimeInputs = with pkgs; [
          coreutils
          ffmpeg
          findutils
          fzf
          gawk
          gnugrep
          gnused
          imagemagick
          libnotify
        ];
        text = ''
          export LC_ALL=C.UTF-8

          usage() {
            cat <<'EOF'
          Usage:
            ojuny-transcode image <input> <jpg|png|webp> [high|medium|low]
            ojuny-transcode video <input> <mp4|webm|gif> [4k|1080p|720p]
            ojuny-transcode ascii <input> [--width N] [--mode ascii|block] [--output FILE]
            ojuny-transcode interactive [directory]

          Explicit modes never prompt. Interactive mode uses fzf to pick a file,
          mode, and format. Output is written next to the input and never
          overwrites an existing file.
          EOF
          }

          notify() {
            notify-send -a "Ojuny Transcode" "$1" "$2" >/dev/null 2>&1 || true
          }

          fail() {
            notify-send -u critical -a "Ojuny Transcode" "Transcode failed" "$1" >/dev/null 2>&1 || true
            printf 'ojuny-transcode: %s\n' "$1" >&2
            exit 1
          }

          require_file() {
            [ -f "$1" ] || fail "input not found: $1"
            [ -r "$1" ] || fail "input not readable: $1"
          }

          unique_output() {
            local dir="$1" stem="$2" ext="$3" suffix="$4"
            local candidate="$dir/$stem''${suffix:+.$suffix}.$ext"
            local n=1
            while [ -e "$candidate" ]; do
              candidate="$dir/$stem''${suffix:+.$suffix}-$n.$ext"
              n=$((n + 1))
            done
            printf '%s\n' "$candidate"
          }

          transcode_image() {
            [ "$#" -ge 2 ] || fail "usage: ojuny-transcode image <input> <jpg|png|webp> [high|medium|low]"
            local input="$1"
            local format quality output dir base stem tmp q
            format="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
            quality="''${3:-medium}"
            require_file "$input"

            case "$format" in
              jpg|jpeg) format=jpg ;;
              png) format=png ;;
              webp) format=webp ;;
              *) fail "unsupported image format: $format (use jpg, png, webp)" ;;
            esac

            case "$quality" in
              high) q=92 ;;
              medium) q=82 ;;
              low) q=70 ;;
              *) fail "unsupported image quality: $quality (use high, medium, low)" ;;
            esac

            dir="$(dirname -- "$input")"
            base="$(basename -- "$input")"
            stem="''${base%.*}"
            output="$(unique_output "$dir" "$stem" "$format" "")"
            tmp="$(mktemp "''${output%.*}.XXXXXX.$format")"
            trap 'rm -f "$tmp"' EXIT

            notify "Transcoding image" "$base -> $format ($quality)"
            magick "$input" -strip -quality "$q" "$tmp" || fail "ImageMagick failed for $input"
            mv -- "$tmp" "$output"
            trap - EXIT
            notify "Transcode complete" "$output"
            printf '%s\n' "$output"
          }

          transcode_video() {
            [ "$#" -ge 2 ] || fail "usage: ojuny-transcode video <input> <mp4|webm|gif> [4k|1080p|720p]"
            local input="$1"
            local format resolution height output dir base stem tmp filter
            format="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
            resolution="''${3:-1080p}"
            require_file "$input"

            case "$format" in
              mp4|webm|gif) ;;
              *) fail "unsupported video format: $format (use mp4, webm, gif)" ;;
            esac

            case "$resolution" in
              4k) height=2160 ;;
              1080p) height=1080 ;;
              720p) height=720 ;;
              *) fail "unsupported video resolution: $resolution (use 4k, 1080p, 720p)" ;;
            esac

            dir="$(dirname -- "$input")"
            base="$(basename -- "$input")"
            stem="''${base%.*}"
            output="$(unique_output "$dir" "$stem" "$format" "")"
            tmp="$(mktemp "''${output%.*}.XXXXXX.$format")"
            trap 'rm -f "$tmp"' EXIT
            filter="scale=-2:$height"

            notify "Transcoding video" "$base -> $format ($resolution)"
            case "$format" in
              mp4)
                ffmpeg -hide_banner -loglevel error -y -i "$input" \
                  -map 0:v:0 -map 0:a? -vf "$filter" \
                  -c:v libx264 -preset medium -crf 20 \
                  -c:a aac -b:a 192k -movflags +faststart \
                  -f mp4 "$tmp" || fail "ffmpeg failed for $input"
                ;;
              webm)
                ffmpeg -hide_banner -loglevel error -y -i "$input" \
                  -map 0:v:0 -map 0:a? -vf "$filter" \
                  -c:v libvpx-vp9 -crf 32 -b:v 0 \
                  -c:a libopus -b:a 128k \
                  -f webm "$tmp" || fail "ffmpeg failed for $input"
                ;;
              gif)
                ffmpeg -hide_banner -loglevel error -y -i "$input" \
                  -map 0:v:0 -an \
                  -vf "fps=15,scale=-2:$height:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
                  -loop 0 -f gif "$tmp" || fail "ffmpeg failed for $input"
                ;;
            esac

            mv -- "$tmp" "$output"
            trap - EXIT
            notify "Transcode complete" "$output"
            printf '%s\n' "$output"
          }

          transcode_ascii() {
            [ "$#" -ge 1 ] || fail "usage: ojuny-transcode ascii <input> [--width N] [--mode ascii|block] [--output FILE]"
            local input="$1"
            shift
            local width=100 ascii_mode=ascii output="" dir base stem tmp ramp

            while [ "$#" -gt 0 ]; do
              case "$1" in
                --width)
                  [ "$#" -ge 2 ] || fail "--width needs a value"
                  width="$2"
                  shift 2
                  ;;
                --mode)
                  [ "$#" -ge 2 ] || fail "--mode needs a value"
                  ascii_mode="$2"
                  shift 2
                  ;;
                --output)
                  [ "$#" -ge 2 ] || fail "--output needs a value"
                  output="$2"
                  shift 2
                  ;;
                *) fail "unknown ascii option: $1" ;;
              esac
            done

            require_file "$input"
            case "$ascii_mode" in
              ascii) ramp=' .:-=+*#%@' ;;
              block) ramp=' ░▒▓█' ;;
              *) fail "unsupported ascii mode: $ascii_mode (use ascii or block)" ;;
            esac
            case "$width" in
              ""|*[!0-9]*) fail "width must be a positive integer" ;;
            esac
            [ "$width" -gt 0 ] || fail "width must be a positive integer"

            if [ -z "$output" ]; then
              dir="$(dirname -- "$input")"
              base="$(basename -- "$input")"
              stem="''${base%.*}"
              output="$(unique_output "$dir" "$stem" "txt" "ascii")"
            fi

            tmp="$(mktemp "$output.XXXXXX")"
            trap 'rm -f "$tmp"' EXIT
            notify "Converting image to text" "$(basename -- "$input") ($ascii_mode, width $width)"
            magick "$input" -colorspace Gray -resize "''${width}x" -depth 8 txt:- |
              gawk -v ramp="$ramp" '
                /^#/ { next }
                {
                  if (!match($0, /#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/)) next
                  hex = substr($0, RSTART + 1, 6)
                  r = strtonum("0x" substr(hex, 1, 2))
                  g = strtonum("0x" substr(hex, 3, 2))
                  b = strtonum("0x" substr(hex, 5, 2))
                  lum = (r * 299 + g * 587 + b * 114) / 1000
                  n = length(ramp)
                  idx = int(lum * n / 256) + 1
                  if (idx > n) idx = n
                  split($1, coords, ",")
                  y = coords[2]
                  sub(/:$/, "", y)
                  if (y != last) {
                    if (last != "") printf "\n"
                    last = y
                  }
                  printf "%s", substr(ramp, idx, 1)
                }
                END { printf "\n" }
              ' >"$tmp" || fail "ImageMagick failed for $input"

            mv -- "$tmp" "$output"
            trap - EXIT
            notify "Text conversion complete" "$output"
            printf '%s\n' "$output"
          }

          interactive() {
            local root="''${1:-$PWD}"
            local file mode format quality resolution ascii_mode width
            [ -d "$root" ] || fail "directory not found: $root"

            file="$(
              find "$root" -maxdepth 2 -type f \
                \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
                -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' \
                -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.gif' \) -print |
                fzf --prompt='File> ' --height=40% --reverse
            )" || true
            [ -n "$file" ] || { printf 'cancelled\n'; return 0; }

            mode="$(printf '%s\n' image video ascii | fzf --prompt='Mode> ' --height=20% --reverse)" || true
            [ -n "$mode" ] || { printf 'cancelled\n'; return 0; }

            case "$mode" in
              image)
                format="$(printf '%s\n' jpg png webp | fzf --prompt='Format> ' --height=20% --reverse)" || true
                [ -n "$format" ] || { printf 'cancelled\n'; return 0; }
                quality="$(printf '%s\n' high medium low | fzf --prompt='Quality> ' --height=20% --reverse)" || true
                [ -n "$quality" ] || { printf 'cancelled\n'; return 0; }
                transcode_image "$file" "$format" "$quality"
                ;;
              video)
                format="$(printf '%s\n' mp4 webm gif | fzf --prompt='Format> ' --height=20% --reverse)" || true
                [ -n "$format" ] || { printf 'cancelled\n'; return 0; }
                resolution="$(printf '%s\n' 4k 1080p 720p | fzf --prompt='Resolution> ' --height=20% --reverse)" || true
                [ -n "$resolution" ] || { printf 'cancelled\n'; return 0; }
                transcode_video "$file" "$format" "$resolution"
                ;;
              ascii)
                ascii_mode="$(printf '%s\n' ascii block | fzf --prompt='Style> ' --height=20% --reverse)" || true
                [ -n "$ascii_mode" ] || { printf 'cancelled\n'; return 0; }
                width="$(printf '%s\n' 60 80 100 120 160 | fzf --prompt='Width> ' --height=20% --reverse)" || true
                [ -n "$width" ] || { printf 'cancelled\n'; return 0; }
                transcode_ascii "$file" --width "$width" --mode "$ascii_mode"
                ;;
            esac
          }

          main() {
            [ "$#" -gt 0 ] || { usage; exit 1; }
            local mode="$1"
            shift
            case "$mode" in
              image) transcode_image "$@" ;;
              video) transcode_video "$@" ;;
              ascii) transcode_ascii "$@" ;;
              interactive) interactive "$@" ;;
              -h|--help|help) usage ;;
              *) usage >&2; fail "unknown mode: $mode" ;;
            esac
          }

          main "$@"
        '';
      };
    in
    {
      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ transcode ];

        desktop.ojuny.dankMenu.menu = {
          "trigger.transcode" = {
            icon = "movie_edit";
            label = "Transcode";
            aliases = [
              "transcode"
              "convert"
            ];
          };
          "trigger.transcode.media" = {
            icon = "perm_media";
            label = "Transcode Media";
            aliases = [
              "image"
              "video"
            ];
            action = "ghostty -e ${transcode}/bin/ojuny-transcode interactive";
          };
          "trigger.transcode.ascii" = {
            icon = "text_fields";
            label = "Image to Text";
            aliases = [
              "ascii"
              "art"
            ];
            action = "ghostty -e ${transcode}/bin/ojuny-transcode interactive";
          };
        };
      };
    };
}
