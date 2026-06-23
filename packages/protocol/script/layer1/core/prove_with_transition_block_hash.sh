#!/usr/bin/env bash
set -euo pipefail

# Submits a Shasta proof with a caller-controlled
# commitment.transitions[numProposals - 1].blockHash.
#
# Required env:
#   PRIVATE_KEY                         Signer private key.
#   RPC_URL                             L1 RPC URL. ETH_RPC_URL is also accepted.
#   INBOX                               Shasta Inbox address.
#   FIRST_PROPOSAL_ID                   commitment.firstProposalId.
#   FIRST_PROPOSAL_PARENT_BLOCK_HASH    commitment.firstProposalParentBlockHash.
#   END_BLOCK_NUMBER                    commitment.endBlockNumber.
#   END_STATE_ROOT                      commitment.endStateRoot.
#   LAST_BLOCK_HASH                     commitment.transitions[numProposals - 1].blockHash.
#
# Optional env:
#   NUM_PROPOSALS             Number of transitions. Default: 1.
#   LAST_PROPOSAL_HASH        commitment.lastProposalHash. If unset, fetched from getProposalHash.
#   LAST_PROPOSAL_ID          Proposal id for getProposalHash. Default: first + num - 1.
#   ACTUAL_PROVER             commitment.actualProver. Default: address(PRIVATE_KEY).
#   TRANSITION_PROPOSERS      Comma-separated transition proposers.
#   TRANSITION_PROPOSER       Default proposer for all transitions. Default: address(PRIVATE_KEY).
#   TRANSITION_TIMESTAMPS     Comma-separated uint48 transition timestamps.
#   TRANSITION_TIMESTAMP      Default timestamp for all transitions.
#   TRANSITION_BLOCK_HASHES   Comma-separated transition block hashes. Last is overridden by
#                             LAST_BLOCK_HASH when LAST_BLOCK_HASH is set.
#   PROOF                     Validity proof bytes. Default: 0x.
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

strip_0x() {
    local value=$1
    echo "${value#0x}"
}

uint_hex() {
    local width=$1
    local value=$2
    printf "%0${width}x" "$value"
}

