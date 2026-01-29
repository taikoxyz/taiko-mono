#!/bin/sh

# This script deploys UserOpsSubmitterFactory and optionally creates a UserOpsSubmitter via the factory.
# If OWNER_ADDRESS is set, it will create a submitter for that owner.
set -e

# Private key for deployment
export PRIVATE_KEY=${PRIVATE_KEY:-"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"}

# Network configuration
export FORK_URL=${FORK_URL:-"http://localhost:8545"}

# Owner address for the UserOpsSubmitter (optional)
# If not set, only the factory will be deployed
export OWNER_ADDRESS=${OWNER_ADDRESS:-""}

# Broadcast transactions
export BROADCAST=${BROADCAST:-false}

# Parameterize broadcasting
export BROADCAST_ARG=""
if [ "$BROADCAST" = "true" ]; then
    BROADCAST_ARG="--broadcast"
fi

# Parameterize log level
export LOG_LEVEL=${LOG_LEVEL:-"-vvvv"}

echo "=====================================";
echo "Deploying UserOpsSubmitterFactory";
if [ -n "$OWNER_ADDRESS" ]; then
    echo "Owner address for submitter: $OWNER_ADDRESS"
fi
echo "=====================================";
echo ""

if [ "$BROADCAST" = "true" ]; then
    echo "Running in BROADCAST mode - transactions will be executed"
else
    echo "Running in SIMULATION mode - set BROADCAST=true to execute transactions"
fi
echo ""

forge script ./script/shared/surge/DeployUserOpsSubmitter.s.sol:DeployUserOpsSubmitter \
    --fork-url $FORK_URL \
    $BROADCAST_ARG \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY
