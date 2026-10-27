name: Development
id: patch-development
description: VSCodium, per-language LSP toggles, optional coding agents, and pinned project scaffolding
dependencies:
version: 2

## Install, enable, remove

```sh
ojuny-patches sync
ojuny-patches install patch-development
```

Installation copies one Nix module and enables nothing. Open the settings GUI, go to Patches, turn on Development, choose languages, editor, agents, and projects, then rebuild.

To remove, turn Development off, rebuild, run `ojuny-patches remove patch-development`, and rebuild again. Removing the file while the switch is still on leaves an option set without a declaration and fails evaluation.

## Languages

Each language row installs its LSP server, formatter, VSCodium extension when one exists, and OpenCode LSP entry. Defaults: Nix, Python, Rust, C, C++, Bash. Go, TypeScript, Lua, YAML, JSON, and Markdown are opt-in.

## Editor

VSCodium uses the `nix` profile as the default launcher. The profile is themed by Stylix. Extensions and settings are selected from the language table.

## Coding agents

No agent is in the base image. OpenCode is the default agent for this patch. Claude Code, Codex, and Gemini CLI are opt-in. `ojuny-agent` launches the selected default. `ojuny-agent-usage` is installed only when Claude Code or Codex is enabled and uses `ccusage`; OpenCode usage is not collected by this patch.

## Projects

`projects` opens a repository picker. It runs the project shell first when `flake.nix` or `shell.nix` exists, then launches the configured editor command.

`ojuny-devshell-new <language> [directory]` writes a `flake.nix` pinned to the host nixpkgs revision, with the runtime, LSP, and formatter for that language. Then run:

```sh
cd <directory>
nix flake lock
nix develop
```

Update the project runtime with `nix flake update`, not with a host-global runtime manager.
