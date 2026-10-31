/*
  @menu
  displayname = "Nixvim";
  icon = "accessories-text-editor-symbolic";
  order = 25;
  description = "Neovim via Nixvim with LSP servers and Stylix theming";
  category = "Patches";
  systems = [ "all" ];
*/

# @inputs name = "nixvim"; url = "github:nix-community/nixvim";

{ self, inputs, ... }:
let
  hasNixvim = inputs ? nixvim;

  languageServers = {
    nix = {
      native = "nixd";
      nixvim = "nixd";
      package = "nixd";
    };
    python = {
      native = "pyright";
      nixvim = "pyright";
      package = "pyright";
    };
    rust = {
      native = "rust_analyzer";
      nixvim = "rust_analyzer";
      package = "rust-analyzer";
    };
    go = {
      native = "gopls";
      nixvim = "gopls";
      package = "gopls";
    };
    c = {
      native = "clangd";
      nixvim = "clangd";
      package = "clang-tools";
    };
    cpp = {
      native = "clangd";
      nixvim = "clangd";
      package = "clang-tools";
    };
    typescript = {
      native = "ts_ls";
      nixvim = "ts_ls";
      package = "typescript-language-server";
    };
    lua = {
      native = "lua_ls";
      nixvim = "lua_ls";
      package = "lua-language-server";
    };
    bash = {
      native = "bashls";
      nixvim = "bashls";
      package = "bash-language-server";
    };
    yaml = {
      native = "yamlls";
      nixvim = "yamlls";
      package = "yaml-language-server";
    };
    json = {
      native = "jsonls";
      nixvim = "jsonls";
      package = "vscode-json-languageserver";
    };
    markdown = {
      native = "marksman";
      nixvim = "marksman";
      package = "marksman";
    };
  };

  languageNames = builtins.attrNames languageServers;

  defaultLanguages = [
    "nix"
    "python"
    "rust"
    "go"
    "c"
    "cpp"
    "typescript"
    "lua"
    "bash"
    "yaml"
    "json"
    "markdown"
  ];
