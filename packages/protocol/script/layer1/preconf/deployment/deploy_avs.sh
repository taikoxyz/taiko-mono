set -e

: "${PRIVATE_KEY:?Environment variable PRIVATE_KEY is required}"
: "${FORK_URL:?Environment variable FORK_URL is required}"
: "${AVS_DIRECTORY:?Environment variable AVS_DIRECTORY is required}"
: "${SLASHER:?Environment variable SLASHER is required}"
: "${TAIKO_L1:?Environment variable TAIKO_L1 is required}"
: "${TAIKO_TOKEN:?Environment variable TAIKO_TOKEN is required}"
: "${BEACON_GENESIS_TIMESTAMP:?Environment variable BEACON_GENESIS_TIMESTAMP is required}"
: "${BEACON_BLOCK_ROOT_CONTRACT:?Environment variable BEACON_BLOCK_ROOT_CONTRACT is required}"
echo "BEACON_GENESIS_TIMESTAMP: $BEACON_GENESIS_TIMESTAMP"

forge script scripts/deployment/DeployAVS.s.sol:DeployAVS \
  --fork-url $FORK_URL \
  --broadcast \
  --skip-simulation \
  --private-key $PRIVATE_KEY