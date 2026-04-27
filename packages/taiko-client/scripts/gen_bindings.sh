#!/bin/bash

# Generate go contract bindings.
# ref: https://geth.ethereum.org/docs/dapp/native-bindings

set -eou pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
PROTOCOL_DIR="${PROTOCOL_DIR:-../protocol}"

echo ""
echo "TAIKO_GETH_DIR: ${TAIKO_GETH_DIR}"
echo "PROTOCOL_DIR: ${PROTOCOL_DIR}"
echo ""

cd ${TAIKO_GETH_DIR} &&
  make all &&
  cd -

cd "${PROTOCOL_DIR}" &&
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

cat "${PROTOCOL_DIR}/out/layer1/MainnetInbox.sol/MainnetInbox.json" |
	jq .abi |
	${ABIGEN_BIN} --abi - --type ShastaInboxClient --pkg ${FORK} --out $DIR/../bindings/${FORK}/gen_shasta_inbox.go

cat "${PROTOCOL_DIR}/out/layer2/Anchor.sol/Anchor.json" |
	jq .abi |
	${ABIGEN_BIN} --abi - --type ShastaAnchor --pkg ${FORK} --out $DIR/../bindings/${FORK}/gen_shasta_anchor.go

cat "${PROTOCOL_DIR}/out/layer1/ComposeVerifier.sol/ComposeVerifier.json" |
  jq .abi |
  ${ABIGEN_BIN} --abi - --type ComposeVerifier --pkg ${FORK} --out $DIR/../bindings/${FORK}/gen_compose_verifier.go

cat "${PROTOCOL_DIR}/out/layer1/PreconfWhitelist.sol/PreconfWhitelist.json" |
  jq .abi |
  ${ABIGEN_BIN} --abi - --type PreconfWhitelist --pkg ${FORK} --out $DIR/../bindings/${FORK}/gen_preconf_whitelist.go

git -C ../../ log --format="%H" -n 1 >./bindings/${FORK}/.githead

echo "🍻 Go contract bindings generated!"
