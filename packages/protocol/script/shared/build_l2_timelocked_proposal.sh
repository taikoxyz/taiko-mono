#!/bin/sh

# This script builds a timelocked proposal for sending a cross-chain message to the L2 DelegateOwner contract
set -e

# L1 configuration
export L1_BRIDGE=${L1_BRIDGE:-"0x144B7C956a04dBE673d290c33580B6e108B9CCe3"}
export L1_TIMELOCK_CONTROLLER=${L1_TIMELOCK_CONTROLLER:-"0xeE6526A0B839A1C7c4a3695be4CFcfF15dc41F1E"}

# L2 configuration
export L2_CHAINID=${L2_CHAINID:-763374}
export L2_DELEGATE_OWNER=${L2_DELEGATE_OWNER:-"0xaA389D37f12905bE3b2C1C83d51d63Cdd1B4EC3A"}
export DEST_OWNER=${DEST_OWNER:-"0x3bc256069FF9af461F3e04494A3ece3f62F183fC"}

# Message configuration
export TARGET_CONTRACT=${TARGET_CONTRACT:-"0xe36F2B6C2138382ed200b0426858e67e56fA12F3"}
export IS_DELEGATE_CALL=${IS_DELEGATE_CALL:-false}
export CALL_DATA=${CALL_DATA:-"0x60fe47b10000000000000000000000000000000000000000000000000000000000000005"}
export GAS_LIMIT=${GAS_LIMIT:-1000000}
export FEE=${VALUE:-1000000000000000000} # 1 eth
export VALUE=${VALUE:-0}

# Timelock configuration
export TIMELOCK_DELAY=${TIMELOCK_DELAY:-600} # 10 minutes

# Foundry profile
export FOUNDRY_PROFILE=${FOUNDRY_PROFILE:-"shared"}

# Parameterize log level
export LOG_LEVEL=${LOG_LEVEL:-"-vvvv"}

# Parameterize block gas limit
export BLOCK_GAS_LIMIT=${BLOCK_GAS_LIMIT:-200000000}

# Validate required environment variables
if [ "$L1_BRIDGE" = "0x0000000000000000000000000000000000000000" ]; then
    echo "Error: L1_BRIDGE environment variable is required"
    exit 1
fi

if [ "$L1_TIMELOCK_CONTROLLER" = "0x0000000000000000000000000000000000000000" ]; then
    echo "Error: L1_TIMELOCK_CONTROLLER environment variable is required"
    exit 1
fi

if [ "$L2_DELEGATE_OWNER" = "0x0000000000000000000000000000000000000000" ]; then
    echo "Error: L2_DELEGATE_OWNER environment variable is required"
    exit 1
fi

if [ "$TARGET_CONTRACT" = "0x0000000000000000000000000000000000000000" ]; then
    echo "Error: TARGET_CONTRACT environment variable is required"
    exit 1
fi

# Build L2 timelocked proposal
forge script ./script/shared/L2TimelockedProposalBuilder.sol:L2TimelockedProposalBuilder \
    --ffi \
    $LOG_LEVEL \
    --block-gas-limit $BLOCK_GAS_LIMIT
