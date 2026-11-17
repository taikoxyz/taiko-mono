#!/bin/bash

# Regenerate the remaining Unzen/Anchor bindings from the Etna artifacts' protocol pin.
# Generated crate files are replaced only after builds and code generation succeed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROTOCOL_DIR="$(cd "${PROTOCOL_DIR:-$SCRIPT_DIR/../../protocol}" && pwd)"
PROTOCOL_CHECKOUT="$(git -C "$PROTOCOL_DIR" rev-parse --show-toplevel)"
PINNED_REVISION="$(sed -n 's/^PINNED_REVISION=//p' "$SCRIPT_DIR/gen_lander_artifacts.sh")"
if [[ "$(git -C "$PROTOCOL_CHECKOUT" rev-parse HEAD)" != "$PINNED_REVISION" ]]; then
    echo "PROTOCOL_DIR must belong to protocol revision $PINNED_REVISION" >&2
    exit 1
fi
git -C "$PROTOCOL_CHECKOUT" diff --quiet HEAD -- packages/protocol/contracts packages/protocol/foundry.toml pnpm-lock.yaml

INSTALL_FLAGS=(--filter @taiko/protocol --frozen-lockfile --ignore-scripts)
if [[ "${PNPM_OFFLINE:-0}" == 1 ]]; then INSTALL_FLAGS+=(--offline); fi
(cd "$PROTOCOL_CHECKOUT" && pnpm install "${INSTALL_FLAGS[@]}")

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT
ALLOY_VERSION="$(python3 -c 'import sys,tomllib; print(tomllib.load(open(sys.argv[1],"rb"))["workspace"]["dependencies"]["alloy"]["version"])' "$CLIENT_DIR/Cargo.toml")"
CRATE_VERSION="$(python3 -c 'import sys,tomllib; print(tomllib.load(open(sys.argv[1],"rb"))["workspace"]["package"]["version"])' "$CLIENT_DIR/Cargo.toml")"

# Collect selected production artifacts from both fork profiles into one clean output.
FOUNDRY_PROFILE=layer1 forge build --root "$PROTOCOL_DIR" \
    --out "$BUILD_DIR/artifacts" --cache-path "$BUILD_DIR/cache/layer1" \
    "$PROTOCOL_DIR/contracts/layer1/core/impl/Inbox.sol" \
    "$PROTOCOL_DIR/contracts/layer1/preconf/impl/PreconfWhitelist.sol"
FOUNDRY_PROFILE=layer2 forge build --root "$PROTOCOL_DIR" \
    --out "$BUILD_DIR/artifacts" --cache-path "$BUILD_DIR/cache/layer2" \
    "$PROTOCOL_DIR/contracts/layer2/core/Anchor.sol"
forge bind --root "$PROTOCOL_DIR" --out "$BUILD_DIR/artifacts" --skip-build \
    --select '^Inbox$' --select '^Anchor$' --select '^PreconfWhitelist$' \
    --bindings-path "$BUILD_DIR/bindings" --crate-name bindings \
    --crate-version "$CRATE_VERSION" --overwrite --alloy-version "$ALLOY_VERSION"

python3 - "$BUILD_DIR" "$CLIENT_DIR" "$PINNED_REVISION" "$CRATE_VERSION" "$PROTOCOL_DIR" <<'PYTHON'
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys

build, client = map(pathlib.Path, sys.argv[1:3])
revision, version = sys.argv[3:5]
protocol = pathlib.Path(sys.argv[5])
staged = build / "bindings"
# Keep the generated crate on workspace Alloy instead of introducing a second dependency.
(staged / "Cargo.toml").write_text(f'''[package]
name = "bindings"
version = "{version}"
edition = "2021"
license.workspace = true

[lib]
doctest = false

[dependencies]
alloy = {{ workspace = true, features = ["sol-types", "contract"] }}
serde = {{ version = "1.0", features = ["derive"] }}

[lints]
rust.warnings = "allow"
''')
manifest = {
    "protocolRevision": revision,
    "generator": "script/gen_bindings.sh",
    "foundryVersion": [line for line in subprocess.check_output(["forge", "--version"], text=True).splitlines() if line.startswith("Commit SHA:")],
    "contracts": {},
}
for name in ["Anchor", "Inbox", "PreconfWhitelist"]:
    artifact = json.loads((build / "artifacts" / (name + ".sol") / (name + ".json")).read_text())
    metadata = json.loads(artifact["rawMetadata"])
    if metadata["compiler"]["version"] != "0.8.30+commit.73712a01" or metadata["settings"]["evmVersion"] != "osaka":
        raise SystemExit("unexpected compiler or fork for " + name)
    abi = json.dumps(artifact["abi"], sort_keys=True, separators=(",", ":")).encode()
    manifest["contracts"][name] = {
        "abiSha256": hashlib.sha256(abi).hexdigest(),
        "compiler": metadata["compiler"],
        "sources": {
            source: {"keccak256": info["keccak256"], "sha256": hashlib.sha256((protocol / source).read_bytes()).hexdigest()}
            for source, info in metadata["sources"].items()
        },
    }
manifest["files"] = {
    path.relative_to(staged).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
    for path in sorted(staged.rglob("*")) if path.is_file()
}
destination = client / "crates/bindings"
shutil.rmtree(destination / "src")
shutil.copytree(staged / "src", destination / "src")
shutil.copyfile(staged / "Cargo.toml", destination / "Cargo.toml")
(destination / "protocol-manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
subprocess.run(["pnpm", "exec", "prettier", "--write", str(destination / "protocol-manifest.json")], cwd=protocol.parents[1], check=True)
print("regenerated Inbox, Anchor and PreconfWhitelist bindings from", revision)
PYTHON
