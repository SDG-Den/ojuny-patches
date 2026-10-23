/* @menu
   displayname = "Development Tools";
   icon = "applications-development-symbolic";
   order = 100;
   description = "Command line development tools";
   category = "Patches";
   systems = [ "all" ];
*/

{ ... }: {

  flake.modules.nixos.patch-development-tools = { config, lib, pkgs, ... }: {

    options.ojuny.patch.development-tools.enable =
      lib.mkEnableOption "the development tools patch";

    config = lib.mkIf config.ojuny.patch.development-tools.enable {
      environment.systemPackages = with pkgs; [
        fd
        jq
        ripgrep
      ];
    };

  };

}
