#!/bin/sh

# This script deploys the Surge Proposer Wrapper on L1
set -e

# Deployer private key
export PRIVATE_KEY=${PRIVATE_KEY:-"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"}

# Network configuration
export FORK_URL=${FORK_URL:-"http://localhost:8545"}

# Proposer wrapper configuration
export TAIKO_WRAPPER=${TAIKO_WRAPPER:-"0x0000000000000000000000000000000000000001"}
export TAIKO_INBOX=${TAIKO_INBOX:-"0x0000000000000000000000000000000000000001"}
export ADMIN=${ADMIN:-"0x1237810000000000000000000000000000000001"}

# Deploy Surge Proposer Wrapper
export FOUNDRY_PROFILE=${FOUNDRY_PROFILE:-"layer1"}

# Verify smart contracts
export VERIFY=${VERIFY:-false}

# Broadcast transactions
export BROADCAST=${BROADCAST:-false}

# Parameterize broadcasting
export BROADCAST_ARG=""
if [ "$BROADCAST" = "true" ]; then
    BROADCAST_ARG="--broadcast"
fi

# Parameterize verification
export VERIFY_ARG=""
if [ "$VERIFY" = "true" ]; then
    VERIFY_ARG="--verify"
fi

# Parameterize log level
export LOG_LEVEL=${LOG_LEVEL:-"-vvvv"}

# Parameterize block gas limit
export BLOCK_GAS_LIMIT=${BLOCK_GAS_LIMIT:-200000000}

forge script ./script/layer1/surge/DeployProposerWrapper.s.sol:DeployProposerWrapper \
    --fork-url $FORK_URL \
    $BROADCAST_ARG \
    $VERIFY_ARG \
    --ffi \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY \
    --block-gas-limit $BLOCK_GAS_LIMIT 