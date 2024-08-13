#!/bin/bash

echo "Deploying contracts"

source scripts/common.sh

# load l1 chain deploy contracts environment variables
source integration_test/l1_env.sh


echo "Deploying contracts 2"

cd ../protocol &&
  forge script script/DeployOnL1.s.sol:DeployOnL1 \
    --fork-url "$L1_NODE_HTTP_ENDPOINT" \
    --broadcast \
    --ffi \
    -vvvvv \
    --evm-version cancun \
    --private-key "$PRIVATE_KEY" \
    --block-gas-limit 100000000 \
    --legacy

echo "Contracts deployed"