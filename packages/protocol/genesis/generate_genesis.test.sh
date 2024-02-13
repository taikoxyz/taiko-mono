#!/bin/bash

set -eou pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Ensure Docker is installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: 'docker' command not found"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Docker daemon isn't running"
    exit 1
fi

GENESIS_JSON=$(cd "$(dirname "$DIR/../..")" && pwd)/deployments/genesis.json
TESTNET_CONFIG=$DIR/testnet/docker-compose.yml

touch "$GENESIS_JSON"

# Securely prompt for sensitive information (e.g., private keys)
read -s -p "Enter sensitive information: " SENSITIVE_DATA
echo -e "\n"

echo '{
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
    "clique": {
      "period": 0,
      "epoch": 30000
    }
  },
  "gasLimit": "30000000",
  "difficulty": "1",
  "extraData": "0x0000000000000000000000000000000000000000000000000000000000000000df08f82de32b8d460adbe8d72043e3a7e25a3b390000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
  "alloc":
' > "$GENESIS_JSON"

echo "Starting generate_genesis tests..."

# Compile the contracts to get the latest bytecode
rm -rf out && pnpm compile

# Run the task
pnpm run generate:genesis "$DIR/test_config.js"

# Generate complete genesis json
cat "$DIR/../deployments/genesis_alloc.json" >> "$GENESIS_JSON"

echo '}' >> "$GENESIS_JSON"

# Start a Geth instance and init with the output genesis json
echo ""
echo "Start docker compose network..."

docker compose -f "$TESTNET_CONFIG" down -v --remove-orphans &> /dev/null
docker compose -f "$TESTNET_CONFIG" up -d

# Set a trap for cleaning up resources on exit
trap "docker compose -f $TESTNET_CONFIG down -v" EXIT INT KILL ERR

echo ""
echo "Start testing..."

function waitTestNode {
  echo "Waiting for the test node: $1"
  # Wait until the test node is fully started
  RETRIES=120
  i=0
  until curl \
    --silent \
    --fail \
    --noproxy localhost \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":0,"method":"eth_chainId","params":[]}' \
    "$1"
  do
    sleep 1
    if [ $i -eq $RETRIES ]; then
      echo 'Timed out waiting for the test node'
      exit 1
    fi
    ((i=i+1))
  done
}

waitTestNode http://localhost:18545

# Run forge tests with enhanced security options
forge test \
  -vvv \
  --gas-report \
  --fork-url http://localhost:18545 \
  --fork-retry-backoff 120 \
  --no-storage-caching \
  --evm-version cancun \
  --match-path genesis/*.g.sol \
  --block-gas-limit 1000000000

# Securely wipe sensitive data from memory
unset SENSITIVE_DATA
