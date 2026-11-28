#!/usr/bin/env bash
set -euo pipefail

# CI supplies the PR merge base. Local runs use the index and working tree relative to HEAD.
base=${FOUNDRY_FMT_BASE:-HEAD}
paths=('*.sol' ':!*_Layout.sol')

{
    git diff --name-only -z --relative --no-renames --diff-filter=AMT "$base" -- "${paths[@]}"
    git ls-files --others --exclude-standard -z -- "${paths[@]}"
} | while IFS= read -r -d '' path; do
    if [[ -f "$path" && ! -L "$path" ]]; then
        printf '%s\0' "$path"
    fi
done | xargs -0 bash -c 'if (( $# )); then forge fmt -- "$@"; fi' _
