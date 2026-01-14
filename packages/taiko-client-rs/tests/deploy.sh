#!/bin/bash

set -euo pipefail

echo "Deploying protocol contracts on L1..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTOCOL_DIR="${PROTOCOL_DIR:-$SCRIPT_DIR/../protocol}"

cd "${PROTOCOL_DIR}" &&
  FOUNDRY_PROFILE=layer1 PRIVATE_KEY=$PRIVATE_KEY forge script script/layer1/core/DeployProtocolOnL1.s.sol:DeployProtocolOnL1 \
    --fork-url "$L1_HTTP" \
    --broadcast \
    --ffi \
    --private-key "$PRIVATE_KEY" \
    --block-gas-limit 200000000 \
