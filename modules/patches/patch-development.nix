/*
  @menu
  displayname = "Development";
  icon = "applications-development-symbolic";
  order = 10;
  description = "Editors, language servers, formatters and develop-shell wrappers";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, inputs, ... }:

{

  flake.modules.nixos.patch-development = { config, lib, pkgs, ... }: {
    options.ojuny.patch.development.enable = lib.mkEnableOption "the development patch";
    # @option widget = "switch"; label = "Development patches"; group = "Patches"; description = "Enable the development patch.";
    config.ojuny.patch.development.enable = false;

    imports = [
      ((import ./_gate.nix { inherit lib; })
        (args: args.config.ojuny.patches && args.config.ojuny.patch.development.enable)
        self.modules.nixos.development-backend)
    ];

    config.home-manager.sharedModules = lib.mkIf config.ojuny.patch.development.enable [ self.modules.homeManager.development-backend ];
  };


  flake.modules.nixos.development-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      projects = pkgs.writeShellScriptBin "projects" ''
        export PATH=${
          lib.makeBinPath (
            with pkgs;
            [
              findutils
              coreutils
              gnugrep
              fzf
              eza
            ]
          )
        }:"$PATH"

        DIR="''${1:-$HOME/repos}"

        REPOS=$(find "$DIR" -maxdepth 5 -name .git -type d -exec dirname {} \; | xargs -I {} readlink -f {})
        if [ -n "''${2:-}" ]; then
          SELECTED=$(printf '%s\n' "$REPOS" | grep -E "$2" | head -n 1)
        else
          SELECTED=$(printf '%s\n' "$REPOS" | fzf --layout=reverse --preview="eza -al --color=always --group-directories-first --icons=always {}")
        fi
        if [ -z "$SELECTED" ]; then
          exit 0
        fi
        if [ -f "$SELECTED/meson.build" ]; then
          DB_DIR="$HOME/.cache/clangd/$(basename "$SELECTED")"
          mkdir -p "$DB_DIR"
          cd "$SELECTED"
          nix develop -c zsh -c "meson setup \"$DB_DIR\" \"$SELECTED\" >/dev/null 2>&1 || true; codium -n \"$SELECTED\""
        elif cd "$SELECTED" && nix develop -c true; then
          nix develop -c codium -n "$SELECTED"
        else
          codium -n "$SELECTED"
        fi
      '';
    in
    {
     
      options.ojuny.apps.development.aliases = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Enable this alias.";
              };
              value = lib.mkOption {
                type = lib.types.str;
                description = "Command the alias expands to.";
              };
            };
          }
        );
        default = { };
        description = "Shell aliases keyed by name, converted to environment.shellAliases.";
      };

      config = {
        

        # @option widget = "packages"; label = "Packages"; group = "Packages"; description = "Language servers, formatters and developer command line tools.";
        environment.systemPackages = (
          with pkgs;
          [
            nixd
            nixfmt
            nixos-anywhere
            deploy-rs
            nvd
            nix-output-monitor
            clang-tools
            rust-analyzer
            pyright
            shellcheck
            github-cli
            netcat-openbsd
          ]
        );
        # @option widget = "table-attrset"; label = "Aliases"; group = "Aliases"; columns = [ "enable" "value" ]; columnTypes = [ "bool" "str" ];
        ojuny.apps.development.aliases = {
          llm = {
            enable = true;
            value = "nix develop -c opencode";
          };
          projects = {
            enable = true;
            value = "${projects}/bin/projects";
          };
        };

        desktop.ojuny.mango.binds.common.projects = {
          # @option widget = "list"; label = "Projects Menu: Modifiers"; group = "Keybind";
          modifier = [
            "SUPER"
            "SHIFT"
          ];
          # @option widget = "list"; label = "Projects Menu: keys"; group = "Keybind";
          keys = [ "Tab" ];
          dispatcher = "spawn_shell";
          args = "ghostty --title='Floating-Menu' -e ${projects}/bin/projects";
          description = "Open projects";
          group = "Applications";
          subcat = "Launch";
        };

        # Derived, no @option: enabled rows become shell aliases.
        environment.shellAliases = (
          lib.mapAttrs (_: entry: entry.value) (
            lib.filterAttrs (_: entry: entry.enable) config.ojuny.apps.development.aliases
          )
        );
      };
    };

  flake.modules.homeManager.development-backend =
    {
      config,
      lib,
      pkgs,
      osConfig ? { },
      ...
    }:
    let
      flakeRef = "git+file://${config.home.homeDirectory}/repos/nix-flake";
    in
    {
      config = {
        programs.vscodium = {
          enable = true;

          # Launch the "nix" profile by default; home-manager has no isDefault
          # option for vscodium, so wrap the launcher with `--profile nix`.
          package =
            pkgs.runCommandLocal "vscodium-default-nix" { nativeBuildInputs = [ pkgs.makeBinaryWrapper ]; }
              ''
                mkdir -p $out/bin
                for b in ${pkgs.vscodium}/bin/*; do
                  n=$(basename "$b")
                  if [ "$n" = codium ] || [ "$n" = vscodium ]; then
                    makeWrapper "$b" "$out/bin/$n" --add-flags "--profile nix"
                  else
                    ln -s "$b" "$out/bin/$n"
                  fi
                done
              '';

          profiles.nix = {
            extensions = with pkgs.vscode-extensions; [
              jnoortheen.nix-ide
              signageos.signageos-vscode-sops
              ms-python.python
              ms-python.debugpy
              ms-python.pylint
              ms-python.mypy-type-checker
              llvm-vs-code-extensions.vscode-clangd
              mesonbuild.mesonbuild
              vadimcn.vscode-lldb
            ];

            userSettings = {
              "nix.serverSettings" = {
                nixd = {
                  nixpkgs.expr = "(builtins.getFlake \"${flakeRef}\").inputs.nixpkgs { }";
                  formatting.command = [ "nixfmt" ];
                  options.ojuny.expr = "(builtins.head (builtins.attrValues (builtins.getFlake \"${flakeRef}\").nixosConfigurations)).options";
                };
              };
              "[nix]" = {
                editor.insertSpaces = true;
                editor.tabSize = 2;
              };
              "nix.enableLanguageServer" = true;
              "mesonbuild.downloadLanguageServer" = false;
              "nix.serverPath" = "${pkgs.nixd}/bin/nixd";
              "clangd.path" = "${pkgs.clang-tools}/bin/clangd";
              "clangd.checkUpdates" = false;
              "clangd.arguments" = [
                "--background-index"
                "--clang-tidy"
                "--completion-style=detailed"
                "--header-insertion=iwyu"
                "--compile-commands-dir=\${userHome}/.cache/clangd/\${workspaceFolderBasename}"
              ];
              "mesonbuild.configureOnOpen" = false;
              "[c]" = {
                editor.insertSpaces = true;
                editor.tabSize = 4;
              };
              "[cpp]" = {
                editor.insertSpaces = true;
                editor.tabSize = 4;
              };
              "[cuda]" = {
                editor.insertSpaces = true;
                editor.tabSize = 4;
              };
            };
          };
        };

        stylix.targets.vscodium.profileNames = [ "nix" ];

        home.packages = [ pkgs.clang-tools ];

        # Fallback for projects without compile_commands.json; a project-level
        # .clangd file always takes precedence.
        home.file.".clangd".text = ''
          CompileFlags:
            Add: [-Wall, -Wextra]
        '';

        programs.opencode = {
          enable = true;
          settings = {
            permission = {
              "*" = "ask";
              read = "allow";
              grep = "allow";
              glob = "allow";
              task = "allow";
              lsp = "allow";
              question = "allow";
              webfetch = "allow";
              websearch = "allow";
              bash = {
                "cat *" = "allow";
                "head *" = "allow";
                "ls *" = "allow";
                "tail *" = "allow";
                "grep *" = "allow";
                "rg *" = "allow";
              };
            };
            lsp = {
              nixd = {
                command = [ "nixd" ];
                extensions = [ ".nix" ];
                args = [
                  "--config"
                  (builtins.toJSON {
                    nixd = {
                      nixpkgs.expr = "(builtins.getFlake \"${flakeRef}\").inputs.nixpkgs { }";
                      formatting.command = [ "nixfmt" ];
                      options.ojuny.expr = "(builtins.head (builtins.attrValues (builtins.getFlake \"${flakeRef}\").nixosConfigurations)).options";
                    };
                  })
                ];
              };
              rust-analyzer = {
                command = [ "rust-analyzer" ];
                extensions = [ ".rs" ];
              };
              pyright = {
                command = [ "pyright-langserver" ];
                extensions = [ ".py" ];
              };
            };
          };
        };
      };
    };

  

}
