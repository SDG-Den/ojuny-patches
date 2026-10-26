/*
  @menu
  displayname = "Local LLM";
  icon = "applications-science-symbolic";
  order = 140;
  description = "Local model server and Nix-managed agent harness";
  category = "Patches";
  systems = [ "all" ];
*/

{ ... }: {

  flake.modules.nixos.patch-local-llm =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.ojuny.patch.local-llm;

      modelSpecs = {
        gemma4-e2b = {
          name = "gemma-4-E2B-it";
          repo = "unsloth/gemma-4-E2B-it-GGUF";
          file = "gemma-4-E2B-it-Q4_K_M.gguf";
          hash = lib.fakeHash;
          ollama = "gemma4:e2b";
        };
        gemma4-e4b = {
          name = "gemma-4-E4B-it";
          repo = "unsloth/gemma-4-E4B-it-GGUF";
          file = "gemma-4-E4B-it-Q4_K_M.gguf";
          hash = "sha256-haiWoEdVPoQvJSl+5bAx1k/zAUfZxK8XseSzlM0fq4c=";
          ollama = "gemma4:e4b";
        };
        gemma4-31b = {
          name = "gemma-4-31B-it";
          repo = "unsloth/gemma-4-31B-it-GGUF";
          file = "gemma-4-31B-it-Q4_K_M.gguf";
          hash = lib.fakeHash;
          ollama = "gemma4:31b";
        };
      };

      model = modelSpecs.${cfg.model};

      modelFile = pkgs.fetchurl {
        url = "https://huggingface.co/${model.repo}/resolve/main/${model.file}";
        hash = model.hash;
      };

      modelsIni = pkgs.writeText "ojuny-models.ini" ''
        version = 1
        [${model.name}]
        model = ${modelFile}
        load-on-startup = true
      '';

      llamaTurbo =
        (pkgs.llama-cpp.override {
          cudaSupport = cfg.acceleration == "cuda";
          rocmSupport = cfg.acceleration == "rocm";
          vulkanSupport = cfg.acceleration == "vulkan";
          cpuArchDynamicDispatch = false;
        }).overrideAttrs
          (previous: {
            src = pkgs.fetchFromGitHub {
              owner = "TheTom";
              repo = "llama-cpp-turboquant";
              rev = "407f3237bfb3eeaff61546797de3d8c1a96be748";
              hash = "sha256-eBKipV3s0DkPvchR5TMR4MNBsRn/Vfymu68MN2OBMr4=";
            };
            npmDepsHash = "sha256-FHvd2bMvBc9EXrJEzu8EN78oUVSLcOKYCc0232V+L4A=";
            cmakeFlags =
              lib.filter (
                flag: !(lib.hasPrefix "-DGGML_NATIVE" flag) && !(lib.hasPrefix "-DCMAKE_CUDA_ARCHITECTURES" flag)
              ) (previous.cmakeFlags or [ ])
              ++ [ "-DGGML_NATIVE=ON" ];
          });
    in
    {
      options.ojuny.patch.local-llm = {
        enable = lib.mkEnableOption "the local LLM patch";
        backend = lib.mkOption {
          type = lib.types.enum [
            "llama-cpp-turbo"
            "ollama"
          ];
          default = "llama-cpp-turbo";
        };
        model = lib.mkOption {
          type = lib.types.enum [
            "gemma4-e2b"
            "gemma4-e4b"
            "gemma4-31b"
          ];
          default = "gemma4-e4b";
        };
        acceleration = lib.mkOption {
          type = lib.types.enum [
            "cpu"
            "cuda"
            "rocm"
            "vulkan"
          ];
          default = "cpu";
        };
        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 8080;
        };
        contextSize = lib.mkOption {
          type = lib.types.int;
          default = 131072;
        };
        gpuLayers = lib.mkOption {
          type = lib.types.int;
          default = 999;
        };
        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        modelId = lib.mkOption {
          type = lib.types.str;
          default = "";
          internal = true;
        };
        harness = lib.mkOption {
          type = lib.types.enum [
            "opencode"
            "none"
          ];
          default = "opencode";
        };
        systemPrompt = lib.mkOption {
          type = lib.types.str;
          default = "You are a NixOS assistant for this Ojuny system. Read ~/repos/ojuny-template. Run ojuny-troubleshoot first for diagnostics. Never change the system unless the user explicitly asks.";
        };
        troubleshootingPrompt = lib.mkOption {
          type = lib.types.str;
          default = "You diagnose Ojuny and NixOS. Run ojuny-troubleshoot first. Read the Nix configuration. Report findings and a minimal fix. Do not edit files or change the system.";
        };
        lspServers = lib.mkOption {
          type = lib.types.listOf (
            lib.types.enum [
              "nixd"
              "rust-analyzer"
              "pyright"
              "typescript"
              "gopls"
              "clangd"
            ]
          );
          default = [
            "nixd"
            "rust-analyzer"
            "pyright"
            "typescript"
            "gopls"
            "clangd"
          ];
        };
        agents = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                description = lib.mkOption { type = lib.types.str; };
                prompt = lib.mkOption { type = lib.types.str; };
                mode = lib.mkOption {
                  type = lib.types.enum [
                    "primary"
                    "subagent"
                    "all"
                  ];
                  default = "subagent";
                };
                model = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                };
                permission = lib.mkOption {
                  type = lib.types.attrs;
                  default = { };
                };
              };
            }
          );
          default = { };
        };
      };

      config = {
        # @option widget = "switch"; label = "Local LLM"; group = "Local LLM";
        ojuny.patch.local-llm.enable = false;

        # @option widget = "dropdown"; label = "Backend"; group = "Local LLM"; choices = [ "llama-cpp-turbo" "ollama" ];
        ojuny.patch.local-llm.backend = "llama-cpp-turbo";

        # @option widget = "dropdown"; label = "Model"; group = "Local LLM"; choices = [ "gemma4-e2b" "gemma4-e4b" "gemma4-31b" ];
        ojuny.patch.local-llm.model = "gemma4-e4b";

        # @option widget = "dropdown"; label = "Acceleration"; group = "Local LLM"; choices = [ "cpu" "cuda" "rocm" "vulkan" ];
        ojuny.patch.local-llm.acceleration = "cpu";

        # @option widget = "text"; label = "Host"; group = "Server";
        ojuny.patch.local-llm.host = "127.0.0.1";

        # @option widget = "spin"; label = "Port"; group = "Server";
        ojuny.patch.local-llm.port = 8080;

        # @option widget = "spin"; label = "Context size"; group = "Server";
        ojuny.patch.local-llm.contextSize = 131072;

        # @option widget = "spin"; label = "GPU layers"; group = "Server";
        ojuny.patch.local-llm.gpuLayers = 999;

        # @option widget = "switch"; label = "Open firewall"; group = "Server";
        ojuny.patch.local-llm.openFirewall = false;

        # @option widget = "dropdown"; label = "Harness"; group = "Harness"; choices = [ "opencode" "none" ];
        ojuny.patch.local-llm.harness = "opencode";

        # @option widget = "raw"; label = "System prompt"; group = "Harness"; rows = 8;
        ojuny.patch.local-llm.systemPrompt = "You are a NixOS assistant for this Ojuny system. Read ~/repos/ojuny-template. Run ojuny-troubleshoot first for diagnostics. Never change the system unless the user explicitly asks.";

        # @option widget = "raw"; label = "Troubleshooting prompt"; group = "Harness"; rows = 6;
        ojuny.patch.local-llm.troubleshootingPrompt = "You diagnose Ojuny and NixOS. Run ojuny-troubleshoot first. Read the Nix configuration. Report findings and a minimal fix. Do not edit files or change the system.";

        # @option widget = "raw"; label = "Agents"; group = "Harness"; rows = 10;
        ojuny.patch.local-llm.agents = { };

        # @option widget = "list"; label = "LSP servers"; group = "Harness";
        ojuny.patch.local-llm.lspServers = [
          "nixd"
          "rust-analyzer"
          "pyright"
          "typescript"
          "gopls"
          "clangd"
        ];

        ojuny.patch.local-llm.modelId = if cfg.backend == "ollama" then model.ollama else model.name;

        services.llama-cpp = lib.mkIf (cfg.enable && cfg.backend == "llama-cpp-turbo") {
          enable = true;
          package = llamaTurbo;
          settings = {
            host = cfg.host;
            port = cfg.port;
            ctx-size = cfg.contextSize;
            n-gpu-layers = cfg.gpuLayers;
            flash-attn = "on";
            cache-type-k = "q8_0";
            cache-type-v = "turbo4";
            sleep-idle-seconds = 60;
            models-preset = modelsIni;
            models-max = 1;
          };
        };

        services.ollama = lib.mkIf (cfg.enable && cfg.backend == "ollama") {
          enable = true;
          package =
            {
              cpu = pkgs.ollama-cpu;
              cuda = pkgs.ollama-cuda;
              rocm = pkgs.ollama-rocm;
              vulkan = pkgs.ollama-vulkan;
            }
            .${cfg.acceleration};
          host = cfg.host;
          port = cfg.port;
          loadModels = [ model.ollama ];
          openFirewall = cfg.openFirewall;
        };

        networking.firewall.allowedTCPPorts = lib.mkIf (
          cfg.enable && cfg.openFirewall && cfg.backend == "llama-cpp-turbo"
        ) [ cfg.port ];
      };
    };

  flake.modules.homeManager.patch-local-llm =
    {
      config,
      lib,
      pkgs,
      osConfig,
      ...
    }:
    let
      cfg = osConfig.ojuny.patch.local-llm;
      providerId = "ojuny-local";
      baseUrl = "http://${cfg.host}:${toString cfg.port}/v1";

      lspConfig = {
        nixd = {
          command = [ "nixd" ];
          extensions = [ ".nix" ];
        };
        rust-analyzer = {
          command = [ "rust-analyzer" ];
          extensions = [ ".rs" ];
        };
        pyright = {
          command = [ "pyright-langserver" ];
          extensions = [ ".py" ];
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
        gopls = {
          command = [ "gopls" ];
          extensions = [ ".go" ];
        };
        clangd = {
          command = [ "clangd" ];
          extensions = [
            ".c"
            ".cpp"
            ".h"
            ".hpp"
          ];
        };
      };

      troubleshoot = pkgs.writeShellScriptBin "ojuny-troubleshoot" ''
        set -euo pipefail
        echo "## system"
        nixos-version
        uname -a
        echo "## nix"
        nix flake metadata "$HOME/repos/ojuny-template" 2>&1 | head -40
        echo "## failed units"
        systemctl --failed --no-pager
        echo "## errors"
        journalctl -p err -b --no-pager | tail -200
        echo "## memory"
        free -h
        echo "## disks"
        df -h
        echo "## graphics"
        lspci -k | grep -A3 -E 'VGA|3D|Display'
      '';
    in
    {
      config = lib.mkIf (cfg.enable && cfg.harness == "opencode") {
        home.packages = [ troubleshoot ];
        home.file.".config/opencode/AGENTS.md".text = cfg.systemPrompt;

        programs.opencode = {
          enable = true;
          settings = {
            provider.${providerId} = {
              npm = "@ai-sdk/openai-compatible";
              name = "Ojuny local";
              options.baseURL = baseUrl;
              models.${cfg.modelId} = {
                name = cfg.modelId;
                limit = {
                  context = cfg.contextSize;
                  output = 8192;
                };
              };
            };
            model = "${providerId}/${cfg.modelId}";
            small_model = "${providerId}/${cfg.modelId}";
            autoupdate = false;
            instructions = [ "~/.config/opencode/AGENTS.md" ];
            lsp = lib.filterAttrs (name: _: lib.elem name cfg.lspServers) lspConfig;
            agent = cfg.agents // {
              troubleshoot = {
                description = "Diagnose Ojuny and NixOS problems with the local CLI.";
                mode = "subagent";
                prompt = cfg.troubleshootingPrompt;
                permission = {
                  edit = "deny";
                  bash = "ask";
                };
              };
            };
          };
        };
      };
    };
}
