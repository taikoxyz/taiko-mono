#!/bin/bash
#
# One-shot devnet smoke for a fully self-deployed Automata DCAP/on-chain PCCS
# stack plus SGX collateral, two SecureSgxVerifier deployments for
# sgx-geth/sgx-reth, and optional SecureSgxVerifier registration.
#
# Required local inputs:
#   DEVNET_ENV=<devnet-env-file>
#   SGX_BOOTSTRAP_JSON=<sgx-bootstrap-json>
#   SGX_GETH_BOOTSTRAP_JSON=  # required only for REGISTER_SECURE_SGX_TARGET=geth|both
#   SGX_RETH_BOOTSTRAP_JSON=  # required only for REGISTER_SECURE_SGX_TARGET=reth|both
#   INTEL_API_SGX=https://<local-pccs>/sgx/certification/v4
#   DEPLOY_SECURE_SGX_VERIFIERS=true
#   TAIKO_CHAIN_ID=167001
#   REGISTER_SECURE_SGX=false
#   REGISTER_SECURE_SGX_TARGET=reth
#   FAKE_QUOTE_SMOKE=true
#
# The local PCCS endpoint usually uses a self-signed cert, so PCS_CURL_INSECURE
# defaults to true for this devnet wrapper only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTOCOL_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
REPO_ROOT="$(cd "$PROTOCOL_DIR/../.." && pwd)"

TMP_ROOT="${TMPDIR:-/tmp}"
DEVNET_ENV="${DEVNET_ENV:-}"
OUT_DIR="${OUT_DIR:-$TMP_ROOT/devnet-sgx-own-pccs}"
WORK_DIR="${WORK_DIR:-$OUT_DIR/work}"
OUTPUT_JSON="${OUTPUT_JSON:-$OUT_DIR/automata_dcap.json}"
SUMMARY_JSON="${SUMMARY_JSON:-$OUT_DIR/devnet_sgx_own_pccs_summary.json}"
SGX_BOOTSTRAP_JSON="${SGX_BOOTSTRAP_JSON:-}"
SGX_GETH_BOOTSTRAP_JSON="${SGX_GETH_BOOTSTRAP_JSON:-}"
SGX_RETH_BOOTSTRAP_JSON="${SGX_RETH_BOOTSTRAP_JSON:-}"
INTEL_API_SGX="${INTEL_API_SGX:-https://127.0.0.1:8081/sgx/certification/v4}"
PCS_CURL_INSECURE="${PCS_CURL_INSECURE:-true}"
DEPLOY_DAIMO_P256="${DEPLOY_DAIMO_P256:-auto}"
KEEP_REPOS="${KEEP_REPOS:-true}"
RESET_WORK_DIR="${RESET_WORK_DIR:-false}"
SECURE_SGX_GETH_VERIFIER="${SECURE_SGX_GETH_VERIFIER:-}"
SECURE_SGX_RETH_VERIFIER="${SECURE_SGX_RETH_VERIFIER:-}"
DEPLOY_SECURE_SGX_VERIFIERS="${DEPLOY_SECURE_SGX_VERIFIERS:-true}"
REGISTER_SECURE_SGX="${REGISTER_SECURE_SGX:-false}"
REGISTER_SECURE_SGX_TARGET="${REGISTER_SECURE_SGX_TARGET:-reth}" # geth | reth | both
FAKE_QUOTE_SMOKE="${FAKE_QUOTE_SMOKE:-true}"
FAKE_SGX_QUOTE="${FAKE_SGX_QUOTE:-0x0300020000000000}"
INSTANCE_VALIDITY_DELAY="${INSTANCE_VALIDITY_DELAY:-86400}"
REGISTRAR="${REGISTRAR:-0x0000000000000000000000000000000000000000}"
ATTRIBUTE_POLICY_MASK="${ATTRIBUTE_POLICY_MASK:-0xffffffffffffffff0000000000000000}"
TAIKO_CHAIN_ID="${TAIKO_CHAIN_ID:-}"
ALLOW_RPC_CHAIN_ID_AS_TAIKO_CHAIN_ID="${ALLOW_RPC_CHAIN_ID_AS_TAIKO_CHAIN_ID:-false}"

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
[[ -n "$DEVNET_ENV" ]] || die "DEVNET_ENV is not set"
[[ -f "$DEVNET_ENV" ]] || die "DEVNET_ENV not found: $DEVNET_ENV"
SETUP_SGX_BOOTSTRAP_JSON=""
if [[ -f "$SGX_BOOTSTRAP_JSON" ]]; then
    SETUP_SGX_BOOTSTRAP_JSON="$SGX_BOOTSTRAP_JSON"
elif [[ -f "$SGX_RETH_BOOTSTRAP_JSON" ]]; then
    SETUP_SGX_BOOTSTRAP_JSON="$SGX_RETH_BOOTSTRAP_JSON"
elif [[ -f "$SGX_GETH_BOOTSTRAP_JSON" ]]; then
    SETUP_SGX_BOOTSTRAP_JSON="$SGX_GETH_BOOTSTRAP_JSON"
elif [[ -z "${FMSPC:-}" && -z "${SGX_BOOTSTRAP_URL:-}" ]]; then
    if [[ -z "$SGX_BOOTSTRAP_JSON" ]]; then
        die "SGX_BOOTSTRAP_JSON is not set; set SGX_BOOTSTRAP_JSON, SGX_BOOTSTRAP_URL, or FMSPC for PCCS collateral setup"
    fi
    die "SGX_BOOTSTRAP_JSON not found: $SGX_BOOTSTRAP_JSON; set SGX_BOOTSTRAP_JSON, SGX_BOOTSTRAP_URL, or FMSPC for PCCS collateral setup"
else
    log "SGX_BOOTSTRAP_JSON not found; continuing with FMSPC/SGX_BOOTSTRAP_URL overrides"
fi

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
if [[ -z "$TAIKO_CHAIN_ID" ]]; then
    if [[ "$ALLOW_RPC_CHAIN_ID_AS_TAIKO_CHAIN_ID" == "true" ]]; then
        TAIKO_CHAIN_ID="$CHAIN_ID"
    else
        die "TAIKO_CHAIN_ID must be set to the Taiko L2 chain ID; set ALLOW_RPC_CHAIN_ID_AS_TAIKO_CHAIN_ID=true only if the RPC chain ID is intentionally the Taiko chain ID"
    fi
fi

log "chain=$CHAIN_ID taikoChainId=$TAIKO_CHAIN_ID rpc=$(redact_rpc "$RPC_URL") deployer=$DEPLOYER"
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
    SGX_BOOTSTRAP_JSON="$SETUP_SGX_BOOTSTRAP_JSON" \
    INTEL_API_SGX="$INTEL_API_SGX" \
    PCS_CURL_INSECURE="$PCS_CURL_INSECURE" \
        "$SCRIPT_DIR/setup_sgx_pccs_extras.sh"
) 2>&1 | tee "$OUT_DIR/setup_sgx_pccs_extras.log"

NEXT_INSTANCE_ID=""
LAST_INSTANCE=""
NEXT_INSTANCE_ID_GETH=""
LAST_INSTANCE_GETH=""
NEXT_INSTANCE_ID_RETH=""
LAST_INSTANCE_RETH=""
QUOTE_INFO_JSON=""
SGX_GETH_QUOTE_INFO_JSON=""
SGX_RETH_QUOTE_INFO_JSON=""
FAKE_QUOTE_SMOKE_GETH_RESULT="skipped"
FAKE_QUOTE_SMOKE_RETH_RESULT="skipped"

