#!/usr/bin/env bash
# Supervise stock Comet and the guarded FilePV helper. Start the ABCI app first.
set -euo pipefail
: "${ETNA_COMET_HOME:?existing Comet home required}"
: "${ETNA_APP_STORE:?running app store required}"
: "${ETNA_PRIV_KEY:?existing registered FilePV key required}"
: "${ETNA_PRIV_STATE:?existing FilePV signing state required}"
: "${ETNA_CHAIN_ID:?verified genesis chain ID required}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ETNA_SIGNER_BIN=${ETNA_SIGNER_BIN:-"$ROOT/target/etna-signer/etna-signer"}
# Parse TOML rather than accepting a commented-out or section-local setting.
SIGNER_ADDR=$(python3 - "$ETNA_COMET_HOME" "$ETNA_PRIV_KEY" "$ETNA_PRIV_STATE" "$ETNA_CHAIN_ID" <<'PYTHON'
import json, pathlib, sys, tomllib
home, key, state = [pathlib.Path(p).resolve() for p in sys.argv[1:4]]
for p in (key, state):
    if not p.is_file() or p.is_relative_to(home):
        raise SystemExit('existing registered key/state must be outside the Comet home')
config = tomllib.loads((home / 'config/config.toml').read_text())
addr = config.get('priv_validator_laddr', '')
if not addr.startswith(('unix://', 'tcp://')):
    raise SystemExit('validator startup requires explicit priv_validator_laddr')
if json.loads((home / 'config/genesis.json').read_text())['chain_id'] != sys.argv[4]:
    raise SystemExit('signer chain ID differs from Comet genesis')
print(addr)
PYTHON
)
signer_pid= comet_pid=
cleanup() {
  trap - EXIT INT TERM
  # Bound drain, then reap before the signer is allowed to disappear.
  if [[ -n "$comet_pid" ]]; then
    kill -TERM "$comet_pid" 2>/dev/null || true
    for _ in {1..100}; do kill -0 "$comet_pid" 2>/dev/null || break; sleep 0.1; done
    kill -KILL "$comet_pid" 2>/dev/null || true
    wait "$comet_pid" 2>/dev/null || true
  fi
  if [[ -n "$signer_pid" ]]; then
    kill -TERM "$signer_pid" 2>/dev/null || true
    wait "$signer_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
"$ETNA_SIGNER_BIN" --comet-signer-addr "$SIGNER_ADDR" \
  --trust-socket "$ETNA_APP_STORE/checkpoint-trust.sock" --chain-id "$ETNA_CHAIN_ID" \
  --priv-key "$ETNA_PRIV_KEY" --priv-state "$ETNA_PRIV_STATE" &
signer_pid=$!
cometbft start --home "$ETNA_COMET_HOME" &
comet_pid=$!
# Bash 3 on macOS has no wait -n. Poll both owned children and fail if either exits.
while kill -0 "$signer_pid" 2>/dev/null && kill -0 "$comet_pid" 2>/dev/null; do sleep 0.25; done
exit 1
