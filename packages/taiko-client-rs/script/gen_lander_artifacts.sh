#!/usr/bin/env bash
# Reproduce the Etna landing ABI and actual-contract integration artifacts, and copy the Etna
# vectors shared with the contracts (testdata/etna_vectors) from the same protocol revision.
# `script/check_lander_artifacts.sh` (`just check-lander-artifacts`) checks that this reproduces
# the committed files.
set -euo pipefail

PINNED_REVISION=23963b68e43b4cbeaf83113eeb61fbc1bddb4c46
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROTOCOL_CHECKOUT="$(cd "${1:?usage: gen_lander_artifacts.sh <taiko-mono-checkout>}" && pwd)"
ACTUAL_REVISION="$(git -C "$PROTOCOL_CHECKOUT" rev-parse HEAD)"
if [[ "$ACTUAL_REVISION" != "$PINNED_REVISION" ]]; then
    echo "protocol checkout must be $PINNED_REVISION (found $ACTUAL_REVISION)" >&2
    exit 1
fi
git -C "$PROTOCOL_CHECKOUT" diff --quiet HEAD -- packages/protocol/contracts packages/protocol/test packages/protocol/foundry.toml pnpm-lock.yaml testdata/etna_vectors
# Dependencies must be installed before invoking Foundry. Offline regeneration is supported
# with PNPM_OFFLINE=1 after the pinned lockfile's dependencies have been cached.
INSTALL_FLAGS=(--frozen-lockfile --ignore-scripts)
if [[ "${PNPM_OFFLINE:-0}" == 1 ]]; then INSTALL_FLAGS+=(--offline); fi
(cd "$PROTOCOL_CHECKOUT" && pnpm install "${INSTALL_FLAGS[@]}")
(cd "$PROTOCOL_CHECKOUT/packages/protocol" && FOUNDRY_PROFILE=layer1 forge build \
    contracts/layer1/etna/impl/EtnaInbox.sol \
    contracts/layer1/etna/impl/EtnaInboxBootstrap.sol \
    contracts/layer1/etna/impl/EtnaStakingRegistry.sol \
    contracts/shared/signal/SignalService.sol test/layer1/etna/EtnaInboxTestBase.sol \
    --build-info)

python3 - "$PROTOCOL_CHECKOUT" "$CLIENT_DIR" "$PINNED_REVISION" <<'PYTHON'
import hashlib
import json
import pathlib
import subprocess
import sys

checkout, client, revision = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
protocol = checkout / "packages/protocol"
output = client / "crates/lander/tests/fixtures/contracts"
output.mkdir(parents=True, exist_ok=True)
artifacts = {
    "EtnaInbox": "EtnaInbox.sol/EtnaInbox.json",
    "EtnaStakingRegistry": "EtnaStakingRegistry.sol/EtnaStakingRegistry.json",
    "EtnaInboxBootstrap": "EtnaInboxBootstrap.sol/EtnaInboxBootstrap.json",
    "SignalService": "SignalService.sol/SignalService.json",
    "ERC1967Proxy": "ERC1967Proxy.sol/ERC1967Proxy.json",
    "MockLandProofVerifier": "EtnaInboxTestBase.sol/MockLandProofVerifier.json",
    "TestERC20": "TestERC20.sol/TestERC20.json",
}
manifest = {
    "protocolRevision": revision,
    "generator": "script/gen_lander_artifacts.sh",
    # The commit only: build timestamps differ between platforms' binaries, and release channels
    # print different version lines for the same commit (`1.5.1-stable`, `1.5.1-v1.5.1`).
    "foundryVersion": [
        line
        for line in subprocess.check_output(["forge", "--version"], text=True).splitlines()
        if line.startswith("Commit SHA:")
    ],
    "artifacts": {},
}
for name, relative in artifacts.items():
    profile = "layer1"
    source = protocol / f"out/{profile}" / relative
    artifact = json.loads(source.read_text())
    metadata = json.loads(artifact["rawMetadata"])
    if metadata["compiler"]["version"] != "0.8.30+commit.73712a01":
        raise SystemExit(f"unexpected Solidity compiler for {name}")
    settings = metadata["settings"]
    if settings["evmVersion"] != "osaka" or settings["optimizer"] != {"enabled": True, "runs": 200}:
        raise SystemExit(f"unexpected compiler settings for {name}")
    sources = {}
    for source_path, info in metadata["sources"].items():
        contents = (protocol / source_path).read_bytes()
        digest = subprocess.check_output(["cast", "keccak"], input="0x" + contents.hex(), text=True).strip()
        if digest.lower() != info["keccak256"].lower():
            raise SystemExit(f"stale compiled source: {source_path}")
        sources[source_path] = {"keccak256": digest, "sha256": hashlib.sha256(contents).hexdigest()}
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
    destination = output / f"{name}.json"
    destination.write_bytes(encoded)
    subprocess.run(["pnpm", "exec", "prettier", "--write", str(destination)], cwd=checkout, check=True)
    encoded = destination.read_bytes()
    manifest["artifacts"][name] = {
        "sourceArtifact": f"packages/protocol/out/{profile}/{relative}",
        "sha256": hashlib.sha256(encoded).hexdigest(),
        "compiler": metadata["compiler"],
        "settings": settings,
        "sources": sources,
    }
# The binding is the complete Inbox ABI.
inbox_artifact = json.loads((output / "EtnaInbox.json").read_text())
bindings_path = client / "crates/lander/contracts/EtnaInbox.json"
bindings_path.write_text(json.dumps({"abi": inbox_artifact["abi"]}, indent=2, sort_keys=True) + "\n")
subprocess.run(["pnpm", "exec", "prettier", "--write", str(bindings_path)], cwd=checkout, check=True)
manifest["bindings"] = {
    "sourceArtifact": "EtnaInbox.json",
    "projection": {"path": "contracts/EtnaInbox.json", "sha256": hashlib.sha256(bindings_path.read_bytes()).hexdigest()},
}
interface_path = "contracts/layer1/etna/iface/IEtnaInbox.sol"
interface = (protocol / interface_path).read_bytes()
(client / "crates/lander/contracts/IEtnaInbox.sol").write_bytes(interface)
manifest["interface"] = {"source": f"packages/protocol/{interface_path}", "sha256": hashlib.sha256(interface).hexdigest()}
# The shared vectors: a byte-identical copy at the same repository path, stale files removed.
vectors_dir = "testdata/etna_vectors"
source_vectors, client_vectors = checkout / vectors_dir, client.parents[1] / vectors_dir
client_vectors.mkdir(parents=True, exist_ok=True)
for stale in client_vectors.iterdir():
    if stale.is_file() and not (source_vectors / stale.name).is_file():
        stale.unlink()
vector_files = {}
for source in sorted(path for path in source_vectors.iterdir() if path.is_file()):
    contents = source.read_bytes()
    (client_vectors / source.name).write_bytes(contents)
    vector_files[source.name] = hashlib.sha256(contents).hexdigest()
manifest["vectors"] = {"source": vectors_dir, "files": vector_files}
(output / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
subprocess.run(["pnpm", "exec", "prettier", "--write", str(output / "manifest.json")], cwd=checkout, check=True)
print(f"exported {len(artifacts)} artifacts, IEtnaInbox and {len(vector_files)} vector files from {revision}")
PYTHON
