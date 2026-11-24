#!/usr/bin/env bash
# Reproduce test-only contract artifacts, independent of protocol sources, and optionally the
# pinned EL inputs, whose devnet genesis carries the pinned protocol revision's Etna predeploys.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTRACT_DIR="$CLIENT_DIR/crates/test-harness/contracts"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT
mkdir -p "$BUILD_DIR/contracts"
cp "$CONTRACT_DIR/InboxSetter.sol" "$CONTRACT_DIR/ZkGasFixture.sol" "$CONTRACT_DIR/FeeRoutingFixture.sol" "$BUILD_DIR/contracts/"
cat > "$BUILD_DIR/foundry.toml" <<'CONFIG'
[profile.default]
src = "contracts"
out = "out"
solc_version = "0.8.30"
evm_version = "osaka"
optimizer = true
optimizer_runs = 200
CONFIG
forge build --root "$BUILD_DIR" --force

python3 - "$BUILD_DIR" "$CONTRACT_DIR" <<'PYTHON'
import hashlib
import json
import pathlib
import subprocess
import sys

build, output = map(pathlib.Path, sys.argv[1:])
for name, manifest_name in [("InboxSetter", "manifest.json"), ("ZkGasFixture", "ZkGasFixture.manifest.json"), ("FeeRoutingFixture", "FeeRoutingFixture.manifest.json")]:
    artifact = json.loads((build / f"out/{name}.sol/{name}.json").read_text())
    metadata = json.loads(artifact["rawMetadata"])
    if metadata["compiler"]["version"] != "0.8.30+commit.73712a01":
        raise SystemExit(f"unexpected Solidity compiler for {name}")
    settings = metadata["settings"]
    if settings["evmVersion"] != "osaka" or settings["optimizer"] != {"enabled": True, "runs": 200}:
        raise SystemExit(f"unexpected compiler settings for {name}")
    source = (output / f"{name}.sol").read_bytes()
    digest = subprocess.check_output(["cast", "keccak"], input="0x" + source.hex(), text=True).strip()
    if metadata["sources"][f"contracts/{name}.sol"]["keccak256"].lower() != digest.lower():
        raise SystemExit(f"stale compiled source: {name}.sol")
    for bytecode in [artifact["bytecode"], artifact["deployedBytecode"]]:
        if bytecode.get("linkReferences"):
            raise SystemExit(f"unresolved library links in {name}")
    exported = {
        "contractName": name,
        "abi": artifact["abi"],
        "bytecode": {"object": artifact["bytecode"]["object"]},
        "deployedBytecode": {"object": artifact["deployedBytecode"]["object"]},
    }
    encoded = (json.dumps(exported, indent=2, sort_keys=True) + "\n").encode()
    (output / f"{name}.json").write_bytes(encoded)
    manifest = {
        "generator": "script/gen_test_harness_artifacts.sh",
        "foundryVersion": subprocess.check_output(["forge", "--version"], text=True).splitlines(),
        "compiler": metadata["compiler"],
        "settings": settings,
        "source": {
            "path": f"crates/test-harness/contracts/{name}.sol",
            "keccak256": digest,
            "sha256": hashlib.sha256(source).hexdigest(),
        },
        "artifact": {
            "path": f"crates/test-harness/contracts/{name}.json",
            "sha256": hashlib.sha256(encoded).hexdigest(),
        },
    }
    (output / manifest_name).write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"exported {name} ABI and runtime with source/compiler provenance")
PYTHON

# Optional regeneration of the pinned EL inputs: `$1` is an alethia-reth checkout at the pinned
# revision and `$2` a taiko-mono checkout at the protocol revision gen_lander_artifacts.sh pins, with
# the protocol package's dependencies installed (gen_lander_artifacts.sh installs them). The devnet
# genesis is alethia-reth's devnet genesis with that protocol revision's Etna predeploys laid over
# it: its genesis generator on the harness configuration below, then its
# script/layer2/build_etna_genesis.py. Runtime tests only consume committed files.
if [[ -n "${1:-}" ]]; then
EL_CHECKOUT="$(cd "$1" && pwd)"
PROTOCOL_CHECKOUT="$(cd "${2:?usage: gen_test_harness_artifacts.sh [<alethia-reth-checkout> <taiko-mono-checkout>]}" && pwd)"
PROTOCOL_REVISION="$(sed -n 's/^PINNED_REVISION=//p' "$SCRIPT_DIR/gen_lander_artifacts.sh")"
if [[ "$(git -C "$PROTOCOL_CHECKOUT" rev-parse HEAD)" != "$PROTOCOL_REVISION" ]]; then
    echo "protocol checkout must be $PROTOCOL_REVISION" >&2
    exit 1
