#!/bin/bash
#
# Deploy two SecureSgxVerifier contracts on a network that already has an
# Automata DCAP attestation entrypoint or proxy.
#
# This is the Hoodi/mainnet path: it does not deploy Automata contracts, upload
# collateral, configure MRENCLAVE/MRSIGNER policy, or register an SGX instance.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTOCOL_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

NETWORK="${NETWORK:-}"
RPC_URL="${RPC_URL:-${FORK_URL:-}}"
TMP_ROOT="${TMPDIR:-/tmp}"
OUT_DIR="${OUT_DIR:-$TMP_ROOT/sgx-existing-automata}"
SUMMARY_JSON="${SUMMARY_JSON:-$OUT_DIR/sgx_existing_automata_summary.json}"

AUTOMATA_DCAP_ATTESTATION="${AUTOMATA_DCAP_ATTESTATION:-}"
SGX_GETH_AUTOMATA_DCAP_ATTESTATION="${SGX_GETH_AUTOMATA_DCAP_ATTESTATION:-${AUTOMATA_DCAP_ATTESTATION:-}}"
SGX_RETH_AUTOMATA_DCAP_ATTESTATION="${SGX_RETH_AUTOMATA_DCAP_ATTESTATION:-${AUTOMATA_DCAP_ATTESTATION:-}}"

SECURE_SGX_GETH_VERIFIER="${SECURE_SGX_GETH_VERIFIER:-}"
SECURE_SGX_RETH_VERIFIER="${SECURE_SGX_RETH_VERIFIER:-}"
TAIKO_CHAIN_ID="${TAIKO_CHAIN_ID:-}"
OWNER="${OWNER:-}"
REGISTRAR="${REGISTRAR:-0x0000000000000000000000000000000000000000}"
INSTANCE_VALIDITY_DELAY="${INSTANCE_VALIDITY_DELAY:-86400}"
ALLOW_RPC_CHAIN_ID_AS_TAIKO_CHAIN_ID="${ALLOW_RPC_CHAIN_ID_AS_TAIKO_CHAIN_ID:-false}"

FAKE_QUOTE_SMOKE="${FAKE_QUOTE_SMOKE:-true}"
FAKE_SGX_QUOTE="${FAKE_SGX_QUOTE:-0x0300020000000000}"

HOODI_TAIKO_CHAIN_ID=167013
MAINNET_TAIKO_CHAIN_ID=167000
HOODI_SGX_GETH_AUTOMATA_DCAP_ATTESTATION="0x488797321FA4272AF9d0eD4cDAe5Ec7a0210cBD5"
HOODI_SGX_RETH_AUTOMATA_DCAP_ATTESTATION="0xebA89cA02449070b902A5DDc406eE709940e280E"
MAINNET_SGX_GETH_AUTOMATA_DCAP_ATTESTATION="0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261"
MAINNET_SGX_RETH_AUTOMATA_DCAP_ATTESTATION="0x8d7C954960a36a7596d7eA4945dDf891967ca8A3"

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "[sgx_existing_automata] $*"; }

usage() {
    cat <<EOF
Deploy two SecureSgxVerifier contracts using existing Automata DCAP attesters.

Usage:
  PRIVATE_KEY=0x... RPC_URL=https://... NETWORK=hoodi \\
    ./script/layer1/verifiers/deploy_sgx_verifiers_with_existing_automata.sh

Required env:
  PRIVATE_KEY    Deployer private key with ETH on the target chain.
  RPC_URL        Target RPC endpoint. FORK_URL is also accepted.

Network shortcuts:
  NETWORK=hoodi    uses Taiko Hoodi chain id and the Hoodi geth/reth Automata proxies
  NETWORK=mainnet  uses Taiko mainnet chain id and the mainnet geth/reth Automata proxies

Custom env:
  TAIKO_CHAIN_ID                         Required unless NETWORK is hoodi/mainnet.
  AUTOMATA_DCAP_ATTESTATION              Shared Automata entrypoint for both verifiers.
  SGX_GETH_AUTOMATA_DCAP_ATTESTATION     Geth-specific Automata entrypoint/proxy.
  SGX_RETH_AUTOMATA_DCAP_ATTESTATION     Reth-specific Automata entrypoint/proxy.
  OWNER                                  Verifier owner. Defaults to the deployer.
  REGISTRAR                              Optional registerInstance caller gate. Defaults to zero.
  INSTANCE_VALIDITY_DELAY                Default: 86400 seconds.
  SECURE_SGX_GETH_VERIFIER               Existing geth verifier; skips deploying geth.
  SECURE_SGX_RETH_VERIFIER               Existing reth verifier; skips deploying reth.
  FAKE_QUOTE_SMOKE                       Default true; eth_call checks fake quote rejection.
  OUT_DIR / SUMMARY_JSON                 Output directory and summary path.

Output:
  SecureSgxGethVerifier and SecureSgxRethVerifier addresses in SUMMARY_JSON.

This script is deploy-only. Configure enclave identity policy and register
instances separately after real quotes are available.
EOF
}

