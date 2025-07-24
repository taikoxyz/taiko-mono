#!/bin/bash

# Generate go contract bindings.
# ref: https://geth.ethereum.org/docs/dapp/native-bindings

set -eou pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

echo ""
echo "TAIKO_GETH_DIR: ${TAIKO_GETH_DIR}"
echo ""

cd ${TAIKO_GETH_DIR} &&
  make all &&
  cd -

cd ../protocol &&
  pnpm clean &&
  pnpm compile &&
  cd -

ABIGEN_BIN=$TAIKO_GETH_DIR/build/bin/abigen
FORK=pacaya

echo ""
echo "PROTOCOL_FORK_NAME: ${FORK}"
echo ""

echo ""
echo "Start generating Go contract bindings..."
echo ""

cat ../protocol/out/layer1/TaikoWrapper.sol/TaikoWrapper.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type TaikoWrapperClient --pkg ${FORK} --out $DIR/../bindings/${FORK}/gen_taiko_wrapper.go

cat ../protocol/out/layer1/ForcedInclusionStore.sol/ForcedInclusionStore.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type ForcedInclusionStore --pkg ${FORK} --out $DIR/../bindings/${FORK}/gen_forced_inclusion_store.go

cat ../protocol/out/layer1/TaikoInbox.sol/TaikoInbox.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type TaikoInboxClient --pkg ${FORK} --out $DIR/../bindings/${FORK}/gen_taiko_inbox.go

cat ../protocol/out/layer2/TaikoAnchor.sol/TaikoAnchor.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type TaikoAnchorClient --pkg ${FORK} --out $DIR/../bindings/${FORK}/gen_taiko_anchor.go

cat ../protocol/out/layer1/TaikoToken.sol/TaikoToken.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type TaikoToken --pkg ${FORK} --out $DIR/../bindings/${FORK}/gen_taiko_token.go

cat ../protocol/out/layer1/ResolverBase.sol/ResolverBase.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type ResolverBase --pkg ${FORK} --out $DIR/../bindings/${FORK}/gen_resolver_base.go

cat ../protocol/out/layer1/ProverSet.sol/ProverSet.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type ProverSet --pkg ${FORK} --out $DIR/../bindings/${FORK}/gen_prover_set.go

cat ../protocol/out/layer1/ForkRouter.sol/ForkRouter.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type ForkRouter --pkg ${FORK} --out $DIR/../bindings/${FORK}/gen_fork_router.go

cat ../protocol/out/layer1/SurgeVerifier.sol/SurgeVerifier.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type SurgeVerifier --pkg ${FORK} --out $DIR/../bindings/${FORK}/gen_surge_verifier.go

cat ../protocol/out/layer1/PreconfWhitelist.sol/PreconfWhitelist.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type PreconfWhitelist --pkg ${FORK} --out $DIR/../bindings/${FORK}/gen_preconf_whitelist.go

cat ../protocol/out/layer1/SurgeProposerWrapper.sol/SurgeProposerWrapper.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type SurgeProposerWrapper --pkg ${FORK} --out $DIR/../bindings/${FORK}/gen_surge_proposer_wrapper.go

git -C ../../ log --format="%H" -n 1 >./bindings/${FORK}/.githead

echo "🍻 Go contract bindings generated!"
