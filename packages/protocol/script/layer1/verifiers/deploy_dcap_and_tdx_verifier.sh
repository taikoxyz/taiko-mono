#!/bin/bash

# Deploy Automata DCAP contracts + AzureTdxVerifier in a single run.
#
# This is a thin orchestrator that calls:
#   1. deploy_automata_dcap.sh   — deploys P256Verifier, PCCS DAOs, DCAP contracts,
#                                  uploads Intel collaterals (if FMSPC / RETH_TDX_URL given;
#                                  `RAIKO2_URL` accepted as legacy alias)
#   2. deploy_tdx_verifier.sh    — deploys AzureTdxVerifier proxy + implementation
#
# The AutomataDcapAttestationFee address produced by step 1 is automatically
# forwarded to step 2 as AUTOMATA_DCAP_ATTESTATION.
#
# Skip step 1 by providing AUTOMATA_DCAP_ATTESTATION directly.
# Skip collateral upload in step 1 by omitting both FMSPC and RETH_TDX_URL.
#
# Dependencies: git, cast, forge, jq, curl, openssl, python3

set -euo pipefail

# ---------------------------------------------------------------
# Config
# ---------------------------------------------------------------
export PRIVATE_KEY="${PRIVATE_KEY:-}"

# RPC endpoint used by both sub-scripts
RPC_URL="${RPC_URL:-http://localhost:8545}"

# --- Step 1: Automata DCAP ---
# 6-byte FMSPC hex (e.g. "90c06f000000").  Takes precedence over RETH_TDX_URL.
FMSPC="${FMSPC:-}"
# Running reth-tdx instance; FMSPC is parsed from its TDX bootstrap quote when FMSPC is unset.
RETH_TDX_URL="${RETH_TDX_URL:-${RAIKO2_URL:-}}"
# Pass an existing PCCS deployment JSON to skip the PCCS clone+deploy step.
PCCS_JSON="${PCCS_JSON:-}"
# Pass an existing AutomataDcapAttestationFee address to skip step 1 entirely.
export AUTOMATA_DCAP_ATTESTATION="${AUTOMATA_DCAP_ATTESTATION:-}"
# Passed through to deploy_automata_dcap.sh as-is.
AUTOMATA_PCCS_REPO="${AUTOMATA_PCCS_REPO:-}"
AUTOMATA_PCCS_REF="${AUTOMATA_PCCS_REF:-}"
AUTOMATA_DCAP_REPO="${AUTOMATA_DCAP_REPO:-}"
AUTOMATA_DCAP_REF="${AUTOMATA_DCAP_REF:-}"
KEEP_REPOS="${KEEP_REPOS:-false}"

# --- Step 2: AzureTdxVerifier ---
CONTRACT_OWNER="${CONTRACT_OWNER:-}"
TAIKO_CHAIN_ID="${TAIKO_CHAIN_ID:-}"
VERIFY="${VERIFY:-false}"
# Optional trusted-params env vars — forwarded unchanged to deploy_tdx_verifier.sh
TRUSTED_PARAMS_INDEX="${TRUSTED_PARAMS_INDEX:-}"
TEE_TCB_SVN="${TEE_TCB_SVN:-}"
PCR_BITMAP="${PCR_BITMAP:-}"
MR_SEAM_BASE64="${MR_SEAM_BASE64:-}"
MR_TD_BASE64="${MR_TD_BASE64:-}"
PCRS_BASE64="${PCRS_BASE64:-}"
ATTESTATION_FILE_PATH="${ATTESTATION_FILE_PATH:-}"
TDX_RETH_HOST="${TDX_RETH_HOST:-${TDX_RAIKO_HOST:-}}"

# Optional: path to write a combined deployment summary JSON
# Defaults to /tmp/deploy_summary_<chain_id>.json once CHAIN_ID is known (below).
OUTPUT_JSON="${OUTPUT_JSON:-}"

# ---------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<EOF
Deploy Automata DCAP contracts + AzureTdxVerifier in one go.

Usage:
  PRIVATE_KEY=0x... RPC_URL=http://... \\
    CONTRACT_OWNER=0x... TAIKO_CHAIN_ID=<id> \\
    [FMSPC=... | RETH_TDX_URL=...] \\
    ./deploy_dcap_and_tdx_verifier.sh

