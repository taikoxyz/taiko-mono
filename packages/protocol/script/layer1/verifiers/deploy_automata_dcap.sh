#!/bin/bash

# Deploy Automata DCAP attestation contracts on any EVM chain
# and upload Intel DCAP collaterals for a given FMSPC.
#
# Steps:
#   1. Deploy P256Verifier via Nick's deterministic factory
#   2. Clone + deploy automata-on-chain-pccs (PCCS DAO contracts)  [skippable]
#   3. Clone + deploy automata-dcap-attestation (DCAP + quote verifiers)  [skippable]
#   4. Upload Intel DCAP collaterals for a given FMSPC
#      (needed for registerInstance with real TDX hardware)
#
# Pass PCCS_JSON and/or AUTOMATA_DCAP_ATTESTATION to skip already-deployed steps.
#
# Dependencies: git, cast, forge, jq, curl, openssl, python3

set -euo pipefail

# ---------------------------------------------------------------
# Config
# ---------------------------------------------------------------
export PRIVATE_KEY="${PRIVATE_KEY:-}"
export RPC_URL="${RPC_URL:-http://localhost:8545}"

AUTOMATA_PCCS_REPO="${AUTOMATA_PCCS_REPO:-https://github.com/automata-network/automata-on-chain-pccs.git}"
AUTOMATA_PCCS_REF="${AUTOMATA_PCCS_REF:-main}"
AUTOMATA_DCAP_REPO="${AUTOMATA_DCAP_REPO:-https://github.com/automata-network/automata-dcap-attestation.git}"
AUTOMATA_DCAP_REF="${AUTOMATA_DCAP_REF:-main}"

# 6-byte FMSPC hex (e.g. "90c06f000000") — required for Intel collateral upload.
# Without it the contracts deploy fine but registerInstance will reject real TDX quotes.
# Provide either FMSPC directly or RETH_TDX_URL to auto-fetch it from the running prover.
FMSPC="${FMSPC:-}"

# Auto-detect FMSPC if not set: fetch from a running reth-tdx instance.
# When set, this script calls GET <RETH_TDX_URL>/bootstrap, extracts the
# raw TDX quote, and parses the FMSPC from the PCK certificate SGX extension.
RETH_TDX_URL="${RETH_TDX_URL:-${RETH_TDX_URL:-}}"

# Skip already-deployed steps by providing existing addresses/files:
#   PCCS_JSON                  Path to existing PCCS deployment JSON → skips PCCS clone+deploy
#   AUTOMATA_DCAP_ATTESTATION  Existing AutomataDcapAttestationFee address → skips DCAP clone+deploy
#                              NOTE: PCCS_JSON must also be set (needed for DAO addresses).
PCCS_JSON="${PCCS_JSON:-}"
export AUTOMATA_DCAP_ATTESTATION="${AUTOMATA_DCAP_ATTESTATION:-}"

# Optional: write deployment summary JSON to this path (stdout hint if empty)
OUTPUT_JSON="${OUTPUT_JSON:-}"

WORK_DIR="${WORK_DIR:-/tmp/automata-deploy-$$}"
KEEP_REPOS="${KEEP_REPOS:-false}"

