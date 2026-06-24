#!/usr/bin/env bash
set -euo pipefail

# Saves a forced inclusion with an empty EIP-4844 blob.
# The Inbox validates BlobReference with blobhash(...), so this must be a blob transaction.
#
# Required env:
#   PRIVATE_KEY  Signer private key.
#   RPC_URL      L1 RPC URL. ETH_RPC_URL is also accepted.
#   INBOX        Shasta Inbox address.
#
# Optional env:
#   BLOB_START_INDEX      uint16 blob start index. Default: 0.
#   BLOB_OFFSET           uint24 blob byte offset. Default: 0.
#   BLOB_PATH             Existing blob payload path. Default: generated empty payload.
#   VALUE_WEI             msg.value override. Default: getCurrentForcedInclusionFee() in gwei.
#   CAST                  cast binary. Default: cast.
#   GAS_LIMIT             Optional gas limit.
#   GAS_PRICE             Optional max fee per gas / legacy gas price.
#   PRIORITY_GAS_PRICE    Optional EIP-1559 priority fee.
#   BLOB_GAS_PRICE        Optional blob gas price.
#   ASYNC                 Set true to print tx hash without waiting for receipt.

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

BLOB_START_INDEX=${BLOB_START_INDEX:-0}
BLOB_OFFSET=${BLOB_OFFSET:-0}

require_uint_max BLOB_START_INDEX "$BLOB_START_INDEX" 65535
require_uint_max BLOB_OFFSET "$BLOB_OFFSET" 16777215

if [[ -z "${VALUE_WEI:-}" ]]; then
    fee_in_gwei=$("$CAST_BIN" call "$INBOX" "getCurrentForcedInclusionFee()(uint64)" \
        --rpc-url "$RPC_URL" | tail -n 1 | awk '{print $1}')
    VALUE_WEI=$("$CAST_BIN" to-wei "$fee_in_gwei" gwei)
fi

tmp_dir=
if [[ -z "${BLOB_PATH:-}" ]]; then
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT
    BLOB_PATH="$tmp_dir/empty-forced-inclusion.blob"
    : > "$BLOB_PATH"
fi

tx_args=()
add_optional_tx_args

blob_reference="($BLOB_START_INDEX,1,$BLOB_OFFSET)"

echo "INBOX=$INBOX"
echo "BLOB_REFERENCE=$blob_reference"
echo "BLOB_PATH=$BLOB_PATH"
echo "VALUE_WEI=$VALUE_WEI"

"$CAST_BIN" send "$INBOX" "saveForcedInclusion((uint16,uint16,uint24))" "$blob_reference" \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --value "$VALUE_WEI" \
    --blob \
    --path "$BLOB_PATH" \
    "${tx_args[@]}"