normalize_hex_len() {
    local name=$1
    local value
    value=$(strip_0x "$2")
    local length=$3
    if ! [[ "$value" =~ ^[0-9a-fA-F]+$ ]] || [[ ${#value} -ne $length ]]; then
        echo "Error: $name must be ${length} hex chars" >&2
        exit 1
    fi
    echo "$value"
}

csv_get() {
    local csv=$1
    local index=$2
    IFS=',' read -r -a values <<< "$csv"
    echo "${values[$index]:-}"
}

add_optional_tx_args() {
    if [[ -n "${GAS_LIMIT:-}" ]]; then tx_args+=(--gas-limit "$GAS_LIMIT"); fi
    if [[ -n "${GAS_PRICE:-}" ]]; then tx_args+=(--gas-price "$GAS_PRICE"); fi
    if [[ -n "${PRIORITY_GAS_PRICE:-}" ]]; then
        tx_args+=(--priority-gas-price "$PRIORITY_GAS_PRICE")
    fi
    if [[ "${ASYNC:-false}" == "true" ]]; then tx_args+=(--async); fi
}

require_env PRIVATE_KEY
require_env RPC_URL
require_env INBOX
require_env FIRST_PROPOSAL_ID
require_env FIRST_PROPOSAL_PARENT_BLOCK_HASH
require_env END_BLOCK_NUMBER
require_env END_STATE_ROOT
require_env LAST_BLOCK_HASH

NUM_PROPOSALS=${NUM_PROPOSALS:-1}
require_uint_max NUM_PROPOSALS "$NUM_PROPOSALS" 65535
require_uint_max FIRST_PROPOSAL_ID "$FIRST_PROPOSAL_ID" 281474976710655
require_uint_max END_BLOCK_NUMBER "$END_BLOCK_NUMBER" 281474976710655

if (( NUM_PROPOSALS == 0 )); then
    echo "Error: NUM_PROPOSALS must be greater than 0" >&2
    exit 1
fi

SIGNER=$("$CAST_BIN" wallet address --private-key "$PRIVATE_KEY")
ACTUAL_PROVER=${ACTUAL_PROVER:-$SIGNER}
TRANSITION_PROPOSER=${TRANSITION_PROPOSER:-$SIGNER}
PROOF=${PROOF:-0x}

FIRST_PARENT_HASH_HEX=$(normalize_hex_len FIRST_PROPOSAL_PARENT_BLOCK_HASH "$FIRST_PROPOSAL_PARENT_BLOCK_HASH" 64)
END_STATE_ROOT_HEX=$(normalize_hex_len END_STATE_ROOT "$END_STATE_ROOT" 64)
ACTUAL_PROVER_HEX=$(normalize_hex_len ACTUAL_PROVER "$ACTUAL_PROVER" 40)
LAST_BLOCK_HASH_HEX=$(normalize_hex_len LAST_BLOCK_HASH "$LAST_BLOCK_HASH" 64)

LAST_PROPOSAL_ID=${LAST_PROPOSAL_ID:-$(( FIRST_PROPOSAL_ID + NUM_PROPOSALS - 1 ))}
require_uint_max LAST_PROPOSAL_ID "$LAST_PROPOSAL_ID" 281474976710655

if [[ -z "${LAST_PROPOSAL_HASH:-}" ]]; then
    LAST_PROPOSAL_HASH=$("$CAST_BIN" call "$INBOX" "getProposalHash(uint256)(bytes32)" \
        "$LAST_PROPOSAL_ID" --rpc-url "$RPC_URL" | tail -n 1)
fi
LAST_PROPOSAL_HASH_HEX=$(normalize_hex_len LAST_PROPOSAL_HASH "$LAST_PROPOSAL_HASH" 64)

TRANSITIONS_HEX=
for ((i = 0; i < NUM_PROPOSALS; ++i)); do
    proposer=$(csv_get "${TRANSITION_PROPOSERS:-}" "$i")
    proposer=${proposer:-$TRANSITION_PROPOSER}

    timestamp=$(csv_get "${TRANSITION_TIMESTAMPS:-}" "$i")
    timestamp=${timestamp:-${TRANSITION_TIMESTAMP:-}}
    if [[ -z "$timestamp" ]]; then
        echo "Error: TRANSITION_TIMESTAMP or TRANSITION_TIMESTAMPS[$i] is required" >&2
        exit 1
    fi

    block_hash=$(csv_get "${TRANSITION_BLOCK_HASHES:-}" "$i")
    if (( i == NUM_PROPOSALS - 1 )); then
        block_hash=$LAST_BLOCK_HASH
    elif [[ -z "$block_hash" ]]; then
        echo "Error: TRANSITION_BLOCK_HASHES[$i] is required for non-last transitions" >&2
        exit 1
    fi

    require_uint_max "TRANSITION_TIMESTAMPS[$i]" "$timestamp" 281474976710655
    proposer_hex=$(normalize_hex_len "TRANSITION_PROPOSERS[$i]" "$proposer" 40)
    block_hash_hex=$(normalize_hex_len "TRANSITION_BLOCK_HASHES[$i]" "$block_hash" 64)

    TRANSITIONS_HEX+="${proposer_hex}$(uint_hex 12 "$timestamp")${block_hash_hex}"
done

PROVE_DATA="0x$(uint_hex 12 "$FIRST_PROPOSAL_ID")${FIRST_PARENT_HASH_HEX}${LAST_PROPOSAL_HASH_HEX}${ACTUAL_PROVER_HEX}$(uint_hex 12 "$END_BLOCK_NUMBER")${END_STATE_ROOT_HEX}$(uint_hex 4 "$NUM_PROPOSALS")${TRANSITIONS_HEX}"

tx_args=()
add_optional_tx_args

echo "INBOX=$INBOX"
echo "FIRST_PROPOSAL_ID=$FIRST_PROPOSAL_ID"
echo "LAST_PROPOSAL_ID=$LAST_PROPOSAL_ID"
echo "LAST_PROPOSAL_HASH=0x$LAST_PROPOSAL_HASH_HEX"
echo "LAST_BLOCK_HASH=0x$LAST_BLOCK_HASH_HEX"
echo "PROVE_DATA=$PROVE_DATA"

"$CAST_BIN" send "$INBOX" "prove(bytes,bytes)" "$PROVE_DATA" "$PROOF" \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    "${tx_args[@]}"
