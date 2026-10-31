#!/usr/bin/env bash
# Regression check for the patch-development project picker.
#
# Extracts the projects script from the module, stubs dms and nix on PATH, and
# asserts the repository list, the action list and the devshell invocation.
# Needs no nix evaluation and no running DMS shell.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_file="$repo_root/modules/patches/patch-development.nix"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

mapfile -t lines < "$source_file"
start=-1
end=-1
for i in "${!lines[@]}"; do
  if [[ "${lines[$i]}" == *'writeShellScriptBin "projects" '* ]]; then
    start=$i
  elif (( start >= 0 )) && [[ "${lines[$i]}" == "      '';" ]]; then
    end=$i
    break
  fi
done
(( start >= 0 && end > start )) || fail "could not locate the projects script in $source_file"

body=()
skipping_path=0
for ((i = start + 1; i < end; i++)); do
  line=${lines[$i]}
  if [[ "$line" == *'export PATH=${'* ]]; then
    [[ "$line" == *'}:"$PATH"'* ]] || skipping_path=1
    continue
  fi
  if (( skipping_path )); then
    [[ "$line" == *'}:"$PATH"'* ]] && skipping_path=0
    continue
  fi
  body+=("$line")
done

script=$(printf '%s\n' "${body[@]}")
script=${script//"''\${"/'${'}
repos="$tmp/repos"
script=${script//'${cfg.projects.searchRoot}'/$repos}
script=${script//'${lib.escapeShellArg cfg.projects.editorCommand}'/editor-stub}
script=${script//'${lib.escapeShellArg cfg.projects.terminalCommand}'/terminal-stub}
script=${script//'${lib.escapeShellArg cfg.projects.assistantCommand}'/assistant-stub}
[[ "$script" != *'${cfg.'* && "$script" != *'${lib.'* ]] || fail "unresolved Nix interpolation in the extracted script"

mkdir -p "$tmp/bin" "$tmp/empty" "$repos/alpha/.git" "$repos/beta/.git"
printf '{ }\n' > "$repos/alpha/flake.nix"

cat > "$tmp/bin/dms" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
cat >> "$DMS_LOG"
if grep -aqx 'Open in editor' "$DMS_LOG"; then
  printf '%s\n' 'Open in editor'
  exit 0
fi
printf '%s\n' "$PICKER_REPO"
STUB

cat > "$tmp/bin/nix" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$NIX_LOG"
if [[ "${1:-}" == develop && "${2:-}" == -c ]]; then
  shift 2
  "$@"
fi
STUB

for name in editor-stub terminal-stub assistant-stub; do
  cat > "$tmp/bin/$name" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB_LOG"
STUB
done

chmod +x "$tmp/bin"/*
printf '#!%s\n%s\n' "$(command -v bash)" "$script" > "$tmp/projects"
chmod +x "$tmp/projects"

export DMS_LOG="$tmp/dms.log"
export NIX_LOG="$tmp/nix.log"
export STUB_LOG="$tmp/stub.log"
export PICKER_REPO="$repos/alpha"
: > "$DMS_LOG"
: > "$NIX_LOG"
: > "$STUB_LOG"

PATH="$tmp/bin:$PATH" "$tmp/projects"

grep -aqF 'alpha  [no-git]  no commits' "$DMS_LOG" || fail "repository list is missing alpha with branch and commit metadata"
grep -aqF 'beta  [no-git]  no commits' "$DMS_LOG" || fail "repository list is missing beta with branch and commit metadata"

for action in 'Open in editor' 'Open terminal' 'Start agent' 'Open Obsidian vault' 'Cancel'; do
  grep -aqx -- "$action" "$DMS_LOG" || fail "action list is missing: $action"
done

grep -aqF 'develop -c true' "$NIX_LOG" || fail "the picker did not probe the repository devshell"
grep -aqF "develop -c editor-stub -n $repos/alpha" "$NIX_LOG" || fail "the chosen action did not run through nix develop -c"
grep -aqF -- "-n $repos/alpha" "$STUB_LOG" || fail "the editor was not started in the selected repository"

if PATH="$tmp/empty" "$tmp/projects" >"$tmp/nodms.out" 2>&1; then
  fail "projects should refuse to start without dms"
fi
grep -qF 'dms is required' "$tmp/nodms.out" || fail "the missing-dms error was not printed"

printf 'ok: the project picker lists repositories and actions and runs the chosen action in the devshell\n'
