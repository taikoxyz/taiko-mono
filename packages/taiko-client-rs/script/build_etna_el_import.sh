#!/usr/bin/env bash
# Build the isolated, pinned local EL import helper without database dependencies in the client.
set -euo pipefail
CLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$CLIENT_DIR"
if [[ -n "${ETNA_EL_IMPORT_BIN:-}" ]]; then
  test -x "$ETNA_EL_IMPORT_BIN"
  exit 0
fi
TASK_TARGET_DIR="${CARGO_TARGET_DIR:-$CLIENT_DIR/target}"
if [[ "$TASK_TARGET_DIR" != /* ]]; then TASK_TARGET_DIR="$CLIENT_DIR/$TASK_TARGET_DIR"; fi
cargo build --locked --manifest-path "$CLIENT_DIR/tools/etna-el-import/Cargo.toml" --target-dir "$TASK_TARGET_DIR" --bin etna-el-import
mkdir -p "$CLIENT_DIR/target/etna-signer"
cp "$TASK_TARGET_DIR/debug/etna-el-import" "$CLIENT_DIR/target/etna-signer/etna-el-import"
