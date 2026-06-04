#!/bin/bash
#
# Idempotent finish for the TDX PCCS bring-up that `deploy_dcap_and_tdx_verifier.sh`
# does not handle. Run this immediately after that script (and before the first
# `registerInstance` call) on any chain where the Automata DCAP contracts were
# freshly deployed by the sibling deploy script.
#
# What this script does (and why it's needed):
#
#   1. Deploys `AutomataFmspcTcbDaoVersioned` + `AutomataEnclaveIdentityDaoVersioned`
#      at the FMSPC's current "standard" TCB Evaluation Data Number.
#      `deploy_automata_dcap.sh` only deploys the legacy non-versioned DAOs and the
#      bare `AutomataTcbEvalDao`, but PCCSRouter resolves TCB info and QE identity
#      through the **versioned** mappings — without these, every V4 quote lookup
#      reverts with `FmspcTcbExpiredOrNotFound` / `QEIdentityExpiredOrNotFound`.
#
#   2. Grants `AutomataDaoStorage.grantDao` to the two new DAOs and `ATTESTER_ROLE`
#      (Solady `_ROLE_0` = 1) to the deployer on FmspcTcbDaoVersioned,
#      EnclaveIdentityDaoVersioned, and AutomataTcbEvalDao. Without these, the
#      collateral upserts in step 5 revert with `Unauthorized`.
#
#   3. Calls `PCCSRouter.setFmspcTcbDaoVersionedAddr` + `setQeIdDaoVersionedAddr`
#      so V4 lookups resolve to the new DAOs. `deploy_automata_dcap.sh` configures
#      only the unversioned router mappings.
#
#   4. Loads `Root CA CRL` and `PCK Platform CA cert + CRL` into PcsDao.
#      `deploy_automata_dcap.sh` skips both — but Automata DCAP `verifyAndAttestOnChain`
#      validates the full PCK certificate chain (including the platform-CA intermediate)
#      and its CRL, so without these the verifier reverts with `CrlExpiredOrNotFound`
#      after PCCS lookups otherwise succeed.
#
#   5. Loads TCB info (`tcbEvaluationDataNumber=<standard>`), QE identity (TD_QE,
#      `tcbEvaluationDataNumber=<standard>`) and TCB Evaluation Data Numbers into
#      the corresponding versioned/legacy DAOs.
#
# Inputs:
#   PRIVATE_KEY                Deployer key (must own AutomataDaoStorage / PcsDao /
#                              PCCSRouter / new versioned DAOs — i.e. the same key
#                              used in `deploy_dcap_and_tdx_verifier.sh`).
#   RPC_URL                    Default: http://localhost:8545
#   RETH_TDX_URL               Required when FMSPC is unset — used to auto-detect the
#                              FMSPC of your TDX hardware AND to extract the PCK
#                              Platform CA cert from the live reth-tdx bootstrap quote
#                              (`GET <url>/bootstrap`).
#   FMSPC                      Optional override (6 hex bytes, e.g. 90c06f000000).
#   AUTOMATA_DCAP_ATTESTATION  AutomataDcapAttestationFee address (printed by the
#                              sibling deploy script). Used to find PCCSRouter via
#                              `quoteVerifiers(4).pccsRouter`.
#   PCCS_JSON                  Path to PCCS deployment JSON; must contain
#                              AutomataDaoStorage, AutomataPcsDao, AutomataPckDao,
#                              AutomataTcbEvalDao, and the helper addresses.
#
# Dependencies: cast, forge, curl, jq, openssl, python3.

set -euo pipefail

PRIVATE_KEY="${PRIVATE_KEY:-}"
RPC_URL="${RPC_URL:-http://localhost:8545}"
RETH_TDX_URL="${RETH_TDX_URL:-${RAIKO2_URL:-}}"
FMSPC="${FMSPC:-}"
AUTOMATA_DCAP_ATTESTATION="${AUTOMATA_DCAP_ATTESTATION:-}"
PCCS_JSON="${PCCS_JSON:-}"
PCCS_REPO="${PCCS_REPO:-${HOME}/Documents/nethermind/automata-on-chain-pccs}"
INTEL_API_TDX="${INTEL_API_TDX:-https://api.trustedservices.intel.com/tdx/certification/v4}"
INTEL_CERTS="${INTEL_CERTS:-https://certificates.trustedservices.intel.com}"

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "[setup_tdx_pccs_extras] $*"; }