Required env:
  PRIVATE_KEY                  Deployer private key (needs ETH on the chain).
  CONTRACT_OWNER               Owner address for the AzureTdxVerifier proxy.
  TAIKO_CHAIN_ID               L2 chain id bound into proof signature hashes.

Optional env (step 1 — Automata DCAP):
  FMSPC                        6-byte FMSPC hex (e.g. "90c06f000000").
                               Triggers Intel collateral upload.
                               Takes precedence over RETH_TDX_URL.
  RETH_TDX_URL                   URL of a running reth-tdx instance inside the TDX VM
                               (`GET <url>/bootstrap`). FMSPC is auto-parsed from the
                               TDX attestation quote. `RAIKO2_URL` is accepted as a
                               legacy alias for backward compatibility.
  PCCS_JSON                    Existing PCCS deployment JSON — skips PCCS deploy.
  AUTOMATA_DCAP_ATTESTATION    Existing AutomataDcapAttestationFee address —
                               skips step 1 entirely (requires PCCS_JSON too).
  AUTOMATA_PCCS_REPO / AUTOMATA_PCCS_REF   (passed through to sub-script)
  AUTOMATA_DCAP_REPO / AUTOMATA_DCAP_REF   (passed through to sub-script)
  KEEP_REPOS                   Keep git clones after success (default: false)

Optional env (step 2 — AzureTdxVerifier):
  VERIFY                       Verify on-chain (default: false).
  TRUSTED_PARAMS_INDEX / TEE_TCB_SVN / PCR_BITMAP /
  MR_SEAM_BASE64 / MR_TD_BASE64 / PCRS_BASE64
                               Inline trusted-params seeding (owner only).
  ATTESTATION_FILE_PATH        Pre-baked attestation JSON for registerInstance.
  TDX_RETH_HOST                Live reth-tdx URL to fetch bootstrap for registerInstance
                               (`TDX_RAIKO_HOST` accepted as legacy alias).

Other:
  RPC_URL                      Chain RPC (default: http://localhost:8545).
  OUTPUT_JSON                  Path for combined deployment summary JSON.

Already-deployed Automata DCAP addresses (skip step 1 with AUTOMATA_DCAP_ATTESTATION):
  Mainnet: 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3
  Hoodi:   0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }

# ---------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done

# ---------------------------------------------------------------
# Validate required vars
# ---------------------------------------------------------------
[[ -z "$PRIVATE_KEY" ]]    && die "PRIVATE_KEY is not set"
[[ -z "$CONTRACT_OWNER" ]] && die "CONTRACT_OWNER is not set"
[[ -z "$TAIKO_CHAIN_ID" ]] && die "TAIKO_CHAIN_ID is not set"

command -v cast    >/dev/null || die "cast not found — install Foundry"
command -v forge   >/dev/null || die "forge not found — install Foundry"
command -v git     >/dev/null || die "git not found"
command -v jq      >/dev/null || die "jq not found"
command -v python3 >/dev/null || die "python3 not found"

if [[ -n "$AUTOMATA_DCAP_ATTESTATION" && -z "$PCCS_JSON" ]]; then
    die "PCCS_JSON must be set when AUTOMATA_DCAP_ATTESTATION is provided"
fi

CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL") || die "Cannot reach $RPC_URL"
DEPLOYER=$(cast wallet address --private-key "$PRIVATE_KEY")
OUTPUT_JSON="${OUTPUT_JSON:-/tmp/deploy_summary_${CHAIN_ID}.json}"

echo "======================================="
echo "DCAP + AzureTdxVerifier full deploy"
echo "  Chain ID:     $CHAIN_ID"
echo "  RPC:          $RPC_URL"
echo "  Deployer:     $DEPLOYER"
echo "  Owner:        $CONTRACT_OWNER"
echo "  L2 chain ID:  $TAIKO_CHAIN_ID"
[[ -n "$FMSPC" ]]                          && echo "  FMSPC:        $FMSPC"
[[ -z "$FMSPC" && -n "$RETH_TDX_URL" ]]      && echo "  RETH_TDX_URL:   $RETH_TDX_URL (FMSPC auto-detect)"
[[ -n "$AUTOMATA_DCAP_ATTESTATION" ]]      && echo "  Step 1:       SKIPPED (using $AUTOMATA_DCAP_ATTESTATION)"
echo "======================================="

