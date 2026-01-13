#!/bin/sh

# This script is only used by `pnpm test:deploy:l1`.
set -e

export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export L2_CHAIN_ID=167001
export TAIKO_TOKEN=0x0000000000000000000000000000000000000000
export PROVER_AUCTION=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
export OLD_FORK_TAIKO_INBOX=0x0000000000000000000000000000000000000000
export TAIKO_ANCHOR_ADDRESS=0x1000777700000000000000000000000000000001
export L2_SIGNAL_SERVICE=0x1000777700000000000000000000000000000007
export TAIKO_TOKEN_PREMINT_RECIPIENT=0xa0Ee7A142d267C1f36714E4a8F75612F20a79720
export TAIKO_TOKEN_NAME="Taiko Token Test"
export TAIKO_TOKEN_SYMBOL=TTKOk
export SHARED_RESOLVER=0x0000000000000000000000000000000000000000
export L2_GENESIS_HASH=0xee1950562d42f0da28bd4550d88886bc90894c77c9c9eaefef775d4c8223f259
export PAUSE_BRIDGE=true
export FOUNDRY_PROFILE="layer1"
export DEPLOY_PRECONF_CONTRACTS=false
export PRECONF_INBOX=false
export PRECONF_ROUTER=false
export INCLUSION_WINDOW=24
export INCLUSION_FEE_IN_GWEI=100
export DUMMY_VERIFIERS=true
export PROPOSER_ADDRESS=0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc
export SECURITY_COUNCIL=0x60997970C51812dc3A010C7d01b50e0d17dc79C8
export CONTRACT_OWNER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export DUMMY_VERIFIERS=true
export ACTIVATE_INBOX=true
export PROPOSER_ADDRESS=0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc \


FOUNDRY_PROFILE="layer1" \
forge script ./script/layer1/core/DeployTaikoToken.s.sol:DeployTaikoToken \
    --fork-url http://localhost:8545 \
    --broadcast \
    --ffi \
    -vvvv \
    --private-key $PRIVATE_KEY \
    --block-gas-limit 200000000

FOUNDRY_PROFILE="layer1" \
forge script ./script/layer1/core/DeployProtocolOnL1.s.sol:DeployProtocolOnL1 \
    --fork-url http://localhost:8545 \
    --broadcast \
    --ffi \
    -vvvv \
    --private-key $PRIVATE_KEY \
    --block-gas-limit 200000000