[[ -z "$PRIVATE_KEY" ]] && die "PRIVATE_KEY is not set"
[[ -z "$AUTOMATA_DCAP_ATTESTATION" ]] && die "AUTOMATA_DCAP_ATTESTATION is not set"
[[ -z "$PCCS_JSON" || ! -f "$PCCS_JSON" ]] && die "PCCS_JSON is not set or not a file: $PCCS_JSON"
[[ -d "$PCCS_REPO" ]] || die "PCCS_REPO not found at $PCCS_REPO (set PCCS_REPO=...)"
for cmd in cast forge curl jq openssl python3; do command -v "$cmd" >/dev/null || die "missing dep: $cmd"; done

DEPLOYER=$(cast wallet address --private-key "$PRIVATE_KEY")
CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL")
log "chain=$CHAIN_ID rpc=$RPC_URL deployer=$DEPLOYER"

# ---- Read PCCS addresses from deployment JSON -----------------------------
STORAGE=$(jq -r '.AutomataDaoStorage'   "$PCCS_JSON")
PCS_DAO=$(jq -r '.AutomataPcsDao'        "$PCCS_JSON")
PCK_DAO=$(jq -r '.AutomataPckDao'        "$PCCS_JSON")
TCB_EVAL_DAO=$(jq -r '.AutomataTcbEvalDao' "$PCCS_JSON")
ENCLAVE_HELPER=$(jq -r '.EnclaveIdentityHelper' "$PCCS_JSON")
FMSPC_HELPER=$(jq -r '.FmspcTcbHelper'   "$PCCS_JSON")
PCK_HELPER=$(jq -r '.PCKHelper'          "$PCCS_JSON")
CRL_HELPER=$(jq -r '.X509CRLHelper'      "$PCCS_JSON")
P256=${P256:-0xc2b78104907F722DABAc4C69f826a522B2754De4}  # Daimo P256, deployed by deploy_automata_dcap.sh

for a in "$STORAGE" "$PCS_DAO" "$PCK_DAO" "$TCB_EVAL_DAO" "$ENCLAVE_HELPER" "$FMSPC_HELPER" "$PCK_HELPER" "$CRL_HELPER"; do
    [[ "$a" == "null" || -z "$a" ]] && die "missing required address in $PCCS_JSON"
done
log "PCCS: storage=$STORAGE pcsDao=$PCS_DAO tcbEvalDao=$TCB_EVAL_DAO"

# ---- Resolve PCCSRouter via V4 QuoteVerifier -----------------------------
V4=$(cast call "$AUTOMATA_DCAP_ATTESTATION" "quoteVerifiers(uint16)(address)" 4 --rpc-url "$RPC_URL")
[[ "$V4" == "0x0000000000000000000000000000000000000000" ]] && die "V4 quote verifier not registered on DCAP"
ROUTER=$(cast call "$V4" "pccsRouter()(address)" --rpc-url "$RPC_URL")
log "router=$ROUTER (via V4 verifier $V4)"

# ---- Fetch fresh Intel collateral & FMSPC --------------------------------
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [[ -z "$FMSPC" ]]; then
    [[ -z "$RETH_TDX_URL" ]] && die "RETH_TDX_URL must be set when FMSPC is not provided"
    log "auto-detecting FMSPC from $RETH_TDX_URL"
    curl -sSf --max-time 30 "${RETH_TDX_URL%/}/bootstrap" > "$TMP/bootstrap.json"
    FMSPC=$(python3 - "$TMP/bootstrap.json" <<'PY'
import sys, json
b = json.load(open(sys.argv[1]))
# reth-tdx's /bootstrap returns the record flat (issuer_type, public_key, quote, ...).
# Pre-reth-tdx raiko2 wrapped the record under its issuer key (`{ "tdx": { ... } }`),
# so accept either shape for forward compatibility with old image bootstrap dumps.
inner = b if "quote" in b else next(iter(b.values()))
quote = bytes.fromhex(inner["quote"])
# Inner JSON envelope. Two shapes:
#   native (tdx issuer): { "RawQuote": b64(raw DCAP quote), "UserData": b64 }
#   azure  issuer:       { "InstanceInfo": b64(JSON{ "AttestationReport": b64 }), ... }
import base64
doc = json.loads(quote)
if "RawQuote" in doc:
    ar = base64.b64decode(doc["RawQuote"])
else:
    ii = json.loads(base64.b64decode(doc["InstanceInfo"]))
    ar = base64.b64decode(ii["AttestationReport"])
# Parse TDX V4 sig data to reach PCK leaf cert and grab FMSPC from SGX extension.
sig_off = 48 + 584
sig_len = int.from_bytes(ar[sig_off:sig_off+4], "little")
sig = ar[sig_off+4:sig_off+4+sig_len]
cert_type = int.from_bytes(sig[128:130], "little")
cert_size = int.from_bytes(sig[130:134], "little")
chain = sig[134:134+cert_size]
import re, base64 as b64
certs = re.findall(b"-----BEGIN CERTIFICATE-----(.+?)-----END CERTIFICATE-----", chain, re.DOTALL)
leaf = b64.b64decode(certs[0].replace(b"\n", b"").strip())
# OID 1.2.840.113741.1.13.1.4 = FMSPC (in DER: 06 0A 2A 86 48 86 F8 4D 01 0D 01 04)
oid = bytes.fromhex("060A2A8648 86F84D010D0104".replace(" ", ""))
i = leaf.find(oid)
rest = leaf[i+len(oid):]
for k in range(min(16, len(rest)-7)):
    if rest[k] == 0x04 and rest[k+1] == 0x06:
        print(rest[k+2:k+8].hex()); sys.exit(0)
sys.exit("FMSPC not found")
PY
)
    log "FMSPC = $FMSPC"
