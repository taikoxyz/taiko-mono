#!/bin/sh

# This script is only used by `pnpm deploy:foundry`.
set -e
: "${FORK_URL:=http://localhost:8545}"

forge script script/upgrade/Upgrade$CONTRACT.s.sol:Upgrade$CONTRACT \
    --fork-url $FORK_URL \
    --broadcast \
    --ffi \
    -vvvv