#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ZERO_ADDRESS="0x0000000000000000000000000000000000000000"

: "${L1_RPC_URL:?L1_RPC_URL is required}"
: "${L2_RPC_URL:?L2_RPC_URL is required}"
: "${USDC_ADMIN:?USDC_ADMIN is required}"
: "${L1_USDC_TOKEN:?L1_USDC_TOKEN is required}"
: "${L1_USDC_FAUCET:?L1_USDC_FAUCET is required}"
: "${L2_USDC_TOKEN:?L2_USDC_TOKEN is required}"
: "${FAUCET_CLAIM_AMOUNT:?FAUCET_CLAIM_AMOUNT is required}"

EXPECTED_PRE_MAPPED_TOKEN="${EXPECTED_PRE_MAPPED_TOKEN:-$ZERO_ADDRESS}"

cd "$ROOT_DIR"

echo "Validating L1 Hoodi USDC deployment"
FOUNDRY_PROFILE=layer1 forge script \
  script/layer1/hoodi/ValidateHoodiL1USDC.s.sol:ValidateHoodiL1USDC \
  --fork-url "$L1_RPC_URL"

echo "Validating L2 Hoodi USDC deployment preconditions"
EXPECTED_BRIDGED_TOKEN="$EXPECTED_PRE_MAPPED_TOKEN" \
FOUNDRY_PROFILE=layer2 forge script \
  script/layer2/hoodi/ValidateHoodiL2USDC.s.sol:ValidateHoodiL2USDC \
  --fork-url "$L2_RPC_URL"

echo "Dry-running Hoodi ERC20 vault mapping and unpause"
BROADCAST_CHANGES=0 \
FOUNDRY_PROFILE=layer2 forge script \
  script/layer2/hoodi/ConfigureHoodiUSDCBridge.s.sol:ConfigureHoodiUSDCBridge \
  --fork-url "$L2_RPC_URL"