deploy_secure_sgx_verifier() {
    local label="$1"
    local log_file="$OUT_DIR/secure_sgx_${label}_verifier_deploy.log"
    local addr

    log "deploying SecureSgxVerifier for $label"
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
    echo "$DEPLOY_OUT" | tee "$log_file"
    addr=$(echo "$DEPLOY_OUT" | grep -oE 'Deployed to: 0x[0-9a-fA-F]{40}' | awk '{print $3}' | tail -1)
    [[ -n "$addr" ]] || die "could not parse SecureSgxVerifier deployment address for $label"

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
    case "$label" in
        geth)
            FAKE_QUOTE_SMOKE_GETH_RESULT="rejected"
            log "fake SGX quote rejected as expected for geth"
            ;;
        reth)
            FAKE_QUOTE_SMOKE_RETH_RESULT="rejected"
            log "fake SGX quote rejected as expected for reth"
            ;;
        *) die "unknown fake quote smoke label: $label" ;;
    esac
}

require_bootstrap_json() {
    local label="$1"
    local path="$2"

    [[ -n "$path" ]] || die "REGISTER_SECURE_SGX_TARGET=$REGISTER_SECURE_SGX_TARGET requires SGX_${label^^}_BOOTSTRAP_JSON"
    [[ -f "$path" ]] || die "SGX_${label^^}_BOOTSTRAP_JSON not found: $path"
}

register_real_sgx_quote() {
    local label="$1"
    local verifier="$2"
    local bootstrap_json="$3"
    local quote_info_json="$OUT_DIR/sgx_${label}_quote_info.json"
    local raw_quote
    local mrenclave
    local mrsigner
    local attributes
    local attribute_policy_expected
    local next_id
    local last_id
    local last_instance

    extract_quote_info "$bootstrap_json" "$quote_info_json"
    raw_quote=$(jq -r '.raw_quote' "$quote_info_json")
    mrenclave=$(jq -r '.mrenclave' "$quote_info_json")
    mrsigner=$(jq -r '.mrsigner' "$quote_info_json")
    attributes=$(jq -r '.attributes' "$quote_info_json")
    attribute_policy_expected="${ATTRIBUTE_POLICY_EXPECTED:-$(policy_expected "$attributes" "$ATTRIBUTE_POLICY_MASK")}"

    log "registering real SGX quote on $label SecureSgxVerifier"
    (
        cd "$PROTOCOL_DIR"
        PRIVATE_KEY="$PRIVATE_KEY" \
        FORK_URL="$RPC_URL" \
        SGX_VERIFIER_ADDRESS="$verifier" \
        SKIP_SIMULATION=true \
            "$SCRIPT_DIR/configure_sgx_verifier.sh" \
                --attribute-policy "$mrenclave" "$ATTRIBUTE_POLICY_MASK" "$attribute_policy_expected" \
                --mrenclave "$mrenclave" \
                --mrsigner "$mrsigner" \
                --quote "$raw_quote"
    ) 2>&1 | tee "$OUT_DIR/secure_sgx_${label}_verifier_register.log"

    next_id=$(cast call "$verifier" "nextInstanceId()(uint256)" --rpc-url "$RPC_URL")
    if [[ "$next_id" =~ ^[0-9]+$ && "$next_id" -gt 0 ]]; then
        last_id=$((next_id - 1))
        last_instance=$(cast call "$verifier" "instances(uint256)((address,uint64))" "$last_id" --rpc-url "$RPC_URL")
        log "registered SGX instance on $label id=$last_id value=$last_instance"
    else
        last_instance=""
        log "$label nextInstanceId=$next_id"
    fi

    case "$label" in
        geth)
            NEXT_INSTANCE_ID_GETH="$next_id"
            LAST_INSTANCE_GETH="$last_instance"
            SGX_GETH_QUOTE_INFO_JSON="$quote_info_json"
            ;;
        reth)
            NEXT_INSTANCE_ID_RETH="$next_id"
            LAST_INSTANCE_RETH="$last_instance"
            SGX_RETH_QUOTE_INFO_JSON="$quote_info_json"
            ;;
        *) die "unknown SGX registration label: $label" ;;
    esac
}

