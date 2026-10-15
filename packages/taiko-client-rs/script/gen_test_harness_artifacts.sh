#!/usr/bin/env bash
# Reproduce the test-only emitting Inbox setter, independent of protocol sources.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTRACT_DIR="$CLIENT_DIR/crates/test-harness/contracts"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT
mkdir -p "$BUILD_DIR/contracts"
cp "$CONTRACT_DIR/InboxSetter.sol" "$BUILD_DIR/contracts/InboxSetter.sol"
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
artifact = json.loads((build / "out/InboxSetter.sol/InboxSetter.json").read_text())
metadata = json.loads(artifact["rawMetadata"])
if metadata["compiler"]["version"] != "0.8.30+commit.73712a01":
    raise SystemExit("unexpected Solidity compiler for InboxSetter")
settings = metadata["settings"]
if settings["evmVersion"] != "osaka" or settings["optimizer"] != {"enabled": True, "runs": 200}:
    raise SystemExit("unexpected compiler settings for InboxSetter")
source = (output / "InboxSetter.sol").read_bytes()
digest = subprocess.check_output(["cast", "keccak"], input="0x" + source.hex(), text=True).strip()
if metadata["sources"]["contracts/InboxSetter.sol"]["keccak256"].lower() != digest.lower():
    raise SystemExit("stale compiled source: InboxSetter.sol")
for bytecode in [artifact["bytecode"], artifact["deployedBytecode"]]:
    if bytecode.get("linkReferences"):
        raise SystemExit("unresolved library links in InboxSetter")
exported = {
    "contractName": "InboxSetter",
    "abi": artifact["abi"],
    "bytecode": {"object": artifact["bytecode"]["object"]},
    "deployedBytecode": {"object": artifact["deployedBytecode"]["object"]},
}
encoded = (json.dumps(exported, indent=2, sort_keys=True) + "\n").encode()
(output / "InboxSetter.json").write_bytes(encoded)
manifest = {
    "generator": "script/gen_test_harness_artifacts.sh",
    "foundryVersion": subprocess.check_output(["forge", "--version"], text=True).splitlines(),
    "compiler": metadata["compiler"],
    "settings": settings,
    "source": {
        "path": "crates/test-harness/contracts/InboxSetter.sol",
        "keccak256": digest,
        "sha256": hashlib.sha256(source).hexdigest(),
    },
    "artifact": {
        "path": "crates/test-harness/contracts/InboxSetter.json",
        "sha256": hashlib.sha256(encoded).hexdigest(),
    },
}
(output / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
print("exported InboxSetter ABI and runtime with source/compiler provenance")
PYTHON
