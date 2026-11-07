#!/bin/bash
#
# Runs the selected ignored ABCI, lander, and CLI integration scenarios. Most
# scenarios boot their own devnet through the Docker CLI
# (`crates/test-harness`: anvil as L1, alethia-reth, CometBFT) and removes it
# afterwards, so this script only checks docker, pre-pulls the images and runs the
# scenarios one at a time. Extra arguments are forwarded to `cargo nextest run`,
# e.g. `just test --no-capture` or `just test restart` (a test-name filter).
#
# Environment:
#   ANVIL_IMAGE, LANDER_ANVIL_IMAGE, ALETHIA_RETH_IMAGE, COMETBFT_IMAGE override the images.
#   PULL_POLICY=missing  reuse images already present on the daemon instead of
#                        pulling them on every run.
#   TAIKO_CLIENT_RS_TEST_LANE=native|devnet  run one of CI's two lanes within the selected
#                        tier: `native` is the governance_recovery binary (stock Comet, native
#                        EL and the recovery test image), `devnet` every other scenario. Unset
#                        runs both.

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run from the package root so the nextest config and the workspace resolve
# regardless of the caller's working directory.
cd "$DIR/.."

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
# The lane term joins the listing too, so helper preparation follows the lane. Only the
# governance_recovery binary (NATIVE_SUITE in selected_dependencies.py) needs stock Comet, the
# native EL or the recovery image; splitting on it keeps those builds out of the devnet lane.
case "${TAIKO_CLIENT_RS_TEST_LANE:-}" in
    '') ;;
    native) filter="$filter & binary_id(taiko-client::governance_recovery)" ;;
    devnet) filter="$filter & !binary_id(taiko-client::governance_recovery)" ;;
    *)
        echo "ERROR: TAIKO_CLIENT_RS_TEST_LANE must be native or devnet, not '$TAIKO_CLIENT_RS_TEST_LANE'" >&2
        exit 2
        ;;
esac

# Use the same build/selection arguments for discovery and execution. Repeated -E expressions
# retain nextest's OR semantics; never parse or reconstruct user filter expressions here.
common=(-p abci -p lander -p taiko-client -p test-harness --all-features --profile integration
        --run-ignored only -E "$filter")
list_args=("${common[@]}" --message-format json)
after_separator=0
run_reporter=0
for arg in "$@"; do
    if [[ "$after_separator" == 0 ]]; then
        case "$arg" in
            --) after_separator=1 ;;
            --no-capture|--nocapture) continue ;;
            --message-format|--message-format=*) run_reporter=1 ;;
            --help|-h|--no-run) exec cargo nextest run "${common[@]}" "$@" ;;
        esac
    fi
    list_args+=("$arg")
done

# Every harness child inherits this label. Cleanup stays scoped to this invocation, including
# lander fixtures, even when cancellation bypasses the harness's normal Drop cleanup.
export TAIKO_CLIENT_RS_TEST_RUN=${TAIKO_CLIENT_RS_TEST_RUN:-local-$$-$RANDOM}
selection_dir=$(mktemp -d)
recovery_image_built=0
docker_ready=0
cleanup_devnets() {
    local status=$?
    trap - EXIT INT TERM
    local failed=0
    local containers networks
    rm -rf "$selection_dir" || failed=1
    if [[ "$docker_ready" == 1 ]]; then
        containers=$(docker ps -aq --filter "label=taiko-client-rs.test-run=$TAIKO_CLIENT_RS_TEST_RUN") || failed=1
        networks=$(docker network ls -q --filter "label=taiko-client-rs.test-run=$TAIKO_CLIENT_RS_TEST_RUN") || failed=1
        if [[ -n "$containers" ]]; then
            # Docker IDs contain no shell whitespace; xargs handles Linux and macOS empty input.
            printf '%s\n' "$containers" | xargs docker rm -f -v || failed=1
        fi
        if [[ -n "$networks" ]]; then
            printf '%s\n' "$networks" | xargs docker network rm || failed=1
        fi
    fi
    if [[ "$recovery_image_built" == 1 ]]; then
        docker image rm "$ETNA_RECOVERY_IMAGE" > /dev/null || failed=1
    fi
    if [[ "$status" == 0 && "$failed" != 0 ]]; then status=1; fi
    exit "$status"
}
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
    if [[ -n "${scenario_pid:-}" ]]; then
        terminate_tree "$scenario_pid"
        wait "$scenario_pid" || true
    fi
    exit "$status"
}
run_child() {
    local status=0
    "$@" &
    scenario_pid=$!
    wait "$scenario_pid" || status=$?
    scenario_pid=''
    return "$status"
}
trap cleanup_devnets EXIT
trap 'stop_scenarios 130' INT
trap 'stop_scenarios 143' TERM

all_helpers=0
if [[ "$run_reporter" == 1 ]]; then
    # run's result reporter has a different format vocabulary and must not override list JSON.
    echo "Preparing all helpers: preserving the requested nextest run reporter" >&2
    all_helpers=1
elif run_child cargo nextest list "${list_args[@]}" \
    > "$selection_dir/tests.json" 2> "$selection_dir/list.err"; then
    cat "$selection_dir/list.err" >&2
    dependencies=$(python3 ./tests/selected_dependencies.py < "$selection_dir/tests.json")
