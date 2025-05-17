#!/bin/bash

source scripts/common.sh

# Load environment variables for deploying L1 contracts.
source integration_test/l1_env.sh

cd ${PACAYA_FORK_TAIKO_MONO}/packages/protocol &&
  PRIVATE_KEY=$PRIVATE_KEY forge script script/layer1/based/DeployProtocolOnL1.s.sol:DeployProtocolOnL1 \
    --fork-url "$L1_HTTP" \
    --broadcast \
    --ffi \
    -vvvvv \
    --evm-version cancun \
    --private-key "$PRIVATE_KEY" \
    --block-gas-limit 200000000 \
    --legacy &&
  cd -
