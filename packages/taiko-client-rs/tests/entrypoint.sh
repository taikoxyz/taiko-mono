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

bash ./script/build_etna_signer.sh
export ETNA_SIGNER_BIN="$PWD/target/etna-signer/etna-signer"

# Internal selectors used by the fixed `just test-smoke` and `just test-full` recipes. Shift only
# this leading flag so all remaining arguments retain their nextest meaning. By default the
# slowest scenario is left to the full run (main, nightly, `just verify`): the L1 finality stall
# needs about 1,150 L2 blocks to age past the 1152 s anchor floor. Unit tests cover its
# halt-and-resume rule.
filter='kind(test) & !test(=stale_l1_finality_pauses_and_resumes_l2)'
if [[ "${1:-}" == "--smoke" ]]; then
    shift
    filter='kind(test) & (test(=single_validator_produces_blocks_by_the_header_rules) | test(=epoch_switch_adds_the_joining_validator) | test(=four_validator_native_consensus_fees_fi_epoch_landing_and_restart) | test(=lander_cli_recovers_from_sigkill_and_resumes_after_sigterm))'
elif [[ "${1:-}" == "--full" ]]; then
    shift
    filter='kind(test)'
fi

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
# The reviewed alethia-reth image supports canonical-config alloc-only Etna genesis.
# Real contracts require canonical zero-storage proofs and modern EIP-7594 wrappers.
export LANDER_ANVIL_IMAGE=${LANDER_ANVIL_IMAGE:-ghcr.io/foundry-rs/foundry:v1.8.5}
export ALETHIA_RETH_IMAGE=${ALETHIA_RETH_IMAGE:-us-docker.pkg.dev/evmchain/images/alethia-reth:sha-b046734@sha256:2cb3b5f4afbd4e792f6d487af3d8d0eb8843ebec94180a845b277ab30fed4fd5}
export COMETBFT_IMAGE=${COMETBFT_IMAGE:-cometbft/cometbft:v0.40.0@sha256:0703fb881dac0987c8e41a5810cc09dbcb503bb59ac91705f6936c4b972ac798}

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
cargo nextest run -p abci -p lander -p taiko-client -p test-harness --all-features --profile integration --run-ignored only -E "$filter" "$@" &
scenario_pid=$!
trap 'stop_scenarios 130' INT
trap 'stop_scenarios 143' TERM
wait "$scenario_pid"
