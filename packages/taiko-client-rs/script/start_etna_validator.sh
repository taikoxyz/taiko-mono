#!/usr/bin/env bash
# Start the ABCI app separately; retain Comet home and authoritative signer storage.
# ETNA_CHAIN_ID selects the one HRS state <ETNA_PRIV_STATE_DIR>/<chain_id>.json that
# `etna-signer init-state` created and logged in ETNA_DOMAINS_LOG; a recovered generation
# is a new chain_id with its own state (tools/etna-signer/README.md). Never derive it from trust.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ETNA_SIGNER_BIN=${ETNA_SIGNER_BIN:-"$ROOT/target/etna-signer/etna-signer"}
exec python3 "$ROOT/script/etna_validator.py"
