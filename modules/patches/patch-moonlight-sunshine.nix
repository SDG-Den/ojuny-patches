/*
  @menu
  displayname = "Moonlight and Sunshine";
  icon = "video-display-symbolic";
  order = 170;
  description = "Moonlight client and optional Sunshine streaming host";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }: {

  flake.modules.nixos.patch-moonlight-sunshine =
    { config, lib, ... }:
    {
      options.ojuny.patch.moonlight-sunshine.enable =
        lib.mkEnableOption "the Moonlight and Sunshine patch";

      # @option widget = "switch"; label = "Moonlight and Sunshine"; group = "Game streaming"; groupOrder = 10; order = 10; description = "Install the Moonlight client. Turn on the Sunshine host only on the machine that will stream games.";
      config.ojuny.patch.moonlight-sunshine.enable = false;

      imports = [ self.modules.nixos.moonlight-sunshine-backend ];
    };

  flake.modules.nixos.moonlight-sunshine-backend =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.ojuny.patch.moonlight-sunshine // {
        enable = active;
      };
      active = config.ojuny.patch.moonlight-sunshine.enable && (config.ojuny.patches or true);

      hostEnabled = cfg.enable && cfg.host;

      normalUsers = lib.mapAttrsToList (name: _: name) (
        lib.filterAttrs (_: user: user.isNormalUser) config.users.users
      );

      sunshineSettings =
        lib.optionalAttrs (cfg.hostName != null && cfg.hostName != "") {
          sunshine_name = cfg.hostName;
        }
        // lib.optionalAttrs (cfg.hostPort != 47989) {
          port = cfg.hostPort;
        };
    in
    {
      options.ojuny.patch.moonlight-sunshine = {
        client = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install the Moonlight client.";
        };

        host = lib.mkEnableOption "Sunshine as a streaming host";

        hostName = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "desktop";
          description = "Sunshine host name advertised to Moonlight. A non-empty value writes services.sunshine.settings and disables Sunshine web UI configuration.";
        };

        hostPort = lib.mkOption {
          type = lib.types.port;
          default = 47989;
          description = "Base Sunshine port. TCP and UDP ports are offset from it. A non-default value writes services.sunshine.settings and disables Sunshine web UI configuration.";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Open Sunshine's streaming ports on every interface. This also exposes the HTTPS admin UI on base port plus one.";
        };

        capSysAdmin = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Give Sunshine CAP_SYS_ADMIN, required for DRM/KMS screen capture.";
        };
      };

      config = lib.mkMerge [
        {
          # @option widget = "switch"; label = "Moonlight client"; group = "Moonlight client"; groupOrder = 20; order = 10; visibleWhen.path = "ojuny.patch.moonlight-sunshine.enable"; visibleWhen.equals = true; description = "Install Moonlight Qt through the NixOS programs.moonlight-qt module. The client can connect to this machine or to another Sunshine host.";
          ojuny.patch.moonlight-sunshine.client = true;

          # @option widget = "switch"; label = "Sunshine host"; group = "Sunshine host"; groupOrder = 30; order = 10; visibleWhen.path = "ojuny.patch.moonlight-sunshine.enable"; visibleWhen.equals = true; description = "Run Sunshine as a user service. This captures the desktop, adds every normal user to the uinput group, and can open the streaming ports. Log out and back in after the first host rebuild so the group applies.";
          ojuny.patch.moonlight-sunshine.host = false;

          # @option widget = "text"; label = "Host name"; group = "Sunshine host"; groupOrder = 30; order = 20; nullable = true; placeholder = "Leave unset to use the web UI"; visibleWhen.path = "ojuny.patch.moonlight-sunshine.host"; visibleWhen.equals = true; description = "Name Moonlight shows for this host. Setting a name writes services.sunshine.settings, which disables Sunshine configuration from the web UI. Leave it unset to keep the web UI configurable.";
          ojuny.patch.moonlight-sunshine.hostName = null;

          # @option widget = "spin"; label = "Base port"; group = "Sunshine host"; groupOrder = 30; order = 30; min = 1024; max = 65514; step = 1; advanced = true; visibleWhen.path = "ojuny.patch.moonlight-sunshine.host"; visibleWhen.equals = true; description = "Base Sunshine port. TCP and UDP ports are offset from it. Changing it writes services.sunshine.settings and disables web UI configuration. Leave 47989 unless it conflicts.";
          ojuny.patch.moonlight-sunshine.hostPort = 47989;

          # @option widget = "switch"; label = "Open firewall ports"; group = "Sunshine host"; groupOrder = 30; order = 40; visibleWhen.path = "ojuny.patch.moonlight-sunshine.host"; visibleWhen.equals = true; description = "Open the Sunshine streaming ports on every interface. This also exposes the HTTPS admin UI on base port plus one. Disable it and open only the LAN or Tailscale ports yourself for a stricter setup.";
          ojuny.patch.moonlight-sunshine.openFirewall = true;

          # @option widget = "switch"; label = "KMS/DRM capture capability"; group = "Sunshine host"; groupOrder = 30; order = 50; visibleWhen.path = "ojuny.patch.moonlight-sunshine.host"; visibleWhen.equals = true; description = "Give Sunshine CAP_SYS_ADMIN, required for KMS/DRM screen capture. Disable it only when using a capture backend that does not need it.";
          ojuny.patch.moonlight-sunshine.capSysAdmin = true;
        }
        {
          assertions = [
            {
              assertion = !hostEnabled || cfg.hostPort <= 65514;
              message = "patch-moonlight-sunshine: hostPort must be at most 65514 so all Sunshine offset ports remain valid.";
            }
          ];
        }
        (lib.mkIf (cfg.enable && cfg.client) {
          programs.moonlight-qt.enable = true;
        })
        (lib.mkIf hostEnabled {
          services.sunshine = {
            enable = true;
            autoStart = true;
            openFirewall = cfg.openFirewall;
            capSysAdmin = cfg.capSysAdmin;
            settings = sunshineSettings;
          };

          users.groups.uinput.members = normalUsers;
        })
      ];
    };
}
