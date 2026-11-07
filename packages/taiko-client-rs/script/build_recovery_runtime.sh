#!/usr/bin/env bash
# Build the complete controller/native-role Linux runtime used by the UID boundary scenario.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../../.."
image=${ETNA_RECOVERY_IMAGE:?ETNA_RECOVERY_IMAGE must name this run image}
context=$(mktemp -d)
trap 'rm -rf "$context"' EXIT
# Only this package is copied by its Dockerfile. Exclude caches, .build and unrelated packages.
# Read current worktree bytes so the tested runtime includes uncommitted implementation fixes.
git ls-files -z packages/taiko-client-rs | tar --null -T - -cf - | tar -xf - -C "$context"
arch=$(docker info --format '{{.Architecture}}')
case "$arch" in aarch64|arm64) arch=arm64 ;; x86_64|amd64) arch=amd64 ;; *) exit 1 ;; esac
set --
if [[ -n "${ETNA_BUILD_TARGET:-}" ]]; then
    set -- --target "$ETNA_BUILD_TARGET"
fi
docker build --platform "linux/$arch" -f "$context/packages/taiko-client-rs/Dockerfile" \
    "$@" --label "taiko-client-rs.test-run=${TAIKO_CLIENT_RS_TEST_RUN:?owned run label}" -t "$image" "$context"