redact_rpc() {
    echo "$1" | sed -E 's#(https?://[^/?]+).*#\1/<redacted>#'
}

normalize_rpc() {
    case "$1" in
        http://*|https://*) echo "$1" ;;
        *) echo "https://$1/" ;;
    esac
}

has_code() {
    local addr="$1"
    local code
    code=$(cast code "$addr" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x")
    [[ -n "${code//0x/}" ]]
}

require_code() {
    local label="$1"
    local addr="$2"

    [[ "$addr" =~ ^0x[0-9a-fA-F]{40}$ ]] || die "$label address is invalid: $addr"
    has_code "$addr" || die "$label has no code at $addr"
}

deploy_secure_sgx_verifier() {
    local label="$1"
    local automata="$2"
    local log_file="$OUT_DIR/secure_sgx_${label}_verifier_deploy.log"
    local deploy_out
    local addr

    log "deploying SecureSgxVerifier for $label with Automata $automata"
    deploy_out=$(
        cd "$PROTOCOL_DIR"
        forge create --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --broadcast --legacy \
            "contracts/layer1/verifiers/SecureSgxVerifier.sol:SecureSgxVerifier" \
            --constructor-args \
            "$TAIKO_CHAIN_ID" \
            "$OWNER" \
            "$automata" \
            "$REGISTRAR" \
            "$INSTANCE_VALIDITY_DELAY" 2>&1
    )
    echo "$deploy_out" | tee "$log_file"

    addr=$(echo "$deploy_out" | grep -oE 'Deployed to: 0x[0-9a-fA-F]{40}' | awk '{print $3}' | tail -1)
    [[ -n "$addr" ]] || die "could not parse SecureSgxVerifier deployment address for $label"
    require_code "SecureSgx${label^}Verifier" "$addr"

    case "$label" in
        geth) SECURE_SGX_GETH_VERIFIER="$addr" ;;
        reth) SECURE_SGX_RETH_VERIFIER="$addr" ;;
        *) die "unknown SecureSgxVerifier label: $label" ;;
    esac
}

run_fake_quote_smoke() {
    local label="$1"
    local verifier="$2"
    local out

    log "running fake SGX quote rejection smoke for $label"
    if out=$(cast call "$verifier" "registerInstance(bytes)" "$FAKE_SGX_QUOTE" \
        --rpc-url "$RPC_URL" 2>&1); then
        echo "$out" | tee "$OUT_DIR/secure_sgx_${label}_verifier_fake_quote.log"
        die "fake SGX quote unexpectedly passed registerInstance eth_call for $label"
    fi

    echo "$out" | tee "$OUT_DIR/secure_sgx_${label}_verifier_fake_quote.log"
    log "fake SGX quote rejected as expected for $label"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done

for cmd in cast forge jq; do command -v "$cmd" >/dev/null || die "missing dep: $cmd"; done
[[ -n "${PRIVATE_KEY:-}" ]] || die "PRIVATE_KEY is not set"
[[ -n "$RPC_URL" ]] || die "RPC_URL or FORK_URL is not set"
RPC_URL="$(normalize_rpc "$RPC_URL")"

case "${NETWORK,,}" in
    hoodi|taiko-hoodi)
        TAIKO_CHAIN_ID="${TAIKO_CHAIN_ID:-$HOODI_TAIKO_CHAIN_ID}"
        SGX_GETH_AUTOMATA_DCAP_ATTESTATION="${SGX_GETH_AUTOMATA_DCAP_ATTESTATION:-$HOODI_SGX_GETH_AUTOMATA_DCAP_ATTESTATION}"
        SGX_RETH_AUTOMATA_DCAP_ATTESTATION="${SGX_RETH_AUTOMATA_DCAP_ATTESTATION:-$HOODI_SGX_RETH_AUTOMATA_DCAP_ATTESTATION}"
        ;;
    mainnet|taiko-mainnet)
        TAIKO_CHAIN_ID="${TAIKO_CHAIN_ID:-$MAINNET_TAIKO_CHAIN_ID}"
        SGX_GETH_AUTOMATA_DCAP_ATTESTATION="${SGX_GETH_AUTOMATA_DCAP_ATTESTATION:-$MAINNET_SGX_GETH_AUTOMATA_DCAP_ATTESTATION}"
        SGX_RETH_AUTOMATA_DCAP_ATTESTATION="${SGX_RETH_AUTOMATA_DCAP_ATTESTATION:-$MAINNET_SGX_RETH_AUTOMATA_DCAP_ATTESTATION}"
        ;;
    "") ;;
    *) die "NETWORK must be hoodi, mainnet, or empty for custom config (got: $NETWORK)" ;;
esac

CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL") || die "Cannot reach $RPC_URL"
if [[ -z "$TAIKO_CHAIN_ID" ]]; then
    if [[ "$ALLOW_RPC_CHAIN_ID_AS_TAIKO_CHAIN_ID" == "true" ]]; then
        TAIKO_CHAIN_ID="$CHAIN_ID"
    else
        die "TAIKO_CHAIN_ID must be set unless NETWORK=hoodi or NETWORK=mainnet"
    fi
fi

[[ -n "$SGX_GETH_AUTOMATA_DCAP_ATTESTATION" ]] || die "SGX_GETH_AUTOMATA_DCAP_ATTESTATION or AUTOMATA_DCAP_ATTESTATION is required"
[[ -n "$SGX_RETH_AUTOMATA_DCAP_ATTESTATION" ]] || die "SGX_RETH_AUTOMATA_DCAP_ATTESTATION or AUTOMATA_DCAP_ATTESTATION is required"

DEPLOYER=$(cast wallet address --private-key "$PRIVATE_KEY")
OWNER="${OWNER:-$DEPLOYER}"

mkdir -p "$OUT_DIR"

log "network=${NETWORK:-custom} chain=$CHAIN_ID taikoChainId=$TAIKO_CHAIN_ID rpc=$(redact_rpc "$RPC_URL") deployer=$DEPLOYER owner=$OWNER"
log "geth Automata=$SGX_GETH_AUTOMATA_DCAP_ATTESTATION reth Automata=$SGX_RETH_AUTOMATA_DCAP_ATTESTATION"

require_code "SGX geth Automata attester" "$SGX_GETH_AUTOMATA_DCAP_ATTESTATION"
require_code "SGX reth Automata attester" "$SGX_RETH_AUTOMATA_DCAP_ATTESTATION"

if [[ -n "$SECURE_SGX_GETH_VERIFIER" ]]; then
    log "using existing SecureSgxGethVerifier: $SECURE_SGX_GETH_VERIFIER"
    require_code "SecureSgxGethVerifier" "$SECURE_SGX_GETH_VERIFIER"
else
    deploy_secure_sgx_verifier "geth" "$SGX_GETH_AUTOMATA_DCAP_ATTESTATION"
fi

if [[ -n "$SECURE_SGX_RETH_VERIFIER" ]]; then
    log "using existing SecureSgxRethVerifier: $SECURE_SGX_RETH_VERIFIER"
    require_code "SecureSgxRethVerifier" "$SECURE_SGX_RETH_VERIFIER"
else
    deploy_secure_sgx_verifier "reth" "$SGX_RETH_AUTOMATA_DCAP_ATTESTATION"
fi

if [[ -n "$SECURE_SGX_GETH_VERIFIER" && -n "$SECURE_SGX_RETH_VERIFIER" \
    && "${SECURE_SGX_GETH_VERIFIER,,}" == "${SECURE_SGX_RETH_VERIFIER,,}" ]]; then
    die "SECURE_SGX_GETH_VERIFIER and SECURE_SGX_RETH_VERIFIER must be different"
fi

if [[ "$FAKE_QUOTE_SMOKE" == "true" ]]; then
    run_fake_quote_smoke "geth" "$SECURE_SGX_GETH_VERIFIER"
    run_fake_quote_smoke "reth" "$SECURE_SGX_RETH_VERIFIER"
fi

jq -n \
    --arg network "${NETWORK:-custom}" \
    --arg chain "$CHAIN_ID" \
    --arg taikoChainId "$TAIKO_CHAIN_ID" \
    --arg rpc "$(redact_rpc "$RPC_URL")" \
    --arg deployer "$DEPLOYER" \
    --arg owner "$OWNER" \
    --arg registrar "$REGISTRAR" \
    --arg instanceValidityDelay "$INSTANCE_VALIDITY_DELAY" \
    --arg sgxGethAutomata "$SGX_GETH_AUTOMATA_DCAP_ATTESTATION" \
    --arg sgxRethAutomata "$SGX_RETH_AUTOMATA_DCAP_ATTESTATION" \
    --arg sgxGeth "$SECURE_SGX_GETH_VERIFIER" \
    --arg sgxReth "$SECURE_SGX_RETH_VERIFIER" \
    --arg fakeQuoteSmoke "$FAKE_QUOTE_SMOKE" \
    '{
        network: $network,
        chain_id: $chain,
        taiko_chain_id: $taikoChainId,
        rpc: $rpc,
        deployer: $deployer,
        owner: $owner,
        registrar: $registrar,
        instanceValidityDelay: $instanceValidityDelay,
        SgxGethAutomataDcapAttestation: $sgxGethAutomata,
        SgxRethAutomataDcapAttestation: $sgxRethAutomata,
        SecureSgxGethVerifier: $sgxGeth,
        SecureSgxRethVerifier: $sgxReth,
        fakeQuoteSmoke: $fakeQuoteSmoke
    }' > "$SUMMARY_JSON"

log "summary written to $SUMMARY_JSON"
