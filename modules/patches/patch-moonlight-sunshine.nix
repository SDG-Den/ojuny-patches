/*
  @menu
  displayname = "Moonlight and Sunshine";
  icon = "video-display-symbolic";
  order = 170;
  description = "Game streaming client and host";
  category = "Patches";
  systems = [ "all" ];
*/

{ ... }: {

  flake.modules.nixos.patch-moonlight-sunshine =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {

      options.ojuny.patch.moonlight-sunshine = {
        enable = lib.mkEnableOption "the Moonlight and Sunshine patch";
        host = lib.mkEnableOption "run Sunshine as a streaming host";
        user = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
      };

      config = lib.mkMerge [
        {
          # @option widget = "switch"; label = "Moonlight and Sunshine"; group = "Game streaming";
          ojuny.patch.moonlight-sunshine.enable = false;

          # @option widget = "switch"; label = "Sunshine host"; group = "Game streaming"; visibleWhen.path = "ojuny.patch.moonlight-sunshine.enable"; visibleWhen.equals = true;
          ojuny.patch.moonlight-sunshine.host = false;

          # @option widget = "text"; label = "Sunshine user"; group = "Game streaming"; visibleWhen.path = "ojuny.patch.moonlight-sunshine.host"; visibleWhen.equals = true; description = "Account added to the uinput group; leave empty to manage groups yourself.";
          ojuny.patch.moonlight-sunshine.user = null;
        }
        (lib.mkIf config.ojuny.patch.moonlight-sunshine.enable {
          environment.systemPackages = [ pkgs.moonlight-qt ];

          services.sunshine.enable = lib.mkIf config.ojuny.patch.moonlight-sunshine.host true;
          services.sunshine.autoStart = lib.mkIf config.ojuny.patch.moonlight-sunshine.host true;
          services.sunshine.capSysAdmin = lib.mkIf config.ojuny.patch.moonlight-sunshine.host true;
          services.sunshine.openFirewall = lib.mkIf config.ojuny.patch.moonlight-sunshine.host true;

          hardware.uinput.enable = lib.mkIf config.ojuny.patch.moonlight-sunshine.host true;

          users.users = lib.mkIf config.ojuny.patch.moonlight-sunshine.host (
            lib.mapAttrs (_: _: { extraGroups = [ "uinput" ]; }) (
              lib.filterAttrs (_: user: user.isNormalUser) config.users.users
            )
          );
        })
      ];
    };
}
