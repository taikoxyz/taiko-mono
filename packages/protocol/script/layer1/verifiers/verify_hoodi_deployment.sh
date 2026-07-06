#!/bin/bash

# Read-only verifier for a Taiko Hoodi proof-stack deployment.
#
# Walks the deployment from two roots (the Shasta inbox and the Taiko-owned
# AutomataDcapAttestationFee entrypoint) and asserts the SGX/DCAP wiring, the
# SecureSgxVerifier policy, the Risc0/SP1 tiers and the MainnetVerifier
# aggregation. Exits non-zero if any hard check fails. No broadcast, no key.

set -euo pipefail

FORK_URL="${FORK_URL:-https://ethereum-hoodi-rpc.publicnode.com}"

usage() {
    cat << 'EOF'
Verify Hoodi Deployment

Usage:
  ./verify_hoodi_deployment.sh --inbox 0x... --attestation 0x... [--pccs 0x...] [--rpc URL]

Required:
  --inbox ADDR          Shasta inbox proxy (root of tier discovery)
  --attestation ADDR    AutomataDcapAttestationFee entrypoint (root of the DCAP subtree)

Optional:
  --pccs ADDR           Expected PCCS router (asserted as an advisory when supplied)
  --rpc URL             RPC endpoint (default: https://ethereum-hoodi-rpc.publicnode.com,
                        or the FORK_URL env var)

Example:
  ./verify_hoodi_deployment.sh \
    --inbox 0xInbox --attestation 0xEntrypoint --pccs 0xPccsRouter
EOF
}

INBOX=""
ATTESTATION=""
PCCS_ROUTER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --inbox) INBOX="$2"; shift 2 ;;
        --attestation) ATTESTATION="$2"; shift 2 ;;
        --pccs) PCCS_ROUTER="$2"; shift 2 ;;
        --rpc|--fork-url) FORK_URL="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -z "$INBOX" || -z "$ATTESTATION" ]]; then
    echo "Error: --inbox and --attestation are required" >&2
    usage
    exit 1
fi

export INBOX ATTESTATION
if [[ -n "$PCCS_ROUTER" ]]; then
    export PCCS_ROUTER
fi

FOUNDRY_PROFILE=layer1 forge script \
    script/layer1/verifiers/VerifyHoodiDeployment.s.sol:VerifyHoodiDeployment \
    --fork-url "$FORK_URL" \
    -vvv
