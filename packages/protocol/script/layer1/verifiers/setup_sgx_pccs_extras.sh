#!/bin/bash
#
# Idempotent finish for SGX PCCS bring-up. Run this after deploying a fresh
# Automata DCAP/on-chain PCCS stack and before the first SGX `registerInstance`
# call on that stack.
#
# What this script does (and why it's needed):
#
#   1. Deploys `AutomataFmspcTcbDaoVersioned` + `AutomataEnclaveIdentityDaoVersioned`
#      at the FMSPC's current "standard" TCB Evaluation Data Number.
#      `deploy_automata_dcap.sh` only deploys the legacy non-versioned DAOs and the
#      bare `AutomataTcbEvalDao`, but PCCSRouter resolves TCB info and QE identity
#      through the **versioned** mappings — without these, SGX V3 quote lookup
#      reverts with `FmspcTcbExpiredOrNotFound` / `QEIdentityExpiredOrNotFound`.
#
#   2. Grants `AutomataDaoStorage.grantDao` to the two new DAOs and `ATTESTER_ROLE`
#      (Solady `_ROLE_0` = 1) to the deployer on FmspcTcbDaoVersioned,
#      EnclaveIdentityDaoVersioned, and AutomataTcbEvalDao. Without these, the
#      collateral upserts in step 5 revert with `Unauthorized`.
#
#   3. Calls `PCCSRouter.setFmspcTcbDaoVersionedAddr` + `setQeIdDaoVersionedAddr`
#      so SGX V3 lookups resolve to the new DAOs. `deploy_automata_dcap.sh` configures
#      only the unversioned router mappings.
#
#   4. Loads `Root CA CRL` and `PCK Platform CA cert + CRL` into PcsDao.
#      `deploy_automata_dcap.sh` skips both — but Automata DCAP `verifyAndAttestOnChain`
#      validates the full PCK certificate chain (including the platform-CA intermediate)
#      and its CRL, so without these the verifier reverts with `CrlExpiredOrNotFound`
#      after PCCS lookups otherwise succeed.
#
#   5. Loads TCB info (`tcbEvaluationDataNumber=<standard>`), QE identity (QE,
#      `tcbEvaluationDataNumber=<standard>`) and TCB Evaluation Data Numbers into
#      the corresponding versioned/legacy DAOs. Hoodi's transaction gas cap is too
#      low for the current synchronous `upsertFmspcTcb` path, so SGX FMSPC TCB
#      defaults to a direct AutomataDaoStorage write of the exact payload the DAO
#      would have stored. Set FMSPC_TCB_UPLOAD_MODE=dao to force the original path.
#
# Inputs:
#   PRIVATE_KEY                Deployer key (must own AutomataDaoStorage / PcsDao /
#                              PCCSRouter / new versioned DAOs — i.e. the same key
#                              used for the DCAP/PCCS deployment.
#   RPC_URL                    Default: http://localhost:8545
#   SGX_BOOTSTRAP_JSON         Local bootstrap JSON containing an SGX quote. Used to
#                              auto-detect FMSPC and extract the PCK Platform CA cert.
#   SGX_BOOTSTRAP_URL          Optional URL whose `/bootstrap` returns the same JSON.
#   FMSPC                      Optional override (6 hex bytes, e.g. 00606a000000).
#   AUTOMATA_DCAP_ATTESTATION  AutomataDcapAttestationFee address (printed by the
#                              sibling deploy script). Used to find PCCSRouter via
#                              `quoteVerifiers(3).pccsRouter`.
#   PCCS_JSON                  Path to PCCS deployment JSON; must contain
#                              AutomataDaoStorage, AutomataPcsDao, AutomataPckDao,
#                              AutomataTcbEvalDao, and the helper addresses.
#   PCCS_REPO                  automata-on-chain-pccs checkout. The one-shot wrapper
#                              sets this to WORK_DIR/pccs when it deploys PCCS.
#
# Dependencies: cast, forge, curl, jq, openssl, python3.

set -euo pipefail

