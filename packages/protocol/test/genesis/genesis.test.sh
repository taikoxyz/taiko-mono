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

# The Etna genesis builder on real generator output (Etna SPEC 10 step 3). The default
# configuration leaves anchorV4 ungated, so the builder must refuse its alloc, both as configured
# and with only the configuration JSON edited to an Etna one; an alloc generated from the Etna
# configuration must pass.
echo ""
echo "Testing the Etna genesis builder on generated predeploys..."

BUILDER="script/layer2/build_etna_genesis.py"
L1_SIGNAL_SERVICE="0x00000000000000000000000000000000000100aa"
WORK="$(mktemp -d)"
cp "$DIR/data/genesis_config.json" "$WORK/default_config.json"
cp "$DIR/data/genesis_alloc.json" "$WORK/default_alloc.json"

# Puts back the default run's outputs, so a local run does not leave the Etna ones behind.
function restoreDefaultGenesis {
  if [ -d "$WORK" ]; then
    cp "$WORK/default_config.json" "$DIR/data/genesis_config.json"
    cp "$WORK/default_alloc.json" "$DIR/data/genesis_alloc.json"
    rm -rf "$WORK"
  fi
}
trap 'restoreDefaultGenesis; docker compose -f "$TESTNET_CONFIG" down -v' EXIT INT KILL ERR

function buildEtnaGenesis {
  python3 "$BUILDER" --base "$GENESIS_JSON" --predeploys "$DIR/data/genesis_alloc.json" \
    --predeploy-config "$1" --l1-signal-service "$L1_SIGNAL_SERVICE" --output "$WORK/genesis.json"
}

function expectBuilderRejects {
  local diagnostic="$1"
  if buildEtnaGenesis "$2" > "$WORK/builder.log" 2>&1; then
    echo "ERROR: the Etna genesis builder accepted a genesis it must refuse"
    cat "$WORK/builder.log"
    return 1
  fi
  if ! grep -qF "$diagnostic" "$WORK/builder.log" || [ -e "$WORK/genesis.json" ]; then
    echo "ERROR: the Etna genesis builder failed without \"$diagnostic\" or left output"
    cat "$WORK/builder.log"
    return 1
  fi
}

expectBuilderRejects "etnaTimestamp must be 0x0" "$DIR/data/genesis_config.json"

python3 -I - "$DIR/data/genesis_config.json" "$WORK/edited_config.json" "$L1_SIGNAL_SERVICE" <<'EOF'
import json, sys
config = json.load(open(sys.argv[1]))
config.update(etnaTimestamp="0x0", remoteSignalService=sys.argv[3])
json.dump(config, open(sys.argv[2], "w"))
EOF
expectBuilderRejects "TaikoAnchorImpl etnaTimestamp is 0x" "$WORK/edited_config.json"

cat > "$WORK/etna_config.js" <<EOF
"use strict";
const base = require("$DIR/data/genesis_config.js");
module.exports = {
  ...base,
  etnaTimestamp: "0x0",
  remoteSignalService: "$L1_SIGNAL_SERVICE",
};
EOF
GENESIS_CONFIG="$WORK/etna_config.js" pnpm run genesis:gen
if ! buildEtnaGenesis "$DIR/data/genesis_config.json"; then
  echo "ERROR: the Etna genesis builder refused the Etna alloc"
  exit 1
fi
python3 -I - "$WORK/genesis.json" <<'EOF'
import json, sys
alloc = json.load(open(sys.argv[1]))["alloc"]
for system in ("0x000f3df6d732807ef1319fb7b8bb8522d0beac02",
               "0x0000f90827f1c53a10cb7a02335b175320002935"):
    assert alloc[system]["code"] != "0x", system
EOF
restoreDefaultGenesis
echo "The Etna genesis builder accepts only the Etna alloc."
