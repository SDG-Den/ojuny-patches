/*
  @menu
  displayname = "Virtualization";
  icon = "preferences-system-symbolic";
  order = 40;
  description = "libvirt daemon, QEMU settings and virt-manager";
  category = "Patches";
  systems = [ "all" ];
*/

/*
  @snippet
  name = "qemu-hook";
  label = "Add qemu hook";
  snippet = ''
    # @option widget = "text"; label = "%%name%% hook script"; group = "Hooks"; description = "Executable invoked on qemu domain events; installed under /var/lib/libvirt/hooks/qemu.d/.";
    virtualisation.libvirtd.hooks.qemu."%%name%%" = "%%script%%";
  '';
  placeholders.name.label = "Hook name";
  placeholders.name.default = "example";
  placeholders.script.label = "Hook script";
  placeholders.script.default = "/etc/libvirt/hooks/example.sh";
*/

{ self, inputs, ... }:

{

  flake.modules.nixos.patch-virtualization =
    { config, lib, ... }:
    {
      options.ojuny.patch.virt.enable = lib.mkEnableOption "the virtualization patch";
      # @option widget = "switch"; label = "Virtualization patch"; group = "Patches"; description = "Enable the virtualization patch.";
      config.ojuny.patch.virt.enable = false;

      imports = [ self.modules.nixos.virt-backend ];
    };

  flake.modules.nixos.virt-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      active = config.ojuny.patch.virt.enable && (config.ojuny.patches or true);
    in
    {
      config = lib.mkIf active {

        # @option widget = "switch"; label = "Libvirt daemon"; group = "Libvirt"; visibleWhen.path = "ojuny.patch.virt.enable"; visibleWhen.equals = true; description = "Manage virtual machines with libvirt. Users in the libvirtd group can control it.";
        virtualisation.libvirtd.enable = true;

        # @option widget = "dropdown"; label = "Guests on host boot"; group = "Libvirt"; visibleWhen.path = "virtualisation.libvirtd.enable"; visibleWhen.equals = true; choices = [ "start" "ignore" ]; description = "Start formerly running guests, or leave them to their own autostart.";
        virtualisation.libvirtd.onBoot = "start";

        # @option widget = "dropdown"; label = "Guests on host shutdown"; group = "Libvirt"; visibleWhen.path = "virtualisation.libvirtd.enable"; visibleWhen.equals = true; choices = [ "suspend" "shutdown" ]; description = "Suspend guests to save their state, or shut them down over ACPI.";
        virtualisation.libvirtd.onShutdown = "suspend";

        # @option widget = "switch"; label = "TPM emulation"; group = "Libvirt"; visibleWhen.path = "virtualisation.libvirtd.enable"; visibleWhen.equals = true; description = "Emulated TPM 2.0 via swtpm, needed by Windows 11 guests.";
        virtualisation.libvirtd.qemu.swtpm.enable = false;

        # @option widget = "packages"; label = "vhost-user drivers"; group = "Libvirt"; visibleWhen.path = "virtualisation.libvirtd.enable"; visibleWhen.equals = true; description = "Out-of-tree vhost-user drivers, e.g. virtiofsd for virtiofs filesystem shares.";
        virtualisation.libvirtd.qemu.vhostUserPackages = [
          pkgs.virtiofsd
        ];

        # @option widget = "switch"; label = "SPICE USB redirection"; group = "Libvirt"; visibleWhen.path = "virtualisation.libvirtd.enable"; visibleWhen.equals = true; description = "Redirect USB devices into SPICE guests from virt-manager.";
        virtualisation.spiceUSBRedirection.enable = false;

        # @option widget = "switch"; label = "Run QEMU as root"; group = "Libvirt"; visibleWhen.path = "virtualisation.libvirtd.enable"; visibleWhen.equals = true; hidden = true; description = "Run qemu as root instead of the qemu-libvirtd user. Changing this after guests exist can break their file permissions.";
        virtualisation.libvirtd.qemu.runAsRoot = true;

        # @option widget = "package"; label = "QEMU package"; group = "Libvirt"; visibleWhen.path = "virtualisation.libvirtd.enable"; visibleWhen.equals = true; hidden = true; description = "qemu_kvm saves disk space; plain qemu can also emulate foreign architectures.";
        virtualisation.libvirtd.qemu.package = pkgs.qemu;

        # @option widget = "switch"; label = "SPICE guest agent"; group = "Libvirt"; hidden = true; visibleWhen.path = "ojuny.patch.virt.enable"; visibleWhen.equals = true; description = "Agent for SPICE guests; only active when this machine itself runs as a SPICE guest.";
        services.spice-vdagentd.enable = true;

        # @option widget = "switch"; label = "virt-manager"; group = "virt-manager"; visibleWhen.path = "virtualisation.libvirtd.enable"; visibleWhen.equals = true; description = "Graphical manager for libvirt VMs, with its GTK settings.";
        programs.virt-manager.enable = true;

        # @option widget = "text"; label = "GDK backend"; group = "virt-manager"; visibleWhen.path = "programs.virt-manager.enable"; visibleWhen.equals = true; description = "virt-manager needs the x11 GTK backend on Wayland to avoid crashes.";
        environment.variables.GDK_BACKEND = "x11";

        /*
          @insert
          name = "qemu-hook";
          group = "Libvirt";
          order = 1000;
        */

      };
    };

}
