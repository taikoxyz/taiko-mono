#!/bin/bash

set -eou pipefail

# load tool commands.
source scripts/common.sh

# make sure all the commands are available.
check_command "cast"
check_command "forge"
check_command "docker"

# start and stop docker compose
internal/docker/start.sh
trap "internal/docker/stop.sh" EXIT INT KILL ERR

# deploy l1 contracts
integration_test/deploy_l1_contract.sh

# load environment variables for integration test
source integration_test/test_env.sh

# make sure environment variables are set
check_env "L1_NODE_HTTP_ENDPOINT"
check_env "L1_NODE_WS_ENDPOINT"
check_env "L2_EXECUTION_ENGINE_HTTP_ENDPOINT"
check_env "L2_EXECUTION_ENGINE_WS_ENDPOINT"
check_env "L2_EXECUTION_ENGINE_AUTH_ENDPOINT"
check_env "TAIKO_L1_ADDRESS"
check_env "TAIKO_L2_ADDRESS"
check_env "TAIKO_TOKEN_ADDRESS"
check_env "TIMELOCK_CONTROLLER"
check_env "ROLLUP_ADDRESS_MANAGER_CONTRACT_ADDRESS"
check_env "GUARDIAN_PROVER_CONTRACT_ADDRESS"
check_env "GUARDIAN_PROVER_MINORITY_ADDRESS"
check_env "SEQUENCER_REGISTRY_ADDRESS"
check_env "L1_CONTRACT_OWNER_PRIVATE_KEY"
check_env "L1_SECURITY_COUNCIL_PRIVATE_KEY"
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
