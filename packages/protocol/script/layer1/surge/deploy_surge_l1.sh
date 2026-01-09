#!/bin/sh

# This script deploys the Surge protocol on L1
set -e

# Deployer private key
export PRIVATE_KEY=${PRIVATE_KEY:-"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"}

# Network configuration
export FORK_URL=${FORK_URL:-"http://localhost:8545"}

# Contract owner configuration
export CONTRACT_OWNER=${CONTRACT_OWNER:-"0x70997970C51812dc3A010C7d01b50e0d17dc79C8"}

# L2 configuration
export L2_CHAIN_ID=${L2_CHAIN_ID:-167004}

# Verifier deployment flags (only RISC0 and SP1)
export DEPLOY_RISC0_RETH_VERIFIER=${DEPLOY_RISC0_RETH_VERIFIER:-true}
export DEPLOY_SP1_RETH_VERIFIER=${DEPLOY_SP1_RETH_VERIFIER:-true}

# Use dummy verifier for testing (default: false for production, set to true for devnet testing)
export USE_DUMMY_VERIFIER=${USE_DUMMY_VERIFIER:-false}

# Signer address for ProofVerifierDummy (required if USE_DUMMY_VERIFIER=true)
# This is wallet address of the key that is used to sign commitments
export DUMMY_VERIFIER_SIGNER=${DUMMY_VERIFIER_SIGNER:-"0x0000000000000000000000000000000000000000"}

# Inbox configuration
# ---------------------------------------------------------------
# Proving window in seconds (default: 2 hours)
export PROVING_WINDOW=${PROVING_WINDOW:-7200}

# Maximum delay allowed between consecutive proofs to still be on time (default: 4 hours)
export MAX_PROOF_SUBMISSION_DELAY=${MAX_PROOF_SUBMISSION_DELAY:-14400}

# Ring buffer size for storing proposal hashes
export RING_BUFFER_SIZE=${RING_BUFFER_SIZE:-16000}

# Percentage of basefee paid to coinbase (0-100, default: 75 for devnet)
export BASEFEE_SHARING_PCTG=${BASEFEE_SHARING_PCTG:-75}

# Minimum number of forced inclusions to process if due
export MIN_FORCED_INCLUSION_COUNT=${MIN_FORCED_INCLUSION_COUNT:-1}

# Delay for forced inclusions in seconds (default: 0 for devnet)
export FORCED_INCLUSION_DELAY=${FORCED_INCLUSION_DELAY:-0}

# Base fee for forced inclusions in Gwei (default: 10,000,000 = 0.01 ETH)
export FORCED_INCLUSION_FEE_IN_GWEI=${FORCED_INCLUSION_FEE_IN_GWEI:-10000000}

# Queue size at which the fee doubles
export FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD=${FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD:-50}

# Minimum delay between checkpoints in seconds (default: 384 seconds = 1 epoch)
export MIN_CHECKPOINT_DELAY=${MIN_CHECKPOINT_DELAY:-384}

# Multiplier for permissionless inclusion window
export PERMISSIONLESS_INCLUSION_MULTIPLIER=${PERMISSIONLESS_INCLUSION_MULTIPLIER:-5}

# Finalization streak configuration
# ---------------------------------------------------------------
# Maximum grace period after which the finalization streak is reset
# Default: 1 hour (3600 seconds)
export MAX_FINALIZATION_DELAY_BEFORE_STREAK_RESET=${MAX_FINALIZATION_DELAY_BEFORE_STREAK_RESET:-3600}

# Rollback configuration
# ---------------------------------------------------------------
# Maximum grace period after which the chain can be rollbacked to the last finalized proposal
# Default: 7 days (604800 seconds)
export MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK=${MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK:-604800}

# SurgeVerifier configuration
# ---------------------------------------------------------------
# Minimum number of distinct proofs required for a transition to finalize
export NUM_PROOFS_THRESHOLD=${NUM_PROOFS_THRESHOLD:-2}

# Timelock configuration (optional)
# ---------------------------------------------------------------
# Set to true to deploy SurgeTimelockController as the owner of all contracts
export USE_TIMELOCK=${USE_TIMELOCK:-false}

# Minimum delay for timelock proposals in seconds (default: 1 day)
export TIMELOCK_MIN_DELAY=${TIMELOCK_MIN_DELAY:-86400}

# Minimum finalization streak required before timelock execution is allowed (default: 7 days)
export TIMELOCK_MIN_FINALIZATION_STREAK=${TIMELOCK_MIN_FINALIZATION_STREAK:-604800}

# Comma-separated list of proposer addresses
export TIMELOCK_PROPOSERS=${TIMELOCK_PROPOSERS:-""}

# Comma-separated list of executor addresses
export TIMELOCK_EXECUTORS=${TIMELOCK_EXECUTORS:-""}

# Deploy Surge protocol
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
export LOG_LEVEL=${LOG_LEVEL:-"-vvv"}

# Parameterize block gas limit
export BLOCK_GAS_LIMIT=${BLOCK_GAS_LIMIT:-200000000}

forge script ./script/layer1/surge/DeploySurgeL1.s.sol:DeploySurgeL1 \
    --fork-url $FORK_URL \
    $BROADCAST_ARG \
    $VERIFY_ARG \
    --ffi \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY \
    --block-gas-limit $BLOCK_GAS_LIMIT
