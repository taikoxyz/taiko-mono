#!/bin/bash

set -euo pipefail

echo "Deploying protocol contracts on L1..."

cd ../protocol &&
  FOUNDRY_PROFILE=layer1 PRIVATE_KEY=$PRIVATE_KEY forge script script/layer1/core/DeployProtocolOnL1.s.sol:DeployProtocolOnL1 \
    --fork-url "$L1_HTTP" \
    --broadcast \
    --ffi \
    -vvvvv \
    --private-key "$PRIVATE_KEY" \
    --block-gas-limit 200000000 \
    --legacy
