#!/bin/sh

# This script sets up the bridge contracts by configuring L1Sender and L2Math with each other's addresses.
# It requires both contracts to be deployed first.
set -e

# Private key for setup transactions
export PRIVATE_KEY=${PRIVATE_KEY:-"0x94eb3102993b41ec55c241060f47daa0f6372e2e3ad7e91612ae36c364042e44"}

# Network configuration
export L1_RPC=${L1_RPC:-"ws://45.33.84.128:32004"}
export L2_RPC=${L2_RPC:-"ws://45.33.84.128:8548"}

# Contract addresses (must be set after deployment)
export L1_SENDER=${L1_SENDER:-""}
export L2_MATH=${L2_MATH:-""}

if [ -z "$L1_SENDER" ] || [ -z "$L2_MATH" ]; then
    echo "Error: L1_SENDER and L2_MATH must be set"
    echo "Usage: L1_SENDER=<address> L2_MATH=<address> ./setup_bridge_contracts.sh"
    exit 1
fi

# Broadcast transactions
export BROADCAST=${BROADCAST:-false}

# Parameterize broadcasting
export BROADCAST_ARG=""
if [ "$BROADCAST" = "true" ]; then
    BROADCAST_ARG="--broadcast"
fi

# Parameterize log level
export LOG_LEVEL=${LOG_LEVEL:-"-vvvv"}

echo "=====================================";
echo "Setting up Bridge Contracts";
echo "=====================================";
echo "L1 RPC: $L1_RPC"
echo "L2 RPC: $L2_RPC"
echo "L1Sender: $L1_SENDER"
echo "L2Math: $L2_MATH"
echo ""

if [ "$BROADCAST" = "true" ]; then
    echo "Running in BROADCAST mode - transactions will be executed"
else
    echo "Running in SIMULATION mode - set BROADCAST=true to execute transactions"
fi
echo ""

# Setup L1Sender (on L1)
echo "Setting L2Math address in L1Sender..."
forge script ./script/shared/surge/examples/SetupBridgeContracts.s.sol:SetupBridgeContracts \
    --fork-url $L1_RPC \
    $BROADCAST_ARG \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY \
    --sig "setupL1Sender()"

echo ""
echo "Setting L1Sender address in L2Math..."
# Setup L2Math (on L2)
forge script ./script/shared/surge/examples/SetupBridgeContracts.s.sol:SetupBridgeContracts \
    --fork-url $L2_RPC \
    $BROADCAST_ARG \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY \
    --sig "setupL2Math()"

echo ""
echo "Setup complete!"
