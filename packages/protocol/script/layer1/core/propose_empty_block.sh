#!/usr/bin/env bash
set -euo pipefail

# Sends an empty Shasta proposal. The Inbox requires a blob transaction because
# ProposeInput.blobReference is validated with blobhash(...).
#
# Required env:
#   PRIVATE_KEY  Signer private key.
#   RPC_URL      L1 RPC URL. ETH_RPC_URL is also accepted.
#   INBOX        Shasta Inbox address.
#
# Optional env:
#   LOOKAHEAD                 Proposer checker payload. Default: 0x.
#   DEADLINE                  uint48 deadline timestamp. Default: 0.
#   BLOB_START_INDEX          uint16 blob start index. Default: 0.
#   NUM_BLOBS                 uint16 blob count. Default: 1.
#   BLOB_OFFSET               uint24 blob byte offset. Default: 0.
#   NUM_FORCED_INCLUSIONS     uint16 forced inclusions to process. Default: 0.
#   BLOB_PATH                 Existing blob payload path. Default: generated zero blob.
#   CAST                      cast binary. Default: cast.

CAST_BIN=${CAST:-cast}
RPC_URL=${RPC_URL:-${ETH_RPC_URL:-}}

require_env() {
    local name=$1
    local value=${!name:-}
    if [[ -z "$value" ]]; then
        echo "Error: $name is required" >&2
        exit 1
    fi
}

require_uint_max() {
    local name=$1
    local value=$2
    local max=$3
    if ! [[ "$value" =~ ^(0x[0-9a-fA-F]+|[0-9]+)$ ]]; then
        echo "Error: $name must be a decimal or hex integer" >&2
        exit 1
    fi
    if (( value > max )); then
        echo "Error: $name exceeds $max" >&2
        exit 1
    fi
}

uint_hex() {
    local width=$1
    local value=$2
    printf "%0${width}x" "$value"
}

add_optional_tx_args() {
    if [[ -n "${GAS_LIMIT:-}" ]]; then tx_args+=(--gas-limit "$GAS_LIMIT"); fi
    if [[ -n "${GAS_PRICE:-}" ]]; then tx_args+=(--gas-price "$GAS_PRICE"); fi
    if [[ -n "${PRIORITY_GAS_PRICE:-}" ]]; then
        tx_args+=(--priority-gas-price "$PRIORITY_GAS_PRICE")
    fi
    if [[ -n "${BLOB_GAS_PRICE:-}" ]]; then tx_args+=(--blob-gas-price "$BLOB_GAS_PRICE"); fi
    if [[ "${ASYNC:-false}" == "true" ]]; then tx_args+=(--async); fi
}

require_env PRIVATE_KEY
require_env RPC_URL
require_env INBOX

LOOKAHEAD=${LOOKAHEAD:-0x}
DEADLINE=${DEADLINE:-0}
BLOB_START_INDEX=${BLOB_START_INDEX:-0}
NUM_BLOBS=${NUM_BLOBS:-1}
BLOB_OFFSET=${BLOB_OFFSET:-0}
NUM_FORCED_INCLUSIONS=${NUM_FORCED_INCLUSIONS:-0}

require_uint_max DEADLINE "$DEADLINE" 281474976710655
require_uint_max BLOB_START_INDEX "$BLOB_START_INDEX" 65535
require_uint_max NUM_BLOBS "$NUM_BLOBS" 65535
require_uint_max BLOB_OFFSET "$BLOB_OFFSET" 16777215
require_uint_max NUM_FORCED_INCLUSIONS "$NUM_FORCED_INCLUSIONS" 65535

if (( NUM_BLOBS == 0 )); then
    echo "Error: NUM_BLOBS must be greater than 0" >&2
    exit 1
fi

PROPOSE_DATA="0x$(uint_hex 12 "$DEADLINE")$(uint_hex 4 "$BLOB_START_INDEX")$(uint_hex 4 "$NUM_BLOBS")$(uint_hex 6 "$BLOB_OFFSET")$(uint_hex 4 "$NUM_FORCED_INCLUSIONS")"

tmp_dir=
if [[ -z "${BLOB_PATH:-}" ]]; then
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT
    BLOB_PATH="$tmp_dir/empty-proposal.blob"
    dd if=/dev/zero of="$BLOB_PATH" bs=131072 count="$NUM_BLOBS" status=none
fi

tx_args=()
add_optional_tx_args

echo "INBOX=$INBOX"
echo "PROPOSE_DATA=$PROPOSE_DATA"
echo "BLOB_PATH=$BLOB_PATH"

"$CAST_BIN" send "$INBOX" "propose(bytes,bytes)" "$LOOKAHEAD" "$PROPOSE_DATA" \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --blob \
    --path "$BLOB_PATH" \
    "${tx_args[@]}"
