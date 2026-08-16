#!/bin/bash

set -euo pipefail

echo "Deploying protocol contracts on L1..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTOCOL_DIR="${PROTOCOL_DIR:-$SCRIPT_DIR/../../protocol}"

# PRIVATE_KEY is exported by entrypoint.sh and read directly by the script via
# vm.envUint("PRIVATE_KEY") for vm.startBroadcast, so no --private-key flag or
# inline re-export is needed here.
cd "${PROTOCOL_DIR}" &&
  FOUNDRY_PROFILE=layer1 forge script script/layer1/core/DeployProtocolOnL1.s.sol:DeployProtocolOnL1 \
    --fork-url "$HARNESS_L1_HTTP" \
    --broadcast \
    --ffi \
    --block-gas-limit 200000000