if [[ "$DEPLOY_SECURE_SGX_VERIFIERS" == "true" && -z "$SECURE_SGX_GETH_VERIFIER" ]]; then
    deploy_secure_sgx_verifier "geth"
elif [[ -n "$SECURE_SGX_GETH_VERIFIER" ]]; then
    log "using existing SecureSgxGethVerifier: $SECURE_SGX_GETH_VERIFIER"
fi

if [[ "$DEPLOY_SECURE_SGX_VERIFIERS" == "true" && -z "$SECURE_SGX_RETH_VERIFIER" ]]; then
    deploy_secure_sgx_verifier "reth"
elif [[ -n "$SECURE_SGX_RETH_VERIFIER" ]]; then
    log "using existing SecureSgxRethVerifier: $SECURE_SGX_RETH_VERIFIER"
fi

if [[ -n "$SECURE_SGX_GETH_VERIFIER" && -n "$SECURE_SGX_RETH_VERIFIER" \
    && "${SECURE_SGX_GETH_VERIFIER,,}" == "${SECURE_SGX_RETH_VERIFIER,,}" ]]; then
    die "SECURE_SGX_GETH_VERIFIER and SECURE_SGX_RETH_VERIFIER must be different; MRENCLAVE policies are configured per verifier"
fi

if [[ "$FAKE_QUOTE_SMOKE" == "true" ]]; then
    [[ -n "$SECURE_SGX_GETH_VERIFIER" ]] || die "FAKE_QUOTE_SMOKE=true requires DEPLOY_SECURE_SGX_VERIFIERS=true or SECURE_SGX_GETH_VERIFIER=0x..."
    [[ -n "$SECURE_SGX_RETH_VERIFIER" ]] || die "FAKE_QUOTE_SMOKE=true requires DEPLOY_SECURE_SGX_VERIFIERS=true or SECURE_SGX_RETH_VERIFIER=0x..."
    run_fake_quote_smoke "geth" "$SECURE_SGX_GETH_VERIFIER"
    run_fake_quote_smoke "reth" "$SECURE_SGX_RETH_VERIFIER"
fi

if [[ "$REGISTER_SECURE_SGX" == "true" ]]; then
    [[ -n "$SECURE_SGX_GETH_VERIFIER" ]] || die "REGISTER_SECURE_SGX=true requires DEPLOY_SECURE_SGX_VERIFIERS=true or SECURE_SGX_GETH_VERIFIER=0x..."
    [[ -n "$SECURE_SGX_RETH_VERIFIER" ]] || die "REGISTER_SECURE_SGX=true requires DEPLOY_SECURE_SGX_VERIFIERS=true or SECURE_SGX_RETH_VERIFIER=0x..."

    case "$REGISTER_SECURE_SGX_TARGET" in
        geth)
            require_bootstrap_json "geth" "$SGX_GETH_BOOTSTRAP_JSON"
            register_real_sgx_quote "geth" "$SECURE_SGX_GETH_VERIFIER" "$SGX_GETH_BOOTSTRAP_JSON"
            QUOTE_INFO_JSON="$SGX_GETH_QUOTE_INFO_JSON"
            NEXT_INSTANCE_ID="$NEXT_INSTANCE_ID_GETH"
            LAST_INSTANCE="$LAST_INSTANCE_GETH"
            ;;
        reth)
            require_bootstrap_json "reth" "$SGX_RETH_BOOTSTRAP_JSON"
            register_real_sgx_quote "reth" "$SECURE_SGX_RETH_VERIFIER" "$SGX_RETH_BOOTSTRAP_JSON"
            QUOTE_INFO_JSON="$SGX_RETH_QUOTE_INFO_JSON"
            NEXT_INSTANCE_ID="$NEXT_INSTANCE_ID_RETH"
            LAST_INSTANCE="$LAST_INSTANCE_RETH"
            ;;
        both)
            require_bootstrap_json "geth" "$SGX_GETH_BOOTSTRAP_JSON"
            require_bootstrap_json "reth" "$SGX_RETH_BOOTSTRAP_JSON"
            register_real_sgx_quote "geth" "$SECURE_SGX_GETH_VERIFIER" "$SGX_GETH_BOOTSTRAP_JSON"
            register_real_sgx_quote "reth" "$SECURE_SGX_RETH_VERIFIER" "$SGX_RETH_BOOTSTRAP_JSON"
            QUOTE_INFO_JSON="$SGX_RETH_QUOTE_INFO_JSON"
            NEXT_INSTANCE_ID="$NEXT_INSTANCE_ID_RETH"
            LAST_INSTANCE="$LAST_INSTANCE_RETH"
            ;;
        *)
            die "REGISTER_SECURE_SGX_TARGET must be geth, reth, or both (got: $REGISTER_SECURE_SGX_TARGET)"
            ;;
    esac
