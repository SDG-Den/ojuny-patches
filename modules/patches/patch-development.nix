/*
  @menu
  displayname = "Development";
  icon = "applications-development-symbolic";
  order = 10;
  description = "VSCodium, language servers, coding agents, and project scaffolding";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, inputs, ... }:

{
  flake.modules.nixos.patch-development =
    { config, lib, ... }:
    {
      options.ojuny.patch.development.enable = lib.mkEnableOption "the development patch";

      # @option widget = "switch"; label = "Development patch"; group = "Patches"; description = "Install VSCodium, the selected language servers, optional coding agents, and project tooling.";
      config.ojuny.patch.development.enable = false;

      imports = [ self.modules.nixos.development-backend ];

      config.home-manager.sharedModules = lib.mkIf (
        config.ojuny.patch.development.enable && (config.ojuny.patches or true)
      ) [ self.modules.homeManager.development-backend ];
    };

  flake.modules.nixos.development-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.ojuny.patch.development;
      active = cfg.enable && (config.ojuny.patches or true);

      languageNames = [
        "nix"
        "python"
        "rust"
        "c"
        "cpp"
        "go"
        "typescript"
        "lua"
        "bash"
        "yaml"
        "json"
        "markdown"
      ];

      defaultLanguages = [
        "nix"
        "python"
        "rust"
        "c"
        "cpp"
        "bash"
      ];

      languageEnabled = name: cfg.languages.${name}.enable or false;
      enabledLanguages = builtins.filter languageEnabled languageNames;

      languagePackages = {
        nix = with pkgs; [ nixd nixfmt statix deadnix ];
        python = with pkgs; [ pyright ruff black ];
        rust = with pkgs; [ rust-analyzer rustfmt ];
        c = with pkgs; [ clang-tools cmake gdb ];
        cpp = with pkgs; [ clang-tools cmake gdb ];
        go = with pkgs; [ gopls golangci-lint ];
        typescript = with pkgs; [ typescript-language-server prettier eslint ];
        lua = with pkgs; [ lua-language-server ];
        bash = with pkgs; [ bash-language-server shellcheck shfmt ];
        yaml = with pkgs; [ yaml-language-server ];
        json = with pkgs; [ vscode-json-languageserver ];
        markdown = with pkgs; [ marksman ];
      };

      lspPackages = lib.unique (lib.concatMap (name: languagePackages.${name}) enabledLanguages);

      usageEnabled =
        cfg.usage.enable
        && (
          (cfg.agents.claude-code.enable or false)
          || (cfg.agents.codex.enable or false)
        );

      scaffoldPackages = {
        python = [ "python3" "pyright" "ruff" "black" ];
        rust = [ "rustc" "cargo" "rust-analyzer" "rustfmt" ];
        go = [ "go" "gopls" "golangci-lint" ];
        typescript = [ "nodejs" "typescript-language-server" "prettier" "eslint" ];
        c = [ "gcc" "gnumake" "cmake" "gdb" "clang-tools" ];
        cpp = [ "gcc" "gnumake" "cmake" "gdb" "clang-tools" ];
        nix = [ "nixd" "nixfmt" "statix" "deadnix" ];
        lua = [ "lua" "lua-language-server" ];
        bash = [ "bashInteractive" "bash-language-server" "shellcheck" "shfmt" ];
      };

      scaffoldCase = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: packages:
          ''
            ${name})
              packages="${lib.concatStringsSep " " packages}"
              ;;
          ''
        ) scaffoldPackages
      );

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

        DIR="''${1:-${cfg.projects.searchRoot}}"
        REPOS=$(find "$DIR" -maxdepth 5 -name .git -type d -exec dirname {} \; | xargs -r -I {} readlink -f {})
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
          nix develop -c zsh -c "meson setup \"$DB_DIR\" \"$SELECTED\" >/dev/null 2>&1 || true; ${lib.escapeShellArg cfg.projects.editorCommand} -n \"$SELECTED\""
        elif cd "$SELECTED" && nix develop -c true; then
          nix develop -c ${lib.escapeShellArg cfg.projects.editorCommand} -n "$SELECTED"
        else
          ${lib.escapeShellArg cfg.projects.editorCommand} -n "$SELECTED"
        fi
      '';

      scaffold = pkgs.writeShellScriptBin "ojuny-devshell-new" ''
        export PATH=${lib.makeBinPath (with pkgs; [ coreutils gnused ])}:"$PATH"
        set -euo pipefail

        language="''${1:-}"
        dir="''${2:-$PWD}"

        case "$language" in
        ${scaffoldCase}
          *)
            echo "usage: ojuny-devshell-new <python|rust|go|typescript|c|cpp|nix|lua|bash> [directory]" >&2
            exit 2
            ;;
        esac

        mkdir -p "$dir"
        if [ -e "$dir/flake.nix" ]; then
          echo "refusing to overwrite $dir/flake.nix" >&2
          exit 1
        fi

        cat > "$dir/flake.nix" <<'EOF'
        {
          description = "Ojuny @LANGUAGE@ development shell";
          inputs.nixpkgs.url = "github:NixOS/nixpkgs/@NIXPKGS_REV@";
          outputs = { self, nixpkgs }:
            let
              system = "@SYSTEM@";
              pkgs = nixpkgs.legacyPackages.''${system};
            in {
              devShells.''${system}.default = pkgs.mkShell {
                packages = with pkgs; [ @PACKAGES@ ];
              };
            };
        }
        EOF

        sed -i \
          -e "s|@LANGUAGE@|$language|g" \
          -e "s|@NIXPKGS_REV@|${cfg.scaffold.nixpkgsRev}|g" \
          -e "s|@SYSTEM@|${pkgs.stdenv.hostPlatform.system}|g" \
          -e "s|@PACKAGES@|$packages|g" \
          "$dir/flake.nix"

        if [ ! -e "$dir/.gitignore" ]; then
          printf '%s\n' "result" ".direnv" > "$dir/.gitignore"
        fi

        echo "Created $dir/flake.nix"
        echo "Next: cd $dir && nix flake lock && nix develop"
      '';
    in
    {
      options.ojuny.patch.development = {
        languages = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options.enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Enable this language's LSP, formatter, and editor integration.";
              };
            }
          );
          default = lib.genAttrs languageNames (name: { enable = builtins.elem name defaultLanguages; });
          description = "Languages with an LSP server, formatter, VSCodium extension, and OpenCode LSP entry.";
        };

        editors.vscodium.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install and configure VSCodium with the nix profile as default.";
        };

        agents = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options.enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Install this coding agent.";
              };
            }
          );
          default = {
            opencode.enable = true;
            claude-code.enable = false;
            codex.enable = false;
            gemini-cli.enable = false;
          };
          description = "Opt-in coding agents. No agent is installed by the base image.";
        };

        defaultAgent = lib.mkOption {
          type = lib.types.enum [
            "opencode"
            "claude-code"
            "codex"
            "gemini-cli"
            "none"
          ];
          default = "opencode";
          description = "Agent launched by ojuny-agent. It must be enabled, or none.";
        };

        usage.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install ojuny-agent-usage. ccusage covers Claude Code and Codex; OpenCode usage is not collected.";
        };

        projects = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Install the projects picker, its alias, and its keybind.";
          };
          searchRoot = lib.mkOption {
            type = lib.types.str;
            default = "$HOME/repos";
            description = "Directory searched for git repositories. $HOME is expanded by the shell.";
          };
          editorCommand = lib.mkOption {
            type = lib.types.str;
            default = "codium";
            description = "Single executable used by the project picker, for example codium or code.";
          };
        };

        scaffold = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Install ojuny-devshell-new for pinned language project flakes.";
          };
          nixpkgsRev = lib.mkOption {
            type = lib.types.str;
            default = inputs.nixpkgs.rev or "nixos-unstable";
            description = "Revision or branch written into generated project flakes.";
          };
        };
      };

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

      config = lib.mkMerge [
        {
          # @option widget = "table-attrset"; label = "Languages"; group = "Languages"; columns = [ "enable" ]; columnTypes = [ "bool" ]; visibleWhen.path = "ojuny.patch.development.enable"; visibleWhen.equals = true; description = "Languages whose LSP server, formatter, and editor extension are installed.";
          ojuny.patch.development.languages = lib.genAttrs languageNames (name: {
            enable = builtins.elem name defaultLanguages;
          });

          # @option widget = "switch"; label = "VSCodium"; group = "Editor"; visibleWhen.path = "ojuny.patch.development.enable"; visibleWhen.equals = true; description = "Install and theme VSCodium and use the nix profile as the default launcher.";
          ojuny.patch.development.editors.vscodium.enable = true;

          # @option widget = "table-attrset"; label = "Coding agents"; group = "AI"; columns = [ "enable" ]; columnTypes = [ "bool" ]; visibleWhen.path = "ojuny.patch.development.enable"; visibleWhen.equals = true; description = "Opt-in coding agents. No agent is installed by the base image.";
          ojuny.patch.development.agents = {
            opencode.enable = true;
            claude-code.enable = false;
            codex.enable = false;
            gemini-cli.enable = false;
          };

          # @option widget = "dropdown"; label = "Default agent"; group = "AI"; choices = [ "opencode" "claude-code" "codex" "gemini-cli" "none" ]; visibleWhen.path = "ojuny.patch.development.enable"; visibleWhen.equals = true; description = "Agent launched by ojuny-agent. It must be enabled, or none.";
          ojuny.patch.development.defaultAgent = "opencode";

          # @option widget = "switch"; label = "Agent usage"; group = "AI"; visibleWhen.path = "ojuny.patch.development.enable"; visibleWhen.equals = true; description = "Install ojuny-agent-usage. ccusage covers Claude Code and Codex; OpenCode usage is not collected.";
          ojuny.patch.development.usage.enable = true;

          # @option widget = "switch"; label = "Project menu"; group = "Projects"; visibleWhen.path = "ojuny.patch.development.enable"; visibleWhen.equals = true; description = "Install the projects picker, its alias, and the Super+Shift+Tab keybind.";
          ojuny.patch.development.projects.enable = true;

          # @option widget = "text"; label = "Project search root"; group = "Projects"; visibleWhen.path = "ojuny.patch.development.enable"; visibleWhen.equals = true; description = "Directory searched for git repositories. $HOME is expanded by the shell.";
          ojuny.patch.development.projects.searchRoot = "$HOME/repos";

          # @option widget = "text"; label = "Project editor command"; group = "Projects"; visibleWhen.path = "ojuny.patch.development.enable"; visibleWhen.equals = true; description = "Single executable used by the project picker, for example codium or code.";
          ojuny.patch.development.projects.editorCommand = "codium";

          # @option widget = "switch"; label = "Project scaffolding"; group = "Projects"; visibleWhen.path = "ojuny.patch.development.enable"; visibleWhen.equals = true; description = "Install ojuny-devshell-new for pinned language project flakes.";
          ojuny.patch.development.scaffold.enable = true;

          # @option widget = "text"; label = "Scaffold nixpkgs revision"; group = "Projects"; advanced = true; visibleWhen.path = "ojuny.patch.development.enable"; visibleWhen.equals = true; description = "Revision or branch written into generated project flakes. The host nixpkgs revision is the default.";
          ojuny.patch.development.scaffold.nixpkgsRev = inputs.nixpkgs.rev or "nixos-unstable";
        }

        (lib.mkIf active {
          assertions = [
            {
              assertion =
                cfg.defaultAgent == "none" || (cfg.agents.${cfg.defaultAgent}.enable or false);
              message = "ojuny.patch.development.defaultAgent must name an enabled agent or be none.";
            }
          ];

          environment.systemPackages =
            lspPackages
            ++ (with pkgs; [
              nixos-anywhere
              deploy-rs
              nvd
              nix-output-monitor
              github-cli
              netcat-openbsd
              ripgrep
            ])
            ++ lib.optional cfg.projects.enable projects
            ++ lib.optional cfg.scaffold.enable scaffold;

          # @option widget = "table-attrset"; label = "Aliases"; group = "Aliases"; columns = [ "enable" "value" ]; columnTypes = [ "bool" "str" ];
          ojuny.apps.development.aliases = {
            llm = {
              enable = cfg.agents.opencode.enable or false;
              value = "nix develop -c opencode";
            };
            agent = {
              enable = cfg.defaultAgent != "none";
              value = "ojuny-agent";
            };
            usage = {
              enable = usageEnabled;
              value = "ojuny-agent-usage";
            };
            projects = {
              enable = cfg.projects.enable;
              value = "${projects}/bin/projects";
            };
            devnew = {
              enable = cfg.scaffold.enable;
              value = "${scaffold}/bin/ojuny-devshell-new";
            };
          };

          desktop.ojuny.mango.binds.common.projects = lib.mkIf cfg.projects.enable {
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

          environment.shellAliases = (
            lib.mapAttrs (_: entry: entry.value) (
              lib.filterAttrs (_: entry: entry.enable) config.ojuny.apps.development.aliases
            )
          );
        })
      ];
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
      cfg = osConfig.ojuny.patch.development or { enable = false; };
      active = cfg.enable && (osConfig.ojuny.patches or true);

      flakeRef = "git+file://${config.home.homeDirectory}/repos/nix-flake";

      languageEnabled = name: cfg.languages.${name}.enable or false;
      onAgent = name: cfg.agents.${name}.enable or false;

      enabledAgentNames = builtins.filter onAgent [
        "opencode"
        "claude-code"
        "codex"
        "gemini-cli"
      ];

      agentCommands = {
        opencode = "opencode";
        claude-code = "claude";
        codex = "codex";
        gemini-cli = "gemini";
      };

      opencodeLsp = {
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
        pyright = {
          command = [ "pyright-langserver" ];
          extensions = [ ".py" ];
        };
        rust-analyzer = {
          command = [ "rust-analyzer" ];
          extensions = [ ".rs" ];
        };
        clangd = {
          command = [ "clangd" ];
          extensions = [
            ".c"
            ".h"
            ".cc"
            ".cpp"
            ".hpp"
          ];
        };
        gopls = {
          command = [ "gopls" ];
          extensions = [ ".go" ];
        };
        typescript = {
          command = [
            "typescript-language-server"
            "--stdio"
          ];
          extensions = [
            ".ts"
            ".tsx"
            ".js"
            ".jsx"
          ];
        };
        lua = {
          command = [ "lua-language-server" ];
          extensions = [ ".lua" ];
        };
        bash = {
          command = [
            "bash-language-server"
            "start"
          ];
          extensions = [
            ".sh"
            ".bash"
          ];
        };
        yaml = {
          command = [
            "yaml-language-server"
            "--stdio"
          ];
          extensions = [
            ".yaml"
            ".yml"
          ];
        };
        json = {
          command = [
            "vscode-json-languageserver"
            "--stdio"
          ];
          extensions = [ ".json" ];
        };
        marksman = {
          command = [
            "marksman"
            "server"
          ];
          extensions = [
            ".md"
            ".markdown"
          ];
        };
      };

      enabledLspNames =
        lib.optional (languageEnabled "nix") "nixd"
        ++ lib.optional (languageEnabled "python") "pyright"
        ++ lib.optional (languageEnabled "rust") "rust-analyzer"
        ++ lib.optional (languageEnabled "c" || languageEnabled "cpp") "clangd"
        ++ lib.optional (languageEnabled "go") "gopls"
        ++ lib.optional (languageEnabled "typescript") "typescript"
        ++ lib.optional (languageEnabled "lua") "lua"
        ++ lib.optional (languageEnabled "bash") "bash"
        ++ lib.optional (languageEnabled "yaml") "yaml"
        ++ lib.optional (languageEnabled "json") "json"
        ++ lib.optional (languageEnabled "markdown") "marksman";

      vscodiumExtensions =
        lib.optionals (languageEnabled "nix") (
          with pkgs.vscode-extensions;
          [
            jnoortheen.nix-ide
            signageos.signageos-vscode-sops
          ]
        )
        ++ lib.optionals (languageEnabled "python") (
          with pkgs.vscode-extensions;
          [
            ms-python.python
            ms-python.debugpy
            ms-python.pylint
            ms-python.mypy-type-checker
            ms-pyright.pyright
          ]
        )
        ++ lib.optionals (languageEnabled "rust") (
          with pkgs.vscode-extensions;
          [ rust-lang.rust-analyzer ]
        )
        ++ lib.optionals (languageEnabled "c" || languageEnabled "cpp") (
          with pkgs.vscode-extensions;
          [
            llvm-vs-code-extensions.vscode-clangd
            mesonbuild.mesonbuild
            vadimcn.vscode-lldb
          ]
        )
        ++ lib.optionals (languageEnabled "go") (
          with pkgs.vscode-extensions;
          [ golang.go ]
        )
        ++ lib.optionals (languageEnabled "lua") (
          with pkgs.vscode-extensions;
          [ sumneko.lua ]
        )
        ++ lib.optionals (languageEnabled "bash") (
          with pkgs.vscode-extensions;
          [
            timonwong.shellcheck
            foxundermoon.shell-format
          ]
        )
        ++ lib.optionals (languageEnabled "yaml") (
          with pkgs.vscode-extensions;
          [ redhat.vscode-yaml ]
        )
        ++ lib.optionals (languageEnabled "markdown") (
          with pkgs.vscode-extensions;
          [ yzhang.markdown-all-in-one ]
        );

      usageEnabled = cfg.usage.enable && (onAgent "claude-code" || onAgent "codex");

      agent =
        pkgs.writeShellScriptBin "ojuny-agent" (
          if cfg.defaultAgent == "none" then
            ''
              echo "ojuny-agent: no default agent is configured" >&2
              exit 1
            ''
          else
            ''
              exec ${agentCommands.${cfg.defaultAgent}} "$@"
            ''
        );

      usage = pkgs.writeShellScriptBin "ojuny-agent-usage" ''
        if [ "''${1:-}" = "--offline" ]; then
          printf '%s\n' '{}'
          exit 0
        fi
        exec ${pkgs.ccusage}/bin/ccusage "$@"
      '';
    in
    {
      config = lib.mkIf active {
        programs.vscodium = lib.mkIf cfg.editors.vscodium.enable {
          enable = true;

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
            extensions = vscodiumExtensions;

            userSettings = lib.mkMerge [
              (lib.mkIf (languageEnabled "nix") {
                "nix.serverSettings" = {
                  nixd = {
                    nixpkgs.expr = "(builtins.getFlake \"${flakeRef}\").inputs.nixpkgs { }";
                    formatting.command = [ "nixfmt" ];
                    options.ojuny.expr = "(builtins.head (builtins.attrValues (builtins.getFlake \"${flakeRef}\").nixosConfigurations)).options";
                  };
                };
                "nix.enableLanguageServer" = true;
                "nix.serverPath" = "${pkgs.nixd}/bin/nixd";
                "[nix]" = {
                  editor.insertSpaces = true;
                  editor.tabSize = 2;
                };
              })
              (lib.mkIf (languageEnabled "c" || languageEnabled "cpp") {
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
                "mesonbuild.downloadLanguageServer" = false;
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
              })
            ];
          };
        };

        stylix.targets.vscodium.profileNames = lib.mkIf cfg.editors.vscodium.enable [ "nix" ];

        home.file = lib.mkMerge [
          (lib.mkIf (languageEnabled "c" || languageEnabled "cpp") {
            ".clangd".text = ''
              CompileFlags:
                Add: [-Wall, -Wextra]
            '';
          })
          (lib.mkIf (cfg.defaultAgent != "none") {
            ".config/ojuny/default-agent".text = cfg.defaultAgent + "\n";
          })
        ];

        home.packages =
          lib.optionals (cfg.defaultAgent != "none" && enabledAgentNames != [ ]) [ agent ]
          ++ lib.optionals usageEnabled [
            usage
            pkgs.ccusage
          ]
          ++ lib.optionals (onAgent "claude-code") [ pkgs.claude-code ]
          ++ lib.optionals (onAgent "codex") [ pkgs.codex ]
          ++ lib.optionals (onAgent "gemini-cli") [ pkgs.gemini-cli ];

        programs.opencode = lib.mkIf (onAgent "opencode") {
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
            lsp = lib.filterAttrs (name: _: builtins.elem name enabledLspNames) opencodeLsp;
          };
        };
      };
    };
}
