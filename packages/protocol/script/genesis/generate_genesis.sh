#!/bin/sh

# This script generates the L2 genesis configuration
set -e

# Contract owner configuration
# ---------------------------------------------------------------
# Owner address of the pre-deployed L2 contracts
export CONTRACT_OWNER=${CONTRACT_OWNER:-"0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39"}

# Chain ID configuration
# ---------------------------------------------------------------
# Chain ID of the Taiko L2 network
export CHAIN_ID=${CHAIN_ID:-167}

# Chain ID of the L1 network
export L1_CHAIN_ID=${L1_CHAIN_ID:-31337}

# Seeding configuration
# ---------------------------------------------------------------
# Seed account address (default: zero address)
export SEED_ADDRESS=${SEED_ADDRESS:-"0x0000000000000000000000000000000000000000"}

# Seed account pre-mint ETH amount (default: 1000)
export SEED_AMOUNT=${SEED_AMOUNT:-1000}

# Bond configuration
# ---------------------------------------------------------------
# Liveness bond amount in wei (default: 128 ETH)
export LIVENESS_BOND=${LIVENESS_BOND:-"128000000000000000000"}

# Withdrawal delay in seconds (default: 1 hour)
export WITHDRAWAL_DELAY=${WITHDRAWAL_DELAY:-3600}

# Minimum bond amount in wei (default: 0)
export MIN_BOND=${MIN_BOND:-0}

# Bond token address (default: zero address for native ETH)
export BOND_TOKEN=${BOND_TOKEN:-"0x0000000000000000000000000000000000000000"}

# External service configuration
# ---------------------------------------------------------------
# L1 signal service address
export REMOTE_SIGNAL_SERVICE=${REMOTE_SIGNAL_SERVICE:-"0x0000000000000000000000000000000000000000"}

# Navigate to protocol directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROTOCOL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROTOCOL_DIR"

echo "=== Genesis Configuration ==="
echo "CONTRACT_OWNER: $CONTRACT_OWNER"
echo "CHAIN_ID: $CHAIN_ID"
echo "L1_CHAIN_ID: $L1_CHAIN_ID"
echo "LIVENESS_BOND: $LIVENESS_BOND"
echo "WITHDRAWAL_DELAY: $WITHDRAWAL_DELAY"
echo "MIN_BOND: $MIN_BOND"
echo "BOND_TOKEN: $BOND_TOKEN"
echo "REMOTE_SIGNAL_SERVICE: $REMOTE_SIGNAL_SERVICE"
echo "============================="

# Run genesis generation
pnpm genesis:gen

