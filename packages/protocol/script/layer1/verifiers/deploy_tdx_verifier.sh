#!/bin/bash

# Deploy a TDX verifier (impl + proxy).
#
# Trusted params and instance registration are decoupled: the typical flow is to deploy
# the contract here, then run `raiko2 tdx register` from a live TDX VM to set trusted
# params and register the first instance.
#
# You can optionally bootstrap trusted params + register the first instance inline by
# passing the trusted-param env vars and `ATTESTATION_FILE_PATH` (or `TDX_RETH_HOST`,
# falling back to the legacy `TDX_RAIKO_HOST` env var).

set -euo pipefail

# ---------------------------------------------------------------
# Defaults (override via env)
# ---------------------------------------------------------------
export PRIVATE_KEY="${PRIVATE_KEY:-}"
export FORK_URL="${FORK_URL:-http://localhost:8545}"
export CONTRACT_OWNER="${CONTRACT_OWNER:-}"
export AUTOMATA_DCAP_ATTESTATION="${AUTOMATA_DCAP_ATTESTATION:-}"
export TAIKO_CHAIN_ID="${TAIKO_CHAIN_ID:-}"

# Which verifier to deploy:
#   tdx_dcap (default) — GcpTdxVerifier: native Intel TDX DCAP (GCP CVMs,
#                        bare-metal); measurements are the quote's RTMR0..3.
#   azure              — AzureTdxVerifier: Azure vTPM-bound TDX; measurements
#                        are vTPM PCRs.
# `tdx` is accepted as a legacy alias for `tdx_dcap`.
export VERIFIER_KIND="${VERIFIER_KIND:-tdx_dcap}"

# Optional: trusted params (set together to seed the registry inline)
export TRUSTED_PARAMS_INDEX="${TRUSTED_PARAMS_INDEX:-0}"
export TEE_TCB_SVN="${TEE_TCB_SVN:-0x0701030000000000000000000000000000000000000000000000000000000000}"
# Azure-only: 24-bit PCR mask + comma-separated base64 PCR digests (32 bytes each).
export PCR_BITMAP="${PCR_BITMAP:-47632}"
export PCRS_BASE64="${PCRS_BASE64:-}"
# Native (tdx_dcap)-only: 4-bit RTMR mask + comma-separated base64 RTMR digests (48 bytes each).
export RTMR_MASK="${RTMR_MASK:-7}"
export RTMRS_BASE64="${RTMRS_BASE64:-}"
# Shared trusted-params measurements.
export MR_SEAM_BASE64="${MR_SEAM_BASE64:-}"
export MR_TD_BASE64="${MR_TD_BASE64:-}"

# Optional: path to a pre-baked attestation JSON (takes priority over TDX_RETH_HOST)
export ATTESTATION_FILE_PATH="${ATTESTATION_FILE_PATH:-}"

# Optional: live raiko node to fetch bootstrap data from
TDX_RETH_HOST="${TDX_RETH_HOST:-${TDX_RAIKO_HOST:-}}"

export FOUNDRY_PROFILE="${FOUNDRY_PROFILE:-layer1}"
VERIFY="${VERIFY:-false}"
LOG_LEVEL="${LOG_LEVEL:--vvv}"
BLOCK_GAS_LIMIT="${BLOCK_GAS_LIMIT:-200000000}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTOCOL_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TEMP_ATTESTATION=""

