#!/bin/sh

# This script deploys the Cross-Chain DEX L2 contracts (vault-based, no mock minting).
set -e

# Private key for deployment
export PRIVATE_KEY=${PRIVATE_KEY:-"0x94eb3102993b41ec55c241060f47daa0f6372e2e3ad7e91612ae36c364042e44"}

# Network configuration
export L1_RPC=${L1_RPC:-"http://178.79.140.153:32003"}
export L2_RPC=${L2_RPC:-"http://178.79.140.153:8547"}

# Bridge addresses
export L2_BRIDGE=${L2_BRIDGE:-"0x7633740000000000000000000000000000000001"}

# Get chain IDs from RPCs
echo "Getting chain IDs from RPCs..."
L1_CHAIN_ID=$(cast chain-id --rpc-url "$L1_RPC")
L2_CHAIN_ID=$(cast chain-id --rpc-url "$L2_RPC")
export L1_CHAIN_ID

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
export FOUNDRY_PROFILE=${FOUNDRY_PROFILE:-"layer2"}

echo "=====================================";
echo "Deploying Cross-Chain DEX L2 (Vault)";
echo "=====================================";
echo "L2 RPC: $L2_RPC"
echo "L2 Bridge: $L2_BRIDGE"
echo "L1 Chain ID: $L1_CHAIN_ID"
echo "No mock minting - liquidity added from L1"
echo ""

if [ "$BROADCAST" = "true" ]; then
    echo "Running in BROADCAST mode - transactions will be executed"
else
    echo "Running in SIMULATION mode - set BROADCAST=true to execute transactions"
fi
echo ""

forge script ./script/layer2/surge/cross-chain-dex/DeployCrossChainDexL2.s.sol:DeployCrossChainDexL2 \
    --fork-url $L2_RPC \
    $BROADCAST_ARG \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY
