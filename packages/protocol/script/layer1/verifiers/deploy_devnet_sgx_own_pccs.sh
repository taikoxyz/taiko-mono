#!/bin/bash
#
# One-shot devnet smoke for a fully self-deployed Automata DCAP/on-chain PCCS
# stack plus SGX collateral and SecureSgxVerifier registration.
#
# Defaults match the local Taiko devnet workflow:
#   DEVNET_ENV=/home/yue/works/taiko/raiko2-k8s/devnet.env
#   SGX_BOOTSTRAP_JSON=/tmp/provider-log-check-20260519/raiko2-sgx/config/bootstrap.json
#   INTEL_API_SGX=https://127.0.0.1:8081/sgx/certification/v4
#
# The local PCCS endpoint usually uses a self-signed cert, so PCS_CURL_INSECURE
# defaults to true for this devnet wrapper only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTOCOL_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
REPO_ROOT="$(cd "$PROTOCOL_DIR/../.." && pwd)"

DEVNET_ENV="${DEVNET_ENV:-/home/yue/works/taiko/raiko2-k8s/devnet.env}"
OUT_DIR="${OUT_DIR:-/tmp/devnet-sgx-own-pccs}"
WORK_DIR="${WORK_DIR:-$OUT_DIR/work}"
OUTPUT_JSON="${OUTPUT_JSON:-$OUT_DIR/automata_dcap.json}"
SUMMARY_JSON="${SUMMARY_JSON:-$OUT_DIR/devnet_sgx_own_pccs_summary.json}"
SGX_BOOTSTRAP_JSON="${SGX_BOOTSTRAP_JSON:-/tmp/provider-log-check-20260519/raiko2-sgx/config/bootstrap.json}"
INTEL_API_SGX="${INTEL_API_SGX:-https://127.0.0.1:8081/sgx/certification/v4}"
PCS_CURL_INSECURE="${PCS_CURL_INSECURE:-true}"
DEPLOY_DAIMO_P256="${DEPLOY_DAIMO_P256:-auto}"
KEEP_REPOS="${KEEP_REPOS:-true}"
RESET_WORK_DIR="${RESET_WORK_DIR:-false}"
REGISTER_SECURE_SGX="${REGISTER_SECURE_SGX:-true}"
INSTANCE_VALIDITY_DELAY="${INSTANCE_VALIDITY_DELAY:-86400}"
REGISTRAR="${REGISTRAR:-0x0000000000000000000000000000000000000000}"
ATTRIBUTE_POLICY_MASK="${ATTRIBUTE_POLICY_MASK:-0xffffffffffffffff0000000000000000}"

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "[devnet_sgx_own_pccs] $*"; }

redact_rpc() {
    echo "$1" | sed -E 's#(https?://[^/?]+).*#\1/<redacted>#'
}

normalize_rpc() {
    case "$1" in
        http://*|https://*) echo "$1" ;;
        *) echo "https://$1/" ;;
    esac
}

policy_expected() {
    python3 - "$1" "$2" <<'PY'
import sys

def parse_hex(value, expected_len):
    raw = value[2:] if value.startswith("0x") else value
    data = bytes.fromhex(raw)
    if len(data) != expected_len:
        raise SystemExit(f"expected {expected_len} bytes, got {len(data)}")
    return data

attributes = parse_hex(sys.argv[1], 16)
mask = parse_hex(sys.argv[2], 16)
print("0x" + bytes(a & m for a, m in zip(attributes, mask)).hex())
PY
}

extract_quote_info() {
    python3 - "$1" "$2" <<'PY'
import base64
import json
import sys

def raw_quote_from_bootstrap(path):
    data = json.load(open(path))
    inner = data if "quote" in data else next(iter(data.values()))
    quote_hex = inner["quote"]
    if quote_hex.startswith("0x"):
        quote_hex = quote_hex[2:]
    quote = bytes.fromhex(quote_hex)
    try:
        doc = json.loads(quote)
        if isinstance(doc, dict) and "RawQuote" in doc:
            quote = base64.b64decode(doc["RawQuote"])
        elif isinstance(doc, dict) and "InstanceInfo" in doc:
            instance_info = json.loads(base64.b64decode(doc["InstanceInfo"]))
            quote = base64.b64decode(instance_info["AttestationReport"])
    except Exception:
        pass
    return quote

quote = raw_quote_from_bootstrap(sys.argv[1])
if len(quote) < 48 + 384:
    raise SystemExit(f"SGX quote too short: {len(quote)} bytes")
report = quote[48:48 + 384]
out = {
    "raw_quote": "0x" + quote.hex(),
    "attributes": "0x" + report[48:64].hex(),
    "mrenclave": "0x" + report[64:96].hex(),
    "mrsigner": "0x" + report[128:160].hex(),
}
json.dump(out, open(sys.argv[2], "w"), indent=2)
PY
}