# ---------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------
usage() {
    cat <<EOF
Deploy a TDX verifier (native tdx_dcap / GcpTdxVerifier, or azure / AzureTdxVerifier)
and optionally seed trusted params.

Usage:
  PRIVATE_KEY=0x... ./deploy_tdx_verifier.sh [OPTIONS]

Required env:
  PRIVATE_KEY                  Deployer private key
  CONTRACT_OWNER               Final contract owner address
  AUTOMATA_DCAP_ATTESTATION    Automata DCAP attestation contract address
  TAIKO_CHAIN_ID               L2 chain id bound into the proof signature hash

Verifier selection:
  VERIFIER_KIND                tdx_dcap (default; native DCAP / GcpTdxVerifier; RTMRs;
                               legacy alias: tdx) |
                               azure (Azure vTPM / AzureTdxVerifier; PCRs)

Optional env (set together to seed trusted params inline):
  TRUSTED_PARAMS_INDEX         Slot index for trusted params (default: 0)
  TEE_TCB_SVN                  TEE TCB SVN as bytes32 hex (default: example value)
  MR_SEAM_BASE64               mrSeam bytes (base64, 48 bytes when decoded)
  MR_TD_BASE64                 mrTd bytes (base64, 48 bytes when decoded)
  PCR_BITMAP                   azure-only: 24-bit PCR index mask (default: 47632)
  PCRS_BASE64                  azure-only: comma-separated base64 PCR digests (32 bytes)
  RTMR_MASK                    tdx_dcap-only: 4-bit RTMR mask (default: 7 = RTMR0,1,2)
  RTMRS_BASE64                 tdx-only: comma-separated base64 RTMR digests (48 bytes)

Optional env (also register the first instance):
  ATTESTATION_FILE_PATH        Pre-baked attestation JSON for registerInstance
  TDX_RETH_HOST                Live reth-tdx URL; fetches /bootstrap
                               (`TDX_RAIKO_HOST` accepted as legacy alias)

Other:
  FORK_URL                     RPC endpoint (default: http://localhost:8545)
  VERIFY                       Set to true to verify on-chain (default: false)
  LOG_LEVEL                    Forge verbosity flag (default: -vvv)

Known Automata DCAP Attestation addresses:
  Ethereum mainnet: 0x0387aB2eDAB2A138a43437e36AF63689Bb7030f4
  Hoodi: 0xaDdeC7e85c2182202b66E331f2a4A0bBB2cEEa1F

Examples:
  # Deploy only — trusted params/registration handled later by raiko2:
  PRIVATE_KEY=0x... CONTRACT_OWNER=0x... AUTOMATA_DCAP_ATTESTATION=0x... \\
    TAIKO_CHAIN_ID=167001 ./deploy_tdx_verifier.sh

  # Deploy + seed trusted params + register from live reth-tdx:
  TDX_RETH_HOST=http://my-tdx-vm:8080 \\
    MR_SEAM_BASE64=... MR_TD_BASE64=... PCRS_BASE64=... \\
    PRIVATE_KEY=0x... CONTRACT_OWNER=0x... AUTOMATA_DCAP_ATTESTATION=0x... \\
    TAIKO_CHAIN_ID=167001 ./deploy_tdx_verifier.sh
EOF
}

cleanup() {
    if [[ -n "$TEMP_ATTESTATION" && -f "$TEMP_ATTESTATION" ]]; then
        rm -f "$TEMP_ATTESTATION"
    fi
}
trap cleanup EXIT

fetch_attestation_from_reth_tdx() {
    local host="$1"
    local endpoint="${host%/}/bootstrap"

    echo "Fetching TDX bootstrap from $endpoint ..."
    local response
    response=$(curl --fail --silent --show-error "$endpoint") || {
        echo "ERROR: Failed to reach $endpoint"
        exit 1
    }

    local metadata
    # reth-tdx returns the record flat at .metadata; legacy raiko2 wrapped under
    # .tdx.metadata. Accept either for backward compat.
    metadata=$(echo "$response" | jq '.metadata // .tdx.metadata // empty')
    if [[ -z "$metadata" || "$metadata" == "null" ]]; then
        echo "ERROR: Could not parse .tdx.metadata from bootstrap response."
        echo "Response was: $response"
        exit 1
    fi

    TEMP_ATTESTATION=$(mktemp /tmp/tdx_attestation_XXXXXX.json)
    echo "$metadata" >"$TEMP_ATTESTATION"
    export ATTESTATION_FILE_PATH="$TEMP_ATTESTATION"
    echo "Saved attestation to $TEMP_ATTESTATION"
}

# ---------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help | -h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------
# Validation
# ---------------------------------------------------------------
[[ -z "$PRIVATE_KEY" ]] && { echo "ERROR: PRIVATE_KEY not set"; exit 1; }
[[ -z "$CONTRACT_OWNER" ]] && { echo "ERROR: CONTRACT_OWNER not set"; exit 1; }
[[ -z "$AUTOMATA_DCAP_ATTESTATION" ]] && { echo "ERROR: AUTOMATA_DCAP_ATTESTATION not set"; exit 1; }
[[ -z "$TAIKO_CHAIN_ID" ]] && { echo "ERROR: TAIKO_CHAIN_ID not set"; exit 1; }

# Resolve the forge deploy script + contract name from VERIFIER_KIND.
case "$VERIFIER_KIND" in
    tdx|tdx_dcap)
        VERIFIER_KIND="tdx_dcap"
        DEPLOY_SCRIPT="DeployGcpTdxVerifier.s.sol:DeployGcpTdxVerifier"
        CONTRACT_NAME="GcpTdxVerifier"
        ;;
    azure)
        DEPLOY_SCRIPT="DeployAzureTdxVerifier.s.sol:DeployAzureTdxVerifier"
        CONTRACT_NAME="AzureTdxVerifier"
        ;;
    *)
        echo "ERROR: VERIFIER_KIND must be 'tdx_dcap' (native DCAP; legacy alias: 'tdx') or 'azure'"; exit 1
        ;;
