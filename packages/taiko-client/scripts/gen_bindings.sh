#!/bin/bash

# Generate go contract bindings.
# ref: https://geth.ethereum.org/docs/dapp/native-bindings

set -eou pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

echo ""
echo "TAIKO_MONO_DIR: ${TAIKO_MONO_DIR}"
echo "TAIKO_GETH_DIR: ${TAIKO_GETH_DIR}"
echo ""

cd ${TAIKO_GETH_DIR} &&
  make all &&
  cd -

cd ${TAIKO_MONO_DIR}/packages/protocol &&
  pnpm clean &&
  pnpm compile &&
  cd -

ABIGEN_BIN=$TAIKO_GETH_DIR/build/bin/abigen

echo ""
echo "Start generating go contract bindings..."
echo ""

cat ${TAIKO_MONO_DIR}/packages/protocol/out/TaikoL1.sol/TaikoL1.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type TaikoL1Client --pkg bindings --out $DIR/../bindings/gen_taiko_l1.go

cat ${TAIKO_MONO_DIR}/packages/protocol/out/LibProving.sol/LibProving.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type LibProving --pkg bindings --out $DIR/../bindings/gen_lib_proving.go

cat ${TAIKO_MONO_DIR}/packages/protocol/out/LibProposing.sol/LibProposing.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type LibProposing --pkg bindings --out $DIR/../bindings/gen_lib_proposing.go

cat ${TAIKO_MONO_DIR}/packages/protocol/out/LibUtils.sol/LibUtils.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type LibUtils --pkg bindings --out $DIR/../bindings/gen_lib_utils.go

cat ${TAIKO_MONO_DIR}/packages/protocol/out/LibVerifying.sol/LibVerifying.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type LibVerifying --pkg bindings --out $DIR/../bindings/gen_lib_verifying.go

cat ${TAIKO_MONO_DIR}/packages/protocol/out/TaikoL2.sol/TaikoL2.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type TaikoL2Client --pkg bindings --out $DIR/../bindings/gen_taiko_l2.go

cat ${TAIKO_MONO_DIR}/packages/protocol/out/TaikoToken.sol/TaikoToken.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type TaikoToken --pkg bindings --out $DIR/../bindings/gen_taiko_token.go

cat ${TAIKO_MONO_DIR}/packages/protocol/out/AddressManager.sol/AddressManager.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type AddressManager --pkg bindings --out $DIR/../bindings/gen_address_manager.go

cat ${TAIKO_MONO_DIR}/packages/protocol/out/GuardianProver.sol/GuardianProver.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type GuardianProver --pkg bindings --out $DIR/../bindings/gen_guardian_prover.go

cat ${TAIKO_MONO_DIR}/packages/protocol/out/AssignmentHook.sol/AssignmentHook.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type AssignmentHook --pkg bindings --out $DIR/../bindings/gen_assignment_hook.go

cat ${TAIKO_MONO_DIR}/packages/protocol/out/DevnetTierProvider.sol/DevnetTierProvider.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type TierProvider --pkg bindings --out $DIR/../bindings/gen_tier_provider.go

cat ${TAIKO_MONO_DIR}/packages/protocol/out/SgxVerifier.sol/SgxVerifier.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type SgxVerifier --pkg bindings --out $DIR/../bindings/gen_sgx_verifier.go

git -C ${TAIKO_MONO_DIR} log --format="%H" -n 1 >./bindings/.githead

echo "🍻 Go contract bindings generated!"
