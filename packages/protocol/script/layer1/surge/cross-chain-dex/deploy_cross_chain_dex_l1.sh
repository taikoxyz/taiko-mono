#!/bin/sh

# This script deploys the Cross-Chain DEX L1 contracts.
set -e

# Private key for deployment
export PRIVATE_KEY=${PRIVATE_KEY:-"0x94eb3102993b41ec55c241060f47daa0f6372e2e3ad7e91612ae36c364042e44"}

# Network configuration
export L1_RPC=${L1_RPC:-"ws://45.33.84.128:32004"}
export L2_RPC=${L2_RPC:-"ws://45.33.84.128:8548"}

# Bridge addresses
export L1_BRIDGE=${L1_BRIDGE:-"0xC935D1c64591Aa954F34eB49Ea6175D06A8F21Eb"}

# Initial token supply (1 million tokens with 18 decimals)
export INITIAL_TOKEN_SUPPLY=${INITIAL_TOKEN_SUPPLY:-"1000000000000000000000000"}

# Get chain IDs from RPCs
echo "Getting chain IDs from RPCs..."
L1_CHAIN_ID=$(cast chain-id --rpc-url "$L1_RPC")
L2_CHAIN_ID=$(cast chain-id --rpc-url "$L2_RPC")
export L2_CHAIN_ID

echo "L1 Chain ID: $L1_CHAIN_ID"
echo "L2 Chain ID: $L2_CHAIN_ID"
echo ""

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
export FOUNDRY_PROFILE=${FOUNDRY_PROFILE:-"layer1"}

echo "=====================================";
echo "Deploying Cross-Chain DEX L1";
echo "=====================================";
echo "L1 RPC: $L1_RPC"
echo "L1 Bridge: $L1_BRIDGE"
echo "L2 Chain ID: $L2_CHAIN_ID"
echo "Initial Token Supply: $INITIAL_TOKEN_SUPPLY"
echo ""

if [ "$BROADCAST" = "true" ]; then
    echo "Running in BROADCAST mode - transactions will be executed"
else
    echo "Running in SIMULATION mode - set BROADCAST=true to execute transactions"
fi
echo ""

forge script ./script/layer1/surge/cross-chain-dex/DeployCrossChainDexL1.s.sol:DeployCrossChainDexL1 \
    --fork-url $L1_RPC \
    $BROADCAST_ARG \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY
