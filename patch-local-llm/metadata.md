name: Local LLM
id: patch-local-llm
description: Local model server, optional chat client and Nix-managed OpenCode harness
dependencies:
version: 1

# Local LLM

This patch runs a local model server and optionally adds an OpenCode harness and
a local chat client. It is off by default. It installs no agent and no AI
application into the base image.

## What this patch installs

- A llama.cpp server using the stable nixpkgs package or the optional
  `llama-cpp-turboquant` fork.
- An Ollama server using the CPU, CUDA, ROCm, or Vulkan package.
- One Gemma 4 preset, a local GGUF file, or an Ollama model tag.
- An optional Open WebUI service on port 8081.
- An optional Jan desktop package.
- An OpenCode provider and instructions file in Home Manager when the harness is
  `opencode`.

Nothing is enabled until `ojuny.patch.local-llm.enable` is true.

## Requirements

- x86_64 Linux from the pinned nixpkgs.
- Enough disk for the model. llama.cpp model files live in the Nix store.
  Ollama models live under its state directory, by default `/var/lib/ollama`.
- Enough RAM for the model and the context cache. The default context is 32768
  tokens. Raise it only after measuring memory use.
- For GPU acceleration, a working driver for the selected backend. `auto`
  reads `ojuny.gpu` when the template provides it; otherwise it reads the
  NixOS video drivers. Override `acceleration` if the result is wrong.

## Install and enable

```
ojuny-patches sync
ojuny-patches install patch-local-llm
```

Then set the switch on the Local LLM page, or edit the installed module:

```
ojuny.patch.local-llm = {
  enable = true;
  backend = "llama-cpp";
  model = "gemma4-e4b";
};
```

The template imports every installed `patch-*` module when `ojuny.patches` is
true. The patch's own `enable` is still false until you turn it on.

## Model management

The simple path is the `model` dropdown:

| Preset | Parameters | Ollama tag |
| --- | --- | --- |
| `gemma4-e2b` | 2B effective | `gemma4:e2b` |
| `gemma4-e4b` | 4B effective | `gemma4:e4b` |
| `gemma4-31b` | 31B | `gemma4:31b` |

The preset determines the Hugging Face file and hash. Changing the preset
changes the download.

Use a local GGUF file when you already have the model:

```
ojuny.patch.local-llm.modelPath = /var/lib/models/my-model.gguf;
ojuny.patch.local-llm.modelName = "my-model";
```

`modelPath` is for the llama.cpp backends only. It is copied into the Nix store
when the configuration is evaluated. `modelName` is optional; without it the
file name without `.gguf` is used. A local path avoids the Hugging Face
download and the preset hash.

For Ollama, use `ollamaModel` to select any tag from the Ollama library:

```
ojuny.patch.local-llm.ollamaModel = "qwen3:8b";
```

`modelsDir` changes the directory where Ollama stores models. `syncModels`
removes installed models that are not declared. `preloadModels = false` stops
the automatic pull and the llama.cpp load-on-startup. The model is still
available for a manual pull or a manual load.

Removing a llama.cpp model is a garbage-collection operation: disable the
patch or change the preset, rebuild, then run `nix-collect-garbage` when no
other generation needs the file. Removing an Ollama model is either
`ollama rm <tag>` or enabling `syncModels` with a shorter declaration. A custom
`modelsDir` is not deleted by this patch.

## Server

| Backend | Default port | Endpoint |
| --- | --- | --- |
| `llama-cpp` | 8080 | `http://127.0.0.1:8080/v1` |
| `llama-cpp-turbo` | 8080 | `http://127.0.0.1:8080/v1` |
| `ollama` | 11434 | `http://127.0.0.1:11434/api` |

`port = null` selects the backend default. An explicit port overrides it.
`host` defaults to `127.0.0.1`. A wildcard host (`0.0.0.0` or `::`) is converted
to loopback for the client and harness URLs; the server still binds the wildcard.
`openFirewall` defaults to false. Opening the firewall on a non-loopback host
exposes an unauthenticated model server; only do it on a trusted network.

`contextSize` is the llama.cpp context and the OpenCode model context limit.
`gpuLayers` is the llama.cpp `n-gpu-layers` value and is ignored by Ollama.
`rocmOverrideGfx` is passed to `services.ollama.rocmOverrideGfx`.

