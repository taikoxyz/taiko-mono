#!/bin/bash

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run from the package root so relative paths (compose file, nextest config,
# workspace crates) resolve regardless of the caller's working directory.
cd "$DIR/.."

PROTOCOL_DIR="${PROTOCOL_DIR:-$DIR/../../protocol}"
export PROTOCOL_DIR
echo "Using PROTOCOL_DIR: $PROTOCOL_DIR"

export HARNESS_L1_HTTP=${HARNESS_L1_HTTP:-http://localhost:18545}
export HARNESS_L1_WS=${HARNESS_L1_WS:-ws://localhost:18545}
export L2_HTTP_0=http://localhost:28545
export L2_WS_0=ws://localhost:28546
export L2_AUTH_0=http://localhost:28551
export L2_WS_1=ws://localhost:38546
export L2_AUTH_1=http://localhost:38551
export JWT_SECRET=$DIR/docker/jwt.hex

# Environment variables for deploying protocol contracts on L1.
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export TAIKO_ANCHOR_ADDRESS=0x1670010000000000000000000000000000010001
export L2_SIGNAL_SERVICE=0x1670010000000000000000000000000000010005
export CONTRACT_OWNER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export TAIKO_TOKEN_PREMINT_RECIPIENT=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export L2_CHAIN_ID=167001
export PAUSE_BRIDGE="false"
export OLD_FORK_TAIKO_INBOX=0x0000000000000000000000000000000000000000
export TAIKO_TOKEN=0x0000000000000000000000000000000000000000
export SHARED_RESOLVER=0x0000000000000000000000000000000000000000
export INCLUSION_WINDOW=3
export INCLUSION_FEE_IN_GWEI=10
export DEPLOY_PRECONF_CONTRACTS="false"
export PRECONF_INBOX="false"
export DUMMY_VERIFIERS="true"
export ACTIVATE_INBOX="true"
export PROPOSER_ADDRESS=0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc
export PRECONF_WHITELIST=0x0000000000000000000000000000000000000000
export REMOTE_SIGNAL_SERVICE=0x1670010000000000000000000000000000000005

# Verify required CLI tools are present before starting containers, so a missing
# binary fails loudly instead of hanging in a readiness loop below.
for cmd in cast forge jq; do
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

COMPOSE_FILE=tests/docker/docker-compose.test.yaml
cleanup() {
    "${DOCKER_COMPOSE[@]}" -f "$COMPOSE_FILE" down -v
}

echo "Starting docker compose services..."
"${DOCKER_COMPOSE[@]}" -f "$COMPOSE_FILE" up -d
trap cleanup EXIT

# Wait for an RPC endpoint to accept requests, bounded so a container that never
# comes up dumps its logs and fails instead of hanging forever.
wait_for_rpc() {
    local url="$1" name="$2" deadline=$((SECONDS + 120))
    until cast chain-id --rpc-url "$url" > /dev/null 2>&1; do
        if (( SECONDS >= deadline )); then
            echo "ERROR: $name ($url) not ready after 120s"
            "${DOCKER_COMPOSE[@]}" -f "$COMPOSE_FILE" logs --tail=100
            exit 1
        fi
        sleep 1
    done
    echo "$name is ready ($url)"
}

wait_for_rpc "$HARNESS_L1_HTTP" "L1 node"
wait_for_rpc "$L2_WS_0" "L2 node 0"
wait_for_rpc "$L2_WS_1" "L2 node 1"

# Get the hash of the L2 genesis block.
L2_GENESIS_HASH=$(cast block 0 --field hash --rpc-url "$L2_HTTP_0")
export L2_GENESIS_HASH
echo "L2_GENESIS_HASH: $L2_GENESIS_HASH"

"$DIR/deploy.sh"

# Export deployed contract addresses and other env vars for tests.
DEPLOYMENT_JSON=$(cat "${PROTOCOL_DIR}/deployments/deploy_l1.json")
SHASTA_INBOX=$(echo "$DEPLOYMENT_JSON" | jq -r '.shasta_inbox')
export SHASTA_INBOX
export TAIKO_ANCHOR=0x1670010000000000000000000000000000010001
export L2_SUGGESTED_FEE_RECIPIENT=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export L1_PROPOSER_PRIVATE_KEY=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a

if [[ -n "${TEST_CRATE:-}" ]]; then
    echo "Running tests for crate: ${TEST_CRATE}"
    cargo nextest -v run -p "${TEST_CRATE}" --all-features "$@"
else
    echo "Running full test suite (default)"
    cargo nextest -v run --workspace --exclude bindings --all-features "$@"
fi
