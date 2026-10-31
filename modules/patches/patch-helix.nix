/*
  @menu
  displayname = "Helix";
  icon = "accessories-text-editor-symbolic";
  order = 30;
  description = "Helix editor with Stylix theming and language servers";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }:

let
  languageServers = {
    nix = {
      command = "nixd";
      args = [ ];
      package = "nixd";
    };
    python = {
      command = "pyright-langserver";
      args = [ "--stdio" ];
      package = "pyright";
    };
    rust = {
      command = "rust-analyzer";
      args = [ ];
      package = "rust-analyzer";
    };
    c = {
      command = "clangd";
      args = [ ];
      package = "clang-tools";
    };
    cpp = {
      command = "clangd";
      args = [ ];
      package = "clang-tools";
    };
    go = {
      command = "gopls";
      args = [ ];
      package = "gopls";
    };
    typescript = {
      command = "typescript-language-server";
      args = [ "--stdio" ];
      package = "typescript-language-server";
    };
    lua = {
      command = "lua-language-server";
      args = [ ];
      package = "lua-language-server";
    };
    bash = {
      command = "bash-language-server";
      args = [ "start" ];
      package = "bash-language-server";
    };
    yaml = {
      command = "yaml-language-server";
      args = [ "--stdio" ];
      package = "yaml-language-server";
    };
    json = {
      command = "vscode-json-languageserver";
      args = [ "--stdio" ];
      package = "vscode-json-languageserver";
    };
    markdown = {
      command = "marksman";
      args = [ "server" ];
      package = "marksman";
    };
  };

  languageNames = builtins.attrNames languageServers;

  defaultLanguages = [
    "nix"
    "python"
    "rust"
    "bash"
  ];
in
{
  flake.modules.nixos.patch-helix =
    {
      config,
      lib,
      ...
    }:
    {
      options.ojuny.patch.helix.enable = lib.mkEnableOption "the Helix patch";

      # @option widget = "switch"; label = "Helix"; group = "Helix"; groupOrder = 10; order = 10; description = "Install and configure Helix with Stylix theming and language servers."
      config.ojuny.patch.helix.enable = false;

      imports = [ self.modules.nixos.helix-backend ];

      config.home-manager.sharedModules = lib.mkIf (
        config.ojuny.patch.helix.enable && (config.ojuny.patches or true)
      ) [ self.modules.homeManager.helix-backend ];
    };

  flake.modules.nixos.helix-backend =
    { lib, ... }:
    {
      options.ojuny.patch.helix = {
        defaultEditor = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Set EDITOR and VISUAL to hx.";
        };

        settings = lib.mkOption {
          type = lib.types.attrs;
          default = {
            editor.line-number = "relative";
            editor.lsp.display-messages = true;
          };
          description = "Helix config.toml contents. The theme is owned by Stylix.";
        };

        languages = lib.mkOption {
          type = lib.types.listOf (lib.types.enum languageNames);
          default = defaultLanguages;
          description = "Languages whose language server is configured and installed.";
        };

        extraPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "Additional packages made available to hx.";
        };
      };

      config = {
        # @option widget = "switch"; label = "Default editor"; group = "Integration"; groupOrder = 20; order = 10; visibleWhen.path = "ojuny.patch.helix.enable"; visibleWhen.equals = true; description = "Set EDITOR and VISUAL to hx. Turn this off if another editor patch or your shell config already owns them."
        ojuny.patch.helix.defaultEditor = false;

        # @option widget = "raw"; rows = 10; label = "Settings"; group = "Settings"; groupOrder = 30; order = 10; visibleWhen.path = "ojuny.patch.helix.enable"; visibleWhen.equals = true; description = "Helix config.toml contents. The theme key is owned by Stylix."
        ojuny.patch.helix.settings = {
          editor.line-number = "relative";
          editor.lsp.display-messages = true;
        };

        # @option widget = "list"; label = "Languages"; group = "Languages"; groupOrder = 40; order = 10; visibleWhen.path = "ojuny.patch.helix.enable"; visibleWhen.equals = true; description = "Languages whose language server is configured and installed. Supported values: nix, python, rust, c, cpp, go, typescript, lua, bash, yaml, json, markdown."
        ojuny.patch.helix.languages = defaultLanguages;

        # @option widget = "packages"; label = "Extra packages"; group = "Extra packages"; groupOrder = 50; order = 10; visibleWhen.path = "ojuny.patch.helix.enable"; visibleWhen.equals = true; description = "Additional packages made available to hx."
        ojuny.patch.helix.extraPackages = [ ];
      };
    };

  flake.modules.homeManager.helix-backend =
    {
      lib,
      pkgs,
      osConfig ? { },
      ...
    }:
    let
      cfg =
        (osConfig.ojuny.patch.helix or {
          enable = false;
          defaultEditor = false;
          settings = { };
          languages = [ ];
          extraPackages = [ ];
        }
        )
        // {
          enable = (osConfig.ojuny.patch.helix.enable or false) && (osConfig.ojuny.patches or true);
        };

      enabledLanguages = builtins.filter (name: builtins.elem name cfg.languages) languageNames;
      selectedServers = map (name: languageServers.${name}) enabledLanguages;
      lspPackages = lib.unique (map (spec: pkgs.${spec.package}) selectedServers);

      languagesConfig = {
        language-server = lib.genAttrs enabledLanguages (name: {
          command = "${pkgs.${languageServers.${name}.package}}/bin/${languageServers.${name}.command}";
          args = languageServers.${name}.args;
        });

        language = map (name: {
          inherit name;
          language-servers = [ name ];
        }) enabledLanguages;
      };
    in
    {
      config = lib.mkIf cfg.enable {
        programs.helix = {
          enable = true;
          defaultEditor = cfg.defaultEditor;
          settings = cfg.settings;
          languages = languagesConfig;
          extraPackages = lspPackages ++ cfg.extraPackages;
        };

        stylix.targets.helix.enable = lib.mkDefault true;
      };
    };
}