# ---------------------------------------------------------------
# Step 1: Automata DCAP
# ---------------------------------------------------------------
_DCAP_OUTPUT_JSON="$(mktemp /tmp/automata_dcap_XXXXXX.json)"
_dcap_cleanup() { rm -f "$_DCAP_OUTPUT_JSON"; }
trap _dcap_cleanup EXIT

if [[ -z "$AUTOMATA_DCAP_ATTESTATION" ]]; then
    echo ""
    echo "##############################################"
    echo "# Step 1: Deploy Automata DCAP"
    echo "##############################################"

    _dcap_env=(
        PRIVATE_KEY="$PRIVATE_KEY"
        RPC_URL="$RPC_URL"
        OUTPUT_JSON="$_DCAP_OUTPUT_JSON"
        KEEP_REPOS="$KEEP_REPOS"
    )
    [[ -n "$FMSPC" ]]               && _dcap_env+=(FMSPC="$FMSPC")
    [[ -n "$RETH_TDX_URL" ]]          && _dcap_env+=(RETH_TDX_URL="$RETH_TDX_URL")
    [[ -n "$PCCS_JSON" ]]           && _dcap_env+=(PCCS_JSON="$PCCS_JSON")
    [[ -n "$AUTOMATA_PCCS_REPO" ]]  && _dcap_env+=(AUTOMATA_PCCS_REPO="$AUTOMATA_PCCS_REPO")
    [[ -n "$AUTOMATA_PCCS_REF" ]]   && _dcap_env+=(AUTOMATA_PCCS_REF="$AUTOMATA_PCCS_REF")
    [[ -n "$AUTOMATA_DCAP_REPO" ]]  && _dcap_env+=(AUTOMATA_DCAP_REPO="$AUTOMATA_DCAP_REPO")
    [[ -n "$AUTOMATA_DCAP_REF" ]]   && _dcap_env+=(AUTOMATA_DCAP_REF="$AUTOMATA_DCAP_REF")

    env "${_dcap_env[@]}" bash "$SCRIPT_DIR/deploy_automata_dcap.sh" \
        || die "deploy_automata_dcap.sh failed"

    AUTOMATA_DCAP_ATTESTATION=$(jq -r '.AutomataDcapAttestationFee' "$_DCAP_OUTPUT_JSON") \
        || die "Failed to read AutomataDcapAttestationFee from DCAP output JSON"
    [[ -z "$AUTOMATA_DCAP_ATTESTATION" || "$AUTOMATA_DCAP_ATTESTATION" == "null" ]] \
        && die "AutomataDcapAttestationFee not found in DCAP output JSON"

    # Capture PCCS_JSON path emitted by the sub-script for the summary
    _pccs_json_out=$(jq -r '.pccs_json // empty' "$_DCAP_OUTPUT_JSON")
    [[ -n "$_pccs_json_out" ]] && PCCS_JSON="$_pccs_json_out"

    echo ""
    echo "Step 1 complete — AutomataDcapAttestationFee: $AUTOMATA_DCAP_ATTESTATION"
else
    echo ""
    echo "Step 1 skipped — using provided AUTOMATA_DCAP_ATTESTATION: $AUTOMATA_DCAP_ATTESTATION"
fi

export AUTOMATA_DCAP_ATTESTATION

# ---------------------------------------------------------------
# Step 1.5: PCCS extras (versioned DAOs, TCB info, QE identity, TCB eval,
# CRLs, PCK Platform CA). Required for V4 TDX quote verification.
# ---------------------------------------------------------------
if [[ -n "$RETH_TDX_URL" ]]; then
    echo ""
    echo "##############################################"
    echo "# Step 1.5: PCCS extras (versioned DAOs + collateral)"
    echo "##############################################"

    _extras_env=(
        PRIVATE_KEY="$PRIVATE_KEY"
        RPC_URL="$RPC_URL"
        RETH_TDX_URL="$RETH_TDX_URL"
        AUTOMATA_DCAP_ATTESTATION="$AUTOMATA_DCAP_ATTESTATION"
        PCCS_JSON="$PCCS_JSON"
    )
    env "${_extras_env[@]}" bash "$SCRIPT_DIR/setup_tdx_pccs_extras.sh" \
        || die "setup_tdx_pccs_extras.sh failed"
