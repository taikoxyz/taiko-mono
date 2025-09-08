#!/bin/bash

source scripts/common.sh

# Load environment variables for deploying L1 contracts.
source integration_test/l1_env.sh

cd ../protocol &&
  FOUNDRY_AUTO_CONFIRM=1 PRIVATE_KEY=$PRIVATE_KEY forge script script/layer1/based/DeployProtocolOnL1.s.sol:DeployProtocolOnL1 \
    --fork-url "$L1_HTTP" \
    --broadcast \
    --ffi \
    --disable-code-size-limit \
    -vvvvv \
    --evm-version cancun \
    --private-key "$PRIVATE_KEY" \
    --block-gas-limit 200000000 \
    --legacy &&
  cd -
