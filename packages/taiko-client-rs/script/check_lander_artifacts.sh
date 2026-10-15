#!/usr/bin/env bash
# Check that script/gen_lander_artifacts.sh, run on the pinned protocol revision, reproduces the
# committed lander contract fixtures, the IEtnaInbox interface copy and the shared Etna vectors
# (testdata/etna_vectors) byte for byte.
#
# The pinned revision is checked out in a temporary git worktree (fetched from origin when it is
# not local). Needs the Foundry release that generated the fixtures (manifest.json
# `foundryVersion`), pnpm and python3; `pnpm install` needs the network unless PNPM_OFFLINE=1
# with a warm pnpm store.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(git -C "$CLIENT_DIR" rev-parse --show-toplevel)"
REVISION="$(sed -n 's/^PINNED_REVISION=//p' "$SCRIPT_DIR/gen_lander_artifacts.sh")"
MANIFEST="$CLIENT_DIR/crates/lander/tests/fixtures/contracts/manifest.json"
GENERATED=(
    packages/taiko-client-rs/crates/lander/tests/fixtures/contracts
    packages/taiko-client-rs/crates/lander/contracts
    testdata/etna_vectors
)

expected_forge="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["foundryVersion"][0])' "$MANIFEST")"
actual_forge="$(forge --version | head -n 1)"
if [[ "$actual_forge" != "$expected_forge" ]]; then
    echo "the fixtures were generated with '$expected_forge'; found '$actual_forge'" >&2
    exit 1
fi
if [[ -n "$(git -C "$REPO_ROOT" status --porcelain -- "${GENERATED[@]}")" ]]; then
    echo "commit or discard local changes to the generated files first:" >&2
    git -C "$REPO_ROOT" status --short -- "${GENERATED[@]}" >&2
    exit 1
fi

SCRATCH="$(mktemp -d)"
PROTOCOL="$SCRATCH/protocol"
cleanup() {
    git -C "$REPO_ROOT" worktree remove --force "$PROTOCOL" >/dev/null 2>&1 || true
    rm -rf "$SCRATCH"
}
trap cleanup EXIT

if ! git -C "$REPO_ROOT" cat-file -e "$REVISION^{commit}" 2>/dev/null; then
    git -C "$REPO_ROOT" fetch --quiet --no-tags --depth=1 origin "$REVISION"
fi
git -C "$REPO_ROOT" worktree add --quiet --detach "$PROTOCOL" "$REVISION"
"$SCRIPT_DIR/gen_lander_artifacts.sh" "$PROTOCOL"

if [[ -n "$(git -C "$REPO_ROOT" status --porcelain -- "${GENERATED[@]}")" ]]; then
    echo "gen_lander_artifacts.sh on $REVISION does not reproduce the committed files:" >&2
    git -C "$REPO_ROOT" status --short -- "${GENERATED[@]}" >&2
    git -C "$REPO_ROOT" --no-pager diff --stat -- "${GENERATED[@]}" >&2
    exit 1
fi
echo "lander artifacts and Etna vectors reproduce from $REVISION"
