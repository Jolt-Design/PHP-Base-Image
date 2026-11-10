#!/usr/bin/env bash
# PostToolUse hook: format the file Claude just edited.
#   .tf / .tofu / .tftest.hcl -> tofu fmt
#   everything else           -> biome check --write: format + lint (only if the repo
#                                has a biome.json(c)). Biome decides which file types it
#                                supports and biome.json's files.includes which files it
#                                touches; anything else is skipped silently.
# Exit 0 = fine/skipped (including formatter not installed).
# Exit 2 = formatter or lint error, stderr is shown to Claude.
set -uo pipefail

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
file="$(jq -r '.tool_input.file_path // empty' 2>/dev/null)"

[[ -z "$file" || ! -f "$file" ]] && exit 0
case "$(realpath "$file")" in
  "$(realpath "$project_dir")"/*) ;;
  *) exit 0 ;; # outside the repo
esac
cd "$project_dir" || exit 0

run() {
  local out
  if ! out="$("$@" 2>&1)"; then
    echo "format hook: '$*' failed:" >&2
    echo "$out" >&2
    exit 2
  fi
}

tofu_cmd() {
  if command -v tofu >/dev/null 2>&1; then
    echo tofu
  elif command -v terraform >/dev/null 2>&1; then
    echo terraform
  fi
}

# Prefer a repo-pinned Biome (Yarn PnP: run it through yarn), else Biome on PATH.
biome_cmd() {
  [[ -f biome.json || -f biome.jsonc ]] || return 0
  if jq -e '(.devDependencies // {}) + (.dependencies // {}) | has("@biomejs/biome")' \
    package.json >/dev/null 2>&1; then
    echo "yarn biome"
  elif command -v biome >/dev/null 2>&1; then
    echo biome
  fi
}

case "$file" in
  *.tf | *.tofu | *.tftest.hcl)
    cmd="$(tofu_cmd)"
    [[ -n "$cmd" ]] && run $cmd fmt -no-color "$file"
    ;;
  *)
    cmd="$(biome_cmd)"
    [[ -n "$cmd" ]] && run $cmd check --write --files-ignore-unknown=true --no-errors-on-unmatched "$file"
    ;;
esac

exit 0