esac

# Inline registerInstance from a bootstrap attestation is only wired for the
# Azure verifier; native (tdx_dcap) instances are registered via `cargo run -p xtask
# -- register-tdx` (it auto-detects the issuer), so the deploy script just sets
# trusted params.
if [[ "$VERIFIER_KIND" == "azure" && -n "$TDX_RETH_HOST" && -z "$ATTESTATION_FILE_PATH" ]]; then
    fetch_attestation_from_reth_tdx "$TDX_RETH_HOST"
fi

# ---------------------------------------------------------------
# Build forge flags
# ---------------------------------------------------------------
BROADCAST_ARG="--broadcast"

VERIFY_ARG=""
[[ "$VERIFY" == "true" ]] && VERIFY_ARG="--verify"

# ---------------------------------------------------------------
# Run
# ---------------------------------------------------------------
echo "======================================="
echo "Deploying $CONTRACT_NAME (VERIFIER_KIND=$VERIFIER_KIND)"
echo "  RPC:                  $FORK_URL"
echo "  Owner:                $CONTRACT_OWNER"
echo "  Automata DCAP:        $AUTOMATA_DCAP_ATTESTATION"
echo "  Taiko chain id:       $TAIKO_CHAIN_ID"
if [[ -n "$MR_SEAM_BASE64" ]]; then
    echo "  Trusted params idx:   $TRUSTED_PARAMS_INDEX (inline)"
    if [[ "$VERIFIER_KIND" == "azure" ]]; then
        echo "  Measurements:         PCRs (bitmap $PCR_BITMAP)"
        if [[ -n "$ATTESTATION_FILE_PATH" ]]; then
            echo "  Attestation file:     $ATTESTATION_FILE_PATH"
        else
            echo "  Instance registration: skipped (no attestation provided)"
        fi
    else
        echo "  Measurements:         RTMRs (mask $RTMR_MASK)"
        echo "  Instance registration: via \`xtask register-tdx\` after VM boots"
    fi
else
    echo "  Trusted params:       deferred — run \`cargo run -p xtask -- register-tdx --trust\` after VM boots"
fi
echo "======================================="

cd "$PROTOCOL_DIR"

forge script "script/layer1/verifiers/$DEPLOY_SCRIPT" \
    --fork-url "$FORK_URL" \
    $BROADCAST_ARG \
    $VERIFY_ARG \
    --ffi \
    $LOG_LEVEL \
    --block-gas-limit "$BLOCK_GAS_LIMIT"

echo "======================================="
echo "Done"
echo "======================================="