The stable `llama-cpp` backend is the default. `llama-cpp-turbo` keeps the
turboquant source and the `q8_0`/`turbo4` cache settings. The turbo fork is
pinned by revision and can lag nixpkgs.

## Hardware detection

`acceleration = "auto"` maps `ojuny.gpu` as follows:

| GPU value | Acceleration |
| --- | --- |
| `nvidia`, `hybrid-intel-nvidia`, `hybrid-amd-nvidia` | `cuda` |
| `amd` | `rocm` |
| `intel` | `vulkan` |
| `none` | `cpu` |

Without `ojuny.gpu`, the module checks `services.xserver.videoDrivers` for
`nvidia`, `amdgpu`, or `radeon`, and falls back to `cpu`. Detection reads the
evaluated configuration; it does not probe the running machine. Override
`acceleration` if the server log shows a CPU-only run or a driver error.

## Chat client

`desktopClient = "open-webui"` enables Open WebUI on `desktopClientPort`
(default 8081). It is preconfigured for the selected backend:

- Ollama uses `OLLAMA_BASE_URL`.
- llama.cpp uses the OpenAI-compatible base URL and the placeholder API key
  `local`.

Open WebUI keeps its own authentication. Create the first admin account on
first launch. The service binds to `host` and has its own
`desktopClientOpenFirewall` switch, default false.

`desktopClient = "jan"` installs the Jan desktop package. Jan cannot be
preconfigured from Nix. In Jan, add an OpenAI-compatible provider with the base
URL from the table above and the model ID from `modelId`. Jan keeps its profile
in the user's home; removing the package does not delete that profile.

## Harness

`harness = "opencode"` writes an OpenCode provider named `ojuny-local` and
uses `modelId` as the model. The provider points at
`http://<host>:<effective-port>/v1`. The default system prompt asks the model
to read the local repository and run `ojuny-troubleshoot` first. The
troubleshooting subagent cannot edit files and must ask before shell commands.

The patch writes the prompt to
`~/.config/opencode/ojuny-local-llm.md` and adds that file to OpenCode's
`instructions`. It does not overwrite `~/.config/opencode/AGENTS.md`.

`installLsps = false` is the default because the development patch already
installs the language servers. Set it to true when this patch is used without
`patch-development`; the selected `lspServers` packages are then added to the
Home Manager profile.

`projectDir = "repos/nix-flake"` is the repository read by
`ojuny-troubleshoot`. Change it if the configuration lives elsewhere.

The Home Manager half requires the NixOS half. If it is imported without
`osConfig`, it stays inert instead of failing evaluation. A standalone Home
Manager user cannot enable the harness through this patch.

## Data and removal

- llama.cpp models are Nix store paths. They disappear only after garbage
  collection and only when no generation references them.
- Ollama models live in `modelsDir` or `/var/lib/ollama/models`. Disabling the
  patch does not delete them.
- Open WebUI state lives in `/var/lib/open-webui`. Disabling the client stops
  the service but keeps the chats and account database.
- Jan keeps its profile in the user's home. Removing the package stops new
  launches but keeps the profile.
- OpenCode configuration is generated by Home Manager. Disabling the harness
  removes the generated provider on the next activation.

To remove the patch:

1. Set `enable = false`, or remove the `ojuny.patch.local-llm` block.
2. Rebuild.
3. Run `ojuny-patches remove patch-local-llm`.
4. Confirm no `ojuny.patch.local-llm` assignment remains in the flake.
5. Optionally garbage-collect the llama.cpp model or remove the Ollama/Open
   WebUI state directories.

Removing the installed `.nix` file while an option assignment remains fails
with an unknown-option error. That is expected.

## Troubleshooting

```
systemctl status llama-cpp
systemctl status ollama
systemctl status open-webui
journalctl -u llama-cpp -b --no-pager
journalctl -u ollama -b --no-pager
curl -s http://127.0.0.1:8080/v1/models
curl -s http://127.0.0.1:11434/api/tags
curl -s http://127.0.0.1:8081/api/config
```

If the server runs on CPU unexpectedly, check `effectiveAcceleration`, then
set `acceleration` explicitly. If llama.cpp runs out of memory, lower
`contextSize` or `gpuLayers`. If Ollama does not detect an AMD card, try
`rocmOverrideGfx`. If the chat client shows no models, confirm the backend URL
and the model ID, and check that the server is listening on the configured
host.

Gemma model files are subject to the model publisher's license. The patch
downloads them from Hugging Face; it does not relicense them.