fi
git -C "$PROTOCOL_CHECKOUT" diff --quiet HEAD -- packages/protocol/contracts packages/protocol/script packages/protocol/test packages/protocol/foundry.toml
PROTOCOL="$PROTOCOL_CHECKOUT/packages/protocol"
GENESIS_DATA="$PROTOCOL/test/genesis/data"
# The harness devnet: chain 167001 on an anvil L1 (chain 31337, the generator's default), the Inbox
# at the client's built-in devnet address, where the harness installs it, and L1 SignalService and
# TAIKO addresses that only fill the L2 predeploys' references (the harness deploys neither on
# L1). EtnaStaking keeps the example's parameters, and each of anvil's first four dev accounts,
# which the alethia-reth devnet genesis funds with ETH, gets a premint of two minStakes: one to
# register a validator key, one to top it up.
L1_SIGNAL_SERVICE=0x00000000000000000000000000000000E7A10005
L1_INBOX=0x00000000000000000000000000000000E7A10001
L1_TAIKO_TOKEN=0x00000000000000000000000000000000E7A10007
cat > "$BUILD_DIR/etna_devnet_config.js" <<CONFIG
"use strict";
const config = { ...require("$GENESIS_DATA/genesis_config_etna.js") };
config.remoteSignalService = "$L1_SIGNAL_SERVICE";
config.etna = {
  ...config.etna,
  inbox: "$L1_INBOX",
  l1TaikoToken: "$L1_TAIKO_TOKEN",
  premint: [
    "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
    "0x90F79bf6EB2c4f870365E785982E1f101E93b906",
  ].map((account) => ({ [account]: "15625000000000000000000000" })),
};
module.exports = config;
CONFIG
# The generator rewrites the checkout's tracked genesis_config.json; put it back afterwards.
mkdir -p "$BUILD_DIR/protocol-data"
cp "$GENESIS_DATA/genesis_config.json" "$BUILD_DIR/protocol-data/"
trap 'cp "$BUILD_DIR/protocol-data/genesis_config.json" "$GENESIS_DATA/"; rm -rf "$BUILD_DIR"' EXIT
# `pnpm genesis:gen`'s steps. The layer2 build is forced: an artifact another build wrote without
# its AST is otherwise kept, and the generator needs the AST to find the immutables.
(cd "$PROTOCOL" && FOUNDRY_PROFILE=layer2 forge build --force --build-info --extra-output storage-layout)
(cd "$PROTOCOL" && FOUNDRY_PROFILE=shared forge build --build-info --extra-output storage-layout)
(cd "$PROTOCOL" && GENESIS_CONFIG="$BUILD_DIR/etna_devnet_config.js" ./node_modules/.bin/ts-node \
    --project ./test/genesis/tsconfig.json ./test/genesis/generate/generate.ts)
python3 "$PROTOCOL/script/layer2/build_etna_genesis.py" \
    --base "$EL_CHECKOUT/crates/chainspec/src/genesis/devnet.json" \
    --predeploys "$GENESIS_DATA/genesis_alloc.json" --predeploy-config "$GENESIS_DATA/genesis_config.json" \
    --l1-signal-service "$L1_SIGNAL_SERVICE" --l1-inbox "$L1_INBOX" --l1-taiko-token "$L1_TAIKO_TOKEN" \
    --artifacts "$PROTOCOL/out/layer2" --output "$BUILD_DIR/devnet-genesis.json"
python3 - "$EL_CHECKOUT" "$CONTRACT_DIR" "$BUILD_DIR/devnet-genesis.json" "$PROTOCOL_REVISION" <<'PYTHON'
import hashlib, json, pathlib, subprocess, sys
checkout, output, genesis = map(pathlib.Path, sys.argv[1:4])
protocol_revision = sys.argv[4]
revision = "493b6074b6d5749cea5e566b444bced8f14b258b"
if subprocess.check_output(["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True).strip() != revision:
    raise SystemExit("EL checkout must match pinned revision " + revision)
paths = ["crates/chainspec/src/genesis/devnet.json", "crates/node/tests/fixtures/etna-genesis.json"]
subprocess.run(["git", "-C", str(checkout), "diff", "--exit-code", "HEAD", "--", *paths], check=True)
base, systems = [(checkout / p).read_bytes() for p in paths]
(output / "devnet-genesis.json").write_bytes(genesis.read_bytes())
alloc = json.loads(systems)["alloc"]
addresses = ["0x000f3df6d732807ef1319fb7b8bb8522d0beac02", "0x0000f90827f1c53a10cb7a02335b175320002935"]
alloc = {"0x" + k.lower().removeprefix("0x"): v for k, v in alloc.items()}
code = {address: alloc[address]["code"] for address in addresses}
encoded = (json.dumps(code, indent=2, sort_keys=True) + "\n").encode()
(output / "system-runtimes.json").write_bytes(encoded)
manifest = {"revision": revision, "protocolRevision": protocol_revision, "generator": "script/gen_test_harness_artifacts.sh", "sources": {p: hashlib.sha256(v).hexdigest() for p,v in zip(paths,[base,systems])}, "artifacts": {"devnet-genesis.json": hashlib.sha256((output / "devnet-genesis.json").read_bytes()).hexdigest(), "system-runtimes.json": hashlib.sha256(encoded).hexdigest()}}
(output / "genesis.manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
PYTHON
fi
