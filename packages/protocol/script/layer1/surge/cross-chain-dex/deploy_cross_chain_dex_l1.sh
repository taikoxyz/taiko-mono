#!/bin/sh

# This script deploys the Cross-Chain DEX L1 contracts (vault-based).
set -e

# Foundry keystore account for deployment
export ACCOUNT=${ACCOUNT:-"surge_gnosis_deployer"}
export PASSWORD_FILE=${PASSWORD_FILE:-"/tmp/.keystore-pw"}

# Network configuration
export L1_RPC=${L1_RPC:-"https://billowing-lingering-vineyard.xdai.quiknode.pro/2392c42ed17769448758d0139b99996a806bb17e"}
export L2_RPC=${L2_RPC:-"http://45.33.84.128:8547"}

# Bridge addresses
export L1_BRIDGE=${L1_BRIDGE:-"0xc1e59A201cE4CD58590FC3Ab45081921cF186550"}

# Existing token address (set to use an existing ERC20 like real USDC instead of deploying)
# If not set, a new SwapToken will be deployed
export SWAP_TOKEN=${SWAP_TOKEN:-""}

# Token decimals (default 18; set to 6 for real USDC)
export TOKEN_DECIMALS=${TOKEN_DECIMALS:-"18"}

# Initial token supply (1 million tokens — raw units, must account for decimals)
# Only used when deploying a new token (SWAP_TOKEN is not set)
export INITIAL_TOKEN_SUPPLY=${INITIAL_TOKEN_SUPPLY:-"1000000000000000000000000"}

# Get chain IDs from RPCs
echo "Getting chain IDs from RPCs..."
L1_CHAIN_ID=$(cast chain-id --rpc-url "$L1_RPC")
L2_CHAIN_ID=$(cast chain-id --rpc-url "$L2_RPC")
export L2_CHAIN_ID

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
export FOUNDRY_PROFILE=${FOUNDRY_PROFILE:-"layer1"}

echo "=====================================";
echo "Deploying Cross-Chain DEX L1 (Vault)";
echo "=====================================";
echo "L1 RPC: $L1_RPC"
echo "L1 Bridge: $L1_BRIDGE"
echo "L2 Chain ID: $L2_CHAIN_ID"
if [ -n "$SWAP_TOKEN" ]; then
    echo "Using existing token: $SWAP_TOKEN"
else
    echo "Initial Token Supply: $INITIAL_TOKEN_SUPPLY"
fi
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
    --account $ACCOUNT \
    --password-file $PASSWORD_FILE \
    --sender $SENDER
