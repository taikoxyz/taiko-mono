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
FORK=shasta

echo ""
echo "PROTOCOL_FORK_NAME: ${FORK}"
echo ""

echo ""
echo "Start generating Go contract bindings..."
echo ""

cat ../protocol/out/layer1/ShastaMainnetInbox.sol/ShastaMainnetInbox.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type ShastaInboxClient --pkg ${FORK} --out $DIR/../bindings/${FORK}/gen_shasta_inbox.go

cat ../protocol/out/layer1/CodecOptimized.sol/CodecOptimized.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type CodecOptimizedClient --pkg ${FORK} --out $DIR/../bindings/${FORK}/gen_shasta_inbox_codec.go

cat ../protocol/out/layer2/ShastaAnchor.sol/ShastaAnchor.json |
	jq .abi |
	${ABIGEN_BIN} --abi - --type ShastaAnchor --pkg ${FORK} --out $DIR/../bindings/${FORK}/gen_shasta_anchor.go

cat ../protocol/out/layer2/BondManager.sol/BondManager.json |
  jq .abi |
  ${ABIGEN_BIN} --abi - --type BondManager --pkg ${FORK} --out $DIR/../bindings/${FORK}/gen_bond_manager.go

git -C ../../ log --format="%H" -n 1 >./bindings/${FORK}/.githead

echo "🍻 Go contract bindings generated!"
