#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

source "$PROJECT_ROOT/scripts/common.sh"

# Load environment variables for deploying L1 contracts.
source "$SCRIPT_DIR/l1_env.sh"

PROTOCOL_DIR="${PROTOCOL_DIR:-$PROJECT_ROOT/../protocol}"

cd "${PROTOCOL_DIR}" &&
  FOUNDRY_PROFILE=layer1 PRIVATE_KEY=$PRIVATE_KEY forge script script/layer1/core/DeployProtocolOnL1.s.sol:DeployProtocolOnL1 \
    --fork-url "$L1_HTTP" \
    --broadcast \
    --ffi \
    --private-key "$PRIVATE_KEY" \
    --block-gas-limit 200000000 &&
  cd -

# Get deployed contract address.
DEPLOYMENT_JSON=$(cat "${PROTOCOL_DIR}/deployments/deploy_l1.json")
export INBOX=$(echo "$DEPLOYMENT_JSON" | jq '.shasta_inbox' | sed 's/\"//g')
export SHARED_RESOLVER=$(echo "$DEPLOYMENT_JSON" | jq '.shared_resolver' | sed 's/\"//g')
export PROPOSER_ADDRESS=0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc
export PRECONF_WHITELIST=0x0000000000000000000000000000000000000000
export REMOTE_SIGNAL_SERVICE=0x1670010000000000000000000000000000000005

printf "L1 contracts deployed:
  Inbox: $INBOX
  SharedAddressManager: $SHARED_RESOLVER
"
