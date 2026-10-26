/*
  @menu
  displayname = "Remote Desktop";
  icon = "video-display-symbolic";
  order = 60;
  description = "RustDesk, Waypipe, WayVNC and general VNC clients";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, inputs, ... }:

{

  flake.modules.nixos.patch-remote-desktop = { config, lib, ... }: {
    options.ojuny.patch.remoteDesktop.enable = lib.mkEnableOption "the remote desktop patch";
    # @option widget = "switch"; label = "Remote desktop patch"; group = "Patches"; description = "Enable the remote desktop patch.";
    config.ojuny.patch.remoteDesktop.enable = false;

    imports = [
      ((import ./_gate.nix { inherit lib; }) (
        args: args.config.ojuny.patches && args.config.ojuny.patch.remoteDesktop.enable
      ) self.modules.nixos.remote-desktop-backend)
    ];

  };

  flake.modules.nixos.remote-desktop-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {

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

      config = {

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

        environment.systemPackages =
          lib.optionals config.ojuny.apps.remoteDesktop.rustdesk [ pkgs.rustdesk ]
          ++ lib.optionals config.ojuny.apps.remoteDesktop.waypipe [ pkgs.waypipe ]
          ++ lib.optionals config.ojuny.apps.remoteDesktop.wayvnc [ pkgs.wayvnc ]
          ++ lib.optionals (config.ojuny.apps.remoteDesktop.vncViewer == "tigervnc") [ pkgs.tigervnc ]
          ++ lib.optionals (config.ojuny.apps.remoteDesktop.vncViewer == "remmina") [ pkgs.remmina ]
          ++ lib.optionals config.ojuny.apps.remoteDesktop.anydesk [ pkgs.anydesk ]
          ++ lib.optionals config.ojuny.apps.remoteDesktop.teamviewer [ pkgs.teamviewer ];
      };

    };

}
