#!/bin/bash
#
# Runs the ABCI, lander, and CLI docker scenarios (all marked
# `#[ignore = "docker"]`). Each scenario boots its own devnet through the docker CLI
# (`crates/test-harness`: anvil as L1, alethia-reth, CometBFT) and removes it
# afterwards, so this script only checks docker, pre-pulls the images and runs the
# scenarios one at a time. Extra arguments are forwarded to `cargo nextest run`,
# e.g. `just test --no-capture` or `just test restart` (a test-name filter).
#
# Environment:
#   ANVIL_IMAGE, LANDER_ANVIL_IMAGE, ALETHIA_RETH_IMAGE, COMETBFT_IMAGE override the images.
#   PULL_POLICY=missing  reuse images already present on the daemon instead of
#                        pulling them on every run.

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run from the package root so the nextest config and the workspace resolve
# regardless of the caller's working directory.
cd "$DIR/.."

# Every harness child inherits this label. Cleanup stays scoped to this invocation, including
# lander fixtures, even when cancellation bypasses the harness's normal Drop cleanup.
export TAIKO_CLIENT_RS_TEST_RUN=${TAIKO_CLIENT_RS_TEST_RUN:-local-$$-$RANDOM}
cleanup_devnets() {
    local status=$?
    trap - EXIT INT TERM
    local failed=0
    local containers networks
    containers=$(docker ps -aq --filter "label=taiko-client-rs.test-run=$TAIKO_CLIENT_RS_TEST_RUN") || failed=1
    networks=$(docker network ls -q --filter "label=taiko-client-rs.test-run=$TAIKO_CLIENT_RS_TEST_RUN") || failed=1
    if [[ -n "$containers" ]]; then
        # Docker IDs contain no shell whitespace; xargs handles both Linux and macOS empty input.
        printf '%s\n' "$containers" | xargs docker rm -f -v || failed=1
    fi
    if [[ -n "$networks" ]]; then
        printf '%s\n' "$networks" | xargs docker network rm || failed=1
    fi
    if [[ "$status" == 0 && "$failed" != 0 ]]; then status=1; fi
    exit "$status"
}

if ! command -v docker > /dev/null 2>&1; then
    echo "ERROR: required command 'docker' not found in PATH"
    exit 1
fi
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: the docker daemon is not reachable"
    exit 1
fi
trap cleanup_devnets EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Pinned to the anvil release the scenarios are verified with: a moving tag could change its
# JSON-RPC behaviour under them (e.g. whether it serves debug_getRawHeader).
export ANVIL_IMAGE=${ANVIL_IMAGE:-ghcr.io/foundry-rs/foundry:v1.5.1}
# Built from taikoxyz/alethia-reth#248; switch back to `alethia-reth:main` when that
# PR merges.
# Real contracts require canonical zero-storage proofs and modern EIP-7594 wrappers.
export LANDER_ANVIL_IMAGE=${LANDER_ANVIL_IMAGE:-ghcr.io/foundry-rs/foundry:v1.8.5}
export ALETHIA_RETH_IMAGE=${ALETHIA_RETH_IMAGE:-us-docker.pkg.dev/evmchain/images/alethia-reth:sha-1e25b48}
export COMETBFT_IMAGE=${COMETBFT_IMAGE:-cometbft/cometbft:v0.40.0}

# Pull before the first scenario so downloads don't eat into its readiness deadlines.
for image in "$ANVIL_IMAGE" "$LANDER_ANVIL_IMAGE" "$ALETHIA_RETH_IMAGE" "$COMETBFT_IMAGE"; do
    if [[ "${PULL_POLICY:-always}" == "missing" ]] && docker image inspect "$image" > /dev/null 2>&1; then
        echo "Using local image $image"
    else
        echo "Pulling $image"
        docker pull --quiet "$image"
    fi
done

echo "Running the ABCI, lander, and CLI docker scenarios"
terminate_tree() {
    local process=$1 child
    for child in $(pgrep -P "$process" || true); do
        terminate_tree "$child"
    done
    kill -TERM "$process" 2>/dev/null || true
}
stop_scenarios() {
    local status=$1
    trap - INT TERM
    terminate_tree "$scenario_pid"
    wait "$scenario_pid" || true
    exit "$status"
}
cargo nextest run -p abci -p lander -p taiko-client -p test-harness --all-features --profile integration --run-ignored only -E 'kind(test)' "$@" &
scenario_pid=$!
trap 'stop_scenarios 130' INT
trap 'stop_scenarios 143' TERM
wait "$scenario_pid"