for cmd in cast forge jq python3; do command -v "$cmd" >/dev/null || die "missing dep: $cmd"; done
[[ -f "$DEVNET_ENV" ]] || die "DEVNET_ENV not found: $DEVNET_ENV"
[[ -f "$SGX_BOOTSTRAP_JSON" ]] || die "SGX_BOOTSTRAP_JSON not found: $SGX_BOOTSTRAP_JSON"

set -a
source "$DEVNET_ENV"
set +a

[[ -n "${PRIVATE_KEY:-}" ]] || die "PRIVATE_KEY is not set by $DEVNET_ENV"
[[ -n "${RPC_URL:-}" ]] || die "RPC_URL is not set by $DEVNET_ENV"
RPC_URL="$(normalize_rpc "$RPC_URL")"
export PRIVATE_KEY RPC_URL

mkdir -p "$OUT_DIR"
if [[ "$RESET_WORK_DIR" == "true" ]]; then
    rm -rf "$WORK_DIR"
fi

DEPLOYER=$(cast wallet address --private-key "$PRIVATE_KEY")
CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL")
TAIKO_CHAIN_ID="${TAIKO_CHAIN_ID:-$CHAIN_ID}"

log "chain=$CHAIN_ID rpc=$(redact_rpc "$RPC_URL") deployer=$DEPLOYER"
log "out=$OUT_DIR work=$WORK_DIR"

(
    cd "$REPO_ROOT"
    WORK_DIR="$WORK_DIR" \
    OUTPUT_JSON="$OUTPUT_JSON" \
    KEEP_REPOS="$KEEP_REPOS" \
    DEPLOY_DAIMO_P256="$DEPLOY_DAIMO_P256" \
    PRIVATE_KEY="$PRIVATE_KEY" \
    RPC_URL="$RPC_URL" \
        "$SCRIPT_DIR/deploy_automata_dcap.sh"
) 2>&1 | tee "$OUT_DIR/deploy_automata_dcap.log"

AUTOMATA_DCAP_ATTESTATION=$(jq -r '.AutomataDcapAttestationFee' "$OUTPUT_JSON")
PCCS_JSON=$(jq -r '.pccs_json' "$OUTPUT_JSON")
PCCS_REPO="$WORK_DIR/pccs"

[[ -n "$AUTOMATA_DCAP_ATTESTATION" && "$AUTOMATA_DCAP_ATTESTATION" != "null" ]] || die "missing AutomataDcapAttestationFee in $OUTPUT_JSON"
[[ -f "$PCCS_JSON" ]] || die "PCCS_JSON not found: $PCCS_JSON"
[[ -d "$PCCS_REPO" ]] || die "PCCS_REPO not found: $PCCS_REPO"

(
    cd "$REPO_ROOT"
    PRIVATE_KEY="$PRIVATE_KEY" \
    RPC_URL="$RPC_URL" \
    AUTOMATA_DCAP_ATTESTATION="$AUTOMATA_DCAP_ATTESTATION" \
    PCCS_JSON="$PCCS_JSON" \
    PCCS_REPO="$PCCS_REPO" \
    SGX_BOOTSTRAP_JSON="$SGX_BOOTSTRAP_JSON" \
    INTEL_API_SGX="$INTEL_API_SGX" \
    PCS_CURL_INSECURE="$PCS_CURL_INSECURE" \
        "$SCRIPT_DIR/setup_sgx_pccs_extras.sh"
) 2>&1 | tee "$OUT_DIR/setup_sgx_pccs_extras.log"

SECURE_SGX_VERIFIER=""
NEXT_INSTANCE_ID=""
LAST_INSTANCE=""
QUOTE_INFO_JSON="$OUT_DIR/sgx_quote_info.json"

