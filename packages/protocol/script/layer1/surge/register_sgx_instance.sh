#!/bin/sh

# This script registers SGX instances for the Surge protocol
set -e

# Deployer private key
export PRIVATE_KEY=${PRIVATE_KEY:-"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"}

# Network configuration
export FORK_URL=${FORK_URL:-"http://localhost:8545"}

# SGX configuration
export AUTOMATA_PROXY=${AUTOMATA_PROXY:-"0x0000000000000000000000000000000000000000"}
export SGX_RETH_VERIFIER=${SGX_RETH_VERIFIER:-"0x0000000000000000000000000000000000000000"}
export PEM_CERT_CHAIN_LIB_ADDR=${PEM_CERT_CHAIN_LIB_ADDR:-"0x0000000000000000000000000000000000000000"}

# MR Enclave and Signer configuration
export MR_ENCLAVE=${MR_ENCLAVE:-"0x0000000000000000000000000000000000000000000000000000000000000000"}
export MR_SIGNER=${MR_SIGNER:-"0x0000000000000000000000000000000000000000000000000000000000000000"}

# Attestation configuration
export QEID_PATH=${QEID_PATH:-"/test/layer1/automata-attestation/assets/0923/identity.json"}
export TCB_INFO_PATH=${TCB_INFO_PATH:-"/test/layer1/automata-attestation/assets/0923/tcb_00606A000000.json"}
export V3_QUOTE_BYTES=${V3_QUOTE_BYTES:-"0x"}

# Foundry configuration
export FOUNDRY_PROFILE=${FOUNDRY_PROFILE:-"layer1"}

# Broadcast transactions
export BROADCAST=${BROADCAST:-false}

# Parameterize broadcasting
export BROADCAST_ARG=""
if [ "$BROADCAST" = "true" ]; then
    BROADCAST_ARG="--broadcast"
fi

# Parameterize log level
export LOG_LEVEL=${LOG_LEVEL:-"-vvvv"}

# Parameterize block gas limit
export BLOCK_GAS_LIMIT=${BLOCK_GAS_LIMIT:-200000000}

forge script ./script/layer1/surge/RegisterSGXInstance.s.sol:RegisterSGXInstance \
    --fork-url $FORK_URL \
    $BROADCAST_ARG \
    --ffi \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY \
    --block-gas-limit $BLOCK_GAS_LIMIT 