PRIVATE_KEY="${PRIVATE_KEY:-}"
RPC_URL="${RPC_URL:-http://localhost:8545}"
SGX_BOOTSTRAP_JSON="${SGX_BOOTSTRAP_JSON:-}"
SGX_BOOTSTRAP_URL="${SGX_BOOTSTRAP_URL:-${RAIKO2_URL:-}}"
FMSPC="${FMSPC:-}"
AUTOMATA_DCAP_ATTESTATION="${AUTOMATA_DCAP_ATTESTATION:-}"
PCCS_JSON="${PCCS_JSON:-}"
PCCS_REPO="${PCCS_REPO:-}"
INTEL_API_SGX="${INTEL_API_SGX:-https://api.trustedservices.intel.com/sgx/certification/v4}"
TCB_EVAL_API_SGX="${TCB_EVAL_API_SGX:-https://api.trustedservices.intel.com/sgx/certification/v4}"
INTEL_CERTS="${INTEL_CERTS:-https://certificates.trustedservices.intel.com}"
PCK_PLATFORM_CA_DER="${PCK_PLATFORM_CA_DER:-}"
PCS_CURL_INSECURE="${PCS_CURL_INSECURE:-false}"
FMSPC_TCB_UPLOAD_MODE="${FMSPC_TCB_UPLOAD_MODE:-direct-storage}" # direct-storage | dao
FMSPC_TCB_GAS_LIMIT="${FMSPC_TCB_GAS_LIMIT:-13000000}"
ENCLAVE_ID_GAS_LIMIT="${ENCLAVE_ID_GAS_LIMIT:-12000000}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTOCOL_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "[setup_sgx_pccs_extras] $*"; }

CURL_PCS_ARGS=(-sSf --max-time 30)
if [[ "$PCS_CURL_INSECURE" == "true" ]]; then
    CURL_PCS_ARGS+=(-k)
fi

curl_pcs() {
    curl "${CURL_PCS_ARGS[@]}" "$@"
}

redact_rpc() {
    echo "$1" | sed -E 's#(https?://[^/?]+).*#\1/<redacted>#'
}

require_code() {
    local label="$1"
    local addr="$2"
    local code

    [[ -z "$addr" || "$addr" == "null" ]] && die "$label address missing"
    code=$(cast code "$addr" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x")
    [[ -n "${code//0x/}" ]] || die "$label has no code at $addr; rerun deploy_automata_dcap.sh with this PCCS_JSON/PCCS_REPO"
}

usage() {
    cat <<EOF
Usage:
  PRIVATE_KEY=0x... RPC_URL=... AUTOMATA_DCAP_ATTESTATION=0x... \\
    PCCS_JSON=<pccs-json> PCCS_REPO=<automata-on-chain-pccs-checkout> \\
    [SGX_BOOTSTRAP_JSON=<sgx-bootstrap-json> | SGX_BOOTSTRAP_URL=http://host:port | FMSPC=00606a000000] \\
    ./setup_sgx_pccs_extras.sh

Helpers:
  ./setup_sgx_pccs_extras.sh --extract-fmspc <sgx-bootstrap-json>
EOF
}

extract_sgx_fmspc() {
    python3 - "$1" <<'PY'
import base64, json, re, sys

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

def certs_from_sgx_quote(quote):
    sig_off = 48 + 384
    sig_len = int.from_bytes(quote[sig_off:sig_off + 4], "little")
    sig = quote[sig_off + 4:sig_off + 4 + sig_len]
    qe_auth_size = int.from_bytes(sig[576:578], "little")
    offset = 578 + qe_auth_size
    cert_type = int.from_bytes(sig[offset:offset + 2], "little")
    if cert_type != 5:
        raise SystemExit(f"unsupported SGX quote cert type: {cert_type}")
    cert_size = int.from_bytes(sig[offset + 2:offset + 6], "little")
    chain = sig[offset + 6:offset + 6 + cert_size]
    certs = re.findall(b"-----BEGIN CERTIFICATE-----(.+?)-----END CERTIFICATE-----", chain, re.DOTALL)
    if not certs:
        raise SystemExit("PCK cert chain not found")
    return certs

quote = raw_quote_from_bootstrap(sys.argv[1])
leaf = base64.b64decode(certs_from_sgx_quote(quote)[0].replace(b"\n", b"").strip())
oid = bytes.fromhex("060A2A864886F84D010D0104")
idx = leaf.find(oid)
if idx < 0:
    raise SystemExit("FMSPC OID not found")
rest = leaf[idx + len(oid):]
for i in range(min(32, len(rest) - 7)):
    if rest[i] == 0x04 and rest[i + 1] == 0x06:
        print(rest[i + 2:i + 8].hex())
        raise SystemExit(0)
raise SystemExit("FMSPC not found")
PY
}

extract_sgx_platform_ca() {
    python3 - "$1" "$2" <<'PY'
import base64, json, re, sys

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
sig_off = 48 + 384
sig_len = int.from_bytes(quote[sig_off:sig_off + 4], "little")
sig = quote[sig_off + 4:sig_off + 4 + sig_len]
qe_auth_size = int.from_bytes(sig[576:578], "little")
offset = 578 + qe_auth_size
cert_type = int.from_bytes(sig[offset:offset + 2], "little")
if cert_type != 5:
    raise SystemExit(f"unsupported SGX quote cert type: {cert_type}")
cert_size = int.from_bytes(sig[offset + 2:offset + 6], "little")
chain = sig[offset + 6:offset + 6 + cert_size]
certs = re.findall(b"-----BEGIN CERTIFICATE-----(.+?)-----END CERTIFICATE-----", chain, re.DOTALL)
if len(certs) < 2:
    raise SystemExit("PCK Platform CA not found in quote cert chain")
platform_ca = b"-----BEGIN CERTIFICATE-----" + certs[1] + b"-----END CERTIFICATE-----"
open(sys.argv[2] + "/pck_plat_ca.pem", "wb").write(platform_ca)
PY
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            usage
            exit 0
            ;;
        --extract-fmspc)
            [[ $# -ge 2 ]] || die "--extract-fmspc requires a bootstrap JSON path"
            extract_sgx_fmspc "$2"
            exit 0
            ;;
        *)
            die "Unknown option: $1"
            ;;
    esac
done

[[ -z "$PRIVATE_KEY" ]] && die "PRIVATE_KEY is not set"
[[ -z "$AUTOMATA_DCAP_ATTESTATION" ]] && die "AUTOMATA_DCAP_ATTESTATION is not set"
[[ -z "$PCCS_JSON" || ! -f "$PCCS_JSON" ]] && die "PCCS_JSON is not set or not a file: $PCCS_JSON"
[[ -n "$PCCS_REPO" && -d "$PCCS_REPO" ]] || die "PCCS_REPO is not set or not a directory"
for cmd in cast forge curl jq openssl python3; do command -v "$cmd" >/dev/null || die "missing dep: $cmd"; done

DEPLOYER=$(cast wallet address --private-key "$PRIVATE_KEY")
CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL")
log "chain=$CHAIN_ID rpc=$(redact_rpc "$RPC_URL") deployer=$DEPLOYER"

# ---- Read PCCS addresses from deployment JSON -----------------------------
STORAGE=$(jq -r '.AutomataDaoStorage'   "$PCCS_JSON")
PCS_DAO=$(jq -r '.AutomataPcsDao'        "$PCCS_JSON")
PCK_DAO=$(jq -r '.AutomataPckDao'        "$PCCS_JSON")
TCB_EVAL_DAO=$(jq -r '.AutomataTcbEvalDao' "$PCCS_JSON")
ENCLAVE_HELPER=$(jq -r '.EnclaveIdentityHelper' "$PCCS_JSON")
FMSPC_HELPER=$(jq -r '.FmspcTcbHelper'   "$PCCS_JSON")
PCK_HELPER=$(jq -r '.PCKHelper'          "$PCCS_JSON")
CRL_HELPER=$(jq -r '.X509CRLHelper'      "$PCCS_JSON")
P256=${P256:-0x0000000000000000000000000000000000000100}  # RIP-7212 P256 precompile used by current Automata PCCS

for a in "$STORAGE" "$PCS_DAO" "$PCK_DAO" "$TCB_EVAL_DAO" "$ENCLAVE_HELPER" "$FMSPC_HELPER" "$PCK_HELPER" "$CRL_HELPER"; do
    [[ "$a" == "null" || -z "$a" ]] && die "missing required address in $PCCS_JSON"
done
require_code "AutomataDaoStorage" "$STORAGE"
require_code "AutomataPcsDao" "$PCS_DAO"
require_code "AutomataPckDao" "$PCK_DAO"
require_code "AutomataTcbEvalDao" "$TCB_EVAL_DAO"
require_code "EnclaveIdentityHelper" "$ENCLAVE_HELPER"
require_code "FmspcTcbHelper" "$FMSPC_HELPER"
require_code "PCKHelper/X509Helper" "$PCK_HELPER"
require_code "X509CRLHelper" "$CRL_HELPER"
log "PCCS: storage=$STORAGE pcsDao=$PCS_DAO tcbEvalDao=$TCB_EVAL_DAO"

# ---- Resolve PCCSRouter via V3 QuoteVerifier -----------------------------
V3=$(cast call "$AUTOMATA_DCAP_ATTESTATION" "quoteVerifiers(uint16)(address)" 3 --rpc-url "$RPC_URL")
[[ "$V3" == "0x0000000000000000000000000000000000000000" ]] && die "V3 quote verifier not registered on DCAP"
ROUTER=$(cast call "$V3" "pccsRouter()(address)" --rpc-url "$RPC_URL")
log "router=$ROUTER (via V3 verifier $V3)"

# ---- Fetch fresh PCS collateral & FMSPC ----------------------------------
TMP=$(mktemp -d)
FORGE_TMP=""
trap 'rm -rf "$TMP" ${FORGE_TMP:+"$FORGE_TMP"}' EXIT

if [[ -z "$FMSPC" ]]; then
    if [[ -n "$SGX_BOOTSTRAP_JSON" ]]; then
        cp "$SGX_BOOTSTRAP_JSON" "$TMP/bootstrap.json"
    elif [[ -n "$SGX_BOOTSTRAP_URL" ]]; then
        log "fetching SGX bootstrap from $SGX_BOOTSTRAP_URL"
        curl_pcs "${SGX_BOOTSTRAP_URL%/}/bootstrap" > "$TMP/bootstrap.json"
    else
        die "FMSPC, SGX_BOOTSTRAP_JSON, or SGX_BOOTSTRAP_URL must be set"
    fi
    log "auto-detecting FMSPC from SGX bootstrap"
    FMSPC=$(extract_sgx_fmspc "$TMP/bootstrap.json")
    log "FMSPC = $FMSPC"
elif [[ -n "$SGX_BOOTSTRAP_JSON" ]]; then
    cp "$SGX_BOOTSTRAP_JSON" "$TMP/bootstrap.json"
elif [[ -n "$SGX_BOOTSTRAP_URL" ]]; then
    curl_pcs "${SGX_BOOTSTRAP_URL%/}/bootstrap" > "$TMP/bootstrap.json"
fi
[[ -n "$FMSPC" ]] || die "FMSPC required"

# Fetch fresh data from the configured PCS endpoint. A local PCCS may not proxy
# tcbevaluationdatanumbers, so that endpoint has an explicit fallback.
curl_pcs -D "$TMP/tcb_hdr.txt" "${INTEL_API_SGX}/tcb?fmspc=${FMSPC}" > "$TMP/tcb.json"
curl_pcs "${INTEL_API_SGX}/qe/identity" > "$TMP/qe.json"
if ! curl_pcs "${INTEL_API_SGX}/tcbevaluationdatanumbers" > "$TMP/eval.json"; then
    log "tcbevaluationdatanumbers unavailable at $(redact_rpc "$INTEL_API_SGX"), falling back to $(redact_rpc "$TCB_EVAL_API_SGX")"
    curl_pcs "${TCB_EVAL_API_SGX}/tcbevaluationdatanumbers" > "$TMP/eval.json"
fi

# Standard TCB eval number = highest with tcbRecoveryEventDate >= 12 months ago.
TCB_EVAL=$(python3 - "$TMP/eval.json" <<'PY'
import sys, json, datetime
data = json.load(open(sys.argv[1]))["tcbEvaluationDataNumbers"]["tcbEvalNumbers"]
now = datetime.datetime.now(datetime.timezone.utc)
twelve_mo = datetime.timedelta(days=365)
for e in data:
    dt = datetime.datetime.fromisoformat(e["tcbRecoveryEventDate"].replace("Z","+00:00"))
    if (now - dt) >= twelve_mo:
        print(e["tcbEvaluationDataNumber"]); sys.exit(0)
sys.exit("no standard tcb eval number found")
PY
)
log "standard TCB evaluation data number = $TCB_EVAL"

# Verify the Intel files match TCB_EVAL (they should, since standard tracks Intel).
got_tcb=$(jq -r '.tcbInfo.tcbEvaluationDataNumber' "$TMP/tcb.json")
got_qe=$(jq  -r '.enclaveIdentity.tcbEvaluationDataNumber' "$TMP/qe.json")
[[ "$got_tcb" == "$TCB_EVAL" ]] || die "TCB info tcbEvaluationDataNumber=$got_tcb != standard=$TCB_EVAL — Intel published a newer number; rerun in 24h or override TCB_EVAL=$got_tcb"
[[ "$got_qe"  == "$TCB_EVAL" ]] || die "QE identity tcbEvaluationDataNumber=$got_qe != $TCB_EVAL"

# Extract the exact JSON byte slices that Intel signed (round-tripping through jq
# re-serializes with different spacing and breaks signature verification).
python3 - "$TMP/tcb.json"  tcbInfo                  "$TMP/tcb_info_str.json"  <<'PY'
import sys
src, key, out = sys.argv[1], sys.argv[2], sys.argv[3]
raw = open(src).read().strip()
needle = '"'+key+'":{'
i = raw.find(needle); start = i + len(needle) - 1
depth, in_str, esc = 0, False, False
for j in range(start, len(raw)):
    c = raw[j]
    if in_str:
        if esc: esc = False
        elif c == '\\': esc = True
        elif c == '"': in_str = False
    else:
        if c == '"': in_str = True
        elif c == '{': depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                open(out,'w').write(raw[start:j+1]); sys.exit(0)
sys.exit("unbalanced")
PY
python3 - "$TMP/qe.json"   enclaveIdentity          "$TMP/qe_id_str.json"      <<'PY'
import sys
src, key, out = sys.argv[1], sys.argv[2], sys.argv[3]
raw = open(src).read().strip()
needle = '"'+key+'":{'
i = raw.find(needle); start = i + len(needle) - 1
depth, in_str, esc = 0, False, False
for j in range(start, len(raw)):
    c = raw[j]
    if in_str:
        if esc: esc = False
        elif c == '\\': esc = True
        elif c == '"': in_str = False
    else:
        if c == '"': in_str = True
        elif c == '{': depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                open(out,'w').write(raw[start:j+1]); sys.exit(0)
sys.exit("unbalanced")
PY
python3 - "$TMP/eval.json" tcbEvaluationDataNumbers "$TMP/tcb_eval_str.json"  <<'PY'
import sys
src, key, out = sys.argv[1], sys.argv[2], sys.argv[3]
raw = open(src).read().strip()
needle = '"'+key+'":{'
i = raw.find(needle); start = i + len(needle) - 1
depth, in_str, esc = 0, False, False
for j in range(start, len(raw)):
    c = raw[j]
    if in_str:
        if esc: esc = False
        elif c == '\\': esc = True
        elif c == '"': in_str = False
    else:
        if c == '"': in_str = True
        elif c == '{': depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                open(out,'w').write(raw[start:j+1]); sys.exit(0)
sys.exit("unbalanced")
PY

TCB_SIG=0x$(jq -r '.signature' "$TMP/tcb.json")
QE_SIG=0x$(jq  -r '.signature' "$TMP/qe.json")
EVAL_SIG=0x$(jq -r '.signature' "$TMP/eval.json")

# Root + signing certs from TCB-Info-Issuer-Chain header.
python3 - "$TMP/tcb_hdr.txt" "$TMP" <<'PY'
import sys, urllib.parse, re, base64
chain = open(sys.argv[1]).read()
m = re.search(r'^Tcb-Info-Issuer-Chain: *(.+)$', chain, re.IGNORECASE | re.MULTILINE)
pem = urllib.parse.unquote(m.group(1).strip())
certs = re.findall(r'-----BEGIN CERTIFICATE-----(.+?)-----END CERTIFICATE-----', pem, re.DOTALL)
open(sys.argv[2] + '/signing.pem', 'wb').write(('-----BEGIN CERTIFICATE-----'+certs[0]+'-----END CERTIFICATE-----').encode())
open(sys.argv[2] + '/root.pem',    'wb').write(('-----BEGIN CERTIFICATE-----'+certs[1]+'-----END CERTIFICATE-----').encode())
PY
openssl x509 -in "$TMP/root.pem"    -outform DER -out "$TMP/root.der"
openssl x509 -in "$TMP/signing.pem" -outform DER -out "$TMP/signing.der"

# Root CA CRL (PEM at certificates.trustedservices.intel.com, no DER endpoint).
curl_pcs "${INTEL_CERTS}/IntelSGXRootCA.crl" -o "$TMP/root_crl.pem"
openssl crl -in "$TMP/root_crl.pem" -outform DER -out "$TMP/root_crl.der"

# PCK Platform CA cert is embedded in the SGX quote's cert chain (index 1).
# Also fetch the PCK Platform CRL from the SGX PCS API.
if [[ -n "$PCK_PLATFORM_CA_DER" ]]; then
    cp "$PCK_PLATFORM_CA_DER" "$TMP/pck_plat_ca.der"
elif [[ -f "$TMP/bootstrap.json" ]]; then
    extract_sgx_platform_ca "$TMP/bootstrap.json" "$TMP"
    openssl x509 -in "$TMP/pck_plat_ca.pem" -outform DER -out "$TMP/pck_plat_ca.der"
fi
curl_pcs "${INTEL_API_SGX}/pckcrl?ca=platform&encoding=der" -o "$TMP/pck_plat_crl.der"

# ---- 1. Deploy versioned DAOs (idempotent: forge create reverts on collision) ----
FMSPC_TCB_DAO_KEY="AutomataFmspcTcbDaoVersioned_tcbeval_${TCB_EVAL}"
QE_ID_DAO_KEY="AutomataEnclaveIdentityDaoVersioned_tcbeval_${TCB_EVAL}"
FMSPC_TCB_DAO=$(jq -r --arg k "$FMSPC_TCB_DAO_KEY" '.[$k] // empty' "$PCCS_JSON")
QE_ID_DAO=$(jq    -r --arg k "$QE_ID_DAO_KEY"    '.[$k] // empty' "$PCCS_JSON")

deploy_versioned() {
    local kind="$1"   # FmspcTcbDaoVersioned | EnclaveIdentityDaoVersioned
    local helper="$2"
    pushd "$PCCS_REPO" >/dev/null
    local out
    out=$(forge create --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --broadcast \
        "src/automata_pccs/versioned/Automata${kind}.sol:Automata${kind}" \
        --constructor-args "$STORAGE" "$P256" "$PCS_DAO" "$helper" "$PCK_HELPER" "$CRL_HELPER" "$DEPLOYER" "$TCB_EVAL" 2>&1)
    popd >/dev/null
    echo "$out" | grep -oE 'Deployed to: 0x[0-9a-fA-F]{40}' | awk '{print $3}'
}

if [[ -z "$FMSPC_TCB_DAO" ]] || [[ "$(cast code "$FMSPC_TCB_DAO" --rpc-url "$RPC_URL" 2>/dev/null)" == "0x" ]]; then
    log "deploying $FMSPC_TCB_DAO_KEY"
    FMSPC_TCB_DAO=$(deploy_versioned FmspcTcbDaoVersioned "$FMSPC_HELPER")
    log "  -> $FMSPC_TCB_DAO"
else
    log "$FMSPC_TCB_DAO_KEY already deployed at $FMSPC_TCB_DAO"
fi

if [[ -z "$QE_ID_DAO" ]] || [[ "$(cast code "$QE_ID_DAO" --rpc-url "$RPC_URL" 2>/dev/null)" == "0x" ]]; then
    log "deploying $QE_ID_DAO_KEY"
    QE_ID_DAO=$(deploy_versioned EnclaveIdentityDaoVersioned "$ENCLAVE_HELPER")
    log "  -> $QE_ID_DAO"
else
    log "$QE_ID_DAO_KEY already deployed at $QE_ID_DAO"
fi

# Persist into PCCS_JSON for future runs (sibling deploy script reads it back).
TMP_JSON="$TMP/pccs.json"
jq --arg k1 "$FMSPC_TCB_DAO_KEY" --arg v1 "$FMSPC_TCB_DAO" \
   --arg k2 "$QE_ID_DAO_KEY"    --arg v2 "$QE_ID_DAO" \
   '.[$k1] = $v1 | .[$k2] = $v2' "$PCCS_JSON" > "$TMP_JSON" && mv "$TMP_JSON" "$PCCS_JSON"

# ---- 2. Grant DAO storage + ATTESTER_ROLE ----
send() {
    local desc="$1"; shift
    local out
    local gas_args=()
    if [[ -n "${SEND_GAS_LIMIT:-}" ]]; then
        gas_args=(--gas-limit "$SEND_GAS_LIMIT")
    fi

    out=$(cast send "$@" "${gas_args[@]}" --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" --json 2>&1) || {
        # ignore idempotent "already granted" reverts
        echo "$out" | grep -qE 'AlreadyExists|already|0xdb148880|0x72bd8361|0x9f4daa9e|Out_Of_Date|out.of.date' && { log "$desc: already set"; return 0; }
        log "$desc: $out"; return 1;
    }
    log "$desc: ok"
}

send_with_gas() {
    local gas_limit="$1"; shift
    SEND_GAS_LIMIT="$gas_limit" send "$@"
}

upload_fmspc_tcb_direct_storage() {
    local zero_hash="0x0000000000000000000000000000000000000000000000000000000000000000"

    FORGE_TMP="$PROTOCOL_DIR/deployments/.sgx-pccs-${CHAIN_ID}-$$"
    rm -rf "$FORGE_TMP"
    mkdir -p "$FORGE_TMP"
    cp "$TMP/tcb_info_str.json" "$FORGE_TMP/tcb_info_str.json"

    log "encoding SGX FMSPC TCB storage payload"
    (
        cd "$PROTOCOL_DIR"
        TCB_INFO_PATH="$FORGE_TMP/tcb_info_str.json" \
            TCB_SIGNATURE="$TCB_SIG" \
            TCB_EVAL="$TCB_EVAL" \
            OUT_DIR="$FORGE_TMP" \
            forge script script/layer1/verifiers/EncodeSgxFmspcTcbStorage.s.sol:EncodeSgxFmspcTcbStorage
    )

    # `AutomataDaoStorage.attest` is guarded by grantDao(). The writer is intentionally the
    # deployer/operator for this gas-cap workaround; the stored bytes still come from signed Intel
    # collateral, encoded by the helper above.
    send "grantDao(deployer direct FMSPC writer)" "$STORAGE" "grantDao(address)" "$DEPLOYER"

    send_with_gas "$FMSPC_TCB_GAS_LIMIT" \
        "direct storage attest FMSPC TCB main(tcbEval=$TCB_EVAL,fmspc=$FMSPC)" \
        "$STORAGE" "attest(bytes32,bytes,bytes32)" \
        "$(cat "$FORGE_TMP/tcb_key.hex")" \
        "$(cat "$FORGE_TMP/tcb_data.hex")" \
        "$(cat "$FORGE_TMP/tcb_sha256.hex")"

    send "direct storage attest FMSPC TCB issue/eval" \
        "$STORAGE" "attest(bytes32,bytes,bytes32)" \
        "$(cat "$FORGE_TMP/issue_eval_key.hex")" \
        "$(cat "$FORGE_TMP/issue_eval_data.hex")" \
        "$zero_hash"

    send "direct storage attest FMSPC TCB contentHash" \
        "$STORAGE" "attest(bytes32,bytes,bytes32)" \
        "$(cat "$FORGE_TMP/content_hash_key.hex")" \
        "$(cat "$FORGE_TMP/content_hash_data.hex")" \
        "$zero_hash"
}

send "grantDao(FmspcTcbDaoVersioned)"        "$STORAGE"       "grantDao(address)" "$FMSPC_TCB_DAO"
send "grantDao(EnclaveIdentityDaoVersioned)" "$STORAGE"       "grantDao(address)" "$QE_ID_DAO"
send "grantRoles ATTESTER (FmspcTcbDaoVersioned)"        "$FMSPC_TCB_DAO" "grantRoles(address,uint256)" "$DEPLOYER" 1
send "grantRoles ATTESTER (EnclaveIdentityDaoVersioned)" "$QE_ID_DAO"     "grantRoles(address,uint256)" "$DEPLOYER" 1
send "grantRoles ATTESTER (TcbEvalDao)"                  "$TCB_EVAL_DAO"  "grantRoles(address,uint256)" "$DEPLOYER" 1

# ---- 3. Wire PCCSRouter ----
send "setFmspcTcbDaoVersionedAddr($TCB_EVAL)" "$ROUTER" "setFmspcTcbDaoVersionedAddr(uint32,address)" "$TCB_EVAL" "$FMSPC_TCB_DAO"
send "setQeIdDaoVersionedAddr($TCB_EVAL)"     "$ROUTER" "setQeIdDaoVersionedAddr(uint32,address)"     "$TCB_EVAL" "$QE_ID_DAO"

# ---- 4. Load certs + CRLs ----
hex_of() { xxd -p "$1" | tr -d '\n'; }
log "uploading Root CA cert"
send "upsertPcsCertificates(ROOT=0)"     "$PCS_DAO" "upsertPcsCertificates(uint8,bytes)" 0 "0x$(hex_of "$TMP/root.der")"
log "uploading Signing cert"
send "upsertPcsCertificates(SIGNING=3)"  "$PCS_DAO" "upsertPcsCertificates(uint8,bytes)" 3 "0x$(hex_of "$TMP/signing.der")"
log "uploading Root CA CRL"
send "upsertRootCACrl"                   "$PCS_DAO" "upsertRootCACrl(bytes)"               "0x$(hex_of "$TMP/root_crl.der")"
if [[ -f "$TMP/pck_plat_ca.der" ]]; then
    log "uploading PCK Platform CA cert"
    send "upsertPcsCertificates(PLATFORM=2)" "$PCS_DAO" "upsertPcsCertificates(uint8,bytes)" 2 "0x$(hex_of "$TMP/pck_plat_ca.der")"
fi
log "uploading PCK Platform CRL"
send "upsertPckCrl(PLATFORM=2)"          "$PCS_DAO" "upsertPckCrl(uint8,bytes)"             2 "0x$(hex_of "$TMP/pck_plat_crl.der")"

# ---- 5. Load TCB info / QE identity / TCB eval directly ------------------
# Automata's current PCCS checkout does not ship a stable Forge loader for
# these three signed Intel JSON objects, so call the DAO upsert entrypoints
# directly. Preserve Intel's exact signed JSON byte slices; do not reserialize
# through jq before uploading.
read_json_slice() {
    python3 - "$1" <<'PY'
import sys
print(open(sys.argv[1]).read().strip(), end="")
PY
}

TCB_INFO_STR=$(read_json_slice "$TMP/tcb_info_str.json")
QE_ID_STR=$(read_json_slice "$TMP/qe_id_str.json")
TCB_EVAL_STR=$(read_json_slice "$TMP/tcb_eval_str.json")

send "upsertTcbEvaluationData(SGX=0)" \
    "$TCB_EVAL_DAO" "upsertTcbEvaluationData((string,bytes))" \
    "('$TCB_EVAL_STR',$EVAL_SIG)"

case "$FMSPC_TCB_UPLOAD_MODE" in
    direct-storage)
        upload_fmspc_tcb_direct_storage
        ;;
    dao)
        send_with_gas "$FMSPC_TCB_GAS_LIMIT" "upsertFmspcTcb(tcbEval=$TCB_EVAL,fmspc=$FMSPC)" \
            "$FMSPC_TCB_DAO" "upsertFmspcTcb((string,bytes))" \
            "('$TCB_INFO_STR',$TCB_SIG)"
        ;;
    *)
        die "unsupported FMSPC_TCB_UPLOAD_MODE=$FMSPC_TCB_UPLOAD_MODE (expected direct-storage or dao)"
        ;;
esac

send_with_gas "$ENCLAVE_ID_GAS_LIMIT" "upsertEnclaveIdentity(QE=0,version=4)" \
    "$QE_ID_DAO" "upsertEnclaveIdentity(uint256,uint256,(string,bytes))" \
    0 4 "('$QE_ID_STR',$QE_SIG)"

log "=== PCCS extras complete ==="
log "  AutomataFmspcTcbDaoVersioned (tcbEval=$TCB_EVAL): $FMSPC_TCB_DAO"
log "  AutomataEnclaveIdentityDaoVersioned (tcbEval=$TCB_EVAL): $QE_ID_DAO"
log "  PCCSRouter: $ROUTER"
log "  PCCS_JSON updated with versioned DAO addresses"
log "SGX registerInstance is now ready against AutomataDcapAttestationFee=$AUTOMATA_DCAP_ATTESTATION"
