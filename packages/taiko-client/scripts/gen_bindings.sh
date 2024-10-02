#!/bin/bash

# Generate go contract bindings.
# ref: https://geth.ethereum.org/docs/dapp/native-bindings

set -eou pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

# echo ""
# echo "TAIKO_GETH_DIR: ${TAIKO_GETH_DIR}"
# echo ""

# cd ${TAIKO_GETH_DIR} &&
#   make all &&
#   cd -

# cd ../protocol &&
#   pnpm clean &&
#   pnpm compile &&
#   cd -

ABIGEN_BIN=$TAIKO_GETH_DIR/build/bin/abigen

# echo ""
# echo "Start generating go contract bindings..."
# echo ""

# cat ../protocol/out/layer1/TaikoL1.sol/TaikoL1.json |
# 	jq .abi |
# 	${ABIGEN_BIN} --abi - --type TaikoL1Client --pkg bindings --out $DIR/../bindings/gen_taiko_l1.go

# cat ../protocol/out/layer1/LibProving.sol/LibProving.json |
# 	jq .abi |
# 	${ABIGEN_BIN} --abi - --type LibProving --pkg bindings --out $DIR/../bindings/gen_lib_proving.go

# cat ../protocol/out/layer1/LibProposing.sol/LibProposing.json |
# 	jq .abi |
# 	${ABIGEN_BIN} --abi - --type LibProposing --pkg bindings --out $DIR/../bindings/gen_lib_proposing.go

# cat ../protocol/out/layer1/LibUtils.sol/LibUtils.json |
# 	jq .abi |
# 	${ABIGEN_BIN} --abi - --type LibUtils --pkg bindings --out $DIR/../bindings/gen_lib_utils.go

# cat ../protocol/out/layer1/LibVerifying.sol/LibVerifying.json |
# 	jq .abi |
# 	${ABIGEN_BIN} --abi - --type LibVerifying --pkg bindings --out $DIR/../bindings/gen_lib_verifying.go

# cat ../protocol/out/layer2/TaikoL2.sol/TaikoL2.json |
# 	jq .abi |
# 	${ABIGEN_BIN} --abi - --type TaikoL2Client --pkg bindings --out $DIR/../bindings/gen_taiko_l2.go

# cat ../protocol/out/layer1/TaikoToken.sol/TaikoToken.json |
# 	jq .abi |
# 	${ABIGEN_BIN} --abi - --type TaikoToken --pkg bindings --out $DIR/../bindings/gen_taiko_token.go

# cat ../protocol/out/layer1/AddressManager.sol/AddressManager.json |
# 	jq .abi |
# 	${ABIGEN_BIN} --abi - --type AddressManager --pkg bindings --out $DIR/../bindings/gen_address_manager.go

# cat ../protocol/out/layer1/GuardianProver.sol/GuardianProver.json |
# 	jq .abi |
# 	${ABIGEN_BIN} --abi - --type GuardianProver --pkg bindings --out $DIR/../bindings/gen_guardian_prover.go

# cat ../protocol/out/layer1/ProverSet.sol/ProverSet.json |
# 	jq .abi |
# 	${ABIGEN_BIN} --abi - --type ProverSet --pkg bindings --out $DIR/../bindings/gen_prover_set.go

# cat ../protocol/out/layer1/DevnetTierProvider.sol/DevnetTierProvider.json |
# 	jq .abi |
# 	${ABIGEN_BIN} --abi - --type TierProvider --pkg bindings --out $DIR/../bindings/gen_tier_provider.go

# cat ../protocol/out/layer1/SgxVerifier.sol/SgxVerifier.json |
# 	jq .abi |
# 	${ABIGEN_BIN} --abi - --type SgxVerifier --pkg bindings --out $DIR/../bindings/gen_sgx_verifier.go

solc --abi --bin -o contracts/out contracts/IPreconfTaskManager.sol --overwrite

${ABIGEN_BIN} --abi=contracts/out/IPreconfTaskManager.abi --type PreconfTaskManager --pkg bindings --out $DIR/../bindings/gen_preconf_task_manager.go

git -C ../../ log --format="%H" -n 1 >./bindings/.githead

echo "🍻 Go contract bindings generated!"
