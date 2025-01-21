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

# deploy old fork l1 contracts
if [ $DEPLOY_OLD_FORK ];then
    echo "Deploying old fork contracts....."
    git checkout protocol-v1.11.0
    source integration_test/l1_env.sh
    cd ../protocol && pnpm clean && pnpm install &&
    forge script script/layer1/DeployProtocolOnL1.s.sol:DeployProtocolOnL1 \
      --fork-url "$L1_HTTP" \
      --broadcast \
      --ffi \
      -vvvvv \
      --evm-version cancun \
      --private-key "$PRIVATE_KEY" \
      --block-gas-limit 200000000 \
      --legacy
    export OLD_FORK_TAIKO_INBOX=$(echo "$DEPLOYMENT_JSON" | jq '.taiko' | sed 's/\"//g')
    echo "Old fork taiko inbox contract: $OLD_FORK_TAIKO_INBOX"
    git checkout pacaya_fork && pnpm clean && pnpm install && cd ../taiko-client
  else
    echo "Don't deploy old fork contracts"
fi

# deploy l1 contracts
integration_test/deploy_l1_contract.sh

# load environment variables for integration test
source integration_test/test_env.sh

# make sure environment variables are set
check_env "L1_HTTP"
check_env "L1_WS"
check_env "L2_HTTP"
check_env "L2_WS"
check_env "L2_AUTH"
check_env "TAIKO_L1"
check_env "TAIKO_L2"
check_env "TAIKO_TOKEN"
check_env "TIMELOCK_CONTROLLER"
check_env "GUARDIAN_PROVER_CONTRACT"
check_env "GUARDIAN_PROVER_MINORITY"
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
