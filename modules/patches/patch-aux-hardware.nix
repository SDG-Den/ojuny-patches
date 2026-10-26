/*
  @menu
  displayname = "Auxiliary hardware";
  icon = "preferences-system-symbolic";
  order = 190;
  description = "Fingerprint, tablet and FIDO2 support";
  category = "Patches";
  systems = [ "all" ];
*/

{ ... }: {

  flake.modules.nixos.patch-aux-hardware =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {

      options.ojuny.patch.aux-hardware = {
        enable = lib.mkEnableOption "the auxiliary hardware patch";
        fingerprint = lib.mkEnableOption "fingerprint authentication";
        tablet = lib.mkEnableOption "OpenTabletDriver";
        fido2 = lib.mkEnableOption "FIDO2 PAM authentication";
      };

      config = lib.mkMerge [
        {
          # @option widget = "switch"; label = "Auxiliary hardware"; group = "Auxiliary hardware";
          ojuny.patch.aux-hardware.enable = false;

          # @option widget = "switch"; label = "Fingerprint"; group = "Auxiliary hardware"; visibleWhen.path = "ojuny.patch.aux-hardware.enable"; visibleWhen.equals = true;
          ojuny.patch.aux-hardware.fingerprint = false;

          # @option widget = "switch"; label = "Tablet"; group = "Auxiliary hardware"; visibleWhen.path = "ojuny.patch.aux-hardware.enable"; visibleWhen.equals = true;
          ojuny.patch.aux-hardware.tablet = false;

          # @option widget = "switch"; label = "FIDO2"; group = "Auxiliary hardware"; visibleWhen.path = "ojuny.patch.aux-hardware.enable"; visibleWhen.equals = true;
          ojuny.patch.aux-hardware.fido2 = false;
        }
        (lib.mkIf config.ojuny.patch.aux-hardware.enable {
          services.fprintd.enable = config.ojuny.patch.aux-hardware.fingerprint;

          security.pam.services.login.fprintAuth = config.ojuny.patch.aux-hardware.fingerprint;
          security.pam.services.sudo.fprintAuth = config.ojuny.patch.aux-hardware.fingerprint;
          security.pam.services.polkit-1.fprintAuth = config.ojuny.patch.aux-hardware.fingerprint;

          hardware.opentabletdriver.enable = config.ojuny.patch.aux-hardware.tablet;
          hardware.uinput.enable =
            config.ojuny.patch.aux-hardware.tablet || config.ojuny.patch.aux-hardware.fido2;

          security.pam.u2f.enable = lib.mkIf config.ojuny.patch.aux-hardware.fido2 true;
          security.pam.u2f.control = lib.mkIf config.ojuny.patch.aux-hardware.fido2 "required";
          security.pam.u2f.settings.origin = lib.mkIf config.ojuny.patch.aux-hardware.fido2 "pam://ojuny";
          security.pam.u2f.settings.appid = lib.mkIf config.ojuny.patch.aux-hardware.fido2 "pam://ojuny";

          environment.systemPackages = with pkgs; [
            fprintd
            libfprint
            openssl
          ];
        })
      ];
    };
}
