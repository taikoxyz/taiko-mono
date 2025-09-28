#!/bin/sh

# This script sets up the Risc0 verifier after deployment
set -e

# Deployer private key
export PRIVATE_KEY=${PRIVATE_KEY:-"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"}

# Network configuration
export FORK_URL=${FORK_URL:-"http://localhost:8545"}

# Required verifier configuration
export RISC0_VERIFIER_ADDRESS=${RISC0_VERIFIER_ADDRESS:-""}

# This should be the L1 timelock controller
export NEW_OWNER=${NEW_OWNER:-""}

# Risc0 configuration
export RISC0_BLOCK_PROVING_IMAGE_ID=${RISC0_BLOCK_PROVING_IMAGE_ID:-"0x0000000000000000000000000000000000000000000000000000000000000000"}
export RISC0_AGGREGATION_IMAGE_ID=${RISC0_AGGREGATION_IMAGE_ID:-"0x0000000000000000000000000000000000000000000000000000000000000000"}

# Foundry profile
export FOUNDRY_PROFILE=${FOUNDRY_PROFILE:-"layer1"}

# Broadcast transactions
export BROADCAST=${BROADCAST:-true}

# Required environment variable validation
if [ -z "$RISC0_VERIFIER_ADDRESS" ]; then
    echo "Error: RISC0_VERIFIER_ADDRESS not set"
    exit 1
fi

if [ -z "$NEW_OWNER" ]; then
    echo "Error: NEW_OWNER not set (should be timelock controller address)"
    exit 1
fi

# Parameterize broadcasting
export BROADCAST_ARG=""
if [ "$BROADCAST" = "true" ]; then
    BROADCAST_ARG="--broadcast"
fi

# Parameterize verification
export VERIFY_ARG=""
if [ "$BROADCAST" = "true" ]; then
    VERIFY_ARG="--verify"
fi

# Parameterize log level
export LOG_LEVEL=${LOG_LEVEL:-"-vvv"}

# Parameterize block gas limit
export BLOCK_GAS_LIMIT=${BLOCK_GAS_LIMIT:-200000000}

echo "Setting up Risc0 verifier..."
echo "Verifier address: $RISC0_VERIFIER_ADDRESS"
echo "New owner: $NEW_OWNER"
echo "Block proving image ID: $RISC0_BLOCK_PROVING_IMAGE_ID"
echo "Aggregation image ID: $RISC0_AGGREGATION_IMAGE_ID"

# Run the setup script
forge script script/layer1/surge/SetupRisc0Verifier.s.sol \
    --fork-url $FORK_URL \
    $BROADCAST_ARG \
    $VERIFY_ARG \
    --ffi \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY \
    --block-gas-limit $BLOCK_GAS_LIMIT

echo "Risc0 verifier setup completed successfully!"
