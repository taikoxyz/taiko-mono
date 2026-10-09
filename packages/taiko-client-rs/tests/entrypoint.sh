#!/bin/bash
#
# Runs the abci docker integration scenarios (`crates/abci/tests`, all marked
# `#[ignore = "docker"]`). Each scenario boots its own devnet through the docker CLI
# (`crates/test-harness`: anvil as L1, alethia-reth, CometBFT) and removes it
# afterwards, so this script only checks docker, pre-pulls the images and runs the
# scenarios one at a time. Extra arguments are forwarded to `cargo nextest run`,
# e.g. `just test --no-capture` or `just test restart` (a test-name filter).
#
# Environment:
#   ANVIL_IMAGE, ALETHIA_RETH_IMAGE, COMETBFT_IMAGE  override the images.
#   PULL_POLICY=missing  reuse images already present on the daemon instead of
#                        pulling the (moving) tags on every run.

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run from the package root so the nextest config and the workspace resolve
# regardless of the caller's working directory.
cd "$DIR/.."

if ! command -v docker > /dev/null 2>&1; then
    echo "ERROR: required command 'docker' not found in PATH"
    exit 1
fi
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: the docker daemon is not reachable"
    exit 1
fi

export ANVIL_IMAGE=${ANVIL_IMAGE:-ghcr.io/foundry-rs/foundry:stable}
# Built from taikoxyz/alethia-reth#248; switch back to `alethia-reth:main` when that
# PR merges.
export ALETHIA_RETH_IMAGE=${ALETHIA_RETH_IMAGE:-us-docker.pkg.dev/evmchain/images/alethia-reth:sha-1e25b48}
export COMETBFT_IMAGE=${COMETBFT_IMAGE:-cometbft/cometbft:v0.40.0}

# Pull before the first scenario so downloads don't eat into its readiness deadlines.
for image in "$ANVIL_IMAGE" "$ALETHIA_RETH_IMAGE" "$COMETBFT_IMAGE"; do
    if [[ "${PULL_POLICY:-always}" == "missing" ]] && docker image inspect "$image" > /dev/null 2>&1; then
        echo "Using local image $image"
    else
        echo "Pulling $image"
        docker pull --quiet "$image"
    fi
done

echo "Running the abci docker scenarios"
cargo nextest run -p abci --all-features --profile integration --run-ignored only -E 'kind(test)' "$@"
