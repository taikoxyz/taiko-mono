#!/bin/sh

# This script is only used by `pnpm test:deploy:l1`.
set -e

forge script ./script/layer1/DeployProtocolOnL1.s.sol:DeployProtocolOnL1 \
    --fork-url $FORK_URL \
    --broadcast \
    --ffi \
    -vvvv \
    --private-key $PRIVATE_KEY \
    --block-gas-limit 200000000

forge script ./script/layer1/DeployTaikoToken.s.sol:DeployTaikoToken \
    --fork-url $FORK_URL \
    --broadcast \
    --skip-simulation \
    --ffi \
    -vvvv \
    --private-key $PRIVATE_KEY \
    --block-gas-limit 200000000
