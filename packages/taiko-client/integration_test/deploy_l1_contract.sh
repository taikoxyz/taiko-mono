#!/bin/bash

source scripts/common.sh

# load l1 chain deploy contracts environment variables
source integration_test/l1_env.sh

cd ../protocol &&
  forge script script/layer1/DeployProtocolOnL1.s.sol:DeployProtocolOnL1 \
    --fork-url "$L1_HTTP" \
    --broadcast \
    --ffi \
    -vvvvv \
    --evm-version cancun \
    --private-key "$PRIVATE_KEY" \
    --block-gas-limit 100000000 \
    --legacy
