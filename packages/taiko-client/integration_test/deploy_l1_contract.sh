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

# Get deployed contract address.
DEPLOYMENT_JSON=$(cat ${PACAYA_FORK_TAIKO_MONO}/packages/protocol/deployments/deploy_l1.json)
export INBOX=$(echo "$DEPLOYMENT_JSON" | jq '.taiko' | sed 's/\"//g')
export SHARED_RESOLVER=$(echo "$DEPLOYMENT_JSON" | jq '.shared_resolver' | sed 's/\"//g')
export PROPOSER_ADDRESS=0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc

cat "L1 contracts deployed:
  TaikoInbox: $INBOX
  SharedAddressManager: $SHARED_RESOLVER
"

cd ../protocol &&
  FOUNDRY_PROFILE=layer1o PRIVATE_KEY=$PRIVATE_KEY forge script script/layer1/devnet/UpgradeShastaL1.s.sol:UpgradeShastaL1 \
    --fork-url "$L1_HTTP" \
    --broadcast \
    --ffi \
    -vvvvv \
    --private-key "$PRIVATE_KEY" \
    --block-gas-limit 200000000 \
    --legacy