fi
[[ -n "$FMSPC" ]] || die "FMSPC required"

# Fetch fresh data from Intel
curl -sSf --max-time 30 -D "$TMP/tcb_hdr.txt" "${INTEL_API_TDX}/tcb?fmspc=${FMSPC}" > "$TMP/tcb.json"
curl -sSf --max-time 30 "${INTEL_API_TDX}/qe/identity" > "$TMP/qe.json"
curl -sSf --max-time 30 "${INTEL_API_TDX}/tcbevaluationdatanumbers" > "$TMP/eval.json"

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
python3 - "$TMP/qe.json"   enclaveIdentity          "$TMP/qe_id_str.json"      < /dev/null || true
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
curl -sSf --max-time 30 "${INTEL_CERTS}/IntelSGXRootCA.crl" -o "$TMP/root_crl.pem"
openssl crl -in "$TMP/root_crl.pem" -outform DER -out "$TMP/root_crl.der"

# PCK Platform CA cert is embedded in the live quote's cert chain (index 1).
# Also fetch the PCK Platform CRL from the SGX PCS API.
if [[ -n "$RETH_TDX_URL" ]]; then
    python3 - "$TMP/bootstrap.json" "$TMP" <<'PY'
import sys, json, base64, re
b = json.load(open(sys.argv[1]))
# Accept either the flat reth-tdx /bootstrap shape or the legacy raiko2-wrapped one.
inner = b if "quote" in b else next(iter(b.values()))
doc = json.loads(bytes.fromhex(inner["quote"]))
if "RawQuote" in doc:
    ar = base64.b64decode(doc["RawQuote"])
else:
    ii = json.loads(base64.b64decode(doc["InstanceInfo"]))
    ar = base64.b64decode(ii["AttestationReport"])
sig_off = 48 + 584
sig_len = int.from_bytes(ar[sig_off:sig_off+4], "little")
sig = ar[sig_off+4:sig_off+4+sig_len]
cert_size = int.from_bytes(sig[130:134], "little")
chain = sig[134:134+cert_size]
certs = re.findall(b"-----BEGIN CERTIFICATE-----(.+?)-----END CERTIFICATE-----", chain, re.DOTALL)
plat = b"-----BEGIN CERTIFICATE-----"+certs[1]+b"-----END CERTIFICATE-----"
open(sys.argv[2] + "/pck_plat_ca.pem", "wb").write(plat)
PY
    openssl x509 -in "$TMP/pck_plat_ca.pem" -outform DER -out "$TMP/pck_plat_ca.der"
fi
curl -sSf --max-time 30 "https://api.trustedservices.intel.com/sgx/certification/v4/pckcrl?ca=platform&encoding=der" -o "$TMP/pck_plat_crl.der"

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
    out=$(cast send "$@" --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" --json 2>&1) || {
        # ignore idempotent "already granted" reverts
        echo "$out" | grep -qE 'AlreadyExists|AccessControl|already|0xdb148880' && { log "$desc: already set"; return 0; }
        log "$desc: $out"; return 1;
    }
    log "$desc: ok"
}

send "grantDao(FmspcTcbDaoVersioned)"        "$STORAGE"       "grantDao(address)" "$FMSPC_TCB_DAO" || true
send "grantDao(EnclaveIdentityDaoVersioned)" "$STORAGE"       "grantDao(address)" "$QE_ID_DAO"     || true
send "grantRoles ATTESTER (FmspcTcbDaoVersioned)"        "$FMSPC_TCB_DAO" "grantRoles(address,uint256)" "$DEPLOYER" 1 || true
send "grantRoles ATTESTER (EnclaveIdentityDaoVersioned)" "$QE_ID_DAO"     "grantRoles(address,uint256)" "$DEPLOYER" 1 || true
send "grantRoles ATTESTER (TcbEvalDao)"                  "$TCB_EVAL_DAO"  "grantRoles(address,uint256)" "$DEPLOYER" 1 || true

