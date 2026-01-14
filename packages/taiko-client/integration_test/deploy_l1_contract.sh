#!/bin/bash

source scripts/common.sh

# Load environment variables for deploying L1 contracts.
source integration_test/l1_env.sh

cd ${PACAYA_FORK_TAIKO_MONO}/packages/protocol &&
  PRIVATE_KEY=$PRIVATE_KEY forge script script/layer1/based/DeployProtocolOnL1.s.sol:DeployProtocolOnL1 \
    --fork-url "$L1_HTTP" \
    --broadcast \
    --ffi \
    --evm-version cancun \
    --private-key "$PRIVATE_KEY" \
    --block-gas-limit 200000000 \
    --legacy &&
  cd -

# Get deployed contract address.
DEPLOYMENT_JSON=$(cat ${PACAYA_FORK_TAIKO_MONO}/packages/protocol/deployments/deploy_l1.json)
export INBOX=$(echo "$DEPLOYMENT_JSON" | jq '.taiko' | sed 's/\"//g')
export SHARED_RESOLVER=$(echo "$DEPLOYMENT_JSON" | jq '.shared_resolver' | sed 's/\"//g')
export PROPOSER_ADDRESS=0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc
export PRECONF_WHITELIST=0x0000000000000000000000000000000000000000
export REMOTE_SIGNAL_SERVICE=0x1670010000000000000000000000000000000005

cat "L1 contracts deployed:
  PacayaTaikoInbox: $INBOX
  SharedAddressManager: $SHARED_RESOLVER
"

cd ${SHASTA_FORK_TAIKO_MONO}/packages/protocol &&
  FOUNDRY_PROFILE=layer1 PRIVATE_KEY=$PRIVATE_KEY forge script script/layer1/core/DeployProtocolOnL1.s.sol:DeployProtocolOnL1 \
    --fork-url "$L1_HTTP" \
    --broadcast \
    --ffi \
    --private-key "$PRIVATE_KEY" \
    --block-gas-limit 200000000