if [[ "$REGISTER_SECURE_SGX" == "true" ]]; then
    extract_quote_info "$SGX_BOOTSTRAP_JSON" "$QUOTE_INFO_JSON"
    RAW_QUOTE=$(jq -r '.raw_quote' "$QUOTE_INFO_JSON")
    MRENCLAVE=$(jq -r '.mrenclave' "$QUOTE_INFO_JSON")
    MRSIGNER=$(jq -r '.mrsigner' "$QUOTE_INFO_JSON")
    ATTRIBUTES=$(jq -r '.attributes' "$QUOTE_INFO_JSON")
    ATTRIBUTE_POLICY_EXPECTED="${ATTRIBUTE_POLICY_EXPECTED:-$(policy_expected "$ATTRIBUTES" "$ATTRIBUTE_POLICY_MASK")}"

    log "deploying SecureSgxVerifier for registration smoke"
    DEPLOY_OUT=$(
        cd "$PROTOCOL_DIR"
        forge create --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --broadcast --legacy \
            "contracts/layer1/verifiers/SecureSgxVerifier.sol:SecureSgxVerifier" \
            --constructor-args \
            "$TAIKO_CHAIN_ID" \
            "$DEPLOYER" \
            "$AUTOMATA_DCAP_ATTESTATION" \
            "$REGISTRAR" \
            "$INSTANCE_VALIDITY_DELAY" 2>&1
    )
    echo "$DEPLOY_OUT" | tee "$OUT_DIR/secure_sgx_verifier_deploy.log"
    SECURE_SGX_VERIFIER=$(echo "$DEPLOY_OUT" | grep -oE 'Deployed to: 0x[0-9a-fA-F]{40}' | awk '{print $3}' | tail -1)
    [[ -n "$SECURE_SGX_VERIFIER" ]] || die "could not parse SecureSgxVerifier deployment address"

    (
        cd "$PROTOCOL_DIR"
        PRIVATE_KEY="$PRIVATE_KEY" \
        FORK_URL="$RPC_URL" \
        SGX_VERIFIER_ADDRESS="$SECURE_SGX_VERIFIER" \
        SKIP_SIMULATION=true \
            "$SCRIPT_DIR/configure_sgx_verifier.sh" \
                --attribute-policy "$MRENCLAVE" "$ATTRIBUTE_POLICY_MASK" "$ATTRIBUTE_POLICY_EXPECTED" \
                --mrenclave "$MRENCLAVE" \
                --mrsigner "$MRSIGNER" \
                --quote "$RAW_QUOTE"
    ) 2>&1 | tee "$OUT_DIR/secure_sgx_verifier_register.log"

    NEXT_INSTANCE_ID=$(cast call "$SECURE_SGX_VERIFIER" "nextInstanceId()(uint256)" --rpc-url "$RPC_URL")
    if [[ "$NEXT_INSTANCE_ID" =~ ^[0-9]+$ && "$NEXT_INSTANCE_ID" -gt 0 ]]; then
        LAST_ID=$((NEXT_INSTANCE_ID - 1))
        LAST_INSTANCE=$(cast call "$SECURE_SGX_VERIFIER" "instances(uint256)((address,uint64))" "$LAST_ID" --rpc-url "$RPC_URL")
        log "registered SGX instance id=$LAST_ID value=$LAST_INSTANCE"
    else
        log "nextInstanceId=$NEXT_INSTANCE_ID"
    fi
fi

jq -n \
    --arg chain "$CHAIN_ID" \
    --arg rpc "$(redact_rpc "$RPC_URL")" \
    --arg deployer "$DEPLOYER" \
    --arg dcap "$AUTOMATA_DCAP_ATTESTATION" \
    --arg pccs "$PCCS_JSON" \
    --arg quoteInfo "$QUOTE_INFO_JSON" \
    --arg secure "$SECURE_SGX_VERIFIER" \
    --arg nextId "$NEXT_INSTANCE_ID" \
    --arg lastInstance "$LAST_INSTANCE" \
    '{
        chain_id: $chain,
        rpc: $rpc,
        deployer: $deployer,
        AutomataDcapAttestationFee: $dcap,
        pccs_json: $pccs,
        sgx_quote_info_json: $quoteInfo,
        SecureSgxVerifier: $secure,
        nextInstanceId: $nextId,
        lastInstance: $lastInstance
    }' > "$SUMMARY_JSON"

log "summary written to $SUMMARY_JSON"
