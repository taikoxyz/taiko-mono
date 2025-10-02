#!/bin/bash

set -eou pipefail

# Load tool commands
source scripts/common.sh

# Make sure all the commands are available
check_command "cast"
check_command "forge"
check_command "docker"

# Start and stop docker-compose
internal/docker/start.sh
trap "internal/docker/stop.sh" EXIT INT KILL ERR

# Deploy L1 contracts
integration_test/deploy_l1_contract.sh

# Load environment variables for the upcoming integration tests
source integration_test/test_env.sh

# Make sure environment variables are set
check_env "L1_HTTP"
check_env "L1_WS"
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

RUN_TESTS=${RUN_TESTS:-false}
PACKAGE=${PACKAGE:-...}

if [ "$RUN_TESTS" == "true" ]; then
    go test -v -p=1 ./"$PACKAGE" -coverprofile=coverage.out -covermode=atomic -timeout=700s
else
    echo "💻 Local dev net started"
fi