# ---- 3. Wire PCCSRouter ----
send "setFmspcTcbDaoVersionedAddr($TCB_EVAL)" "$ROUTER" "setFmspcTcbDaoVersionedAddr(uint32,address)" "$TCB_EVAL" "$FMSPC_TCB_DAO" || true
send "setQeIdDaoVersionedAddr($TCB_EVAL)"     "$ROUTER" "setQeIdDaoVersionedAddr(uint32,address)"     "$TCB_EVAL" "$QE_ID_DAO"     || true

# ---- 4. Load certs + CRLs ----
hex_of() { xxd -p "$1" | tr -d '\n'; }
log "uploading Root CA cert"
send "upsertPcsCertificates(ROOT=0)"     "$PCS_DAO" "upsertPcsCertificates(uint8,bytes)" 0 "0x$(hex_of "$TMP/root.der")"        || true
log "uploading Signing cert"
send "upsertPcsCertificates(SIGNING=3)"  "$PCS_DAO" "upsertPcsCertificates(uint8,bytes)" 3 "0x$(hex_of "$TMP/signing.der")"     || true
log "uploading Root CA CRL"
send "upsertRootCACrl"                   "$PCS_DAO" "upsertRootCACrl(bytes)"               "0x$(hex_of "$TMP/root_crl.der")"     || true
if [[ -f "$TMP/pck_plat_ca.der" ]]; then
    log "uploading PCK Platform CA cert"
    send "upsertPcsCertificates(PLATFORM=2)" "$PCS_DAO" "upsertPcsCertificates(uint8,bytes)" 2 "0x$(hex_of "$TMP/pck_plat_ca.der")"  || true
fi
log "uploading PCK Platform CRL"
send "upsertPckCrl(PLATFORM=2)"          "$PCS_DAO" "upsertPckCrl(uint8,bytes)"             2 "0x$(hex_of "$TMP/pck_plat_crl.der")" || true

# ---- 5. Load TCB info / QE identity / TCB eval via LoadPccsData forge script ----
pushd "$PCCS_REPO" >/dev/null
mkdir -p .tmp_collateral
cp "$TMP/root.der"               .tmp_collateral/root_ca.der
cp "$TMP/signing.der"            .tmp_collateral/signing.der
cp "$TMP/tcb_info_str.json"      .tmp_collateral/tcb_info_str.json
cp "$TMP/qe_id_str.json"         .tmp_collateral/qe_id_str.json
cp "$TMP/tcb_eval_str.json"      .tmp_collateral/tcb_eval_str.json

PRIVATE_KEY="$PRIVATE_KEY" \
PCS_DAO="$PCS_DAO" \
FMSPC_TCB_DAO="$FMSPC_TCB_DAO" \
ENCLAVE_IDENTITY_DAO="$QE_ID_DAO" \
TCB_EVAL_DAO="$TCB_EVAL_DAO" \
ROOT_CERT_PATH=.tmp_collateral/root_ca.der \
SIGNING_CERT_PATH=.tmp_collateral/signing.der \
TCB_INFO_STR_PATH=.tmp_collateral/tcb_info_str.json \
TCB_SIG_HEX="$TCB_SIG" \
IDENTITY_STR_PATH=.tmp_collateral/qe_id_str.json \
IDENTITY_SIG_HEX="$QE_SIG" \
QE_ID=2 \
QE_VERSION=4 \
TCB_EVAL_STR_PATH=.tmp_collateral/tcb_eval_str.json \
TCB_EVAL_SIG_HEX="$EVAL_SIG" \
forge script script/automata/LoadPccsData.s.sol:LoadPccsData \
    --rpc-url "$RPC_URL" --broadcast --slow -vvv 2>&1 | tee /tmp/loadpccs.log | tail -30
popd >/dev/null

log "=== PCCS extras complete ==="
log "  AutomataFmspcTcbDaoVersioned (tcbEval=$TCB_EVAL): $FMSPC_TCB_DAO"
log "  AutomataEnclaveIdentityDaoVersioned (tcbEval=$TCB_EVAL): $QE_ID_DAO"
log "  PCCSRouter: $ROUTER"
log "  PCCS_JSON updated with versioned DAO addresses"
log "registerInstance is now ready: cargo run -p xtask -- register-tdx --register --reth-tdx-url $RETH_TDX_URL ..."