# ---------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------
usage() {
    cat <<EOF
Deploy Automata DCAP attestation contracts on an existing EVM chain.

Usage:
  PRIVATE_KEY=0x... RPC_URL=http://... [FMSPC=...] ./deploy_automata_dcap.sh

Required env:
  PRIVATE_KEY    Deployer private key with ETH on the target chain.

Optional env:
  RPC_URL        RPC endpoint (default: http://localhost:8545)
  FMSPC          6-byte FMSPC of your TDX hardware (e.g. "90c06f000000").
                 Triggers download+upload of Intel DCAP collaterals so that
                 registerInstance works with real TDX quotes.
                 Takes precedence over RETH_TDX_URL when both are set.
  RETH_TDX_URL     URL of a running reth-tdx instance (e.g. "http://localhost:8080").
                 When FMSPC is not set, fetches GET <url>/bootstrap
                 and parses the FMSPC from the embedded PCK certificate.
  PCCS_JSON      Path to an existing PCCS deployment JSON — skips PCCS clone+deploy.
  AUTOMATA_DCAP_ATTESTATION
                 Existing AutomataDcapAttestationFee address — skips DCAP clone+deploy.
                 Requires PCCS_JSON to also be set.
  OUTPUT_JSON    Write deployment summary JSON to this file path.
  AUTOMATA_PCCS_REPO / AUTOMATA_PCCS_REF   (default: main)
  AUTOMATA_DCAP_REPO / AUTOMATA_DCAP_REF   (default: main)
  WORK_DIR       Clone directory (default: /tmp/automata-deploy-<pid>)
  KEEP_REPOS     Set true to keep clones after success (default: false)

Output:
  AutomataDcapAttestationFee address — use as AUTOMATA_DCAP_ATTESTATION
  in deploy_tdx_verifier.sh.

Already-deployed addresses on supported networks (skip this script there):
  Mainnet: 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3
  Hoodi:   0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }

cleanup() {
    [[ "$KEEP_REPOS" != "true" && -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# ---------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done

# ---------------------------------------------------------------
# Validate
# ---------------------------------------------------------------
[[ -z "$PRIVATE_KEY" ]] && die "PRIVATE_KEY is not set"
command -v cast   >/dev/null || die "cast not found — install Foundry"
command -v forge  >/dev/null || die "forge not found — install Foundry"
command -v git    >/dev/null || die "git not found"
command -v jq     >/dev/null || die "jq not found"
command -v python3 >/dev/null || die "python3 not found"

if [[ -n "$AUTOMATA_DCAP_ATTESTATION" && -z "$PCCS_JSON" ]]; then
    die "PCCS_JSON must be set when AUTOMATA_DCAP_ATTESTATION is provided (needed for DAO addresses)"
fi

CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL") || die "Cannot reach $RPC_URL"
DEPLOYER=$(cast wallet address --private-key "$PRIVATE_KEY")

echo "======================================="
echo "Deploying Automata DCAP"
echo "  Chain ID:  $CHAIN_ID"
echo "  RPC:       $RPC_URL"
echo "  Deployer:  $DEPLOYER"
[[ -n "$FMSPC" ]]                      && echo "  FMSPC:     $FMSPC"
[[ -z "$FMSPC" && -n "$RETH_TDX_URL" ]] && echo "  RETH_TDX_URL: $RETH_TDX_URL (will auto-detect FMSPC)"
[[ -n "$PCCS_JSON" ]]                  && echo "  PCCS:      using existing $PCCS_JSON"
[[ -n "$AUTOMATA_DCAP_ATTESTATION" ]]  && echo "  DCAP:      using existing $AUTOMATA_DCAP_ATTESTATION"
echo "======================================="

mkdir -p "$WORK_DIR"

# ---------------------------------------------------------------
# Auto-detect FMSPC from raiko2 bootstrap endpoint
# ---------------------------------------------------------------
if [[ -z "$FMSPC" && -n "$RETH_TDX_URL" ]]; then
    echo ""
    echo "--- Fetching FMSPC from reth-tdx bootstrap ---"
    _bootstrap_url="${RETH_TDX_URL%/}/bootstrap"
    _bootstrap_json=$(curl -sS --max-time 30 "$_bootstrap_url") \
        || die "Failed to call $_bootstrap_url"
    _quote_hex=$(echo "$_bootstrap_json" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError as e:
    sys.stderr.write(f'Invalid JSON from bootstrap endpoint: {e}\n')
    sys.exit(1)
if not isinstance(data, dict) or not data:
    sys.stderr.write('Unexpected bootstrap response shape\n')
    sys.exit(1)
# reth-tdx returns the record flat ({ 'quote': ..., ... }); legacy raiko2 wrapped
# it under an issuer-type key ({ 'tdx': { 'quote': ..., ... } }). Accept either.
inner = data if 'quote' in data else next(iter(data.values()))
quote = inner.get('quote', '')
if not quote:
    sys.stderr.write(f'No quote field in bootstrap response: {data}\n')
    sys.exit(1)
print(quote)
") || die "Failed to extract quote from bootstrap response: $_bootstrap_json"

    FMSPC=$(python3 - "$_quote_hex" <<'PYEOF'
import sys, base64, re

quote_hex = sys.argv[1]
try:
    quote = bytes.fromhex(quote_hex)
except ValueError as e:
    sys.stderr.write(f'Invalid hex quote: {e}\n')
    sys.exit(1)

# Raiko bootstrap wraps the TDX quote in a JSON envelope:
# tdx.quote = hex(JSON{ Attestation, InstanceInfo, UserData })
# The raw DCAP quote is at: JSON → base64(InstanceInfo) → JSON → base64(AttestationReport)
import json as _json
try:
    _doc = _json.loads(quote)
    _inst = _json.loads(base64.b64decode(_doc["InstanceInfo"]))
    quote = base64.b64decode(_inst["AttestationReport"])
except Exception:
    pass  # already raw TDX bytes (non-raiko format)

# TDX / SGX quote structure (v3/v4):
#   Header:        48 bytes
#   Report body:   384 bytes (SGX v3) or 584 bytes (TDX v4)
# We try both report-body lengths; we only need the sig-data-len field
# which sits right after the header+body.
#
# Instead of parsing the binary signature structure (which varies between
# TDX firmware versions — the QE report is 384 bytes for SGX but can be
# 390 bytes for some TDX V4 firmwares), we locate the PEM cert chain
# directly by scanning for "-----BEGIN CERTIFICATE-----" in the sig bytes.
for report_body_len in (584, 384):
    sig_off = 48 + report_body_len
    if sig_off + 4 > len(quote):
        continue
    sig_data_len = int.from_bytes(quote[sig_off:sig_off+4], 'little')
    sig = quote[sig_off+4:sig_off+4+sig_data_len]
    if not sig:
        continue

    # Find the PEM cert chain directly — avoids depending on exact QE report size
    pem_str = sig.decode('ascii', errors='replace')
    certs = re.findall(
        r'-----BEGIN CERTIFICATE-----(.+?)-----END CERTIFICATE-----',
        pem_str, re.DOTALL
    )
    if not certs:
        continue
    try:
        leaf_der = base64.b64decode(certs[0].replace('\n', '').strip())
    except Exception:
        continue

    # Search for FMSPC OID 1.2.840.113741.1.13.1.4 in DER
    # DER encoding: 06 0A 2A 86 48 86 F8 4D 01 0D 01 04
    fmspc_oid = bytes.fromhex('060A2A864886F84D010D0104')
    idx = leaf_der.find(fmspc_oid)
    if idx == -1:
        continue

    # After OID expect OCTET STRING: 04 06 <6 bytes FMSPC>
    rest = leaf_der[idx + len(fmspc_oid):]
    for i in range(min(16, len(rest) - 7)):
        if rest[i] == 0x04 and rest[i+1] == 0x06:
            print(rest[i+2:i+8].hex())
            sys.exit(0)

sys.stderr.write('Failed to parse FMSPC from TDX quote\n')
sys.exit(1)
PYEOF
) || die "Failed to extract FMSPC from TDX quote"
    echo "  FMSPC auto-detected: $FMSPC"
fi

# ---------------------------------------------------------------
# 1. Nick's deterministic factory (CREATE2 deployer)
# ---------------------------------------------------------------
NICK_FACTORY="0x4e59b44847b379578588920cA78FbF26c0B4956C"

FACTORY_CODE=$(cast code "$NICK_FACTORY" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x")
if [[ -z "${FACTORY_CODE//0x/}" ]]; then
    echo ""
    echo "--- Deploying Nick's deterministic factory ---"
    NICK_DEPLOYER="0x3fab184622dc19b6109349b94811493bf2a45362"

    cast send "$NICK_DEPLOYER" --value 0.025ether \
        --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" --quiet

    cast publish \
        "0xf8a58085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf31ba02222222222222222222222222222222222222222222222222222222222222222a02222222222222222222222222222222222222222222222222222222222222222" \
        --rpc-url "$RPC_URL" || true

    FACTORY_CODE=$(cast code "$NICK_FACTORY" --rpc-url "$RPC_URL")
    [[ -z "${FACTORY_CODE//0x/}" ]] && die "Nick's factory deployment failed"
    echo "Deployed: $NICK_FACTORY"
else
    echo "Nick's factory: already at $NICK_FACTORY"
fi

# ---------------------------------------------------------------
# 2. P256Verifier (via Nick's factory, salt = bytes32(0))
# ---------------------------------------------------------------
echo ""
echo "--- Deploying P256Verifier ---"

P256_BYTECODE="6080806040523461001657610dd1908161001c8239f35b600080fdfe60e06040523461001a57610012366100c7565b602081519101f35b600080fd5b6040810190811067ffffffffffffffff82111761003b57604052565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b60e0810190811067ffffffffffffffff82111761003b57604052565b90601f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0910116810190811067ffffffffffffffff82111761003b57604052565b60a08103610193578060201161001a57600060409180831161018f578060601161018f578060801161018f5760a01161018c57815182810181811067ffffffffffffffff82111761015f579061013291845260603581526080356020820152833560203584356101ab565b15610156575060ff6001915b5191166020820152602081526101538161001f565b90565b60ff909161013e565b6024837f4e487b710000000000000000000000000000000000000000000000000000000081526041600452fd5b80fd5b5080fd5b5060405160006020820152602081526101538161001f565b909283158015610393575b801561038b575b8015610361575b6103585780519060206101dc818301938451906103bd565b1561034d57604051948186019082825282604088015282606088015260808701527fffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc63254f60a08701527fffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551958660c082015260c081526102588161006a565b600080928192519060055afa903d15610345573d9167ffffffffffffffff831161031857604051926102b1857fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f8401160185610086565b83523d828585013e5b156102eb57828280518101031261018c5750015190516102e693929185908181890994099151906104eb565b061490565b807f4e487b7100000000000000000000000000000000000000000000000000000000602492526001600452fd5b6024827f4e487b710000000000000000000000000000000000000000000000000000000081526041600452fd5b6060916102ba565b505050505050600090565b50505050600090565b507fffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc6325518310156101c4565b5082156101bd565b507fffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc6325518410156101b6565b7fffffffff00000001000000000000000000000000ffffffffffffffffffffffff90818110801590610466575b8015610455575b61044d577f5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b8282818080957fffffffff00000001000000000000000000000000fffffffffffffffffffffffc0991818180090908089180091490565b505050600090565b50801580156103f1575082156103f1565b50818310156103ea565b7f800000000000000000000000000000000000000000000000000000000000000081146104bc577fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0190565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b909192608052600091600160a05260a05193600092811580610718575b61034d57610516838261073d565b95909460ff60c05260005b600060c05112156106ef575b60a05181036106a1575050507f4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5957f6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c2969594939291965b600060c05112156105c7575050505050507fffffffff00000001000000000000000000000000ffffffffffffffffffffffff91506105c260a051610ca2565b900990565b956105d9929394959660a05191610a98565b9097929181928960a0528192819a6105f66080518960c051610722565b61060160c051610470565b60c0528061061b5750505050505b96959493929196610583565b969b5061067b96939550919350916001810361068857507f4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5937f6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c29693610952565b979297919060a05261060f565b6002036106985786938a93610952565b88938893610952565b600281036106ba57505050829581959493929196610583565b9197917ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd0161060f575095508495849661060f565b506106ff6080518560c051610722565b8061070b60c051610470565b60c052156105215761052d565b5060805115610508565b91906002600192841c831b16921c1681018091116104bc5790565b8015806107ab575b6107635761075f91610756916107b3565b92919091610c42565b9091565b50507f6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296907f4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f590565b508115610745565b919082158061094a575b1561080f57507f6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c29691507f4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5906001908190565b7fb01cbd1c01e58065711814b583f061e9d431cca994cea1313449bf97c840ae0a917fffffffff00000001000000000000000000000000ffffffffffffffffffffffff808481600186090894817f94e82e0c1ed3bdb90743191a9c5bbf0d88fc827fd214cc5f0b5ec6ba27673d6981600184090893841561091b575050808084800993840994818460010994828088600109957f6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c29609918784038481116104bc5784908180867fffffffff00000001000000000000000000000000fffffffffffffffffffffffd0991818580090808978885038581116104bc578580949281930994080908935b93929190565b9350935050921560001461093b5761093291610b6d565b91939092610915565b50506000806000926000610915565b5080156107bd565b91949592939095811580610a90575b15610991575050831580610989575b61097a5793929190565b50600093508392508291508190565b508215610970565b85919294951580610a88575b610a78577fffffffff00000001000000000000000000000000ffffffffffffffffffffffff968703918783116104bc5787838189850908938689038981116104bc5789908184840908928315610a5d575050818880959493928180848196099b8c9485099b8c920999099609918784038481116104bc5784908180867fffffffff00000001000000000000000000000000fffffffffffffffffffffffd0991818580090808978885038581116104bc578580949281930994080908929190565b965096505050509093501560001461093b5761093291610b6d565b9550509150915091906001908190565b50851561099d565b508015610961565b939092821580610b65575b61097a577fffffffff00000001000000000000000000000000ffffffffffffffffffffffff908185600209948280878009809709948380888a0998818080808680097fffffffff00000001000000000000000000000000fffffffffffffffffffffffc099280096003090884808a7fffffffff00000001000000000000000000000000fffffffffffffffffffffffd09818380090898898603918683116104bc57888703908782116104bc578780969481809681950994089009089609930990565b508015610aa3565b919091801580610c3a575b610c2d577fffffffff00000001000000000000000000000000ffffffffffffffffffffffff90818460020991808084800980940991817fffffffff00000001000000000000000000000000fffffffffffffffffffffffc81808088860994800960030908958280837fffffffff00000001000000000000000000000000fffffffffffffffffffffffd09818980090896878403918483116104bc57858503928584116104bc5785809492819309940890090892565b5060009150819081908190565b508215610b78565b909392821580610c9a575b610c8d57610c5a90610ca2565b9182917fffffffff00000001000000000000000000000000ffffffffffffffffffffffff80809581940980099009930990565b5050509050600090600090565b508015610c4d565b604051906020918281019183835283604083015283606083015260808201527fffffffff00000001000000000000000000000000fffffffffffffffffffffffd60a08201527fffffffff00000001000000000000000000000000ffffffffffffffffffffffff60c082015260c08152610d1a8161006a565b600080928192519060055afa903d15610d93573d9167ffffffffffffffff83116103185760405192610d73857fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f8401160185610086565b83523d828585013e5b156102eb57828280518101031261018c5750015190565b606091610d7c56fea2646970667358221220fa55558b04ced380e93d0a46be01bb895ff30f015c50c516e898c341cd0a230264736f6c63430008150033"

# calldata = bytes32(0) salt ++ initcode
# calldata = bytes32(0) salt ++ initcode
# Suppress revert if already deployed at same CREATE2 address
cast send "$NICK_FACTORY" \
    "0000000000000000000000000000000000000000000000000000000000000000${P256_BYTECODE}" \
    --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" --quiet 2>/dev/null || true
echo "P256Verifier: deployed or already present"

# ---------------------------------------------------------------
# 3. automata-on-chain-pccs (skip if PCCS_JSON provided)
# ---------------------------------------------------------------
if [[ -n "$PCCS_JSON" ]]; then
    echo ""
    echo "--- Skipping PCCS deployment (using existing: $PCCS_JSON) ---"
    [[ -f "$PCCS_JSON" ]] || die "PCCS_JSON file not found: $PCCS_JSON"
else
    echo ""
    echo "--- Cloning automata-on-chain-pccs ---"
    git clone --depth 1 --branch "$AUTOMATA_PCCS_REF" "$AUTOMATA_PCCS_REPO" "$WORK_DIR/pccs" 2>/dev/null || \
        git clone --depth 1 "$AUTOMATA_PCCS_REPO" "$WORK_DIR/pccs"
    git -C "$WORK_DIR/pccs" submodule update --init --recursive

    cd "$WORK_DIR/pccs"
    echo "--- Deploying PCCS contracts (helpers + DAOs) ---"

    # Step 1: compute helper CREATE2 addresses via local simulation (no --rpc-url).
    # make deploy-all always fails on a fresh clone (no out/ directory), so we go
    # straight to forge script which compiles on-the-fly and writes deployment/31337.json.
    OWNER="$DEPLOYER" forge script script/helper/DeployHelpers.s.sol:DeployHelpers \
        --private-key "$PRIVATE_KEY" -vv 2>&1 || die "Helper simulation failed"
    [[ -f "deployment/31337.json" ]] || die "Expected deployment/31337.json after helper simulation"
    cp "deployment/31337.json" "deployment/${CHAIN_ID}.json"
    echo "  Helper addresses computed for chain ${CHAIN_ID}"

    # Step 2: deploy helpers on-chain (idempotent — CREATE2 means re-deploying is a no-op revert).
    PRIVATE_KEY="$PRIVATE_KEY" make deploy-helpers RPC_URL="$RPC_URL" 2>&1 || true

    # Step 3: deploy core DAOs on-chain.
    if ! PRIVATE_KEY="$PRIVATE_KEY" make deploy-dao RPC_URL="$RPC_URL"; then
        echo "  DAO deploy failed — DAOs may already be deployed, simulating for addresses..."
        # Run deployAll(bool) with WITH_STORAGE=true in pure local simulation (no --rpc-url).
        # This deploys Storage+PcsDao+PckDao on the local EVM and writes deployment/31337.json.
        # EnclaveIdDao and FmspcTcbDao are handled separately below (per-DAO simulation).
        OWNER="$DEPLOYER" forge script script/automata/DeployAutomataDao.s.sol:DeployAutomataDao \
            --sig "deployAll(bool)" true \
            --private-key "$PRIVATE_KEY" -vv 2>&1 || die "DAO simulation failed"
        [[ -f "deployment/31337.json" ]] || die "Expected deployment/31337.json after DAO simulation"
        cp "deployment/31337.json" "deployment/${CHAIN_ID}.json"
        echo "  DAO addresses computed for chain ${CHAIN_ID}"
    fi

    # AutomataTcbEvalDao is NOT deployed by `make deploy-all` (only by DeployAutomataVersioned),
    # but it IS required by the DCAP router.  Compute its deterministic CREATE2 address.
    if ! jq -e '.AutomataTcbEvalDao' "deployment/${CHAIN_ID}.json" >/dev/null 2>&1; then
        echo "  Computing/deploying AutomataTcbEvalDao (required by DCAP router)..."
        # Always sync chain-specific JSON → 31337.json so the local simulation (which runs
        # on a fresh EVM and reads deployment/31337.json) can find AutomataDaoStorage that
        # was written by make deploy-dao to the chain-specific file.
        cp "deployment/${CHAIN_ID}.json" "deployment/31337.json"

        # Step 1: compute CREATE2 address via local simulation (no --rpc-url = fresh EVM).
        # AutomataTcbEvalDao is successfully created, then the tx reverts at grantDao
        # (AutomataDaoStorage has no code in the local EVM). We capture the address from the trace.
        SIM_OUT=$(OWNER="$DEPLOYER" forge script \
            script/automata/versioned/DeployAutomataVersioned.s.sol:DeployAutomataVersioned \
            --sig "deployTcbEvalDao()" \
            --private-key "$PRIVATE_KEY" -vv 2>&1 || true)
        echo "$SIM_OUT"
        TCBEVAL_ADDR=$(echo "$SIM_OUT" | \
            grep -oE 'new AutomataTcbEvalDao@0x[0-9a-fA-F]{40}' | \
            grep -oE '0x[0-9a-fA-F]{40}' | head -1)
        [[ -z "$TCBEVAL_ADDR" ]] && die "Cannot extract AutomataTcbEvalDao address from simulation trace"
        echo "  AutomataTcbEvalDao CREATE2 address: $TCBEVAL_ADDR"

        # Step 2: check if already on-chain. If not, deploy for real (AutomataDaoStorage
        # IS in genesis so grantDao succeeds with --rpc-url).
        TCBEVAL_CODE=$(cast code "$TCBEVAL_ADDR" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x")
        if [[ -z "${TCBEVAL_CODE//0x/}" ]]; then
            echo "  Not yet deployed — deploying AutomataTcbEvalDao..."
            OWNER="$DEPLOYER" forge script \
                script/automata/versioned/DeployAutomataVersioned.s.sol:DeployAutomataVersioned \
                --sig "deployTcbEvalDao()" \
                --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" \
                --broadcast -vv 2>&1 || die "AutomataTcbEvalDao deployment failed"
            echo "  AutomataTcbEvalDao deployed"
            [[ -f "deployment/${CHAIN_ID}.json" ]] && cp "deployment/${CHAIN_ID}.json" "deployment/31337.json"
        else
            echo "  Already deployed — recording address in JSON"
        fi

        # Step 3: ensure address is written into both JSON files
        for f in "deployment/31337.json" "deployment/${CHAIN_ID}.json"; do
            if [[ -f "$f" ]] && ! jq -e '.AutomataTcbEvalDao' "$f" >/dev/null 2>&1; then
                jq --arg a "$TCBEVAL_ADDR" '. + {AutomataTcbEvalDao: $a}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
            fi
        done
        echo "  AutomataTcbEvalDao address for chain ${CHAIN_ID}: $TCBEVAL_ADDR"
    fi

    # AutomataEnclaveIdentityDao and AutomataFmspcTcbDao are the two "legacy" DAOs
    # required by the collateral-upload section.  The current PCCS make deploy-dao
    # only deploys Storage+PcsDao+PckDao, so we simulate each legacy DAO individually
    # using deployEnclaveIdDao() / deployFmspcTcbDao() to compute their CREATE2 addresses.
    if ! jq -e '.AutomataEnclaveIdentityDao' "deployment/${CHAIN_ID}.json" >/dev/null 2>&1 || \
       ! jq -e '.AutomataFmspcTcbDao' "deployment/${CHAIN_ID}.json" >/dev/null 2>&1; then
        echo "  Legacy DAO addresses missing from JSON — running per-DAO simulations..."
        # Ensure 31337.json is current so simulations can resolve AutomataDaoStorage etc.
        cp "deployment/${CHAIN_ID}.json" "deployment/31337.json"
        for _SIM_DAO in AutomataEnclaveIdentityDao AutomataFmspcTcbDao; do
            if ! jq -e ".$_SIM_DAO" "deployment/${CHAIN_ID}.json" >/dev/null 2>&1; then
                [[ "$_SIM_DAO" == "AutomataEnclaveIdentityDao" ]] \
                    && _SIM_SIG="deployEnclaveIdDao()" || _SIM_SIG="deployFmspcTcbDao()"
                _SIM_OUT=$(OWNER="$DEPLOYER" forge script \
                    script/automata/DeployAutomataDao.s.sol:DeployAutomataDao \
                    --sig "$_SIM_SIG" \
                    --private-key "$PRIVATE_KEY" -vv 2>&1 || true)
                # Contract address appears in trace as "new ClassName@0x..."
                # (before the grantDao revert that happens because AutomataDaoStorage
                # has no code in the fresh local EVM).
                _SIM_ADDR=$(echo "$_SIM_OUT" | \
                    grep -oE "new ${_SIM_DAO}@0x[0-9a-fA-F]{40}" | \
                    grep -oE '0x[0-9a-fA-F]{40}' | head -1)
                if [[ -n "$_SIM_ADDR" ]]; then
                    for _f in "deployment/${CHAIN_ID}.json" "deployment/31337.json"; do
                        jq --arg k "$_SIM_DAO" --arg a "$_SIM_ADDR" \
                            '.[$k] = $a' "$_f" > "$_f.tmp" && mv "$_f.tmp" "$_f"
                    done
                    echo "  $_SIM_DAO CREATE2 address: $_SIM_ADDR"
                fi
            fi
        done
    fi

    for DAO_LABEL in AutomataEnclaveIdentityDao AutomataFmspcTcbDao; do
        DAO_ADDR=$(jq -r ".$DAO_LABEL // empty" "deployment/${CHAIN_ID}.json")
        [[ -z "$DAO_ADDR" ]] && die "$DAO_LABEL address not in deployment JSON after simulation"
        DAO_CODE=$(cast code "$DAO_ADDR" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x")
        if [[ -z "${DAO_CODE//0x/}" ]]; then
            echo "  Deploying $DAO_LABEL on-chain..."
            if [[ "$DAO_LABEL" == "AutomataEnclaveIdentityDao" ]]; then
                DAO_SIG="deployEnclaveIdDao()"
            else
                DAO_SIG="deployFmspcTcbDao()"
            fi
            # Backup JSON: forge may overwrite it via vm.writeJson during broadcast.
            cp "deployment/${CHAIN_ID}.json" "deployment/${CHAIN_ID}.json.bak"
            OWNER="$DEPLOYER" forge script script/automata/DeployAutomataDao.s.sol:DeployAutomataDao \
                --sig "$DAO_SIG" \
                --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" \
                --broadcast -vv 2>&1 || die "$DAO_LABEL deployment failed"
            # Restore full JSON (in case vm.writeJson replaced it) and inject address.
            cp "deployment/${CHAIN_ID}.json.bak" "deployment/${CHAIN_ID}.json"
            jq --arg k "$DAO_LABEL" --arg a "$DAO_ADDR" '.[$k] = $a' \
                "deployment/${CHAIN_ID}.json" > "deployment/${CHAIN_ID}.json.tmp" \
                && mv "deployment/${CHAIN_ID}.json.tmp" "deployment/${CHAIN_ID}.json"
            cp "deployment/${CHAIN_ID}.json" "deployment/31337.json"
            echo "  $DAO_LABEL deployed at $DAO_ADDR"
        else
            echo "  $DAO_LABEL already on-chain at $DAO_ADDR"
            # Ensure address is in 31337.json as well
            for f in "deployment/31337.json" "deployment/${CHAIN_ID}.json"; do
                if [[ -f "$f" ]] && ! jq -e ".$DAO_LABEL" "$f" >/dev/null 2>&1; then
                    jq --arg k "$DAO_LABEL" --arg a "$DAO_ADDR" '.[$k] = $a' \
                        "$f" > "$f.tmp" && mv "$f.tmp" "$f"
                fi
            done
        fi
    done

    PCCS_JSON="$WORK_DIR/pccs/deployment/${CHAIN_ID}.json"
    [[ -f "$PCCS_JSON" ]] || die "PCCS deployment JSON not found at $PCCS_JSON"
    echo "PCCS deployed — addresses in $PCCS_JSON"
fi

# ---------------------------------------------------------------
# 4. automata-dcap-attestation (skip if AUTOMATA_DCAP_ATTESTATION provided)
# ---------------------------------------------------------------
if [[ -n "$AUTOMATA_DCAP_ATTESTATION" ]]; then
    echo ""
    echo "--- Skipping DCAP deployment (using existing: $AUTOMATA_DCAP_ATTESTATION) ---"
    AUTOMATA_DCAP="$AUTOMATA_DCAP_ATTESTATION"
else
    echo ""
    echo "--- Cloning automata-dcap-attestation ---"
    git clone --depth 1 --branch "$AUTOMATA_DCAP_REF" "$AUTOMATA_DCAP_REPO" "$WORK_DIR/dcap" 2>/dev/null || \
        git clone --depth 1 "$AUTOMATA_DCAP_REPO" "$WORK_DIR/dcap"
    git -C "$WORK_DIR/dcap" submodule update --init --recursive

    # Wire PCCS output into the expected location
    DCAP_REGISTRY_DIR="$WORK_DIR/dcap/rust-crates/libraries/network-registry/deployment/current/${CHAIN_ID}"
    mkdir -p "$DCAP_REGISTRY_DIR"
    cp "$PCCS_JSON" "$DCAP_REGISTRY_DIR/onchain_pccs.json"

    cd "$WORK_DIR/dcap/evm"
    echo "--- Deploying DCAP contracts (router + attestation + quote verifiers) ---"
    if ! PRIVATE_KEY="$PRIVATE_KEY" make deploy-all RPC_URL="$RPC_URL"; then
        echo "  DCAP deploy-all failed — contracts may already be deployed, simulating..."

        # Seed the local-simulation (chainid=31337) directory so DeployRouter can read PCCS
        # addresses.  In local sim, forge uses block.chainid=31337 for JSON paths.
        SIM_DIR="$DCAP_REGISTRY_DIR/../31337"
        mkdir -p "$SIM_DIR"
        cp "$DCAP_REGISTRY_DIR/onchain_pccs.json" "$SIM_DIR/onchain_pccs.json"

        # Run each forge script directly in local simulation mode (no --rpc-url,
        # no --broadcast, no MULTICHAIN env var).  Without --rpc-url, forge uses a
        # fresh local EVM with block.chainid=31337 and CREATE2 always succeeds.
        # IMPORTANT: do NOT set MULTICHAIN — the forge scripts check
        # vm.envOr("MULTICHAIN", false) and would require CHAINS= if set.
        OWNER="$DEPLOYER" forge script DeployRouter \
            --private-key "$PRIVATE_KEY" -vv 2>&1 || true
        [[ -f "$SIM_DIR/dcap.json" ]] && cp "$SIM_DIR/dcap.json" "$SIM_DIR/dcap.step_router.json" || true

        OWNER="$DEPLOYER" forge script AttestationScript \
            --sig "deployEntrypoint()" \
            --private-key "$PRIVATE_KEY" -vv 2>&1 || true
        [[ -f "$SIM_DIR/dcap.json" ]] && cp "$SIM_DIR/dcap.json" "$SIM_DIR/dcap.step_attest.json" || true

        VERSIONS=$(jq -r '.supportedVersions[]' verifier-versions.json 2>/dev/null || echo "3 4 5")
        for VER in $VERSIONS; do
            OWNER="$DEPLOYER" QUOTE_VERIFIER_VERSION="$VER" forge script DeployVerifier \
                --private-key "$PRIVATE_KEY" -vv 2>&1 || true
            [[ -f "$SIM_DIR/dcap.json" ]] && cp "$SIM_DIR/dcap.json" "$SIM_DIR/dcap.step_v${VER}.json" || true
        done

        # Merge all step files — each script may overwrite dcap.json with only its own
        # address, so we combine them to ensure all addresses are present.
        MERGED="{}"
        for step_file in "$SIM_DIR"/dcap.step_*.json; do
            [[ -f "$step_file" ]] && \
                MERGED=$(jq -s '.[0] * .[1]' <(echo "$MERGED") "$step_file" 2>/dev/null) || true
        done
        [[ "$MERGED" != "{}" ]] && echo "$MERGED" > "$SIM_DIR/dcap.json" || true

        if [[ -f "$SIM_DIR/dcap.json" ]]; then
            cp "$SIM_DIR/dcap.json" "$DCAP_REGISTRY_DIR/dcap.json"
            echo "  DCAP addresses computed from simulation"
        fi
        [[ -f "$DCAP_REGISTRY_DIR/dcap.json" ]] || \
            die "DCAP simulation did not produce dcap.json — check forge output above"

        # For each contract, check if already on-chain; deploy any that are missing.
        # PCCSRouter
        ROUTER_ADDR=$(jq -r '.PCCSRouter // empty' "$DCAP_REGISTRY_DIR/dcap.json")
        if [[ -n "$ROUTER_ADDR" ]]; then
            ROUTER_CODE=$(cast code "$ROUTER_ADDR" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x")
            if [[ -z "${ROUTER_CODE//0x/}" ]]; then
                echo "  Deploying PCCSRouter..."
                OWNER="$DEPLOYER" forge script DeployRouter \
                    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --broadcast -vv \
                    || die "PCCSRouter deployment failed"
                # setup-router: authorize PCCSRouter to call AutomataDaoStorage
                STORAGE_ADDR=$(jq -r '.AutomataDaoStorage // empty' "$DCAP_REGISTRY_DIR/onchain_pccs.json")
                [[ -n "$STORAGE_ADDR" ]] && \
                    cast send "$STORAGE_ADDR" "setCallerAuthorization(address,bool)" \
                        "$ROUTER_ADDR" true \
                        --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" 2>/dev/null || true
            else
                echo "  PCCSRouter already on-chain at $ROUTER_ADDR"
            fi
        fi

        # AutomataDcapAttestationFee
        ATTEST_ADDR=$(jq -r '.AutomataDcapAttestationFee // .AutomataDCAPAttestationFee // empty' \
            "$DCAP_REGISTRY_DIR/dcap.json")
        if [[ -n "$ATTEST_ADDR" ]]; then
            ATTEST_CODE=$(cast code "$ATTEST_ADDR" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x")
            if [[ -z "${ATTEST_CODE//0x/}" ]]; then
                echo "  Deploying AutomataDcapAttestationFee..."
                OWNER="$DEPLOYER" forge script AttestationScript \
                    --sig "deployEntrypoint()" \
                    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --broadcast -vv \
                    || die "AutomataDcapAttestationFee deployment failed"
            else
                echo "  AutomataDcapAttestationFee already on-chain at $ATTEST_ADDR"
            fi
        fi

        # QuoteVerifiers — iterate over versions listed in verifier-versions.json
        VERSIONS=$(jq -r '.supportedVersions[]' verifier-versions.json 2>/dev/null || echo "3 4 5")
        for VER in $VERSIONS; do
            V_KEY="V${VER}QuoteVerifier"
            V_ADDR=$(jq -r ".${V_KEY} // empty" "$DCAP_REGISTRY_DIR/dcap.json")
            if [[ -n "$V_ADDR" ]]; then
                V_CODE=$(cast code "$V_ADDR" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x")
                if [[ -z "${V_CODE//0x/}" ]]; then
                    echo "  Deploying V${VER}QuoteVerifier..."
                    OWNER="$DEPLOYER" QUOTE_VERIFIER_VERSION="$VER" forge script DeployVerifier \
                        --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --broadcast -vv \
                        || die "V${VER}QuoteVerifier deployment failed"
                else
                    echo "  $V_KEY already on-chain at $V_ADDR"
                fi
            fi
        done
    fi

    DCAP_JSON="$DCAP_REGISTRY_DIR/dcap.json"
    [[ -f "$DCAP_JSON" ]] || die "DCAP deployment JSON not found at $DCAP_JSON"

    # Read the AutomataDcapAttestationFee address (key name varies by version)
    AUTOMATA_DCAP=$(jq -r '.AutomataDcapAttestationFee // .AutomataDCAPAttestationFee // empty' "$DCAP_JSON")
    [[ -z "$AUTOMATA_DCAP" ]] && die "Cannot read AutomataDcapAttestationFee from $DCAP_JSON — check JSON: $(cat "$DCAP_JSON")"

    echo "AutomataDcapAttestationFee: $AUTOMATA_DCAP"
fi

# ---------------------------------------------------------------
# 5. Intel DCAP collaterals (only if FMSPC is provided)
# ---------------------------------------------------------------
if [[ -n "$FMSPC" ]]; then
    echo ""
    echo "--- Uploading Intel DCAP collaterals for FMSPC=$FMSPC ---"
    command -v openssl >/dev/null || die "openssl not found (required for collateral upload)"

    INTEL_API="https://api.trustedservices.intel.com/tdx/certification/v4"
    ASSETS="$WORK_DIR/assets"
    mkdir -p "$ASSETS"

    PCS_DAO=$(jq -r '.AutomataPcsDao // empty' "$PCCS_JSON")
    FMSPC_TCB_DAO=$(jq -r '.AutomataFmspcTcbDao // empty' "$PCCS_JSON")
    ENCLAVE_ID_DAO=$(jq -r '.AutomataEnclaveIdentityDao // empty' "$PCCS_JSON")
    [[ -z "$PCS_DAO" || -z "$FMSPC_TCB_DAO" || -z "$ENCLAVE_ID_DAO" ]] && \
        die "Cannot read DAO addresses from $PCCS_JSON"

    # Download TCB info (includes PCS cert chain in response headers)
    echo "Downloading TCB info from Intel PCCS..."
    TCB_RESP=$(curl -sf -D "$ASSETS/tcb_headers.txt" "${INTEL_API}/tcb?fmspc=${FMSPC}") || \
        die "Failed to fetch TCB info for FMSPC $FMSPC — verify FMSPC is correct"
    echo "$TCB_RESP" | jq -c . > "$ASSETS/tcb.json"

    # Extract cert chain from headers
    CERT_CHAIN_ENC=$(grep -i "^Tcb-Info-Issuer-Chain:" "$ASSETS/tcb_headers.txt" | \
        cut -d' ' -f2- | tr -d '\r\n')
    [[ -z "$CERT_CHAIN_ENC" ]] && die "No Tcb-Info-Issuer-Chain header in response"

    CERT_CHAIN=$(python3 -c "import sys,urllib.parse; print(urllib.parse.unquote(sys.argv[1]))" "$CERT_CHAIN_ENC")

    # Split cert chain into signing cert (1st) and root cert (2nd)
    echo "$CERT_CHAIN" | awk '
        /-----BEGIN CERTIFICATE-----/ { n++ }
        n==1 { print > "/tmp/tcb_signing.pem" }
        n==2 { print > "/tmp/tcb_root.pem" }
    '

    for i in signing root; do
        PEM="/tmp/tcb_${i}.pem"
        HEX="$ASSETS/tcb_${i}.hex"
        [[ -f "$PEM" ]] && openssl x509 -in "$PEM" -outform DER 2>/dev/null | \
            python3 -c "import sys; print('0x' + sys.stdin.buffer.read().hex())" > "$HEX"
    done

    # Download QE identity
    echo "Downloading QE identity from Intel PCCS..."
    curl -sf "${INTEL_API}/qe/identity" | jq -c . > "$ASSETS/qe_identity.json" || \
        die "Failed to fetch QE identity"

    # Upload root PCS cert (CA.ROOT = 0)
    if [[ -f "$ASSETS/tcb_root.hex" ]]; then
        ROOT_HEX=$(cat "$ASSETS/tcb_root.hex")
        cast send "$PCS_DAO" "upsertPcsCertificates(uint8,bytes)" 0 "$ROOT_HEX" \
            --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" --quiet 2>/dev/null || \
            echo "  Root PCS cert: already uploaded (Duplicate_Collateral)"
        echo "Root PCS cert: done"
    fi

    # Upload signing PCS cert (CA.SIGNING = 3)
    if [[ -f "$ASSETS/tcb_signing.hex" ]]; then
        SIGN_HEX=$(cat "$ASSETS/tcb_signing.hex")
        cast send "$PCS_DAO" "upsertPcsCertificates(uint8,bytes)" 3 "$SIGN_HEX" \
            --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" --quiet 2>/dev/null || \
            echo "  Signing PCS cert: already uploaded (Duplicate_Collateral)"
        echo "Signing PCS cert: done"
    fi

    # NOTE: TCB info + QE identity are uploaded by setup_tdx_pccs_extras.sh
    # against the *versioned* DAOs (FmspcTcbDaoVersioned, EnclaveIdentityDaoVersioned),
    # which are required for V4 quote verification. The legacy DAOs share the same
    # AutomataDaoStorage keyspace, so uploading here would later cause
    # Duplicate_Collateral when the versioned DAO upserts the same data.

    echo "Skipped legacy TCB info / QE identity upload — handled by setup_tdx_pccs_extras.sh"
fi

# ---------------------------------------------------------------
# Summary
# ---------------------------------------------------------------
echo ""
echo "======================================="
echo "Automata DCAP deployment complete"
echo "  Chain ID:                   $CHAIN_ID"
echo "  AutomataDcapAttestationFee: $AUTOMATA_DCAP"
echo "======================================="

if [[ -n "$OUTPUT_JSON" ]]; then
    # PCCS_JSON lives inside WORK_DIR which is deleted on EXIT.
    # Copy it to a stable path alongside OUTPUT_JSON so callers can use it after this script exits.
    _stable_pccs="$(dirname "$OUTPUT_JSON")/pccs_${CHAIN_ID}.json"
    if [[ -n "$PCCS_JSON" && -f "$PCCS_JSON" ]]; then
        cp "$PCCS_JSON" "$_stable_pccs"
        PCCS_JSON="$_stable_pccs"
    fi
    jq -n \
        --arg chain  "$CHAIN_ID" \
        --arg rpc    "$RPC_URL" \
        --arg dcap   "$AUTOMATA_DCAP" \
        --arg pccs   "$PCCS_JSON" \
        '{chain_id: $chain, rpc_url: $rpc, AutomataDcapAttestationFee: $dcap, pccs_json: $pccs}' \
        > "$OUTPUT_JSON"
    echo "Deployment summary written to $OUTPUT_JSON"
fi

echo ""
echo "Use in deploy_tdx_verifier.sh:"
echo "  AUTOMATA_DCAP_ATTESTATION=$AUTOMATA_DCAP \\"
echo "  PRIVATE_KEY=\$PRIVATE_KEY \\"
echo "  CONTRACT_OWNER=\$OWNER \\"
echo "  TAIKO_CHAIN_ID=\$L2_CHAIN_ID \\"
echo "  FORK_URL=$RPC_URL \\"
echo "  BROADCAST=true ./deploy_tdx_verifier.sh"
echo "======================================="
