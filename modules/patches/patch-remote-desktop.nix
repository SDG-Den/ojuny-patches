/*
  @menu
  displayname = "Remote Desktop";
  icon = "video-display-symbolic";
  order = 60;
  description = "RustDesk, Waypipe, WayVNC, VNC/RDP clients and a privacy-first session watch";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }:

{
  flake.modules.nixos.patch-remote-desktop =
    { config, lib, ... }:
    {
      options.ojuny.patch.remoteDesktop.enable = lib.mkEnableOption "the remote desktop patch";

      imports = [ self.modules.nixos.remote-desktop-backend ];

      config = {
        # @option widget = "switch"; label = "Remote desktop patch"; group = "Patches"; description = "Install the selected remote desktop clients and the session indicator.";
        ojuny.patch.remoteDesktop.enable = false;

        # @option widget = "switch"; label = "Session indicator"; group = "Session indicator"; groupOrder = 50; order = 10; visibleWhen.path = "ojuny.patch.remoteDesktop.enable"; visibleWhen.equals = true; description = "Show remote and capture activity in the bar. VNC and RDP appear only while a server is listening.";
        ojuny.patch.remoteDesktop.indicator.enable = true;

        # @option widget = "switch"; label = "VNC"; group = "Session indicator"; groupOrder = 50; order = 20; visibleWhen.path = "ojuny.patch.remoteDesktop.indicator.enable"; visibleWhen.equals = true; description = "Watch the VNC port. The label means a VNC server is listening, not that a client is connected.";
        ojuny.patch.remoteDesktop.indicator.vnc = true;

        # @option widget = "switch"; label = "RDP"; group = "Session indicator"; groupOrder = 50; order = 30; visibleWhen.path = "ojuny.patch.remoteDesktop.indicator.enable"; visibleWhen.equals = true; description = "Watch the RDP port. This patch does not install an RDP server.";
        ojuny.patch.remoteDesktop.indicator.rdp = true;

        # @option widget = "switch"; label = "Recording"; group = "Session indicator"; groupOrder = 50; order = 40; visibleWhen.path = "ojuny.patch.remoteDesktop.indicator.enable"; visibleWhen.equals = true; description = "Show the screen capture toolbar recording pill. The pill is a floating overlay, not a bar widget. This Nix-owns the screenCaptureToolbar settings.";
        ojuny.patch.remoteDesktop.indicator.recording = true;

        # @option widget = "switch"; label = "Privacy indicator"; group = "Session indicator"; groupOrder = 50; order = 50; visibleWhen.path = "ojuny.patch.remoteDesktop.indicator.enable"; visibleWhen.equals = true; description = "Add the DMS privacy indicator to the default and custom bars. It appears only while microphone, camera, or screen sharing is active. It does not block or notify.";
        ojuny.patch.remoteDesktop.indicator.privacyIndicator = true;

        # @option widget = "switch"; label = "Listening ports"; group = "Session indicator"; groupOrder = 50; order = 60; visibleWhen.path = "ojuny.patch.remoteDesktop.indicator.enable"; visibleWhen.equals = true; description = "Add one Ports pill for other TCP listeners in 1000-9999. It shows a count, not one pill per port. Off by default because it is noisy.";
        ojuny.patch.remoteDesktop.indicator.listeningPorts = false;

        # @option widget = "spin"; label = "VNC port"; group = "Port watches"; groupOrder = 60; order = 10; min = 1000; max = 9999; step = 1; advanced = true; visibleWhen.path = "ojuny.patch.remoteDesktop.indicator.vnc"; visibleWhen.equals = true; description = "VNC TCP port. localServices only scans 1000-9999.";
        ojuny.patch.remoteDesktop.indicator.vncPort = 5900;

        # @option widget = "spin"; label = "RDP port"; group = "Port watches"; groupOrder = 60; order = 20; min = 1000; max = 9999; step = 1; advanced = true; visibleWhen.path = "ojuny.patch.remoteDesktop.indicator.rdp"; visibleWhen.equals = true; description = "RDP TCP port. localServices only scans 1000-9999.";
        ojuny.patch.remoteDesktop.indicator.rdpPort = 3389;

        # @option widget = "list"; label = "Extra port watches"; group = "Port watches"; groupOrder = 60; order = 30; itemLabel = "Port or range"; addLabel = "Add watch"; advanced = true; visibleWhen.path = "ojuny.patch.remoteDesktop.indicator.enable"; visibleWhen.equals = true; description = "Extra port or range watches, for example 21115-21119 for RustDesk.";
        ojuny.patch.remoteDesktop.indicator.extraWatches = [ ];

        # @option widget = "list"; label = "Ignored ports"; group = "Port watches"; groupOrder = 60; order = 40; itemLabel = "Port"; addLabel = "Ignore port"; advanced = true; visibleWhen.path = "ojuny.patch.remoteDesktop.indicator.enable"; visibleWhen.equals = true; description = "Ports hidden from discovery and watches.";
        ojuny.patch.remoteDesktop.indicator.ignoredPorts = [ ];

        # @option widget = "raw"; label = "Extra port labels"; group = "Port watches"; groupOrder = 60; order = 50; rows = 6; advanced = true; visibleWhen.path = "ojuny.patch.remoteDesktop.indicator.enable"; visibleWhen.equals = true; description = "Nix attrset of port or range-start to label. Example: { \"5900\" = \"Work VNC\"; }.";
        ojuny.patch.remoteDesktop.indicator.labels = { };

        # @option widget = "spin"; label = "Refresh interval"; group = "Port watches"; groupOrder = 60; order = 60; min = 2; max = 60; step = 1; unit = "s"; advanced = true; visibleWhen.path = "ojuny.patch.remoteDesktop.indicator.enable"; visibleWhen.equals = true; description = "localServices scan interval.";
        ojuny.patch.remoteDesktop.indicator.refreshSeconds = 5;

        # @option widget = "switch"; label = "Favicon lookup"; group = "Port watches"; groupOrder = 60; order = 70; advanced = true; visibleWhen.path = "ojuny.patch.remoteDesktop.indicator.enable"; visibleWhen.equals = true; description = "Let localServices probe localhost for favicons. Disable to avoid local HTTP probes.";
        ojuny.patch.remoteDesktop.indicator.showFavicons = true;

        # @option widget = "switch"; label = "RustDesk"; group = "Clients"; groupOrder = 10; order = 10; description = "RustDesk remote desktop client."; visibleWhen.path = "ojuny.patch.remoteDesktop.enable"; visibleWhen.equals = true;
        ojuny.apps.remoteDesktop.rustdesk = true;

        # @option widget = "switch"; label = "Waypipe"; group = "Wayland tools"; groupOrder = 20; order = 10; description = "Forward individual Wayland applications over SSH with waypipe."; visibleWhen.path = "ojuny.patch.remoteDesktop.enable"; visibleWhen.equals = true;
        ojuny.apps.remoteDesktop.waypipe = true;

        # @option widget = "switch"; label = "WayVNC"; group = "Wayland tools"; groupOrder = 20; order = 20; description = "VNC server for wlroots-based Wayland sessions. Run it inside the session, not as a system service."; visibleWhen.path = "ojuny.patch.remoteDesktop.enable"; visibleWhen.equals = true;
        ojuny.apps.remoteDesktop.wayvnc = true;

        # @option widget = "dropdown"; label = "VNC viewer"; group = "VNC"; groupOrder = 30; order = 10; choices = [ "tigervnc" "remmina" "none" ]; description = "TigerVNC provides the plain vncviewer; Remmina adds a general RDP, VNC and SSH client."; visibleWhen.path = "ojuny.patch.remoteDesktop.enable"; visibleWhen.equals = true;
        ojuny.apps.remoteDesktop.vncViewer = "tigervnc";

        # @option widget = "switch"; label = "AnyDesk"; group = "Optional proprietary"; groupOrder = 40; order = 10; description = "Unfree AnyDesk client. Runs through XWayland and needs manual service setup for unattended access."; visibleWhen.path = "ojuny.patch.remoteDesktop.enable"; visibleWhen.equals = true;
        ojuny.apps.remoteDesktop.anydesk = false;

        # @option widget = "switch"; label = "TeamViewer"; group = "Optional proprietary"; groupOrder = 40; order = 20; description = "Unfree TeamViewer client. The teamviewerd daemon is not managed by NixOS and needs manual setup."; visibleWhen.path = "ojuny.patch.remoteDesktop.enable"; visibleWhen.equals = true;
        ojuny.apps.remoteDesktop.teamviewer = false;
      };
    };

  flake.modules.nixos.remote-desktop-backend =
    {
      config,
      lib,
      pkgs,
      options,
      ...
    }:
    let
      cfg = config.ojuny.patch.remoteDesktop // {
        enable = active;
      };
      active = config.ojuny.patch.remoteDesktop.enable && (config.ojuny.patches or true);
      apps = config.ojuny.apps.remoteDesktop;
      indicator = cfg.indicator;

      watchActive = cfg.enable && indicator.enable;

      vncRange = "${toString indicator.vncPort}-${toString indicator.vncPort}";
      rdpRange = "${toString indicator.rdpPort}-${toString indicator.rdpPort}";

      portWatches =
        lib.optional indicator.vnc vncRange
        ++ lib.optionals indicator.rdp [ rdpRange ]
        ++ indicator.extraWatches
        ++ lib.optional indicator.listeningPorts "1000-9999";

      portLabels =
        lib.optionalAttrs indicator.vnc {
          "${toString indicator.vncPort}" = "VNC";
        }
        // lib.optionalAttrs indicator.rdp {
          "${toString indicator.rdpPort}" = "RDP";
        }
        // lib.optionalAttrs indicator.listeningPorts {
          "1000" = "Ports";
        }
        // indicator.labels;

      localServicesSettings = {
        exactWatches = "";
        rangeWatches = lib.concatStringsSep "," portWatches;
        ignoredPorts = lib.concatMapStringsSep "," toString indicator.ignoredPorts;
        labels = builtins.toJSON portLabels;
        iconOverrides = "{}";
        refreshSeconds = indicator.refreshSeconds;
        showFavicons = indicator.showFavicons;
      };

      screenCaptureSettings = {
        enableAudioRecorder = true;
        multiMonitorScreenshot = true;
        showNotify = false;
        showRecPill = true;
        toolbarOpacity = 1.0;
        pillOpacity = 1.0;
      };

      privacyBarEntry = lib.optionalAttrs (watchActive && indicator.privacyIndicator) {
        privacyIndicator = {
          _order = 55;
        };
      };

      hasPlugins = options ? desktop.ojuny.dux.plugins || options ? desktop.ojuny.dms.plugins;
      hasBars = options ? desktop.ojuny.dux.barConfigs || options ? desktop.ojuny.dms.barConfigs;
    in
    {
      options.ojuny.patch.remoteDesktop = {
        indicator = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Show remote and capture activity in the desktop bar.";
          };

          vnc = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Watch the VNC TCP port. The bar state means a server is listening, not that a client is connected.";
          };

          rdp = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Watch the RDP TCP port. The patch does not install an RDP server.";
          };

          recording = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Show the screen capture toolbar recording pill while recording.";
          };

          privacyIndicator = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Add the active-only DMS privacy indicator to the default and custom bars.";
          };

          listeningPorts = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Add one broad range watch for TCP listeners in ports 1000-9999.";
          };

          vncPort = lib.mkOption {
            type = lib.types.port;
            default = 5900;
            description = "VNC TCP port. Must be inside the localServices scan range 1000-9999.";
          };

          rdpPort = lib.mkOption {
            type = lib.types.port;
            default = 3389;
            description = "RDP TCP port. Must be inside the localServices scan range 1000-9999.";
          };

          extraWatches = lib.mkOption {
            type = lib.types.listOf (lib.types.strMatching "[0-9]+(-[0-9]+)?");
            default = [ ];
            example = [
              "8081"
              "21115-21119"
            ];
            description = "Extra localServices range watches. Each entry is a port or a low-high range.";
          };

          ignoredPorts = lib.mkOption {
            type = lib.types.listOf lib.types.port;
            default = [ ];
            example = [
              8081
              9000
            ];
            description = "TCP ports hidden from localServices discovery and watches.";
          };

          labels = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            example = {
              "5900" = "Work VNC";
            };
            description = "Extra localServices labels keyed by port or range start.";
          };

          refreshSeconds = lib.mkOption {
            type = lib.types.ints.between 2 60;
            default = 5;
            description = "localServices scan interval in seconds.";
          };

          showFavicons = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Let localServices probe localhost for favicons.";
          };
        };
      };

      options.ojuny.apps.remoteDesktop = {
        rustdesk = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install the RustDesk remote desktop client.";
        };
        waypipe = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install waypipe for forwarding Wayland applications over SSH.";
        };
        wayvnc = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install the WayVNC server for wlroots-based Wayland sessions.";
        };
        vncViewer = lib.mkOption {
          type = lib.types.enum [
            "tigervnc"
            "remmina"
            "none"
          ];
          default = "tigervnc";
          description = "VNC viewer to install: TigerVNC's vncviewer, Remmina, or none.";
        };
        anydesk = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Install AnyDesk. Unfree package; runs through XWayland.";
        };
        teamviewer = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Install TeamViewer. Unfree package; the daemon is not managed by NixOS.";
        };
      };

      config = lib.mkMerge [
        {
          assertions = [
            {
              assertion =
                !(watchActive && indicator.vnc) || (indicator.vncPort >= 1000 && indicator.vncPort <= 9999);
              message = "patch-remote-desktop: VNC port must be between 1000 and 9999 because localServices only scans TCP ports in that range.";
            }
            {
              assertion =
                !(watchActive && indicator.rdp) || (indicator.rdpPort >= 1000 && indicator.rdpPort <= 9999);
              message = "patch-remote-desktop: RDP port must be between 1000 and 9999 because localServices only scans TCP ports in that range.";
            }
            {
              assertion =
                !(watchActive && indicator.vnc && indicator.rdp) || indicator.vncPort != indicator.rdpPort;
              message = "patch-remote-desktop: VNC and RDP cannot use the same watch port.";
            }
          ];
        }
        (lib.mkIf cfg.enable {
          environment.systemPackages =
            lib.optionals apps.rustdesk [ pkgs.rustdesk ]
            ++ lib.optionals apps.waypipe [ pkgs.waypipe ]
            ++ lib.optionals apps.wayvnc [ pkgs.wayvnc ]
            ++ lib.optionals (apps.vncViewer == "tigervnc") [ pkgs.tigervnc ]
            ++ lib.optionals (apps.vncViewer == "remmina") [ pkgs.remmina ]
            ++ lib.optionals apps.anydesk [ pkgs.anydesk ]
            ++ lib.optionals apps.teamviewer [ pkgs.teamviewer ];
        })
        (lib.mkIf (watchActive && hasPlugins && portWatches != [ ]) {
          desktop.ojuny.dux.plugins.localServices.settings = lib.mkForce localServicesSettings;
        })
        (lib.mkIf (watchActive && hasBars && privacyBarEntry != { }) {
          desktop.ojuny.dux.barConfigs = {
            default.rightWidgets = privacyBarEntry;
            custom.rightWidgets = privacyBarEntry;
          };
        })
        (lib.mkIf (watchActive && indicator.recording && hasPlugins) {
          desktop.ojuny.dux.plugins.screenCaptureToolbar.settings = lib.mkForce screenCaptureSettings;
        })
      ];
    };
}
