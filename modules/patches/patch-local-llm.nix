/*
  @menu
  displayname = "Local LLM";
  icon = "applications-science-symbolic";
  order = 140;
  description = "Local model server, optional chat client and Nix-managed agent harness";
  category = "Patches";
  systems = [ "all" ];
*/

{ self, ... }: {

  flake.modules.nixos.patch-local-llm =
    { config, lib, ... }:
    {
      options.ojuny.patch.local-llm.enable = lib.mkEnableOption "the local LLM patch";

      # @option widget = "switch"; label = "Local LLM"; group = "Local LLM"; description = "Run a local model server. The patch is off by default.";
      config.ojuny.patch.local-llm.enable = false;

      imports = [ self.modules.nixos.local-llm-backend ];

      config.home-manager.sharedModules = lib.mkIf (
        config.ojuny.patch.local-llm.enable && (config.ojuny.patches or true)
      ) [ self.modules.homeManager.local-llm-backend ];
    };

  flake.modules.nixos.local-llm-backend =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.ojuny.patch.local-llm;
      active = cfg.enable && (config.ojuny.patches or true);

      modelSpecs = {
        gemma4-e2b = {
          name = "gemma-4-E2B-it";
          repo = "unsloth/gemma-4-E2B-it-GGUF";
          file = "gemma-4-E2B-it-Q4_K_M.gguf";
          hash = "sha256-dAGFsh0izrg6EcOqYq1YQu8yxw9gltdWu+6FoeTsNLg=";
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
          hash = "sha256-OL1kyFLEtGBDTMcWL6m9zyQvr4ZQJYGnVMtylWuxf4Q=";
          ollama = "gemma4:31b";
        };
      };

      preset = modelSpecs.${cfg.model};

      modelName =
        if cfg.modelName != null then
          cfg.modelName
        else if cfg.modelPath != null then
          lib.removeSuffix ".gguf" (baseNameOf cfg.modelPath)
        else
          preset.name;

      ollamaModel = if cfg.ollamaModel != null then cfg.ollamaModel else preset.ollama;

      modelFile =
        if cfg.modelPath != null then
          cfg.modelPath
        else
          pkgs.fetchurl {
            url = "https://huggingface.co/${preset.repo}/resolve/main/${preset.file}";
            hash = preset.hash;
          };

      modelId = if cfg.backend == "ollama" then ollamaModel else modelName;

      isLlama = cfg.backend == "llama-cpp" || cfg.backend == "llama-cpp-turbo";

      modelsIni = pkgs.writeText "ojuny-models.ini" ''
        version = 1
        [${modelName}]
        model = ${modelFile}
        load-on-startup = ${if cfg.preloadModels then "true" else "false"}
      '';

      templateGpu = config.ojuny.gpu or null;

      detectedAcceleration =
        if
          builtins.elem templateGpu [
            "nvidia"
            "hybrid-intel-nvidia"
            "hybrid-amd-nvidia"
          ]
        then
          "cuda"
        else if templateGpu == "amd" then
          "rocm"
        else if templateGpu == "intel" then
          "vulkan"
        else if templateGpu == "none" then
          "cpu"
        else if builtins.elem "nvidia" (config.services.xserver.videoDrivers or [ ]) then
          "cuda"
        else if
          builtins.any (
            driver:
            builtins.elem driver [
              "amdgpu"
              "radeon"
            ]
          ) (config.services.xserver.videoDrivers or [ ])
        then
          "rocm"
        else
          "cpu";

      acceleration = if cfg.acceleration == "auto" then detectedAcceleration else cfg.acceleration;

      effectivePort =
        if cfg.port != null then
          cfg.port
        else if cfg.backend == "ollama" then
          11434
        else
          8080;

      connectHost =
        if cfg.host == "0.0.0.0" then
          "127.0.0.1"
        else if cfg.host == "::" then
          "::1"
        else
          cfg.host;

      baseUrl = "http://${connectHost}:${toString effectivePort}/v1";

      llamaBase = pkgs.llama-cpp.override {
        cudaSupport = acceleration == "cuda";
        rocmSupport = acceleration == "rocm";
        vulkanSupport = acceleration == "vulkan";
        cpuArchDynamicDispatch = false;
      };

      llamaTurbo = llamaBase.overrideAttrs (previous: {
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

      llamaPackage = if cfg.backend == "llama-cpp-turbo" then llamaTurbo else llamaBase;

      ollamaPackage =
        {
          cpu = pkgs.ollama-cpu;
          cuda = pkgs.ollama-cuda;
          rocm = pkgs.ollama-rocm;
          vulkan = pkgs.ollama-vulkan;
        }
        .${acceleration};
    in
    {
      options.ojuny.patch.local-llm = {
        backend = lib.mkOption {
          type = lib.types.enum [
            "llama-cpp"
            "llama-cpp-turbo"
            "ollama"
          ];
          default = "llama-cpp";
          description = "Model server implementation. llama-cpp tracks nixpkgs; llama-cpp-turbo uses the pinned turboquant fork; ollama uses the Ollama service.";
        };

        model = lib.mkOption {
          type = lib.types.enum [
            "gemma4-e2b"
            "gemma4-e4b"
            "gemma4-31b"
          ];
          default = "gemma4-e4b";
          description = "Preset model. Ignored when modelPath or ollamaModel replaces the source.";
        };

        modelPath = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Local GGUF file for a llama.cpp backend. When set, the preset download and hash are skipped.";
        };

        modelName = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Model ID exposed to clients. Defaults to the preset name or the modelPath file name without .gguf.";
        };

        ollamaModel = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Ollama tag to load. Defaults to the tag from the selected preset.";
        };

        modelsDir = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Directory for Ollama models. The upstream default is /var/lib/ollama/models. Do not use a home directory that the service cannot write.";
        };

        syncModels = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Remove Ollama models that are not declared by loadModels.";
        };

        preloadModels = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Download the Ollama model or set llama.cpp load-on-startup when the server starts.";
        };

        acceleration = lib.mkOption {
          type = lib.types.enum [
            "auto"
            "cpu"
            "cuda"
            "rocm"
            "vulkan"
          ];
          default = "auto";
          description = "Backend acceleration. auto reads ojuny.gpu, then the NixOS video drivers, and falls back to cpu.";
        };

        rocmOverrideGfx = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "HSA_OVERRIDE_GFX_VERSION for Ollama on AMD cards that are not detected correctly.";
        };

        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Bind address for the model server and the chat client.";
        };

        port = lib.mkOption {
          type = lib.types.nullOr lib.types.port;
          default = null;
          description = "Model server port. Null uses 8080 for llama.cpp and 11434 for Ollama.";
        };

        contextSize = lib.mkOption {
          type = lib.types.int;
          default = 32768;
          description = "llama.cpp context size and the OpenCode model context limit. Raise only after measuring memory use.";
        };

        gpuLayers = lib.mkOption {
          type = lib.types.int;
          default = 999;
          description = "llama.cpp n-gpu-layers. Ignored by Ollama.";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Open the model server port. The server has no authentication.";
        };

        desktopClient = lib.mkOption {
          type = lib.types.enum [
            "none"
            "open-webui"
            "jan"
          ];
          default = "none";
          description = "Optional local chat client. Open WebUI is preconfigured; Jan must be configured in its own UI.";
        };

        desktopClientPort = lib.mkOption {
          type = lib.types.port;
          default = 8081;
          description = "Open WebUI port. Kept separate from the llama.cpp default of 8080.";
        };

        desktopClientOpenFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Open the Open WebUI port. The UI keeps its own authentication.";
        };

        harness = lib.mkOption {
          type = lib.types.enum [
            "opencode"
            "none"
          ];
          default = "opencode";
          description = "Home Manager coding harness. none leaves the server and chat client only.";
        };

        installLsps = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Install the selected language servers in the Home Manager profile. The development patch already provides them.";
        };

        projectDir = lib.mkOption {
          type = lib.types.str;
          default = "repos/nix-flake";
          description = "Repository under $HOME that ojuny-troubleshoot reads.";
        };

        systemPrompt = lib.mkOption {
          type = lib.types.str;
          default = "You are a NixOS assistant for this Ojuny system. Read ~/repos/nix-flake. Run ojuny-troubleshoot first for diagnostics. Never change the system unless the user explicitly asks.";
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

        modelId = lib.mkOption {
          type = lib.types.str;
          default = "";
          internal = true;
        };

        effectiveAcceleration = lib.mkOption {
          type = lib.types.enum [
            "cpu"
            "cuda"
            "rocm"
            "vulkan"
          ];
          default = "cpu";
          internal = true;
        };
      };

      config = lib.mkMerge [
        {
          # @option widget = "dropdown"; label = "Backend"; group = "Local LLM"; choices = [ "llama-cpp" "llama-cpp-turbo" "ollama" ]; visibleWhen.path = "ojuny.patch.local-llm.enable"; visibleWhen.equals = true; description = "llama-cpp is the stable nixpkgs package. llama-cpp-turbo uses the pinned turboquant fork. ollama uses the Ollama service.";
          ojuny.patch.local-llm.backend = "llama-cpp";

          # @option widget = "dropdown"; label = "Model"; group = "Local LLM"; choices = [ "gemma4-e2b" "gemma4-e4b" "gemma4-31b" ]; visibleWhen.path = "ojuny.patch.local-llm.enable"; visibleWhen.equals = true; description = "Preset model. Use the Model group to override the file or the Ollama tag.";
          ojuny.patch.local-llm.model = "gemma4-e4b";

          # @option widget = "path"; label = "Local GGUF"; group = "Model"; nullable = true; visibleWhen.path = "ojuny.patch.local-llm.enable"; visibleWhen.equals = true; description = "Use a local GGUF file for a llama.cpp backend instead of the preset download.";
          ojuny.patch.local-llm.modelPath = null;

          # @option widget = "text"; label = "Model ID"; group = "Model"; nullable = true; visibleWhen.path = "ojuny.patch.local-llm.enable"; visibleWhen.equals = true; description = "Model ID exposed to clients. Defaults to the preset name or the local file name.";
          ojuny.patch.local-llm.modelName = null;

          # @option widget = "text"; label = "Ollama tag"; group = "Model"; nullable = true; placeholder = "gemma4:e4b"; visibleWhen.path = "ojuny.patch.local-llm.backend"; visibleWhen.equals = "ollama"; description = "Any tag from the Ollama library. Overrides the preset tag.";
          ojuny.patch.local-llm.ollamaModel = null;

          # @option widget = "text"; label = "Ollama models directory"; group = "Model"; nullable = true; placeholder = "/var/lib/ollama/models"; visibleWhen.path = "ojuny.patch.local-llm.backend"; visibleWhen.equals = "ollama"; description = "Where Ollama stores models. Use a path the service can write.";
          ojuny.patch.local-llm.modelsDir = null;

          # @option widget = "switch"; label = "Sync Ollama models"; group = "Model"; visibleWhen.path = "ojuny.patch.local-llm.backend"; visibleWhen.equals = "ollama"; description = "Remove installed Ollama models that are not declared by this patch.";
          ojuny.patch.local-llm.syncModels = false;

          # @option widget = "switch"; label = "Preload model"; group = "Model"; visibleWhen.path = "ojuny.patch.local-llm.enable"; visibleWhen.equals = true; description = "Download the Ollama model or mark the llama.cpp model load-on-startup.";
          ojuny.patch.local-llm.preloadModels = true;

          # @option widget = "dropdown"; label = "Acceleration"; group = "Server"; choices = [ "auto" "cpu" "cuda" "rocm" "vulkan" ]; visibleWhen.path = "ojuny.patch.local-llm.enable"; visibleWhen.equals = true; description = "auto reads ojuny.gpu, then the NixOS video drivers, and falls back to cpu.";
          ojuny.patch.local-llm.acceleration = "auto";

          # @option widget = "text"; label = "ROCm GFX override"; group = "Server"; nullable = true; placeholder = "10.3.0"; visibleWhen.path = "ojuny.patch.local-llm.acceleration"; visibleWhen.equals = "rocm"; description = "HSA_OVERRIDE_GFX_VERSION for Ollama on AMD cards that are not detected correctly.";
          ojuny.patch.local-llm.rocmOverrideGfx = null;

          # @option widget = "text"; label = "Host"; group = "Server"; visibleWhen.path = "ojuny.patch.local-llm.enable"; visibleWhen.equals = true; description = "Bind address for the model server and the chat client.";
          ojuny.patch.local-llm.host = "127.0.0.1";

          # @option widget = "spin"; label = "Port"; group = "Server"; nullable = true; placeholder = "auto"; min = 1; max = 65535; visibleWhen.path = "ojuny.patch.local-llm.enable"; visibleWhen.equals = true; description = "Null uses 8080 for llama.cpp and 11434 for Ollama.";
          ojuny.patch.local-llm.port = null;

          # @option widget = "spin"; label = "Context size"; group = "Server"; min = 1024; max = 262144; step = 1024; visibleWhen.path = "ojuny.patch.local-llm.enable"; visibleWhen.equals = true; description = "llama.cpp context and the OpenCode model context limit.";
          ojuny.patch.local-llm.contextSize = 32768;

          # @option widget = "spin"; label = "GPU layers"; group = "Server"; min = 0; max = 999; visibleWhen.path = "ojuny.patch.local-llm.enable"; visibleWhen.equals = true; description = "llama.cpp n-gpu-layers. Ignored by Ollama.";
          ojuny.patch.local-llm.gpuLayers = 999;

          # @option widget = "switch"; label = "Open firewall"; group = "Server"; visibleWhen.path = "ojuny.patch.local-llm.enable"; visibleWhen.equals = true; description = "Open the model server port. The server has no authentication.";
          ojuny.patch.local-llm.openFirewall = false;

          # @option widget = "dropdown"; label = "Chat client"; group = "Chat client"; choices = [ "none" "open-webui" "jan" ]; visibleWhen.path = "ojuny.patch.local-llm.enable"; visibleWhen.equals = true; description = "Open WebUI is preconfigured. Jan must be configured in its own UI.";
          ojuny.patch.local-llm.desktopClient = "none";

          # @option widget = "spin"; label = "Open WebUI port"; group = "Chat client"; min = 1; max = 65535; visibleWhen.path = "ojuny.patch.local-llm.desktopClient"; visibleWhen.equals = "open-webui"; description = "Kept separate from the llama.cpp default of 8080.";
          ojuny.patch.local-llm.desktopClientPort = 8081;

          # @option widget = "switch"; label = "Open chat client firewall"; group = "Chat client"; visibleWhen.path = "ojuny.patch.local-llm.desktopClient"; visibleWhen.equals = "open-webui"; description = "Open the Open WebUI port. The UI keeps its own authentication.";
          ojuny.patch.local-llm.desktopClientOpenFirewall = false;

          # @option widget = "dropdown"; label = "Harness"; group = "Harness"; choices = [ "opencode" "none" ]; visibleWhen.path = "ojuny.patch.local-llm.enable"; visibleWhen.equals = true; description = "OpenCode provider or server only.";
          ojuny.patch.local-llm.harness = "opencode";

          # @option widget = "switch"; label = "Install LSP servers"; group = "Harness"; visibleWhen.path = "ojuny.patch.local-llm.harness"; visibleWhen.equals = "opencode"; description = "Add the selected language servers to the Home Manager profile. The development patch already provides them.";
          ojuny.patch.local-llm.installLsps = false;

          # @option widget = "text"; label = "Repository"; group = "Harness"; visibleWhen.path = "ojuny.patch.local-llm.harness"; visibleWhen.equals = "opencode"; description = "Repository under $HOME that ojuny-troubleshoot reads.";
          ojuny.patch.local-llm.projectDir = "repos/nix-flake";

          # @option widget = "raw"; label = "System prompt"; group = "Harness"; rows = 8; visibleWhen.path = "ojuny.patch.local-llm.harness"; visibleWhen.notEquals = "none";
          ojuny.patch.local-llm.systemPrompt = "You are a NixOS assistant for this Ojuny system. Read ~/repos/nix-flake. Run ojuny-troubleshoot first for diagnostics. Never change the system unless the user explicitly asks.";

          # @option widget = "raw"; label = "Troubleshooting prompt"; group = "Harness"; rows = 6; visibleWhen.path = "ojuny.patch.local-llm.harness"; visibleWhen.equals = "opencode";
          ojuny.patch.local-llm.troubleshootingPrompt = "You diagnose Ojuny and NixOS. Run ojuny-troubleshoot first. Read the Nix configuration. Report findings and a minimal fix. Do not edit files or change the system.";

          # @option widget = "list"; label = "LSP servers"; group = "Harness"; visibleWhen.path = "ojuny.patch.local-llm.harness"; visibleWhen.equals = "opencode";
          ojuny.patch.local-llm.lspServers = [
            "nixd"
            "rust-analyzer"
            "pyright"
            "typescript"
            "gopls"
            "clangd"
          ];

          # @option widget = "raw"; label = "Agents"; group = "Harness"; advanced = true; rows = 10; visibleWhen.path = "ojuny.patch.local-llm.harness"; visibleWhen.equals = "opencode";
          ojuny.patch.local-llm.agents = { };

          ojuny.patch.local-llm.modelId = modelId;
          ojuny.patch.local-llm.effectiveAcceleration = acceleration;
        }
        (lib.mkIf active {
          assertions = [
            {
              assertion = isLlama || cfg.modelPath == null;
              message = "ojuny.patch.local-llm.modelPath is only supported by the llama.cpp backends.";
            }
            {
              assertion = cfg.ollamaModel != "" && cfg.modelName != "";
              message = "ojuny.patch.local-llm model overrides must not be empty strings.";
            }
            {
              assertion = !(cfg.desktopClient == "open-webui" && cfg.desktopClientPort == effectivePort);
              message = "ojuny.patch.local-llm.desktopClientPort must differ from the model server port.";
            }
          ];

          services.llama-cpp = lib.mkIf isLlama {
            enable = true;
            package = llamaPackage;
            openFirewall = cfg.openFirewall;
            settings = {
              host = cfg.host;
              port = effectivePort;
              ctx-size = cfg.contextSize;
              n-gpu-layers = cfg.gpuLayers;
              flash-attn = "on";
              sleep-idle-seconds = 60;
              models-preset = modelsIni;
              models-max = 1;
            }
            // lib.optionalAttrs (cfg.backend == "llama-cpp-turbo") {
              cache-type-k = "q8_0";
              cache-type-v = "turbo4";
            };
          };

          services.ollama = lib.mkIf (cfg.backend == "ollama") (
            {
              enable = true;
              package = ollamaPackage;
              host = cfg.host;
              port = effectivePort;
              loadModels = lib.optional cfg.preloadModels ollamaModel;
              syncModels = cfg.syncModels;
              rocmOverrideGfx = cfg.rocmOverrideGfx;
              openFirewall = cfg.openFirewall;
            }
            // lib.optionalAttrs (cfg.modelsDir != null) {
              modelsDir = cfg.modelsDir;
            }
          );

          services.open-webui = lib.mkIf (cfg.desktopClient == "open-webui") {
            enable = true;
            host = cfg.host;
            port = cfg.desktopClientPort;
            openFirewall = cfg.desktopClientOpenFirewall;
            environment = {
              ENABLE_OLLAMA_API = if cfg.backend == "ollama" then "True" else "False";
              OLLAMA_BASE_URL = "http://${connectHost}:${toString effectivePort}";
              ENABLE_OPENAI_API = if cfg.backend == "ollama" then "False" else "True";
              OPENAI_API_BASE_URL = baseUrl;
              OPENAI_API_KEY = "local";
            };
          };

          environment.systemPackages = lib.optionals (cfg.desktopClient == "jan") [ pkgs.jan ];
        })
      ];
    };

  flake.modules.homeManager.local-llm-backend =
    {
      lib,
      pkgs,
      osConfig ? { },
      ...
    }:
    let
      fallback = {
        enable = false;
        backend = "llama-cpp";
        harness = "none";
        modelId = "local";
        host = "127.0.0.1";
        port = null;
        contextSize = 32768;
        installLsps = false;
        projectDir = "repos/nix-flake";
        systemPrompt = "";
        troubleshootingPrompt = "";
        lspServers = [ ];
        agents = { };
      };

      cfg = fallback // (osConfig.ojuny.patch.local-llm or { });
      active = cfg.enable && (osConfig.ojuny.patches or true);

      effectivePort =
        if cfg.port != null then
          cfg.port
        else if cfg.backend == "ollama" then
          11434
        else
          8080;

      connectHost =
        if cfg.host == "0.0.0.0" then
          "127.0.0.1"
        else if cfg.host == "::" then
          "::1"
        else
          cfg.host;

      providerId = "ojuny-local";
      baseUrl = "http://${connectHost}:${toString effectivePort}/v1";

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

      lspPackages = {
        nixd = [
          pkgs.nixd
          pkgs.nixfmt
        ];
        rust-analyzer = [ pkgs.rust-analyzer ];
        pyright = [ pkgs.pyright ];
        typescript = [
          pkgs.typescript-language-server
          pkgs.typescript
        ];
        gopls = [ pkgs.gopls ];
        clangd = [ pkgs.clang-tools ];
      };

      selectedLspPackages = lib.unique (lib.concatMap (name: lspPackages.${name}) cfg.lspServers);

      troubleshoot = pkgs.writeShellScriptBin "ojuny-troubleshoot" ''
        set -euo pipefail
        echo "## system"
        nixos-version
        uname -a
        echo "## nix"
        nix flake metadata "''${OJUNY_REPO_PATH:-$HOME/${cfg.projectDir}}" 2>&1 | head -40
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
      config = lib.mkIf (active && cfg.harness == "opencode") {
        home.packages = [
          troubleshoot
          pkgs.pciutils
        ]
        ++ lib.optionals cfg.installLsps selectedLspPackages;

        home.file.".config/opencode/ojuny-local-llm.md".text = cfg.systemPrompt;

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
            model = lib.mkDefault "${providerId}/${cfg.modelId}";
            small_model = lib.mkDefault "${providerId}/${cfg.modelId}";
            autoupdate = lib.mkDefault false;
            instructions = lib.mkDefault [ "~/.config/opencode/ojuny-local-llm.md" ];
            lsp = lib.mkDefault (lib.filterAttrs (name: _: lib.elem name cfg.lspServers) lspConfig);
            agent = lib.mkDefault (
              cfg.agents
              // {
                troubleshoot = {
                  description = "Diagnose Ojuny and NixOS problems with the local CLI.";
                  mode = "subagent";
                  prompt = cfg.troubleshootingPrompt;
                  permission = {
                    edit = "deny";
                    bash = "ask";
                  };
                };
              }
            );
          };
        };
      };
    };
}
