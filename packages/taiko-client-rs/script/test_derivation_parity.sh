#!/usr/bin/env bash
set -euo pipefail

PARITY_RS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PARITY_REPO_ROOT="$(cd "$PARITY_RS_ROOT/../.." && pwd)"
if [[ -n "$(docker ps -q --filter 'name=^/(l1_node|l2_node_0|l2_node_1)$')" ]]; then
    echo "The shared driver harness containers are already running; refusing to reuse them" >&2
    exit 1
fi
PARITY_TMP="$(mktemp -d)"
export TAIKO_GO_DRIVER_PID_FILE="$PARITY_TMP/go-driver.pid"
cleanup() {
    # SIGKILL skips the Rust test's Drop. Reap its child before removing the PID file.
    if [[ -s "$TAIKO_GO_DRIVER_PID_FILE" ]]; then
        local driver_pid
        driver_pid="$(cat "$TAIKO_GO_DRIVER_PID_FILE")"
        if [[ "$driver_pid" =~ ^[0-9]+$ ]]; then
            kill -KILL "$driver_pid" 2>/dev/null || true
        fi
    fi
    rm -rf "$PARITY_TMP"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ -z "${TAIKO_GO_DRIVER_BIN:-}" ]]; then
    export TAIKO_GO_DRIVER_BIN="$PARITY_TMP/taiko-client"
    (
        cd "$PARITY_REPO_ROOT"
        GOTOOLCHAIN=go1.26.0 CGO_CFLAGS="-O -D__BLST_PORTABLE__" \
            CGO_CFLAGS_ALLOW="-O -D__BLST_PORTABLE__" \
            go build -o "$TAIKO_GO_DRIVER_BIN" ./packages/taiko-client/cmd
    )
fi
[[ -x "$TAIKO_GO_DRIVER_BIN" ]] || { echo "Go driver binary is not executable" >&2; exit 1; }
cd "$PARITY_RS_ROOT"
# Whitelist bootstrap mines ahead in L1 time; Go intentionally waits for future
# L2 timestamps. Match the Go harness's past Anvil genesis for this test only.
if docker compose version > /dev/null 2>&1; then
    PARITY_COMPOSE=(docker compose)
else
    PARITY_COMPOSE=(docker-compose)
fi
"${PARITY_COMPOSE[@]}" -f tests/docker/docker-compose.test.yaml config --format json |
    jq --arg timestamp "$(( $(date -u +%s) - 7200 ))"         '.services.l1_node.entrypoint += ["--timestamp", $timestamp]' > "$PARITY_TMP/compose.json"
export TAIKO_TEST_COMPOSE_FILE="$PARITY_TMP/compose.json"
TEST_CRATE=driver just test --run-ignored only -E 'test(derivation_split_parity)'
