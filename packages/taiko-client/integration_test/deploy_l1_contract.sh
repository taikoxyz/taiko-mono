#!/bin/bash

source scripts/common.sh

# load l1 chain deploy contracts environment variables
source integration_test/l1_env.sh

cd ../protocol &&
  forge script script/DeployOnL1.s.sol:DeployOnL1 \
    --fork-url "$L1_HTTP" \
    --broadcast \
    --ffi \
    -vvvvv \
    --evm-version cancun \
    --private-key "$PRIVATE_KEY" \
    --block-gas-limit 100000000 \
    --legacy
