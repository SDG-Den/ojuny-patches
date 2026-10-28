/*
  @menu
  displayname = "Emacs";
  icon = "applications-development-symbolic";
  order = 70;
  description = "Emacs GUI with Stylix theming and Eglot language server integration";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }:

{
  flake.modules.nixos.patch-emacs =
    {
      config,
      lib,
      ...
    }:
    {
      options.ojuny.patch.emacs.enable = lib.mkEnableOption "the Emacs patch";

      # @option widget = "switch"; label = "Emacs"; group = "Emacs"; groupOrder = 10; order = 10; description = "Install and configure Emacs with Stylix theming and Eglot language servers."
      config.ojuny.patch.emacs.enable = false;

      imports = [ self.modules.nixos.emacs-backend ];

      config.home-manager.sharedModules = lib.mkIf (
        config.ojuny.patch.emacs.enable && (config.ojuny.patches or true)
      ) [ self.modules.homeManager.emacs-backend ];
    };

  flake.modules.nixos.emacs-backend =
    { lib, ... }:
    {
      options.ojuny.patch.emacs = {
        variant = lib.mkOption {
          type = lib.types.enum [
            "pgtk"
            "gtk"
          ];
          default = "pgtk";
          description = "Emacs build: pgtk for native Wayland, gtk for the X11 build.";
        };
        defaultEditor = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Set EDITOR and VISUAL to Emacs.";
        };
        languages = lib.mkOption {
          type = lib.types.listOf (
            lib.types.enum [
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
            ]
          );
          default = [
            "nix"
            "python"
            "rust"
            "c"
            "cpp"
            "bash"
          ];
          description = "Languages whose LSP servers and Emacs major modes are installed.";
        };
        extraPackages = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional Emacs package names from the selected nixpkgs emacsPackages set, for example magit.";
        };
      };

      config = {
        # @option widget = "dropdown"; label = "Package variant"; group = "Package"; groupOrder = 20; order = 10; choices = [ "pgtk" "gtk" ]; visibleWhen.path = "ojuny.patch.emacs.enable"; visibleWhen.equals = true; description = "pgtk is the native Wayland build and is recommended. gtk is the X11 build for compatibility."
        ojuny.patch.emacs.variant = "pgtk";

        # @option widget = "switch"; label = "Default editor"; group = "Integration"; groupOrder = 30; order = 10; visibleWhen.path = "ojuny.patch.emacs.enable"; visibleWhen.equals = true; description = "Set EDITOR and VISUAL to Emacs. Turn this off if another editor patch or your shell config already owns them."
        ojuny.patch.emacs.defaultEditor = false;

        # @option widget = "list"; label = "Languages"; group = "Integration"; groupOrder = 30; order = 20; visibleWhen.path = "ojuny.patch.emacs.enable"; visibleWhen.equals = true; description = "Languages with an LSP server and Emacs major mode. Supported values: nix, python, rust, c, cpp, go, typescript, lua, bash, yaml, json, markdown."
        ojuny.patch.emacs.languages = [
          "nix"
          "python"
          "rust"
          "c"
          "cpp"
          "bash"
        ];

        # @option widget = "list"; label = "Extra Emacs packages"; group = "Extra packages"; groupOrder = 40; order = 10; visibleWhen.path = "ojuny.patch.emacs.enable"; visibleWhen.equals = true; description = "Additional names from the nixpkgs emacsPackages set, for example magit. Names are resolved at evaluation time, so a typo fails the build."
        ojuny.patch.emacs.extraPackages = [ ];
      };
    };

  flake.modules.homeManager.emacs-backend =
    {
      lib,
      pkgs,
      osConfig ? { },
      ...
    }:
    let
      active = (osConfig.ojuny.patch.emacs.enable or false) && (osConfig.ojuny.patches or true);
      cfg =
        (osConfig.ojuny.patch.emacs or {
          enable = false;
          variant = "pgtk";
          defaultEditor = false;
          languages = [ ];
          extraPackages = [ ];
        }
        )
        // {
          enable = active;
        };

      package = if cfg.variant == "pgtk" then pkgs.emacs-pgtk else pkgs.emacs;

      languageSpecs = {
        nix = {
          mode = "nix-mode";
          server = [ "nixd" ];
          packages = [
            pkgs.nixd
            pkgs.nixfmt
          ];
        };
        python = {
          mode = "python-mode";
          server = [
            "pyright-langserver"
            "--stdio"
          ];
          packages = [ pkgs.pyright ];
        };
        rust = {
          mode = "rust-mode";
          server = [ "rust-analyzer" ];
          packages = [
            pkgs.rust-analyzer
            pkgs.rustfmt
          ];
        };
        c = {
          mode = "c-mode";
          server = [ "clangd" ];
          packages = [ pkgs.clang-tools ];
        };
        cpp = {
          mode = "c++-mode";
          server = [ "clangd" ];
          packages = [ pkgs.clang-tools ];
        };
        go = {
          mode = "go-mode";
          server = [ "gopls" ];
          packages = [ pkgs.gopls ];
        };
        typescript = {
          mode = "typescript-mode";
          server = [
            "typescript-language-server"
            "--stdio"
          ];
          packages = [ pkgs.typescript-language-server ];
        };
        lua = {
          mode = "lua-mode";
          server = [ "lua-language-server" ];
          packages = [ pkgs.lua-language-server ];
        };
        bash = {
          mode = "sh-mode";
          server = [
            "bash-language-server"
            "start"
          ];
          packages = [
            pkgs.bash-language-server
            pkgs.shellcheck
            pkgs.shfmt
          ];
        };
        yaml = {
          mode = "yaml-mode";
          server = [
            "yaml-language-server"
            "--stdio"
          ];
          packages = [ pkgs.yaml-language-server ];
        };
        json = {
          mode = "json-mode";
          server = [
            "vscode-json-languageserver"
            "--stdio"
          ];
          packages = [ pkgs.vscode-json-languageserver ];
        };
        markdown = {
          mode = "markdown-mode";
          server = [
            "marksman"
            "server"
          ];
          packages = [ pkgs.marksman ];
        };
      };

      enabledLanguages = lib.filter (name: builtins.elem name cfg.languages) (
        builtins.attrNames languageSpecs
      );

      emacsList = items: "(${lib.concatMapStringsSep " " (item: "\"${item}\"") items})";

      eglotConfig = lib.concatMapStringsSep "\n" (
        name:
        let
          spec = languageSpecs.${name};
        in
        ''
          (add-to-list 'eglot-server-programs '(${spec.mode} . ${emacsList spec.server}))
          (add-hook '${spec.mode}-hook #'eglot-ensure)
        ''
      ) enabledLanguages;

      modePackages =
        epkgs:
        lib.optionals (builtins.elem "nix" cfg.languages) [ epkgs.nix-mode ]
        ++ lib.optionals (builtins.elem "rust" cfg.languages) [ epkgs.rust-mode ]
        ++ lib.optionals (builtins.elem "go" cfg.languages) [ epkgs.go-mode ]
        ++ lib.optionals (builtins.elem "typescript" cfg.languages) [ epkgs.typescript-mode ]
        ++ lib.optionals (builtins.elem "lua" cfg.languages) [ epkgs.lua-mode ]
        ++ lib.optionals (builtins.elem "yaml" cfg.languages) [ epkgs.yaml-mode ]
        ++ lib.optionals (builtins.elem "json" cfg.languages) [ epkgs.json-mode ]
        ++ lib.optionals (builtins.elem "markdown" cfg.languages) [ epkgs.markdown-mode ];
    in
    {
      config = lib.mkIf cfg.enable {
        programs.emacs = {
          enable = true;
          package = lib.mkDefault package;
          defaultEditor = lib.mkDefault cfg.defaultEditor;
          extraPackages = epkgs: modePackages epkgs ++ map (name: epkgs.${name}) cfg.extraPackages;
          extraConfig = ''
            (require 'eglot)
            (setq eglot-autoshutdown t)
            ${eglotConfig}
          '';
        };

        home.packages = lib.unique (lib.concatMap (name: languageSpecs.${name}.packages) enabledLanguages);

        stylix.targets.emacs.enable = lib.mkDefault true;
      };
    };
}
