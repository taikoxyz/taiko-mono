#!/usr/bin/env bash
# Build exactly the EL revision already pinned in this client's Cargo graph for native tests.
set -euo pipefail
CLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$CLIENT_DIR"
if [[ -n "${ETNA_EL_BIN:-}" ]]; then
  test -x "$ETNA_EL_BIN"
  exit 0
fi
TASK_PINNED_REVISION=20a9282a24b14567ebad82c427f8ceeeaf40aab4
TASK_PINNED_SOURCE=$(cargo metadata --locked --format-version=1 | python3 -c '
import json,pathlib,sys
data=json.load(sys.stdin)
matches=[p for p in data["packages"] if p["name"]=="alethia-reth-chainspec" and (p.get("source") or "").endswith("#"+sys.argv[1])]
if len(matches)!=1: raise SystemExit("expected one exact pinned EL source")
print(pathlib.Path(matches[0]["manifest_path"]).parents[2])
' "$TASK_PINNED_REVISION")
test "$(git -C "$TASK_PINNED_SOURCE" rev-parse HEAD)" = "$TASK_PINNED_REVISION"
git -C "$TASK_PINNED_SOURCE" diff --quiet HEAD --
TASK_TARGET_DIR="${CARGO_TARGET_DIR:-$CLIENT_DIR/target}"
if [[ "$TASK_TARGET_DIR" != /* ]]; then TASK_TARGET_DIR="$CLIENT_DIR/$TASK_TARGET_DIR"; fi
CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-2}" cargo build --locked --manifest-path "$TASK_PINNED_SOURCE/Cargo.toml" --target-dir "$TASK_TARGET_DIR" -p alethia-reth-bin
git -C "$TASK_PINNED_SOURCE" diff --quiet HEAD --
mkdir -p "$CLIENT_DIR/target/etna-signer"
cp "$TASK_TARGET_DIR/debug/alethia-reth" "$CLIENT_DIR/target/etna-signer/alethia-reth"
