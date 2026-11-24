#!/usr/bin/env bash
# Reproduce the Etna contract artifacts (the lander's Inbox bindings and the actual-contract
# integration fixtures), and copy the Etna vectors shared with the contracts (testdata/etna_vectors)
# from the same protocol revision. `PINNED_REVISION` is the only protocol pin: a re-pin edits it
# and regenerates.
# `script/check_lander_artifacts.sh` (`just check-lander-artifacts`) checks that this reproduces
# the committed files.
set -euo pipefail

PINNED_REVISION=dcada2ae2982f06bafa2a6da489d129b66ef6d4f
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
INSTALL_FLAGS=(--filter @taiko/protocol --frozen-lockfile --ignore-scripts)
if [[ "${PNPM_OFFLINE:-0}" == 1 ]]; then INSTALL_FLAGS+=(--offline); fi
(cd "$PROTOCOL_CHECKOUT" && pnpm install "${INSTALL_FLAGS[@]}")
(cd "$PROTOCOL_CHECKOUT/packages/protocol" && FOUNDRY_PROFILE=layer1 forge build \
    contracts/layer1/etna/impl/EtnaInbox.sol \
    contracts/layer1/etna/impl/EtnaInboxBootstrap.sol \
    contracts/layer1/core/impl/InboxWithEtnaCutoffs.sol \
    contracts/shared/signal/EtnaSignalService.sol test/layer1/etna/EtnaInboxTestBase.sol \
    test/layer1/etna/MockUnzenInbox.sol test/mocks/TestERC20.sol \
    --build-info)
# The L2 staking contract, the proxy it is deployed behind and the L2 TAIKO token it stakes.
(cd "$PROTOCOL_CHECKOUT/packages/protocol" && FOUNDRY_PROFILE=layer2 forge build \
    contracts/layer2/etna/EtnaStaking.sol \
    node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol \
    contracts/layer2/mainnet/BridgedTaikoToken.sol \
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
# Name -> (Foundry profile, artifact path under that profile's output).
artifacts = {
    "EtnaInbox": ("layer1", "EtnaInbox.sol/EtnaInbox.json"),
    "EtnaInboxBootstrap": ("layer1", "EtnaInboxBootstrap.sol/EtnaInboxBootstrap.json"),
    # The root-only SignalService that L1 runs on an Etna network.
    "EtnaSignalService": ("layer1", "EtnaSignalService.sol/EtnaSignalService.json"),
    "InboxWithEtnaCutoffs": ("layer1", "InboxWithEtnaCutoffs.sol/InboxWithEtnaCutoffs.json"),
    "MockLandProofVerifier": ("layer1", "EtnaInboxTestBase.sol/MockLandProofVerifier.json"),
    "MockUnzenInbox": ("layer1", "MockUnzenInbox.sol/MockUnzenInbox.json"),
    "TestERC20": ("layer1", "TestERC20.sol/TestERC20.json"),
    "EtnaStaking": ("layer2", "EtnaStaking.sol/EtnaStaking.json"),
    "ERC1967Proxy": ("layer2", "ERC1967Proxy.sol/ERC1967Proxy.json"),
    "BridgedTaikoToken": ("layer2", "BridgedTaikoToken.sol/BridgedTaikoToken.json"),
}
# An artifact the list no longer names is removed, so the committed set is exactly the list.
for stale in output.glob("*.json"):
    if stale.stem not in artifacts and stale.name != "manifest.json":
        stale.unlink()
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
for name, (profile, relative) in artifacts.items():
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
    # The cutoff implementation uses Unzen's external libraries. The client consumes its ABI,
    # not an unlinked deployment image; preserve those references explicitly in provenance.
    abi_only = name == "InboxWithEtnaCutoffs"
    for bytecode in [artifact["bytecode"], artifact["deployedBytecode"]]:
        if bytecode.get("linkReferences") and not abi_only:
            raise SystemExit(f"unresolved library links in {name}")
    exported = {
        "contractName": name,
        "abi": artifact["abi"],
    }
    if not abi_only:
        exported["bytecode"] = {"object": artifact["bytecode"]["object"]}
        exported["deployedBytecode"] = {"object": artifact["deployedBytecode"]["object"]}
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
    if abi_only:
        manifest["artifacts"][name]["abiOnly"] = True
        manifest["artifacts"][name]["linkReferences"] = {
            "bytecode": artifact["bytecode"].get("linkReferences", {}),
            "deployedBytecode": artifact["deployedBytecode"].get("linkReferences", {}),
        }
# The shared vectors: a byte-identical copy at the same repository path, stale files removed.
vectors_dir = "testdata/etna_vectors"
source_vectors, client_vectors = checkout / vectors_dir, client.parents[1] / vectors_dir
client_vectors.mkdir(parents=True, exist_ok=True)
# Include tracked generator helpers such as valgen/, not build/cache files left in the
# checkout. Relative names keep the manifest reproducible as the vector suite grows.
tracked_vectors = subprocess.check_output(
    ["git", "ls-files", "-z", "--", vectors_dir], cwd=checkout
).decode().split("\0")
relative_vectors = sorted(
    pathlib.Path(name).relative_to(vectors_dir) for name in tracked_vectors if name
)
for stale in client_vectors.rglob("*"):
    if stale.is_file() and stale.relative_to(client_vectors) not in relative_vectors:
        stale.unlink()
vector_files = {}
for relative in relative_vectors:
    contents = (source_vectors / relative).read_bytes()
    destination = client_vectors / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(contents)
    vector_files[relative.as_posix()] = hashlib.sha256(contents).hexdigest()
manifest["vectors"] = {"source": vectors_dir, "files": vector_files}
(output / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
subprocess.run(["pnpm", "exec", "prettier", "--write", str(output / "manifest.json")], cwd=checkout, check=True)
print(f"exported {len(artifacts)} artifacts and {len(vector_files)} vector files from {revision}")
PYTHON