else
    status=$?
    cat "$selection_dir/list.err" >&2
    # list deliberately lacks runner/reporter flags. Recognize only their clap error, then
    # preserve the old all-helper preparation rather than maintain a second argv parser.
    unsupported=$(sed -n "s/^error: unexpected argument '\([^']*\)' found$/\1/p" "$selection_dir/list.err")
    case "$status:$unsupported" in
        2:--retries|2:--test-threads|2:--jobs|2:-j|2:--fail-fast|2:--ff|2:--no-fail-fast|2:--nff|\
        2:--max-fail|2:--no-tests|2:--failure-output|2:--success-output|2:--status-level|\
        2:--final-status-level|2:--no-output-indent|2:--hide-progress-bar|2:--no-input-handler|\
        2:--message-format-version|2:--stress-count|2:--stress-duration|2:--debugger|2:--tracer|\
        2:--flaky-result|2:--max-progress-running|2:--rerun|2:-R)
            echo "Preparing all helpers: nextest list does not support $unsupported" >&2
            all_helpers=1
            ;;
        *) exit "$status" ;;
    esac
fi
if [[ "$all_helpers" == 1 ]]; then
    # Listing without the caller's arguments still builds every binary and records the client's path.
    run_child cargo nextest list "${common[@]}" --message-format json > "$selection_dir/tests.json"
    dependencies='docker signer comet el recovery'
fi

# An empty selection keeps nextest's own no-tests result (including --no-tests/env overrides).
if [[ -z "$dependencies" ]]; then
    run_child cargo nextest run "${common[@]}" "$@"
    exit 0
fi
if ! command -v docker > /dev/null 2>&1; then
    echo "ERROR: required command 'docker' not found in PATH"
    exit 1
fi
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: the docker daemon is not reachable"
    exit 1
fi
docker_ready=1

# Pinned to the anvil release the scenarios are verified with: a moving tag could change its
# JSON-RPC behaviour under them (e.g. whether it serves debug_getRawHeader).
export ANVIL_IMAGE=${ANVIL_IMAGE:-ghcr.io/foundry-rs/foundry:v1.5.1}
# The reviewed alethia-reth image supports canonical-config alloc-only Etna genesis.
# Real contracts require canonical zero-storage proofs and modern EIP-7594 wrappers.
export LANDER_ANVIL_IMAGE=${LANDER_ANVIL_IMAGE:-ghcr.io/foundry-rs/foundry:v1.8.5}
export ALETHIA_RETH_IMAGE=${ALETHIA_RETH_IMAGE:-us-docker.pkg.dev/evmchain/images/alethia-reth:sha-6ac93d4@sha256:a92fca2305a657d4a9267e61ba198531db52c3a173d236fc3dc14984d66d2e3d}
export COMETBFT_IMAGE=${COMETBFT_IMAGE:-cometbft/cometbft:v0.40.0@sha256:0703fb881dac0987c8e41a5810cc09dbcb503bb59ac91705f6936c4b972ac798}

# Pull before the first scenario so downloads don't eat into its readiness deadlines, and before
# the helpers so the Linux EL runtime copies out of the alethia-reth image pulled here.
for image in "$ANVIL_IMAGE" "$LANDER_ANVIL_IMAGE" "$ALETHIA_RETH_IMAGE" "$COMETBFT_IMAGE"; do
    if [[ "${PULL_POLICY:-always}" == "missing" ]] && docker image inspect "$image" > /dev/null 2>&1; then
        echo "Using local image $image"
    else
        echo "Pulling $image"
        run_child docker pull --quiet "$image"
    fi
done

if [[ " $dependencies " == *' signer '* ]]; then
    run_child bash ./script/build_etna_signer.sh
    export ETNA_SIGNER_BIN="$PWD/target/etna-signer/etna-signer"
fi
if [[ " $dependencies " == *' comet '* ]]; then
    run_child bash ./script/build_stock_comet.sh
    export ETNA_COMET_BIN="$PWD/target/etna-signer/cometbft"
fi
if [[ " $dependencies " == *' el '* ]]; then
    run_child bash ./script/build_etna_el_import.sh
    export ETNA_EL_IMPORT_BIN="${ETNA_EL_IMPORT_BIN:-$PWD/target/etna-signer/etna-el-import}"
    run_child bash ./script/build_etna_el_runtime.sh
    export ETNA_EL_BIN="${ETNA_EL_BIN:-$PWD/target/etna-signer/alethia-reth}"
fi

# Only these selected consumers need the complete Linux runtime. Never remove an explicit
# caller-owned override; build before running so compilation does not consume test timeouts.
# The image runs the client that the listing above built.
if [[ " $dependencies " == *' recovery '* && -z "${ETNA_RECOVERY_IMAGE:-}" ]]; then
    client_bin=$(python3 ./tests/selected_dependencies.py --client-bin < "$selection_dir/tests.json")
    export ETNA_RECOVERY_IMAGE="etna-client-recovery-test:$TAIKO_CLIENT_RS_TEST_RUN"
    run_child bash ./script/build_recovery_runtime.sh "$client_bin"
    recovery_image_built=1
fi

echo "Running the ABCI, lander, and CLI docker scenarios"
run_child cargo nextest run "${common[@]}" "$@"
