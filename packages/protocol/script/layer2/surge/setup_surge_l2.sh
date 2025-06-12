#!/bin/sh

# This script sets up the Surge protocol on L2
set -e

# Deployer private key
# This is the existing owner of the L2 contracts
export PRIVATE_KEY=${PRIVATE_KEY:-"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"}

# Network configuration
export FORK_URL=${FORK_URL:-"http://localhost:8545"}

# L1 configuration
export L1_CHAINID=${L1_CHAINID:-1}
export L1_BRIDGE=${L1_BRIDGE:-"0x0000000000000000000000000000000000000000"}
export L1_SIGNAL_SERVICE=${L1_SIGNAL_SERVICE:-"0x0000000000000000000000000000000000000000"}
export L1_ERC20_VAULT=${L1_ERC20_VAULT:-"0x0000000000000000000000000000000000000000"}
export L1_ERC721_VAULT=${L1_ERC721_VAULT:-"0x0000000000000000000000000000000000000000"}
export L1_ERC1155_VAULT=${L1_ERC1155_VAULT:-"0x0000000000000000000000000000000000000000"}

# L1 Timelock controller
# This is the owner of the existing L1 contracts
export L1_TIMELOCK_CONTROLLER=${L1_TIMELOCK_CONTROLLER:-"0x0000000000000000000000000000000000000000"}

# Deploy Surge protocol
export FOUNDRY_PROFILE=${FOUNDRY_PROFILE:-"layer2"}

# Broadcast transactions
export BROADCAST=${BROADCAST:-false}

# Parameterize broadcasting
export BROADCAST_ARG=""
if [ "$BROADCAST" = "true" ]; then
    BROADCAST_ARG="--broadcast"
fi

forge script ./script/layer1/surge/SetupSurgeL2.s.sol:SetupSurgeL2 \
    --fork-url $FORK_URL \
    $BROADCAST_ARG \
    --ffi \
    -vvvv \
    --private-key $PRIVATE_KEY \
    --block-gas-limit 200000000 