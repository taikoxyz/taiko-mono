#!/bin/bash

# Ethereum-mainnet SGX-verifier swap. Deploys, in two broadcasts:
#   [1] DeployAutomataDcapAttestation (profile layer1o / via_ir) — a fresh Taiko-owned
#       AutomataDcapAttestationFee entrypoint wired to the on-chain PCCS router (PCCS_ROUTER).
#   [2] DeploySgxSwapProofStack (profile layer1) — two new SecureSgxVerifiers wired to [1], a new
#       ZkRequiredVerifier composing them with the LIVE RISC0 + SP1 verifiers (reused), and a new
#       MainnetInbox impl identical to the Proposal0019 impl except its proofVerifier.
#
# It deploys IMPLEMENTATIONS ONLY. It does not touch the live INBOX proxy. Applying the swap is a
# governance action (see the printed next-steps). Pass --verify to also verify on Etherscan
# (needs ETHERSCAN_API_KEY).

set -euo pipefail

FORK_URL="${FORK_URL:-https://ethereum-rpc.publicnode.com}"
# Automata's Ethereum-mainnet PCCS router (provisioned; getStandardTcbEvaluationDataNumber != revert).
PCCS_ROUTER="${PCCS_ROUTER:-0xE2Cd5aA44a0896D683684B8EA15eB54B269fC933}"
VERIFY=false

usage() {
    cat << 'EOF'
Ethereum-mainnet SGX-verifier swap: new SGX verifiers on a fresh Automata DCAP entrypoint, a new
ZkRequiredVerifier (reusing the live RISC0 + SP1), and a new MainnetInbox impl (Proposal0019 config
with only proofVerifier changed). Deploys implementations only — the proxy upgrade is a DAO action.

Usage:
  PRIVATE_KEY=0x... CONTRACT_OWNER=0x... ./deploy_sgx_swap.sh [--rpc URL] [--verify]

Required:
  PRIVATE_KEY       Funded deployer key (this script BROADCASTS real transactions)
  CONTRACT_OWNER    Owner of the new AutomataDcapAttestationFee entrypoint (use the DAO controller
                    0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a)

Optional environment variables:
  SGX_REGISTRAR     The only address allowed to registerInstance on the new SGX verifiers.
                    Defaults to the live production registrar (LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH,
                    0x9CBeE534…). Set address(0) for permissionless registration.
  PCCS_ROUTER       Automata on-chain PCCS router (default: mainnet 0xE2Cd5aA4…).
  ETHERSCAN_API_KEY Etherscan API key; REQUIRED when --verify is passed.
  VERIFIER_URL      Override the Etherscan verifier URL.

Options:
  --rpc URL, --fork-url URL   RPC endpoint (default: mainnet public RPC, or $FORK_URL)
  --verify                    Verify the deployed contracts on Etherscan (needs ETHERSCAN_API_KEY)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpc | --fork-url)
            FORK_URL="$2"
            shift 2
            ;;
        --verify)
            VERIFY=true
            shift
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

export PCCS_ROUTER

for v in PRIVATE_KEY CONTRACT_OWNER; do
    if [[ -z "${!v:-}" ]]; then
        echo "Error: $v not set" >&2
        usage
        exit 1
    fi
done

# Etherscan verification args, forwarded to both broadcasts. Empty unless --verify was passed.
verify_args=()
if [[ "$VERIFY" == "true" ]]; then
    if [[ -z "${ETHERSCAN_API_KEY:-}" ]]; then
        echo "Error: --verify requires ETHERSCAN_API_KEY" >&2
        exit 1
    fi
    verify_args=(--verify --etherscan-api-key "$ETHERSCAN_API_KEY")
    if [[ -n "${VERIFIER_URL:-}" ]]; then
        verify_args+=(--verifier-url "$VERIFIER_URL")
    fi
fi

echo "==> [1/2] Deploying AutomataDcapAttestationFee entrypoint (profile layer1o, PCCS_ROUTER=$PCCS_ROUTER)..."
entrypoint_log=$(FOUNDRY_PROFILE=layer1o forge script \
    script/layer1/verifiers/DeployAutomataDcapAttestation.s.sol:DeployAutomataDcapAttestation \
    --fork-url "$FORK_URL" --broadcast --legacy ${verify_args[@]+"${verify_args[@]}"} 2>&1 \
    | tee /dev/stderr)

ATTESTATION=$(echo "$entrypoint_log" \
    | grep -oE 'AutomataDcapAttestationFee deployed: 0x[0-9a-fA-F]{40}' \
    | grep -oE '0x[0-9a-fA-F]{40}' | tail -1)
if [[ -z "$ATTESTATION" ]]; then
    echo "Error: could not parse the deployed AutomataDcapAttestationFee address" >&2
    exit 1
fi
echo "==> Entrypoint deployed: $ATTESTATION"

echo "==> [2/2] Deploying the SGX swap stack wired to the entrypoint (profile layer1)..."
swap_log=$(DCAP_ATTESTATION="$ATTESTATION" FOUNDRY_PROFILE=layer1 forge script \
    script/layer1/core/DeploySgxSwapProofStack.s.sol:DeploySgxSwapProofStack \
    --fork-url "$FORK_URL" --broadcast --legacy ${verify_args[@]+"${verify_args[@]}"} 2>&1 \
    | tee /dev/stderr)

INBOX_IMPL=$(echo "$swap_log" \
    | grep -oE 'MainnetInbox impl deployed: 0x[0-9a-fA-F]{40}' \
    | grep -oE '0x[0-9a-fA-F]{40}' | tail -1)
if [[ -z "$INBOX_IMPL" ]]; then
    echo "Error: could not parse the deployed MainnetInbox impl address" >&2
    exit 1
fi

echo ""
echo "==> SGX swap stack deployed (implementations only — the live proxy is untouched):"
echo "    ATTESTATION (new entrypoint): $ATTESTATION"
echo "    MainnetInbox impl:            $INBOX_IMPL"
echo "    (SGX / ZkRequiredVerifier addresses are in the log above)"
echo ""
echo "==> To apply the swap, the DAO controller (0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a) must:"
echo "    1. On each new SGX verifier: setEnclaveAttributePolicy(mrEnclave, mask, expected) for every"
echo "       trusted enclave, then have the registrar registerInstance(...) with a fresh quote."
echo "    2. Upgrade the INBOX proxy to the new impl:"
echo "       upgradeTo($INBOX_IMPL)  on  0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f"
echo "    NOTE: sequence AFTER Proposal0019 (which trusts the new RISC0/SP1 image IDs on the reused"
echo "    verifiers); until SGX instances are registered, proving continues via RISC0 + SP1."
