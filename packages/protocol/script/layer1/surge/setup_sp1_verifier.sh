#!/bin/sh

# This script sets up the SP1 verifier after deployment
set -e

# Deployer private key
export PRIVATE_KEY=${PRIVATE_KEY:-"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"}

# Network configuration
export FORK_URL=${FORK_URL:-"http://localhost:8545"}

# Required verifier configuration
export SP1_VERIFIER_ADDRESS=${SP1_VERIFIER_ADDRESS:-""}

# This should be the L1 timelock controller
export NEW_OWNER=${NEW_OWNER:-""}

# SP1 configuration
export SP1_BLOCK_PROVING_PROGRAM_VKEY=${SP1_BLOCK_PROVING_PROGRAM_VKEY:-"0x0000000000000000000000000000000000000000000000000000000000000000"}
export SP1_AGGREGATION_PROGRAM_VKEY=${SP1_AGGREGATION_PROGRAM_VKEY:-"0x0000000000000000000000000000000000000000000000000000000000000000"}

# Foundry profile
export FOUNDRY_PROFILE=${FOUNDRY_PROFILE:-"layer1"}

# Broadcast transactions
export BROADCAST=${BROADCAST:-true}

# Required environment variable validation
if [ -z "$SP1_VERIFIER_ADDRESS" ]; then
    echo "Error: SP1_VERIFIER_ADDRESS not set"
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

echo "Setting up SP1 verifier..."
echo "Verifier address: $SP1_VERIFIER_ADDRESS"
echo "New owner: $NEW_OWNER"
echo "Block proving program VKey: $SP1_BLOCK_PROVING_PROGRAM_VKEY"
echo "Aggregation program VKey: $SP1_AGGREGATION_PROGRAM_VKEY"

# Run the setup script
forge script script/layer1/surge/SetupSP1Verifier.s.sol \
    --fork-url $FORK_URL \
    $BROADCAST_ARG \
    $VERIFY_ARG \
    --ffi \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY \
    --block-gas-limit $BLOCK_GAS_LIMIT

echo "SP1 verifier setup completed successfully!"
