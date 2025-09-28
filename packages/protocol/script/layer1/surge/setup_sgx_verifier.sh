#!/bin/sh

# This script sets up the SGX verifier after deployment
set -e

# Deployer private key
export PRIVATE_KEY=${PRIVATE_KEY:-"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"}

# Network configuration
export FORK_URL=${FORK_URL:-"http://localhost:8545"}

# Required verifier configuration
export SGX_VERIFIER_ADDRESS=${SGX_VERIFIER_ADDRESS:-""}
export AUTOMATA_PROXY_ADDRESS=${AUTOMATA_PROXY_ADDRESS:-""}
export PEM_CERT_CHAIN_LIB_ADDRESS=${PEM_CERT_CHAIN_LIB_ADDRESS:-""}

# This should be the L1 timelock controller
export NEW_OWNER=${NEW_OWNER:-""}

# SGX configuration (optional)
export MR_ENCLAVE=${MR_ENCLAVE:-""}
export MR_SIGNER=${MR_SIGNER:-""}
export QEID_PATH=${QEID_PATH:-""}
export TCB_INFO_PATH=${TCB_INFO_PATH:-""}
export V3_QUOTE_BYTES=${V3_QUOTE_BYTES:-""}

# Foundry profile
export FOUNDRY_PROFILE=${FOUNDRY_PROFILE:-"layer1"}

# Broadcast transactions
export BROADCAST=${BROADCAST:-true}

# Verify smart contracts
export VERIFY=${VERIFY:-false}

# Required environment variable validation
if [ -z "$SGX_VERIFIER_ADDRESS" ]; then
    echo "Error: SGX_VERIFIER_ADDRESS not set"
    exit 1
fi

if [ -z "$AUTOMATA_PROXY_ADDRESS" ]; then
    echo "Error: AUTOMATA_PROXY_ADDRESS not set"
    exit 1
fi

if [ -z "$PEM_CERT_CHAIN_LIB_ADDRESS" ]; then
    echo "Error: PEM_CERT_CHAIN_LIB_ADDRESS not set"
    exit 1
fi

if [ -z "$NEW_OWNER" ]; then
    echo "Error: NEW_OWNER not set (should be timelock controller address)"
    exit 1
fi

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
export LOG_LEVEL=${LOG_LEVEL:-"-vvv"}

# Parameterize block gas limit
export BLOCK_GAS_LIMIT=${BLOCK_GAS_LIMIT:-200000000}

echo "Setting up SGX verifier..."
echo "SGX Verifier address: $SGX_VERIFIER_ADDRESS"
echo "Automata Proxy address: $AUTOMATA_PROXY_ADDRESS"
echo "PEM Cert Chain Lib address: $PEM_CERT_CHAIN_LIB_ADDRESS"
echo "New owner: $NEW_OWNER"

if [ -n "$MR_ENCLAVE" ]; then
    echo "MR Enclave: $MR_ENCLAVE"
fi

if [ -n "$MR_SIGNER" ]; then
    echo "MR Signer: $MR_SIGNER"
fi

if [ -n "$QEID_PATH" ]; then
    echo "QE Identity path: $QEID_PATH"
fi

if [ -n "$TCB_INFO_PATH" ]; then
    echo "TCB Info path: $TCB_INFO_PATH"
fi

if [ -n "$V3_QUOTE_BYTES" ]; then
    echo "V3 Quote bytes provided for instance registration"
fi

# Run the setup script
forge script script/layer1/surge/SetupSGXVerifier.s.sol \
    --fork-url $FORK_URL \
    $BROADCAST_ARG \
    $VERIFY_ARG \
    --ffi \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY \
    --block-gas-limit $BLOCK_GAS_LIMIT

echo "SGX verifier setup completed successfully!"
