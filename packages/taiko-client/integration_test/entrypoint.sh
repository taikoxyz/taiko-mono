#!/bin/bash

set -eou pipefail

# Load tool commands
source scripts/common.sh

# Make sure all the commands are available
check_command "cast"
check_command "forge"
check_command "docker"

# Ensure Shasta fork activation times are set for taiko-geth (L2) and Anvil (L1).
if [ -z "${TAIKO_INTERNAL_SHASTA_TIME:-}" ] || [ -z "${ANVIL_INTERNAL_SHASTA_TIME:-}" ]; then
  # Set L2 Shsata fork activation time to current timestamp - 1 hour, and make the L1 timestamp one hour earlier.
  NOW=$(date -u +%s)
  export TAIKO_INTERNAL_SHASTA_TIME=$((NOW - 3600))
  export ANVIL_INTERNAL_SHASTA_TIME=$((NOW - 7200))
fi

# Start and stop docker-compose
internal/docker/start.sh
trap "internal/docker/stop.sh" EXIT INT KILL ERR

# Deploy L1 contracts
integration_test/deploy_l1_contract.sh

# Load environment variables for the upcoming integration tests
source integration_test/test_env.sh

# Make sure environment variables are set
check_env "L1_HTTP"
check_env "L1_BEACON"
check_env "L2_HTTP"
check_env "L2_WS"
check_env "L2_AUTH"
check_env "PACAYA_INBOX"
check_env "SHASTA_INBOX"
check_env "TAIKO_WRAPPER"
check_env "FORCED_INCLUSION_STORE"
check_env "PROVER_SET"
check_env "TAIKO_ANCHOR"
check_env "TAIKO_TOKEN"
check_env "L1_CONTRACT_OWNER_PRIVATE_KEY"
check_env "L1_PROPOSER_PRIVATE_KEY"
check_env "L1_PROVER_PRIVATE_KEY"
check_env "TREASURY"
check_env "JWT_SECRET"
check_env "VERBOSITY"
check_env "TAIKO_INTERNAL_SHASTA_TIME"
check_env "ANVIL_INTERNAL_SHASTA_TIME"

echo "TAIKO_INTERNAL_SHASTA_TIME=$TAIKO_INTERNAL_SHASTA_TIME"
echo "ANVIL_INTERNAL_SHASTA_TIME=$ANVIL_INTERNAL_SHASTA_TIME"

RUN_TESTS=${RUN_TESTS:-false}
PACKAGE=${PACKAGE:-...}

if [ "$RUN_TESTS" == "true" ]; then
    go test -v -p=1 ./"$PACKAGE" -coverprofile=coverage.out -covermode=atomic -timeout=700s
else
    echo "💻 Local dev net started"
fi
