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
    let
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
    in
    {
      options.ojuny.patch.development.enable = lib.mkEnableOption "the development patch";

      imports = [ self.modules.nixos.development-backend ];

      config = {
        # @option widget = "switch"; label = "Development patch"; group = "Patches"; description = "Install VSCodium, the selected language servers, optional coding agents, and project tooling.";
        ojuny.patch.development.enable = false;

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

        # @option widget = "text"; label = "Project search root"; group = "Projects"; visibleWhen.path = "ojuny.patch.development.enable"; visibleWhen.equals = true; description = "Directory searched for git repositories. $OJUNY_REPO_PATH is expanded by the shell.";
        ojuny.patch.development.projects.searchRoot = "$OJUNY_REPO_PATH/..";

        # @option widget = "text"; label = "Project editor command"; group = "Projects"; visibleWhen.path = "ojuny.patch.development.enable"; visibleWhen.equals = true; description = "Single executable used by the project picker, for example codium or code.";
        ojuny.patch.development.projects.editorCommand = "codium";

        # @option widget = "text"; label = "Project terminal command"; group = "Projects"; visibleWhen.path = "ojuny.patch.development.enable"; visibleWhen.equals = true; description = "Terminal opened by the project picker for the chosen repository.";
        ojuny.patch.development.projects.terminalCommand = "ghostty";

        # @option widget = "text"; label = "Project agent command"; group = "Projects"; visibleWhen.path = "ojuny.patch.development.enable"; visibleWhen.equals = true; description = "Coding agent started by the project picker inside the chosen repository.";
        ojuny.patch.development.projects.assistantCommand = "opencode";

        # @option widget = "switch"; label = "Project scaffolding"; group = "Projects"; visibleWhen.path = "ojuny.patch.development.enable"; visibleWhen.equals = true; description = "Install ojuny-devshell-new for pinned language project flakes.";
        ojuny.patch.development.scaffold.enable = true;

        # @option widget = "text"; label = "Scaffold nixpkgs revision"; group = "Projects"; advanced = true; visibleWhen.path = "ojuny.patch.development.enable"; visibleWhen.equals = true; description = "Revision or branch written into built-in fallback flakes. Upstream templates keep their own pin. The host nixpkgs revision is the default.";
        ojuny.patch.development.scaffold.nixpkgsRev = inputs.nixpkgs.rev or "nixos-unstable";

        home-manager.sharedModules = lib.mkIf (
          config.ojuny.patch.development.enable && (config.ojuny.patches or true)
        ) [ self.modules.homeManager.development-backend ];
      };
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

      templateLanguageMap = {
        the-nix-way = {
          bash = "shell";
          c = "c-cpp";
          cpp = "c-cpp";
          go = "go";
          nix = "nix";
          python = "python";
          rust = "rust";
        };
        NixOS = {
          bash = "bash-hello";
          c = "c-hello";
          go = "go-hello";
          python = "python";
          rust = "rust";
          typescript = "typescript";
        };
      };

      sortedTemplateRepos = lib.sort (a: b: a.priority < b.priority) cfg.scaffold.templateRepos;

      scaffoldCase = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: packages:
          let
            templates = lib.concatMap (
              repo:
              let template = templateLanguageMap.${repo.name}.${name} or null;
              in lib.optional (template != null) "${repo.name}|${repo.url}|${template}"
            ) sortedTemplateRepos;
          in
          ''
            ${name})
              packages="${lib.concatStringsSep " " packages}"
              templates=${lib.escapeShellArg (lib.concatStringsSep "\n" templates)}
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
              git
              gnugrep
              xdg-utils
            ]
          )
        }:"$PATH"

        if ! command -v dms >/dev/null 2>&1; then
          echo "projects: dms is required for the project picker; install DankMaterialShell or use ojuny-devshell-new for a project shell" >&2
          exit 1
        fi

        DIR="''${1:-${cfg.projects.searchRoot}}"

        REPOS=$(find "$DIR" -maxdepth 5 -name .git -type d -exec dirname {} \; 2>/dev/null | xargs -r -I {} readlink -f {})
        if [ -z "$REPOS" ]; then
          echo "projects: no git repositories under $DIR" >&2
          exit 0
        fi

        repo_rows() {
          printf '%s\n' "$REPOS" | while IFS= read -r repo; do
            branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null) || branch="no-git"
            subject=$(git -C "$repo" log -1 --format='%h %s' 2>/dev/null | cut -c1-72) || subject=""
            [ -n "$subject" ] || subject="no commits"
            printf '%s\0display\x1f%s  [%s]  %s\n' "$repo" "''${repo#"$DIR"/}" "$branch" "$subject"
          done
        }

        if [ -n "''${2:-}" ]; then
          SELECTED=$(printf '%s\n' "$REPOS" | grep -E -- "$2" | head -n 1)
        else
          SELECTED=$(repo_rows | dms dmenu --prompt "Project" --lines 12 --format s)
        fi

        if [ -z "$SELECTED" ]; then
          exit 0
        fi

        ACTION=$(printf '%s\n' \
          "Open in editor" \
          "Open terminal" \
          "Start agent" \
          "Open Obsidian vault" \
          "Cancel" \
          | dms dmenu --prompt "$(basename "$SELECTED")" --lines 6 --no-custom)

        if [ -z "$ACTION" ] || [ "$ACTION" = "Cancel" ]; then
          exit 0
        fi

        editor=${lib.escapeShellArg cfg.projects.editorCommand}
        terminal=${lib.escapeShellArg cfg.projects.terminalCommand}
        assistant=${lib.escapeShellArg cfg.projects.assistantCommand}

        run_in_devshell() {
          if [ -f "$SELECTED/flake.nix" ] || [ -f "$SELECTED/shell.nix" ]; then
            if ( cd "$SELECTED" && nix develop -c true >/dev/null 2>&1 ); then
              ( cd "$SELECTED" && nix develop -c "$@" )
              return
            fi
          fi
          ( cd "$SELECTED" && "$@" )
        }

        case "$ACTION" in
          "Open in editor")
            if [ -f "$SELECTED/meson.build" ]; then
              DB_DIR="$HOME/.cache/clangd/$(basename "$SELECTED")"
              mkdir -p "$DB_DIR"
              ( cd "$SELECTED" && nix develop -c zsh -c "meson setup \"$DB_DIR\" \"$SELECTED\" >/dev/null 2>&1 || true; $editor -n \"$SELECTED\"" )
            else
              run_in_devshell "$editor" -n "$SELECTED"
            fi
            ;;
          "Open terminal")
            run_in_devshell "$terminal"
            ;;
          "Start agent")
            run_in_devshell "$assistant"
            ;;
          "Open Obsidian vault")
            vault_path="$SELECTED"
            vault_path="''${vault_path// /%20}"
            xdg-open "obsidian://open?path=$vault_path" >/dev/null 2>&1 &
            ;;
        esac
      '';

      scaffold = pkgs.writeShellScriptBin "ojuny-devshell-new" ''
        export PATH=${lib.makeBinPath (with pkgs; [ coreutils gnused findutils ])}:"$PATH"
        set -euo pipefail

        language="''${1:-}"
        dir="''${2:-$PWD}"
        used_repo=""
        used_template=""

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

        while IFS='|' read -r repo_name repo_url repo_template; do
          [ -n "$repo_name" ] || continue
          if ( cd "$dir" && nix flake init -t "$repo_url#$repo_template" ); then
            used_repo="$repo_name"
            used_template="$repo_template"
            break
          fi
          echo "ojuny-devshell-new: $repo_name#$repo_template is unavailable, trying the next template source" >&2
        done <<< "$templates"

        if [ -z "$used_repo" ]; then
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
        fi

        if [ ! -e "$dir/.gitignore" ]; then
          printf '%s\n' "result" ".direnv" > "$dir/.gitignore"
        fi

        if [ -n "$used_repo" ]; then
          echo "Created $dir from $used_repo#$used_template"
        else
          echo "Created $dir/flake.nix from the built-in $language template"
        fi
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
            default = "$OJUNY_REPO_PATH/..";
            description = "Directory searched for git repositories. $OJUNY_REPO_PATH is expanded by the shell.";
          };
          editorCommand = lib.mkOption {
            type = lib.types.str;
            default = "codium";
            description = "Single executable used by the project picker, for example codium or code.";
          };
          terminalCommand = lib.mkOption {
            type = lib.types.str;
            default = "ghostty";
            description = "Terminal opened by the project picker for the chosen repository.";
          };
          assistantCommand = lib.mkOption {
            type = lib.types.str;
            default = "opencode";
            description = "Coding agent started by the project picker inside the chosen repository.";
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
            description = "Revision or branch written into built-in fallback flakes. Upstream templates keep their own nixpkgs pin.";
          };
          templateRepos = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  name = lib.mkOption {
                    type = lib.types.str;
                    description = "Repository identifier used to look up the per-language template names.";
                  };
                  url = lib.mkOption {
                    type = lib.types.str;
                    description = "Pinned flake reference passed to nix flake init -t.";
                  };
                  priority = lib.mkOption {
                    type = lib.types.int;
                    default = 0;
                    description = "Tried in ascending order; the lowest priority value wins.";
                  };
                };
              }
            );
            default = [
              {
                name = "the-nix-way";
                url = "github:the-nix-way/dev-templates/9ffac48bbda3ba44e58e250d9a57d4520ce55401";
                priority = 10;
              }
              {
                name = "NixOS";
                url = "github:NixOS/templates/3348e5b68b7a53c1ef9d20605c3cad169f65899a";
                priority = 20;
              }
            ];
            description = "Template flake repositories tried in ascending priority order. A repository without a mapping for the requested language is skipped.";
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

      config = lib.mkIf active {
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
      cfg = osConfig.ojuny.patch.development or { enable = false; };
      active = cfg.enable && (osConfig.ojuny.patches or true);

      flakeRef = "git+file://${
        osConfig.environment.variables.OJUNY_REPO_PATH
          or "${config.home.homeDirectory}/${osConfig.ojuny.repoPath or "repos/nix-flake"}"
      }";

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
