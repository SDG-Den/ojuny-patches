name: Development
id: patch-development
description: VSCodium, per-language LSP toggles, optional coding agents, the dmenu project picker with devshell actions, and multi-repository project scaffolding
dependencies:
version: 4

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

`SUPER+SHIFT+Tab` opens the `projects` picker. It lists git repositories under the search root with their branch and last commit, then asks for an action: editor, terminal, coding agent, Obsidian vault, or cancel. Actions run through `nix develop -c` when the repository has a `flake.nix` or `shell.nix` and the devshell evaluates. The picker needs `dms` for `dms dmenu` and refuses to start without it. `dms dmenu` has no preview flag, so there is no file preview.

`ojuny-devshell-new <language> [directory]` creates a project shell. It walks `ojuny.patch.development.scaffold.templateRepos` in ascending `priority` order and runs `nix flake init -t <url>#<template>` for the first repository with a mapping for the language. The defaults are `the-nix-way/dev-templates` at commit `9ffac48` and `NixOS/templates` at commit `3348e5b`. A repository without a mapping is skipped.

Upstream templates keep their own nixpkgs pin. When no repository matches or every repository is unreachable, the command writes the built-in `flake.nix` pinned to `ojuny.patch.development.scaffold.nixpkgsRev`. The built-in flake is the offline path and the command never fails only because the network is down. Then run:

```sh
cd <directory>
nix flake lock
nix develop
```

Update the project runtime with `nix flake update`, not with a host-global runtime manager.
