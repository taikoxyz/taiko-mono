#!/bin/bash

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTOCOL_DIR="${PROTOCOL_DIR:-$DIR/../protocol}"
export PROTOCOL_DIR

echo "Starting docker compose services..."

export L1_HTTP=http://localhost:18545
export L2_HTTP=http://localhost:28545
export L2_WS=ws://localhost:28546
export L2_AUTH=http://localhost:28551
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

docker compose -f tests/docker/docker-compose.test.yaml up -d
trap "docker compose -f tests/docker/docker-compose.test.yaml down -v" EXIT INT KILL ERR

# check until L1 node is ready
until cast chain-id --rpc-url "$L1_HTTP" 2> /dev/null; do
    sleep 1
done

# check until L2 node is ready
until cast chain-id --rpc-url "$L2_WS" 2> /dev/null; do
    sleep 1
done

# Get the hash of the L2 genesis block.
export L2_GENESIS_HASH=$(
    curl \
        --silent \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":0,"method":"eth_getBlockByNumber","params":["0x0", false]}' \
        $L2_HTTP | jq .result.hash | sed 's/\"//g'
)
echo "L2_GENESIS_HASH: $L2_GENESIS_HASH"

$DIR/deploy.sh

# Export deployed contract addresses and other env vars for tests.
DEPLOYMENT_JSON=$(cat "${PROTOCOL_DIR}/deployments/deploy_l1.json")
export SHASTA_INBOX=$(echo "$DEPLOYMENT_JSON" | jq '.shasta_inbox' | sed 's/\"//g')
export TAIKO_ANCHOR=0x1670010000000000000000000000000000010001
export TAIKO_TOKEN=$(echo "$DEPLOYMENT_JSON" | jq '.taiko_token' | sed 's/\"//g')
export FORCED_INCLUSION_STORE=$(echo "$DEPLOYMENT_JSON" | jq '.forced_inclusion_store' | sed 's/\"//g')
export COMPOSE_VERIFIER=$(echo "$DEPLOYMENT_JSON" | jq '.proof_verifier' | sed 's/\"//g')
export L1_CONTRACT_OWNER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export L1_PROPOSER_PRIVATE_KEY=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
export L2_SUGGESTED_FEE_RECIPIENT=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export L1_PROVER_PRIVATE_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
export TEST_ACCOUNT_PRIVATE_KEY=0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6
export TREASURY=0x1670010000000000000000000000000000010001

if [[ -n "${TEST_CRATE:-}" ]]; then
    echo "Running tests for crate: ${TEST_CRATE}"
    cargo nextest -v run -p "${TEST_CRATE}" --all-features --config-file nextest.toml
else
    echo "Running full test suite (default)"
    cargo nextest -v run --workspace --exclude bindings --all-features --config-file nextest.toml
fi
