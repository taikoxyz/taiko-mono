#!/bin/bash

set -eou pipefail

# load tool commands.
source integration_test/common.sh

# make sure all the commands are available.
check_command "cast"
check_command "forge"
check_command "docker"

# start and stop docker compose
integration_test/docker/start.sh
trap "integration_test/docker/stop.sh" EXIT INT KILL ERR

echo "docker compose finished"

# deploy l1 contracts
integration_test/deploy_l1_contract.sh

echo "l1 contracts deployed"

# load environment variables for integration test
source integration_test/test_env.sh

# make sure environment variables are set

PACKAGE=${PACKAGE:-...}

go test -v -p=1 ./"$PACKAGE" -coverprofile=coverage.out -covermode=atomic -timeout=700s