#!/bin/bash

# Deploy the Taiko Hoodi proof-verification stack: a fresh Taiko-owned
# AutomataDcapAttestationFee entrypoint plus the proof verifiers (2 SGX + Risc0 +
# SP1 + MainnetVerifier) wired to it. It does NOT deploy the Shasta inbox / signal
# service / whitelists — for the full system, use DeployShastaHoodi.
#
# Two broadcasts: (1) DeployAutomataDcapAttestation under profile layer1o (via_ir),
# (2) DeployHoodiProofStack under profile layer1 with DCAP_ATTESTATION set to (1)'s
# deployed address. Deployed addresses are read from each script's logged output.

set -euo pipefail

FORK_URL="${FORK_URL:-https://ethereum-hoodi-rpc.publicnode.com}"

# Automata's on-chain PCCS router on Ethereum Hoodi (deterministic CREATE2, verified live). Consumed
# by DeployAutomataDcapAttestation to build the V3QuoteVerifier. Export PCCS_ROUTER to override.
export PCCS_ROUTER="${PCCS_ROUTER:-0xe20C4d54afBbea5123728d5b7dAcD9CB3c65C39a}"

usage() {
    cat << 'EOF'
Deploy the Taiko Hoodi proof-verification stack (AutomataDcapAttestationFee entrypoint
+ the proof verifiers wired to it). Does NOT deploy the Shasta inbox / signal service /
whitelists — use DeployShastaHoodi for the full system.

Usage:
  PRIVATE_KEY=0x... CONTRACT_OWNER=0x... \
  ./deploy_hoodi_proof_stack.sh [--rpc URL]

Required environment variables:
  PRIVATE_KEY           Funded deployer key (this script BROADCASTS real transactions)
  CONTRACT_OWNER        Owner of the AutomataDcapAttestationFee entrypoint

Optional environment variables:
  PCCS_ROUTER           Automata on-chain PCCS router; defaults to the verified Ethereum Hoodi
                        router 0xe20C4d54afBbea5123728d5b7dAcD9CB3c65C39a

Options:
  --rpc URL, --fork-url URL   RPC endpoint (default: https://ethereum-hoodi-rpc.publicnode.com,
                              or the FORK_URL env var)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpc | --fork-url)
            FORK_URL="$2"
            shift 2
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

for v in PRIVATE_KEY CONTRACT_OWNER; do
    if [[ -z "${!v:-}" ]]; then
        echo "Error: $v not set" >&2
        usage
        exit 1
    fi
done

echo "==> [1/2] Deploying AutomataDcapAttestationFee entrypoint (profile layer1o)..."
entrypoint_log=$(FOUNDRY_PROFILE=layer1o forge script \
    script/layer1/verifiers/DeployAutomataDcapAttestation.s.sol:DeployAutomataDcapAttestation \
    --fork-url "$FORK_URL" --broadcast --legacy 2>&1 | tee /dev/stderr)

ATTESTATION=$(echo "$entrypoint_log" \
    | grep -oE 'AutomataDcapAttestationFee deployed: 0x[0-9a-fA-F]{40}' \
    | grep -oE '0x[0-9a-fA-F]{40}' | tail -1)
if [[ -z "$ATTESTATION" ]]; then
    echo "Error: could not parse the deployed AutomataDcapAttestationFee address" >&2
    exit 1
fi
echo "==> Entrypoint deployed: $ATTESTATION"

echo "==> [2/2] Deploying the proof verifiers wired to the entrypoint (profile layer1)..."
stack_log=$(DCAP_ATTESTATION="$ATTESTATION" FOUNDRY_PROFILE=layer1 forge script \
    script/layer1/core/DeployHoodiProofStack.s.sol:DeployHoodiProofStack \
    --fork-url "$FORK_URL" --broadcast --legacy 2>&1 | tee /dev/stderr)

MAINNET_VERIFIER=$(echo "$stack_log" \
    | grep -oE 'MainnetVerifier deployed: 0x[0-9a-fA-F]{40}' \
    | grep -oE '0x[0-9a-fA-F]{40}' | tail -1)
if [[ -z "$MAINNET_VERIFIER" ]]; then
    echo "Error: could not parse the deployed MainnetVerifier address" >&2
    exit 1
fi

echo ""
echo "==> Taiko Hoodi proof stack deployed:"
echo "    ATTESTATION     (AutomataDcapAttestationFee): $ATTESTATION"
echo "    MainnetVerifier (proof aggregator):           $MAINNET_VERIFIER"
echo "    (the SGX / Risc0 / SP1 tier addresses are in the log above)"
echo ""
echo "==> This deploys no inbox. Point a Shasta inbox's proofVerifier at the MainnetVerifier,"
echo "    then verify end-to-end (companion Hoodi verifier, PR #21917):"
echo "    ./script/layer1/verifiers/verify_hoodi_deployment.sh --inbox <INBOX> --attestation $ATTESTATION"
echo ""
echo "==> Then configure the SGX allowlist + register instances (separate step):"
echo "    ./script/layer1/verifiers/configure_sgx_verifier.sh --help"
