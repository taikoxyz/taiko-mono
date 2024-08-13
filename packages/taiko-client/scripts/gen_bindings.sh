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

echo ""
echo "Start generating go contract bindings..."
echo ""

cat ../protocol/out/TaikoL1.sol/TaikoL1.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type TaikoL1Client --pkg bindings --out $DIR/../bindings/v2/gen_taiko_l1.go

cat ../protocol/out/LibProving.sol/LibProving.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type LibProving --pkg bindings --out $DIR/../bindings/v2/gen_lib_proving.go

cat ../protocol/out/LibProposing.sol/LibProposing.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type LibProposing --pkg bindings --out $DIR/../bindings/v2/gen_lib_proposing.go

cat ../protocol/out/LibUtils.sol/LibUtils.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type LibUtils --pkg bindings --out $DIR/../bindings/v2/gen_lib_utils.go

cat ../protocol/out/LibVerifying.sol/LibVerifying.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type LibVerifying --pkg bindings --out $DIR/../bindings/v2/gen_lib_verifying.go

cat ../protocol/out/TaikoL2.sol/TaikoL2.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type TaikoL2Client --pkg bindings --out $DIR/../bindings/v2/gen_taiko_l2.go

cat ../protocol/out/TaikoToken.sol/TaikoToken.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type TaikoToken --pkg bindings --out $DIR/../bindings/v2/gen_taiko_token.go

cat ../protocol/out/AddressManager.sol/AddressManager.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type AddressManager --pkg bindings --out $DIR/../bindings/v2/gen_address_manager.go

cat ../protocol/out/GuardianProver.sol/GuardianProver.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type GuardianProver --pkg bindings --out $DIR/../bindings/v2/gen_guardian_prover.go

cat ../protocol/out/ProverSet.sol/ProverSet.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type ProverSet --pkg bindings --out $DIR/../bindings/v2/gen_prover_set.go

cat ../protocol/out/DevnetTierProvider.sol/DevnetTierProvider.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type TierProvider --pkg bindings --out $DIR/../bindings/v2/gen_tier_provider.go

cat ../protocol/out/SgxVerifier.sol/SgxVerifier.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type SgxVerifier --pkg bindings --out $DIR/../bindings/v2/gen_sgx_verifier.go

cat ../protocol/out/SequencerRegistry.sol/SequencerRegistry.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type SequencerRegistry --pkg bindings --out $DIR/../bindings/v2/gen_sequencer_registry.go

echo "🍻 Go contract bindings generated!"
