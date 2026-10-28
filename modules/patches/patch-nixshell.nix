/*
  @menu
  displayname = "Nix shell";
  icon = "utilities-terminal-symbolic";
  order = 50;
  description = "Shell aliases that open nix shell with preset packages";
  category = "Patches";
  systems = [ "all" ];
*/

/*
  @snippet
  name = "nixshell-alias";
  label = "Add nix shell alias";
  snippet = ''
    # @option widget = "packages"; label = "%%name%% packages"; group = "Aliases"; description = "Packages opened by the %%name%% alias.";
    ojuny.apps.nixshell.aliases."%%name%%".packages = with (builtins.mapAttrs (n: _: n) pkgs); [ %%packages%% ];
  '';
  placeholders.name.label = "Alias";
  placeholders.name.default = "pydev";
  placeholders.packages.label = "Packages";
  placeholders.packages.default = "";
*/

{ self, ... }:

{

  flake.modules.nixos.patch-nixshell =
    { config, lib, ... }:
    {
      options.ojuny.patch.nixshell.enable = lib.mkEnableOption "the nix shell preset patch";
      # @option widget = "switch"; label = "Nix Shell patch"; group = "Patches"; description = "Enable the Nix Shell patch.";
      config.ojuny.patch.nixshell.enable = false;

      imports = [ self.modules.nixos.nixshell-backend ];
    };

  flake.modules.nixos.nixshell-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      active = config.ojuny.patch.nixshell.enable && (config.ojuny.patches or true);
    in
    {

      options.ojuny.apps.nixshell = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Export the configured aliases to environment.shellAliases.";
        };
        aliases = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options.packages = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Package names the alias opens through nix shell.";
              };
            }
          );
          default = { };
          description = "Shell aliases keyed by alias name. Each runs nix shell followed by nixpkgs#<name> for every package.";
        };
      };

      config = lib.mkIf active {

        # @option widget = "switch"; label = "Nix shell aliases"; group = "Aliases"; description = "Export the aliases below to the shell environment.";
        ojuny.apps.nixshell.enable = true;

        # The with-scope below maps every pkgs attribute to its own name, so bare names evaluate to strings and nixpkgs# refs stay exact.
        # @option widget = "packages"; label = "pydev packages"; group = "Aliases"; description = "Packages opened by the pydev alias.";
        ojuny.apps.nixshell.aliases."pydev".packages = with pkgs; [
          python3
          pyright
          pylint
          black
          uv
        ];

        # @option widget = "packages"; label = "tsdev packages"; group = "Aliases"; description = "Packages opened by the tsdev alias.";
        ojuny.apps.nixshell.aliases."tsdev".packages = with pkgs; [
          nodejs
          typescript-language-server
          prettier
          eslint
        ];

        # @option widget = "packages"; label = "rsdev packages"; group = "Aliases"; description = "Packages opened by the rsdev alias.";
        ojuny.apps.nixshell.aliases."rsdev".packages = with pkgs; [
          rustc
          cargo
          rust-analyzer
          rustfmt
        ];

        # @option widget = "packages"; label = "godev packages"; group = "Aliases"; description = "Packages opened by the godev alias.";
        ojuny.apps.nixshell.aliases."godev".packages = with pkgs; [
          go
          gopls
          golangci-lint
        ];

        # @option widget = "packages"; label = "cppdev packages"; group = "Aliases"; description = "Packages opened by the cppdev alias.";
        ojuny.apps.nixshell.aliases."cppdev".packages = with pkgs; [
          gcc
          clang-tools
          cmake
          gdb
          cppcheck
        ];

        # @option widget = "packages"; label = "javadev packages"; group = "Aliases"; description = "Packages opened by the javadev alias.";
        ojuny.apps.nixshell.aliases."javadev".packages = with pkgs; [
          jdk
          jdt-language-server
          maven
          gradle
        ];

        # @option widget = "packages"; label = "nixdev packages"; group = "Aliases"; description = "Packages opened by the nixdev alias.";
        ojuny.apps.nixshell.aliases."nixdev".packages = with pkgs; [
          nixd
          nixfmt
          statix
          deadnix
        ];

        # @option widget = "packages"; label = "shdev packages"; group = "Aliases"; description = "Packages opened by the shdev alias.";
        ojuny.apps.nixshell.aliases."shdev".packages = with pkgs; [
          bash
          shellcheck
          shfmt
        ];

        # @option widget = "packages"; label = "dbgtools packages"; group = "Aliases"; description = "Packages opened by the dbgtools alias.";
        ojuny.apps.nixshell.aliases."dbgtools".packages = with pkgs; [
          gdb
          strace
          ltrace
          valgrind
          rr
        ];

        # @option widget = "packages"; label = "netdbg packages"; group = "Aliases"; description = "Packages opened by the netdbg alias.";
        ojuny.apps.nixshell.aliases."netdbg".packages = with pkgs; [
          tcpdump
          wireshark
          nmap
          dnsutils
        ];

        # @option widget = "packages"; label = "androiddbg packages"; group = "Aliases"; description = "Packages opened by the androiddbg alias.";
        ojuny.apps.nixshell.aliases."androiddbg".packages = with pkgs; [
          android-tools
          jdk
          gradle
          apktool
          scrcpy
        ];

        # Derived, no @option: every non-empty alias becomes "nix shell nixpkgs#<name> ...".
        environment.shellAliases = lib.mapAttrs (
          _: entry: "nix shell ${lib.concatMapStringsSep " " (name: "nixpkgs#${name}") entry.packages}"
        ) (lib.filterAttrs (_: entry: entry.packages != [ ]) config.ojuny.apps.nixshell.aliases);

        /*
          @insert
          name = "nixshell-alias";
          group = "Aliases";
          order = 10;
        */

      };

    };

}
