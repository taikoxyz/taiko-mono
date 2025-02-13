#!/bin/bash

source scripts/common.sh

# load l1 chain deploy contracts environment variables
source integration_test/l1_env.sh

# Deploy v1.9.1 protocol at first
cd ${OLD_FORK_TAIKO_MONO}/packages/protocol &&
  forge script script/layer1/DeployProtocolOnL1.s.sol:DeployProtocolOnL1 \
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
DEPLOYMENT_JSON=$(cat ${OLD_FORK_TAIKO_MONO}/packages/protocol/deployments/deploy_l1.json)
export OLD_FORK=0x1291Be112d480055DaFd8a610b7d1e203891C274
export TAIKO_INBOX=$(echo "$DEPLOYMENT_JSON" | jq '.taiko' | sed 's/\"//g')
export ROLLUP_RESOLVER=$(echo "$DEPLOYMENT_JSON" | jq '.rollup_address_manager' | sed 's/\"//g')
export PROVER_SET=$(echo "$DEPLOYMENT_JSON" | jq '.prover_set' | sed 's/\"//g')
export TAIKO_TOKEN=$(echo "$DEPLOYMENT_JSON" | jq '.taiko_token' | sed 's/\"//g')
export SGX_VERIFIER=$(echo "$DEPLOYMENT_JSON" | jq '.tier_sgx' | sed 's/\"//g')
export RISC0_VERIFIER=$(echo "$DEPLOYMENT_JSON" | jq '.tier_zkvm_risc0' | sed 's/\"//g')
export SP1_VERIFIER=$(echo "$DEPLOYMENT_JSON" | jq '.tier_zkvm_sp1' | sed 's/\"//g')
export SHARED_RESOLVER=$(echo "$DEPLOYMENT_JSON" | jq '.shared_address_manager' | sed 's/\"//g')
export BRIDGE_L1=$(echo "$DEPLOYMENT_JSON" | jq '.bridge' | sed 's/\"//g')
export SIGNAL_SERVICE=$(echo "$DEPLOYMENT_JSON" | jq '.signal_service' | sed 's/\"//g')
export ERC20_VAULT=$(echo "$DEPLOYMENT_JSON" | jq '.erc20_vault' | sed 's/\"//g')
export ERC721_VAULT=$(echo "$DEPLOYMENT_JSON" | jq '.erc721_vault' | sed 's/\"//g')
export ERC1155_VAULT=$(echo "$DEPLOYMENT_JSON" | jq '.erc1155_vault' | sed 's/\"//g')
export QUOTA_MANAGER=0x0000000000000000000000000000000000000000

cd ../protocol &&
  PRIVATE_KEY=$PRIVATE_KEY forge script script/layer1/devnet/UpgradeDevnetPacayaL1.s.sol:UpgradeDevnetPacayaL1 \
    --fork-url "$L1_HTTP" \
    --broadcast \
    --ffi \
    -vvvvv \
    --evm-version cancun \
    --private-key "$PRIVATE_KEY" \
    --block-gas-limit 200000000 \
    --legacy
