#!/bin/sh

# This script accepts ownership of multiple contracts using the AcceptOwnership script.
# It supports two modes:
#   1. Direct acceptance: when INTERMEDIATE_CONTRACT is not set, calls acceptOwnership()
#      directly on each contract (requires PRIVATE_KEY to be the pending owner)
#   2. Intermediate contract: when INTERMEDIATE_CONTRACT is set (e.g., SurgeTimelockController
#      on L1 or DelegateController on L2), calls acceptOwnership(address[]) on that contract
#      which then accepts ownership of all specified contracts (permissionless call)
set -e

# Private key
# - For direct acceptance: must be the pending owner
# - For intermediate contract: can be any funded account (permissionless call)
export PRIVATE_KEY=${PRIVATE_KEY:-"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"}

# Network configuration
export FORK_URL=${FORK_URL:-"http://localhost:8545"}

# Contract addresses to accept ownership (comma-separated)
export CONTRACT_ADDRESSES=${CONTRACT_ADDRESSES:-""}

# Intermediate contract (optional)
# - L1: SurgeTimelockController address
# - L2: DelegateController address
# If not set, ownership is accepted directly by the pending owner
export INTERMEDIATE_CONTRACT=${INTERMEDIATE_CONTRACT:-"0x0000000000000000000000000000000000000000"}

# Broadcast transactions
export BROADCAST=${BROADCAST:-false}

# Parameterize broadcasting
export BROADCAST_ARG=""
if [ "$BROADCAST" = "true" ]; then
    BROADCAST_ARG="--broadcast"
fi

# Parameterize log level
export LOG_LEVEL=${LOG_LEVEL:-"-vvvv"}

echo "Contract addresses to accept ownership:"
echo "$CONTRACT_ADDRESSES"
echo ""
if [ "$INTERMEDIATE_CONTRACT" != "0x0000000000000000000000000000000000000000" ]; then
    echo "Intermediate contract: $INTERMEDIATE_CONTRACT"
    echo ""
fi

if [ "$BROADCAST" = "true" ]; then
    echo "Running in BROADCAST mode - transactions will be executed"
else
    echo "Running in SIMULATION mode - set BROADCAST=true to execute transactions"
fi
echo ""

forge script ./script/layer1/surge/AcceptOwnership.s.sol:AcceptOwnership \
    --fork-url $FORK_URL \
    $BROADCAST_ARG \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY