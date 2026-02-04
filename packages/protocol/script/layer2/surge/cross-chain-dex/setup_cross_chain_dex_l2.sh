#!/bin/sh

# This script sets up the Cross-Chain DEX by setting L1 handler on L2 handler.
# Run this on L2 after both L1 and L2 contracts are deployed.
set -e

# Private key for deployment
export PRIVATE_KEY=${PRIVATE_KEY:-"0x94eb3102993b41ec55c241060f47daa0f6372e2e3ad7e91612ae36c364042e44"}

# Network configuration
export L2_RPC=${L2_RPC:-"ws://45.33.84.128:8548"}

# Handler addresses (must be set after deployment)
export L1_HANDLER=${L1_HANDLER:-""}
export L2_HANDLER=${L2_HANDLER:-""}

if [ -z "$L1_HANDLER" ] || [ -z "$L2_HANDLER" ]; then
    echo "ERROR: L1_HANDLER and L2_HANDLER must be set"
    echo "Usage: L1_HANDLER=0x... L2_HANDLER=0x... ./setup_cross_chain_dex_l2.sh"
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

# Parametrize foundry profile
export FOUNDRY_PROFILE=${FOUNDRY_PROFILE:-"layer2"}

echo "=====================================";
echo "Setting up Cross-Chain DEX (L2)";
echo "=====================================";
echo "L2 RPC: $L2_RPC"
echo "L1 Handler: $L1_HANDLER"
echo "L2 Handler: $L2_HANDLER"
echo ""

if [ "$BROADCAST" = "true" ]; then
    echo "Running in BROADCAST mode - transactions will be executed"
else
    echo "Running in SIMULATION mode - set BROADCAST=true to execute transactions"
fi
echo ""

forge script ./script/layer2/surge/cross-chain-dex/SetupCrossChainDexL2.s.sol:SetupCrossChainDexL2 \
    --fork-url $L2_RPC \
    $BROADCAST_ARG \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY
