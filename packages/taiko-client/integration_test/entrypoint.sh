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
check_command "jq"

# Keep L2 Unzen fork active from genesis in the integration test environment, and
# start Anvil from a past timestamp so preconf activation stays behind wall
# clock time during test bootstrap.
if [ -z "${ANVIL_L1_START_TIMESTAMP:-}" ]; then
  NOW=$(date -u +%s)
  export ANVIL_L1_START_TIMESTAMP=$((NOW - 7200))
fi

# Etna activation time shared by the client and the L2 execution engine. alethia-reth runs the
# anchorless Etna fork from genesis; taiko-geth has no Etna consensus rules yet, so its job keeps Etna
# disabled. The boundary job activates Etna one hour after the (past) L1 start timestamp, and its test
# moves L1 time across that boundary.
if [ -z "${TAIKO_DEVNET_ETNA_TIME:-}" ]; then
  if [ "${TAIKO_TEST_ETNA_BOUNDARY:-false}" == "true" ]; then
    export TAIKO_DEVNET_ETNA_TIME=$((ANVIL_L1_START_TIMESTAMP + 3600))
  elif [ "${L2_NODE:-l2_geth}" == "l2_reth" ]; then
    export TAIKO_DEVNET_ETNA_TIME=0
  else
    export TAIKO_DEVNET_ETNA_TIME=18446744073709551615
  fi
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
check_env "TAIKO_ANCHOR"
check_env "L1_CONTRACT_OWNER_PRIVATE_KEY"
check_env "L1_PROPOSER_PRIVATE_KEY"
check_env "L1_PROVER_PRIVATE_KEY"
check_env "TREASURY"
check_env "JWT_SECRET"
check_env "VERBOSITY"
check_env "ANVIL_L1_START_TIMESTAMP"
check_env "TAIKO_DEVNET_ETNA_TIME"

echo "ANVIL_L1_START_TIMESTAMP=$ANVIL_L1_START_TIMESTAMP"
echo "TAIKO_DEVNET_ETNA_TIME=$TAIKO_DEVNET_ETNA_TIME"

RUN_TESTS=${RUN_TESTS:-false}
PACKAGE=${PACKAGE:-...}
GO_TEST_RUN=${GO_TEST_RUN:-}

if [ "$RUN_TESTS" == "true" ]; then
    go test -v -p=1 ./"$PACKAGE" -run "${GO_TEST_RUN:-.}" -coverprofile=coverage.out -covermode=atomic -timeout=700s
else
    echo "💻 Local dev net started"
fi
