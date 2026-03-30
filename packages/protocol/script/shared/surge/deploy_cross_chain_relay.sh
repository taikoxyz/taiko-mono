#!/bin/sh
set -e

export PRIVATE_KEY=${PRIVATE_KEY:?"PRIVATE_KEY required"}
export L2_RPC=${L2_RPC:?"L2_RPC required"}
export FOUNDRY_PROFILE=${FOUNDRY_PROFILE:-"shared"}

echo "================================"
echo "Deploying CrossChainRelay on L2"
echo "================================"

forge script ./script/shared/surge/DeployCrossChainRelay.s.sol:DeployCrossChainRelay \
    --fork-url $L2_RPC \
    --broadcast \
    --evm-version paris \
    --private-key $PRIVATE_KEY \
    -vvvv

echo "Done!"
