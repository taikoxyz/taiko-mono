#!/usr/bin/env bash
# Reproduce test-only contract artifacts, independent of protocol sources.
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

# Optional regeneration of the pinned EL inputs. Runtime tests only consume committed files.
if [[ -n "${1:-}" ]]; then
python3 - "$1" "$CONTRACT_DIR" <<'PYTHON'
import hashlib, json, pathlib, subprocess, sys
checkout, output = map(pathlib.Path, sys.argv[1:])
revision = "5d4d21ac472c024703082ba46c6eacfa3b8ec1bf"
if subprocess.check_output(["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True).strip() != revision:
    raise SystemExit("EL checkout must match pinned revision " + revision)
paths = ["crates/chainspec/src/genesis/devnet.json", "crates/node/tests/fixtures/etna-genesis.json"]
subprocess.run(["git", "-C", str(checkout), "diff", "--exit-code", "HEAD", "--", *paths], check=True)
base, systems = [(checkout / p).read_bytes() for p in paths]
(output / "devnet-genesis.json").write_bytes(base.rstrip(b"\n") + b"\n")
alloc = json.loads(systems)["alloc"]
addresses = ["0x000f3df6d732807ef1319fb7b8bb8522d0beac02", "0x0000f90827f1c53a10cb7a02335b175320002935"]
alloc = {"0x" + k.lower().removeprefix("0x"): v for k, v in alloc.items()}
code = {address: alloc[address]["code"] for address in addresses}
encoded = (json.dumps(code, indent=2, sort_keys=True) + "\n").encode()
(output / "system-runtimes.json").write_bytes(encoded)
manifest = {"revision": revision, "generator": "script/gen_test_harness_artifacts.sh", "sources": {p: hashlib.sha256(v).hexdigest() for p,v in zip(paths,[base,systems])}, "artifacts": {"devnet-genesis.json": hashlib.sha256((output / "devnet-genesis.json").read_bytes()).hexdigest(), "system-runtimes.json": hashlib.sha256(encoded).hexdigest()}}
(output / "genesis.manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
PYTHON
fi