in
{
  flake.modules.nixos.patch-nixvim =
    { config, lib, ... }:
    {
      options.ojuny.patch.nixvim.enable = lib.mkEnableOption "the Nixvim patch";

      # @option widget = "switch"; label = "Nixvim"; group = "Nixvim"; description = "Install the Neovim editor and its language servers.";
      config.ojuny.patch.nixvim.enable = false;

      imports = [ self.modules.nixos.nixvim-backend ];

      config.home-manager.sharedModules = lib.mkIf (
        config.ojuny.patch.nixvim.enable && (config.ojuny.patches or true)
      ) [ self.modules.homeManager.nixvim-backend ];
    };

  flake.modules.nixos.nixvim-backend =
    { config, lib, ... }:
    let
      cfg = config.ojuny.patch.nixvim;
      active = cfg.enable && (config.ojuny.patches or true);
    in
    {
      options.ojuny.patch.nixvim = {
        engine = lib.mkOption {
          type = lib.types.enum [
            "auto"
            "nixvim"
            "native"
          ];
          default = "auto";
          description = "Editor engine. auto uses Nixvim when inputs.nixvim is present and native Neovim otherwise.";
        };

        defaultEditor = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Set EDITOR and VISUAL to nvim. The template's global EDITOR default is micro.";
        };

        languages = lib.mkOption {
          type = lib.types.listOf (lib.types.enum languageNames);
          default = defaultLanguages;
          description = "Language servers enabled in the editor.";
        };

        extraPlugins = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "Extra vim plugins, normally used only from the advanced GUI field.";
        };
      };

      config = {
        # @option widget = "dropdown"; label = "Engine"; group = "Nixvim"; choices = [ "auto" "nixvim" "native" ]; visibleWhen.path = "ojuny.patch.nixvim.enable"; visibleWhen.equals = true; description = "auto uses Nixvim when the host flake provides inputs.nixvim, otherwise native Neovim.";
        ojuny.patch.nixvim.engine = "auto";

        # @option widget = "switch"; label = "Default editor"; group = "Nixvim"; visibleWhen.path = "ojuny.patch.nixvim.enable"; visibleWhen.equals = true; description = "Set EDITOR and VISUAL to nvim. The template's global EDITOR default is micro.";
        ojuny.patch.nixvim.defaultEditor = false;

        # @option widget = "list"; label = "Language servers"; group = "Language servers"; visibleWhen.path = "ojuny.patch.nixvim.enable"; visibleWhen.equals = true; description = "Languages whose LSP server is installed and enabled.";
        ojuny.patch.nixvim.languages = defaultLanguages;

        # @option widget = "packages"; label = "Extra plugins"; group = "Advanced"; hidden = true; visibleWhen.path = "ojuny.patch.nixvim.enable"; visibleWhen.equals = true; description = "Additional vim plugins as nixpkgs packages.";
        ojuny.patch.nixvim.extraPlugins = [ ];

        assertions = lib.optionals active [
          {
            assertion = cfg.engine != "nixvim" || hasNixvim;
            message = "patch-nixvim: engine = \"nixvim\" requires inputs.nixvim. Add github:nix-community/nixvim to the host flake or set engine = \"native\".";
          }
        ];
      };
    };

  flake.modules.homeManager.nixvim-backend =
    {
      config,
      lib,
      pkgs,
      options,
      osConfig,
      ...
    }:
    let
      cfg = osConfig.ojuny.patch.nixvim;
      selected = map (name: languageServers.${name}) cfg.languages;
      nativeServers = lib.unique (map (entry: entry.native) selected);
      nixvimServers = lib.unique (map (entry: entry.nixvim) selected);
      lspPackages = lib.unique (map (entry: pkgs.${entry.package}) selected);

      effectiveEngine = if hasNixvim && cfg.engine != "native" then "nixvim" else "native";

      commonNixvim = {
        enable = true;
        defaultEditor = cfg.defaultEditor;
        viAlias = true;
        vimAlias = true;
        globals.mapleader = " ";
        opts = {
          number = true;
          relativenumber = true;
          shiftwidth = 2;
          expandtab = true;
          termguicolors = true;
          signcolumn = "yes";
        };
        plugins = {
          lsp = {
            enable = true;
            servers = lib.genAttrs nixvimServers (_: {
              enable = true;
            });
          };
          treesitter.enable = true;
          telescope.enable = true;
          lualine.enable = true;
          gitsigns.enable = true;
          which-key.enable = true;
        };
        extraPlugins = cfg.extraPlugins;
        keymaps = [
          {
            mode = "n";
            key = "<leader>ff";
            action = "<cmd>Telescope find_files<cr>";
            options.silent = true;
          }
          {
            mode = "n";
            key = "<leader>fg";
            action = "<cmd>Telescope live_grep<cr>";
            options.silent = true;
          }
          {
            mode = "n";
            key = "<leader>fb";
            action = "<cmd>Telescope buffers<cr>";
            options.silent = true;
          }
        ];
      };

      nativeLua = ''
        vim.opt.number = true
        vim.opt.relativenumber = true
        vim.opt.shiftwidth = 2
        vim.opt.expandtab = true
        vim.opt.termguicolors = true
        vim.opt.signcolumn = "yes"
        vim.g.mapleader = " "
        vim.lsp.enable({ ${lib.concatMapStringsSep ", " (name: "'${name}'") nativeServers} })
        require("telescope").setup({})
        require("lualine").setup({})
        require("gitsigns").setup({})
        require("which-key").setup({})
        local builtin = require("telescope.builtin")
        vim.keymap.set("n", "<leader>ff", builtin.find_files, { silent = true })
        vim.keymap.set("n", "<leader>fg", builtin.live_grep, { silent = true })
        vim.keymap.set("n", "<leader>fb", builtin.buffers, { silent = true })
      '';
    in
    {
      imports = lib.optionals hasNixvim [ inputs.nixvim.homeManagerModules.nixvim ];

      config = lib.mkIf (cfg.enable && (osConfig.ojuny.patches or true)) (
        lib.mkMerge [
          {
            warnings =
              lib.optional (cfg.engine == "auto" && !hasNixvim)
                "patch-nixvim: inputs.nixvim is not available; using native Neovim. Add github:nix-community/nixvim to the host flake to enable the Nixvim engine.";
          }
          (
            if effectiveEngine == "nixvim" then
              lib.mkMerge [
                { programs.nixvim = commonNixvim; }
                (lib.optionalAttrs (options ? stylix) {
                  stylix.targets.nixvim.enable = true;
                })
              ]
            else
              lib.mkMerge [
                {
                  programs.neovim = {
                    enable = true;
                    defaultEditor = cfg.defaultEditor;
                    viAlias = true;
                    vimAlias = true;
                    extraPackages = lspPackages;
                    plugins = [
                      pkgs.vimPlugins.nvim-lspconfig
                      pkgs.vimPlugins.telescope-nvim
                      pkgs.vimPlugins.lualine-nvim
                      pkgs.vimPlugins.gitsigns-nvim
                      pkgs.vimPlugins.which-key-nvim
                    ]
                    ++ cfg.extraPlugins;
                    extraLuaConfig = nativeLua;
                  };
                }
                (lib.optionalAttrs (options ? stylix) {
                  stylix.targets.neovim.enable = true;
                })
              ]
          )
        ]
      );
    };
}
