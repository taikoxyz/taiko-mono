#!/bin/sh

# This script deploys the Cross-Chain DEX L2 contracts (vault-based, no mock minting).
set -e

# Foundry keystore account for deployment
export ACCOUNT=${ACCOUNT:-"surge_gnosis_deployer"}
export PASSWORD_FILE=${PASSWORD_FILE:-"/tmp/.keystore-pw"}

# Network configuration
export L1_RPC=${L1_RPC:-"https://billowing-lingering-vineyard.xdai.quiknode.pro/2392c42ed17769448758d0139b99996a806bb17e"}
export L2_RPC=${L2_RPC:-"http://45.33.84.128:8547"}

# Bridge addresses
export L2_BRIDGE=${L2_BRIDGE:-"0x7633740000000000000000000000000000000001"}

# Token decimals (must match L1 token; default 18)
export TOKEN_DECIMALS=${TOKEN_DECIMALS:-"18"}

# Get chain IDs from RPCs
echo "Getting chain IDs from RPCs..."
L1_CHAIN_ID=$(cast chain-id --rpc-url "$L1_RPC")
L2_CHAIN_ID=$(cast chain-id --rpc-url "$L2_RPC")
export L1_CHAIN_ID

echo "L1 Chain ID: $L1_CHAIN_ID"
echo "L2 Chain ID: $L2_CHAIN_ID"

# Resolve account address for --sender
SENDER=$(cast wallet address --account "$ACCOUNT" --password-file "$PASSWORD_FILE")
echo "Deployer: $SENDER"
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
    --account $ACCOUNT \
    --password-file $PASSWORD_FILE \
    --sender $SENDER