fi

jq -n \
    --arg chain "$CHAIN_ID" \
    --arg taikoChainId "$TAIKO_CHAIN_ID" \
    --arg rpc "$(redact_rpc "$RPC_URL")" \
    --arg deployer "$DEPLOYER" \
    --arg dcap "$AUTOMATA_DCAP_ATTESTATION" \
    --arg pccs "$PCCS_JSON" \
    --arg quoteInfo "$QUOTE_INFO_JSON" \
    --arg sgxGethQuoteInfo "$SGX_GETH_QUOTE_INFO_JSON" \
    --arg sgxRethQuoteInfo "$SGX_RETH_QUOTE_INFO_JSON" \
    --arg sgxGeth "$SECURE_SGX_GETH_VERIFIER" \
    --arg sgxReth "$SECURE_SGX_RETH_VERIFIER" \
    --arg registerSecureSgx "$REGISTER_SECURE_SGX" \
    --arg registerSecureSgxTarget "$REGISTER_SECURE_SGX_TARGET" \
    --arg fakeQuoteSmoke "$FAKE_QUOTE_SMOKE" \
    --arg fakeQuoteSmokeGethResult "$FAKE_QUOTE_SMOKE_GETH_RESULT" \
    --arg fakeQuoteSmokeRethResult "$FAKE_QUOTE_SMOKE_RETH_RESULT" \
    --arg nextId "$NEXT_INSTANCE_ID" \
    --arg lastInstance "$LAST_INSTANCE" \
    --arg nextIdGeth "$NEXT_INSTANCE_ID_GETH" \
    --arg lastInstanceGeth "$LAST_INSTANCE_GETH" \
    --arg nextIdReth "$NEXT_INSTANCE_ID_RETH" \
    --arg lastInstanceReth "$LAST_INSTANCE_RETH" \
    '{
        chain_id: $chain,
        taiko_chain_id: $taikoChainId,
        rpc: $rpc,
        deployer: $deployer,
        AutomataDcapAttestationFee: $dcap,
        pccs_json: $pccs,
        sgx_quote_info_json: $quoteInfo,
        sgx_geth_quote_info_json: $sgxGethQuoteInfo,
        sgx_reth_quote_info_json: $sgxRethQuoteInfo,
        SecureSgxGethVerifier: $sgxGeth,
        SecureSgxRethVerifier: $sgxReth,
        registerSecureSgx: $registerSecureSgx,
        registerSecureSgxTarget: $registerSecureSgxTarget,
        fakeQuoteSmoke: $fakeQuoteSmoke,
        fakeQuoteSmokeGethResult: $fakeQuoteSmokeGethResult,
        fakeQuoteSmokeRethResult: $fakeQuoteSmokeRethResult,
        nextInstanceId: $nextId,
        lastInstance: $lastInstance,
        nextInstanceIdGeth: $nextIdGeth,
        lastInstanceGeth: $lastInstanceGeth,
        nextInstanceIdReth: $nextIdReth,
        lastInstanceReth: $lastInstanceReth
    }' > "$SUMMARY_JSON"

log "summary written to $SUMMARY_JSON"
