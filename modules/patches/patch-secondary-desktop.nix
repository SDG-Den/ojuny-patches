/*
  @menu
  displayname = "Secondary desktop";
  icon = "view-dual-symbolic";
  order = 165;
  description = "Niri or Sway Wayland session alongside Mango and DMS";
  category = "Patches";
  systems = [ "all" ];
*/

{ ... }:

{
  flake.modules.nixos.patch-secondary-desktop =
    { config, lib, pkgs, ... }:
    let
      cfg = config.ojuny.patch.secondary-desktop;

      niriConfig = ''
        input {
            keyboard {
                xkb {
                    layout "us"
                }
            }
            touchpad {
                tap
                natural-scroll
            }
        }

        layout {
            gaps 8
        }

        binds {
            Mod+Return { spawn "ghostty"; }
            Mod+D { spawn "dms" "ipc" "call" "spotlight" "toggle"; }
            Mod+Q { close-window; }
            Mod+Shift+E { quit; }

            Mod+H { focus-column-left; }
            Mod+L { focus-column-right; }
            Mod+J { focus-window-down; }
            Mod+K { focus-window-up; }
            Mod+Shift+H { move-column-left; }
            Mod+Shift+L { move-column-right; }
            Mod+Shift+J { move-window-down; }
            Mod+Shift+K { move-window-up; }

            Mod+R { switch-preset-column-width; }
            Mod+F { maximize-column; }
            Mod+Shift+F { fullscreen-window; }

            Mod+1 { focus-workspace 1; }
            Mod+2 { focus-workspace 2; }
            Mod+3 { focus-workspace 3; }
            Mod+4 { focus-workspace 4; }
            Mod+5 { focus-workspace 5; }
            Mod+6 { focus-workspace 6; }
            Mod+7 { focus-workspace 7; }
            Mod+8 { focus-workspace 8; }
            Mod+9 { focus-workspace 9; }
            Mod+Shift+1 { move-column-to-workspace 1; }
            Mod+Shift+2 { move-column-to-workspace 2; }
            Mod+Shift+3 { move-column-to-workspace 3; }
            Mod+Shift+4 { move-column-to-workspace 4; }
            Mod+Shift+5 { move-column-to-workspace 5; }
            Mod+Shift+6 { move-column-to-workspace 6; }
            Mod+Shift+7 { move-column-to-workspace 7; }
            Mod+Shift+8 { move-column-to-workspace 8; }
            Mod+Shift+9 { move-column-to-workspace 9; }
        }
      '';

      swayConfig = ''
        include /etc/sway/config.d/*

        set $mod Mod4
        set $term ghostty

        font pango:monospace 10
        default_border pixel 2
        gaps inner 8
        gaps outer 4

        bindsym $mod+Return exec $term
        bindsym $mod+d exec dms ipc call spotlight toggle
        bindsym $mod+q kill
        bindsym $mod+Shift+e exec swaynag -t warning -m 'Exit session?' -B 'Yes' 'swaymsg exit'

        bindsym $mod+h focus left
        bindsym $mod+l focus right
        bindsym $mod+j focus down
        bindsym $mod+k focus up
        bindsym $mod+Shift+h move left
        bindsym $mod+Shift+l move right
        bindsym $mod+Shift+j move down
        bindsym $mod+Shift+k move up

        bindsym $mod+f fullscreen toggle
        bindsym $mod+Shift+space floating toggle

        bindsym $mod+1 workspace number 1
        bindsym $mod+2 workspace number 2
        bindsym $mod+3 workspace number 3
        bindsym $mod+4 workspace number 4
        bindsym $mod+5 workspace number 5
        bindsym $mod+6 workspace number 6
        bindsym $mod+7 workspace number 7
        bindsym $mod+8 workspace number 8
        bindsym $mod+9 workspace number 9
        bindsym $mod+Shift+1 move container to workspace number 1
        bindsym $mod+Shift+2 move container to workspace number 2
        bindsym $mod+Shift+3 move container to workspace number 3
        bindsym $mod+Shift+4 move container to workspace number 4
        bindsym $mod+Shift+5 move container to workspace number 5
        bindsym $mod+Shift+6 move container to workspace number 6
        bindsym $mod+Shift+7 move container to workspace number 7
        bindsym $mod+Shift+8 move container to workspace number 8
        bindsym $mod+Shift+9 move container to workspace number 9
      '';
    in
    {
      options.ojuny.patch.secondary-desktop = {
        enable = lib.mkEnableOption "the secondary Wayland desktop patch";

        desktop = lib.mkOption {
          type = lib.types.enum [
            "niri"
            "sway"
          ];
          default = "niri";
          description = "Secondary Wayland session to install. Niri is available in the pinned nixpkgs and is the default; Sway is the fallback.";
        };
      };

      config = lib.mkMerge [
        {
          # @option widget = "switch"; label = "Secondary desktop"; group = "Patches"; description = "Install a second Wayland session without changing the Mango/DMS session.";
          ojuny.patch.secondary-desktop.enable = false;

          # @option widget = "dropdown"; label = "Desktop"; group = "Secondary desktop"; choices = [ "niri" "sway" ]; visibleWhen.path = "ojuny.patch.secondary-desktop.enable"; visibleWhen.equals = true; description = "Secondary Wayland session to install.";
          ojuny.patch.secondary-desktop.desktop = "niri";
        }
        (lib.mkIf cfg.enable {
          programs.niri.enable = cfg.desktop == "niri";
          programs.sway.enable = cfg.desktop == "sway";

          services.displayManager.defaultSession = lib.mkForce "ojuny";

          environment.systemPackages = [ pkgs.ghostty ];

          environment.etc =
            lib.optionalAttrs (cfg.desktop == "niri") {
              "niri/config.kdl".text = niriConfig;
            }
            // lib.optionalAttrs (cfg.desktop == "sway") {
              "sway/config".text = swayConfig;
            };
        })
      ];
    };
}
