#!/bin/bash

set -eou pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v docker &> /dev/null 2>&1; then
    echo "ERROR: `docker` command not found"
    exit 1
fi

if ! docker info > /dev/null 2>&1; then
    echo "ERROR: docker daemon isn't running"
    exit 1
fi

GENESIS_JSON="$DIR/data/genesis.json"
TESTNET_CONFIG="$DIR/testnet/docker-compose.yml"

touch "$GENESIS_JSON"

# The node only serves the generated genesis state over RPC; it does not produce blocks. Configure
# it as post-Merge and activate Osaka at genesis so its EVM matches the contracts' target.
echo '
{
  "config": {
    "chainId": 167,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip150Hash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "muirGlacierBlock": 0,
    "berlinBlock": 0,
    "londonBlock": 0,
    "arrowGlacierBlock": 0,
    "grayGlacierBlock": 0,
    "mergeNetsplitBlock": 0,
    "terminalTotalDifficulty": 0,
    "terminalTotalDifficultyPassed": true,
    "shanghaiTime": 0,
    "cancunTime": 0,
    "pragueTime": 0,
    "osakaTime": 0,
    "blobSchedule": {
      "cancun": {
        "target": 3,
        "max": 6,
        "baseFeeUpdateFraction": 3338477
      },
      "prague": {
        "target": 6,
        "max": 9,
        "baseFeeUpdateFraction": 5007716
      },
      "osaka": {
        "target": 6,
        "max": 9,
        "baseFeeUpdateFraction": 5007716
      }
    }
  },
  "gasLimit": "30000000",
  "difficulty": "0",
  "alloc":
' > "$GENESIS_JSON"

echo "Starting generate_genesis tests..."

# compile the contracts to get latest bytecode
rm -rf out && pnpm compile:genesis

# run the task
pnpm run genesis:gen $DIR/test_config.js

# generate complete genesis json
cat "$DIR/data/genesis_alloc.json" >> "$GENESIS_JSON"

echo '}' >> "$GENESIS_JSON"

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

function checkOsakaSupport {
  local rpcUrl="$1"
  local initCode="0x600160005d60005c1e60005260206000f3"
  local expected="0x00000000000000000000000000000000000000000000000000000000000000ff"
  local actual

  echo "Checking Osaka support on test node: $rpcUrl"

  # The init code stores 1 in transient slot 0, loads it, applies Osaka's CLZ opcode, and returns 255.
  if ! actual=$(cast rpc --rpc-url "$rpcUrl" eth_call "{\"data\":\"$initCode\"}" latest); then
      echo "ERROR: test node does not support the Osaka EVM"
      return 1
  fi

  actual="${actual#\"}"
  actual="${actual%\"}"

  if [ "$actual" != "$expected" ]; then
      echo "ERROR: unexpected Osaka probe result: $actual"
      return 1
  fi
}

RPC_URL=http://localhost:18545

waitTestNode "$RPC_URL"
checkOsakaSupport "$RPC_URL"

FOUNDRY_PROFILE=genesis forge test \
  -vvv \
  --gas-report \
  --fork-url "$RPC_URL" \
  --fork-retry-backoff 120 \
  --no-storage-caching \
  --match-path test/genesis/GenerateGenesis.g.sol \
  --block-gas-limit 1000000000
