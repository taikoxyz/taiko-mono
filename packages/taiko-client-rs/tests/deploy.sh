#!/bin/bash

set -euo pipefail

echo "Deploying protocol contracts on L1..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTOCOL_DIR="${PROTOCOL_DIR:-$SCRIPT_DIR/../../protocol}"

# PRIVATE_KEY is exported by entrypoint.sh. The script reads it via
# vm.envUint("PRIVATE_KEY") for vm.startBroadcast, and it must also be passed as
# --private-key so forge runs the script with the broadcaster as msg.sender from
# the first simulation pass, like the Go harness and the protocol deploy scripts.
# Without it forge uses its default sender and, since Foundry 1.8.3, aborts with
# "Usage of `msg.sender` inside a `broadcast`" because DeployProtocolOnL1 reads
# msg.sender under the broadcast.
cd "${PROTOCOL_DIR}" &&
  FOUNDRY_PROFILE=layer1 forge script script/layer1/core/DeployProtocolOnL1.s.sol:DeployProtocolOnL1 \
    --fork-url "$HARNESS_L1_HTTP" \
    --broadcast \
    --ffi \
    --private-key "$PRIVATE_KEY" \
    --block-gas-limit 200000000
