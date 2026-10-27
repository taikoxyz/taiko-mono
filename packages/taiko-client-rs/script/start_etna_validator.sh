#!/usr/bin/env bash
# Start the ABCI app separately; retain Comet home and authoritative signer storage.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ETNA_SIGNER_BIN=${ETNA_SIGNER_BIN:-"$ROOT/target/etna-signer/etna-signer"}
exec python3 "$ROOT/script/etna_validator.py"
