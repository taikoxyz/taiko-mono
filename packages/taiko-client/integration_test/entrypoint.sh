#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# Load tool commands
source "$PROJECT_ROOT/scripts/common.sh"

# Make sure all the commands are available
check_command "cast"
check_command "forge"
check_command "docker"
# jq is required for NMC to dynamically inject shastaTimestamp into chainspec
if [ "${L2_NODE:-}" == "l2_nmc" ]; then
  check_command "jq"
fi

# Keep L2 Shasta active from genesis in the integration test environment, and
# start Anvil from a past timestamp so preconf activation stays behind wall
# clock time during test bootstrap.
if [ -z "${ANVIL_L1_START_TIMESTAMP:-}" ]; then
  NOW=$(date -u +%s)
  export ANVIL_L1_START_TIMESTAMP=$((NOW - 7200))
fi

# Start and stop docker-compose
trap "$PROJECT_ROOT/internal/docker/stop.sh" EXIT INT KILL ERR
"$PROJECT_ROOT/internal/docker/start.sh"

# Deploy L1 contracts
"$SCRIPT_DIR/deploy_l1_contract.sh"

# Load environment variables for the upcoming integration tests
source "$SCRIPT_DIR/test_env.sh"

# Make sure environment variables are set
check_env "L1_HTTP"
check_env "L1_WS"
check_env "L2_HTTP"
check_env "L2_WS"
check_env "L2_AUTH"
check_env "INBOX"
check_env "TAIKO_WRAPPER"
check_env "FORCED_INCLUSION_STORE"
check_env "TAIKO_ANCHOR"
check_env "L1_CONTRACT_OWNER_PRIVATE_KEY"
check_env "L1_PROPOSER_PRIVATE_KEY"
check_env "L1_PROVER_PRIVATE_KEY"
check_env "TREASURY"
check_env "JWT_SECRET"
check_env "VERBOSITY"
check_env "ANVIL_L1_START_TIMESTAMP"

echo "ANVIL_L1_START_TIMESTAMP=$ANVIL_L1_START_TIMESTAMP"

RUN_TESTS=${RUN_TESTS:-false}
PACKAGE=${PACKAGE:-...}

if [ "$RUN_TESTS" == "true" ]; then
    go test -v -p=1 ./"$PACKAGE" -coverprofile=coverage.out -covermode=atomic -timeout=700s
else
    echo "💻 Local dev net started"
fi