else
    echo ""
    echo "Step 1.5 skipped — RETH_TDX_URL not set, registerInstance will not work until PCCS extras are loaded"
fi

# ---------------------------------------------------------------
# Step 2: AzureTdxVerifier
# ---------------------------------------------------------------
echo ""
echo "##############################################"
echo "# Step 2: Deploy AzureTdxVerifier"
echo "##############################################"

_tdxv_env=(
    PRIVATE_KEY="$PRIVATE_KEY"
    FORK_URL="$RPC_URL"
    CONTRACT_OWNER="$CONTRACT_OWNER"
    AUTOMATA_DCAP_ATTESTATION="$AUTOMATA_DCAP_ATTESTATION"
    TAIKO_CHAIN_ID="$TAIKO_CHAIN_ID"
    VERIFY="$VERIFY"
)
[[ -n "$TRUSTED_PARAMS_INDEX" ]]  && _tdxv_env+=(TRUSTED_PARAMS_INDEX="$TRUSTED_PARAMS_INDEX")
[[ -n "$TEE_TCB_SVN" ]]           && _tdxv_env+=(TEE_TCB_SVN="$TEE_TCB_SVN")
[[ -n "$PCR_BITMAP" ]]            && _tdxv_env+=(PCR_BITMAP="$PCR_BITMAP")
[[ -n "$MR_SEAM_BASE64" ]]        && _tdxv_env+=(MR_SEAM_BASE64="$MR_SEAM_BASE64")
[[ -n "$MR_TD_BASE64" ]]          && _tdxv_env+=(MR_TD_BASE64="$MR_TD_BASE64")
[[ -n "$PCRS_BASE64" ]]           && _tdxv_env+=(PCRS_BASE64="$PCRS_BASE64")
[[ -n "$ATTESTATION_FILE_PATH" ]] && _tdxv_env+=(ATTESTATION_FILE_PATH="$ATTESTATION_FILE_PATH")
[[ -n "$TDX_RETH_HOST" ]]         && _tdxv_env+=(TDX_RETH_HOST="$TDX_RETH_HOST")

env "${_tdxv_env[@]}" bash "$SCRIPT_DIR/deploy_tdx_verifier.sh" 2>&1 | tee /tmp/_tdxv_deploy.log
_tdxv_rc=${PIPESTATUS[0]}
[[ $_tdxv_rc -ne 0 ]] && die "deploy_tdx_verifier.sh failed"

# Extract AzureTdxVerifier proxy address from deploy log
TDX_VERIFIER_PROXY=$(grep -oE 'Deployed AzureTdxVerifier proxy: 0x[0-9a-fA-F]{40}' /tmp/_tdxv_deploy.log | tail -1 | awk '{print $NF}')

# ---------------------------------------------------------------
# Combined summary
# ---------------------------------------------------------------
echo ""
echo "======================================="
echo "Full deployment complete"
echo "  Chain ID:                   $CHAIN_ID"
echo "  RPC:                        $RPC_URL"
echo "  AutomataDcapAttestationFee: $AUTOMATA_DCAP_ATTESTATION"
echo "  AzureTdxVerifier proxy:          ${TDX_VERIFIER_PROXY:-<not detected>}"
echo "======================================="

if [[ -n "$OUTPUT_JSON" ]]; then
    jq -n \
        --arg chain  "$CHAIN_ID" \
        --arg rpc    "$RPC_URL" \
        --arg dcap   "$AUTOMATA_DCAP_ATTESTATION" \
        --arg tdxv   "${TDX_VERIFIER_PROXY:-}" \
        --arg pccs   "${PCCS_JSON:-}" \
        '{chain_id: $chain, rpc_url: $rpc, AutomataDcapAttestationFee: $dcap, AzureTdxVerifier: $tdxv, pccs_json: $pccs}' \
        > "$OUTPUT_JSON"
    echo "Summary written to $OUTPUT_JSON"
fi
