#!/bin/bash

set -eou pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v docker &> /dev/null 2>&1; then
    echo "ERROR: \`docker\` command not found"
    exit 1
fi

if ! docker info > /dev/null 2>&1; then
    echo "ERROR: docker daemon isn't running"
    exit 1
fi

GENESIS_JSON="$DIR/data/genesis.json"
TESTNET_CONFIG="$DIR/testnet/docker-compose.yml"

echo "Starting generate_genesis tests..."

# compile the contracts to get latest bytecode
rm -rf out && pnpm compile:genesis

# run the task - this now generates the full genesis.json
pnpm run genesis:gen $DIR/test_config.js

# Verify genesis.json was generated
if [ ! -f "$GENESIS_JSON" ]; then
    echo "ERROR: genesis.json was not generated"
    exit 1
fi

echo "Genesis JSON generated at: $GENESIS_JSON"

# start a geth instance and init with the output genesis json
echo ""
echo "Start docker compose network..."

docker compose -f "$TESTNET_CONFIG" down -v --remove-orphans &> /dev/null
docker compose -f "$TESTNET_CONFIG" up -d

trap "docker compose -f $TESTNET_CONFIG down -v" EXIT INT KILL ERR

echo ""
echo "Start testing..."

function waitTestNode {
  echo "Waiting for test node: $1"
  # Wait till the test node fully started
  RETRIES=120
  i=0
  until cast chain-id --rpc-url "$1" &> /dev/null 2>&1
  do
      sleep 1
      if [ $i -eq $RETRIES ]; then
          echo 'Timed out waiting for test node'
          exit 1
      fi
      ((i=i+1))
  done
}

waitTestNode http://localhost:18545

FOUNDRY_PROFILE=genesis forge test \
  -vvv \
  --gas-report \
  --fork-url http://localhost:18545 \
  --fork-retry-backoff 120 \
  --no-storage-caching \
  --match-path test/genesis/GenerateGenesis.g.sol \
  --block-gas-limit 1000000000