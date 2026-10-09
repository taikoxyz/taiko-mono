#!/bin/bash

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run from the package root so relative paths (compose file, nextest config,
# workspace crates) resolve regardless of the caller's working directory.
cd "$DIR/.."

export HARNESS_L1_HTTP=${HARNESS_L1_HTTP:-http://localhost:18545}
export HARNESS_L1_WS=${HARNESS_L1_WS:-ws://localhost:18545}
export L2_HTTP_0=http://localhost:28545
export L2_WS_0=ws://localhost:28546
export L2_AUTH_0=http://localhost:28551
export JWT_SECRET=$DIR/docker/jwt.hex

# Verify required CLI tools are present before starting containers, so a missing
# binary fails loudly instead of hanging in a readiness loop below.
for cmd in cast; do
    if ! command -v "$cmd" > /dev/null 2>&1; then
        echo "ERROR: required command '$cmd' not found in PATH"
        exit 1
    fi
done

# Prefer Docker Compose v2 plugin; fallback to the standalone v1/v2 binary.
if docker compose version > /dev/null 2>&1; then
    DOCKER_COMPOSE=(docker compose)
elif command -v docker-compose > /dev/null 2>&1; then
    DOCKER_COMPOSE=(docker-compose)
else
    echo "ERROR: neither 'docker compose' nor 'docker-compose' is available"
    exit 1
fi

COMPOSE_FILE="${TAIKO_TEST_COMPOSE_FILE:-tests/docker/docker-compose.test.yaml}"
COMPOSE_ARGS=(-f "$COMPOSE_FILE")
cleanup() {
    "${DOCKER_COMPOSE[@]}" "${COMPOSE_ARGS[@]}" down -v
}

echo "Starting docker compose services..."
"${DOCKER_COMPOSE[@]}" "${COMPOSE_ARGS[@]}" up -d
trap cleanup EXIT

# Wait for an RPC endpoint to accept requests, bounded so a container that never
# comes up dumps its logs and fails instead of hanging forever.
wait_for_rpc() {
    local url="$1" name="$2" deadline=$((SECONDS + 120))
    until cast chain-id --rpc-url "$url" > /dev/null 2>&1; do
        if (( SECONDS >= deadline )); then
            echo "ERROR: $name ($url) not ready after 120s"
            "${DOCKER_COMPOSE[@]}" "${COMPOSE_ARGS[@]}" logs --tail=100
            exit 1
        fi
        sleep 1
    done
    echo "$name is ready ($url)"
}

wait_for_rpc "$HARNESS_L1_HTTP" "L1 node"
wait_for_rpc "$L2_WS_0" "L2 node 0"

if [[ -n "${TEST_CRATE:-}" ]]; then
    echo "Running integration tests for crate: ${TEST_CRATE}"
    cargo nextest -v run -p "${TEST_CRATE}" --all-features -E 'kind(test)' "$@"
else
    echo "Running integration tests (default)"
    cargo nextest -v run --workspace --all-features -E 'kind(test)' "$@"
fi
