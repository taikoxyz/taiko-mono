#!/bin/bash

# Deploy the Taiko proof-verification stack for Ethereum Hoodi or Mainnet: a fresh Taiko-owned
# AutomataDcapAttestationFee entrypoint plus the proof verifiers (2 SGX + Risc0 + SP1 +
# MainnetVerifier) wired to it. It does NOT deploy the Shasta inbox / signal service / whitelists —
# for the full system use DeployShastaHoodi / DeployShastaMainnet.
#
# Two broadcasts: (1) DeployAutomataDcapAttestation under profile layer1o (via_ir), (2)
# Deploy{Hoodi,Mainnet}ProofStack under profile layer1 with DCAP_ATTESTATION set to (1)'s deployed
# address. Deployed addresses are read from each script's logged output. Pass --verify to also
# verify the deployed contracts on Etherscan (needs ETHERSCAN_API_KEY).

set -euo pipefail

NETWORK=""
FORK_URL=""
VERIFY=false

usage() {
    cat << 'EOF'
Deploy the Taiko proof-verification stack (AutomataDcapAttestationFee entrypoint + the proof
verifiers wired to it) for Ethereum Hoodi or Mainnet. Does NOT deploy the Shasta inbox / signal
service / whitelists — use DeployShastaHoodi / DeployShastaMainnet for the full system.

Usage:
  PRIVATE_KEY=0x... CONTRACT_OWNER=0x... \
  ./deploy_proof_stack.sh --network hoodi|mainnet [--rpc URL] [--verify]

Required:
  --network hoodi|mainnet   Target network (selects PCCS_ROUTER, RPC and the forge script)
  PRIVATE_KEY               Funded deployer key (this script BROADCASTS real transactions)
  CONTRACT_OWNER            Owner of the AutomataDcapAttestationFee entrypoint

Optional environment variables:
  SGX_REGISTRAR         SGX registrar (the only address allowed to registerInstance); defaults to
                        the deployer. Set to a durable multisig, or to the zero address for
                        permissionless registration.
  R0_GROTH16            RiscZero Groth16 verifier to wrap. Mainnet deploys a FRESH one when unset;
                        Hoodi defaults to its known verifier. Set an address to reuse an existing one.
  SP1_PLONK             SP1 Plonk verifier to wrap; same fresh-deploy / default rules as R0_GROTH16.
  PCCS_ROUTER           Automata on-chain PCCS router; defaults to the selected network's router
  ETHERSCAN_API_KEY     Etherscan API key; REQUIRED when --verify is passed
  VERIFIER_URL          Override the Etherscan verifier URL

Options:
  --rpc URL, --fork-url URL   RPC endpoint (default: the selected network's public RPC, or FORK_URL)
  --verify                    Verify the deployed contracts on Etherscan (needs ETHERSCAN_API_KEY)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --network)
            NETWORK="$2"
            shift 2
            ;;
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

# Resolve per-network defaults. PCCS_ROUTER addresses come from Automata's official deployment
# registry (https://github.com/automata-network/automata-dcap-attestation). Consumed by
# DeployAutomataDcapAttestation to build the V3QuoteVerifier; export PCCS_ROUTER to override.
case "$NETWORK" in
    hoodi)
        SCRIPT_CLASS="DeployHoodiProofStack"
        DEFAULT_PCCS_ROUTER="0x8e480c9879F1Db31dC209e5f4d239d5126e6e07B"
        DEFAULT_FORK_URL="https://ethereum-hoodi-rpc.publicnode.com"
        DISPLAY_NAME="Taiko Hoodi"
        ;;
    mainnet)
        SCRIPT_CLASS="DeployMainnetProofStack"
        # Automata's Ethereum Mainnet PCCSRouter (latest registry; the pinned v1.1.0 has no mainnet
        # entry). Confirm its Automata version is compatible with Taiko's pinned V3QuoteVerifier
        # before a production run.
        DEFAULT_PCCS_ROUTER="0xE2Cd5aA44a0896D683684B8EA15eB54B269fC933"
        DEFAULT_FORK_URL="https://ethereum-rpc.publicnode.com"
        DISPLAY_NAME="Taiko Mainnet"
        ;;
    *)
        echo "Error: --network must be 'hoodi' or 'mainnet' (got '${NETWORK:-}')" >&2
        usage
        exit 1
        ;;
esac

export PCCS_ROUTER="${PCCS_ROUTER:-$DEFAULT_PCCS_ROUTER}"
FORK_URL="${FORK_URL:-$DEFAULT_FORK_URL}"

for v in PRIVATE_KEY CONTRACT_OWNER; do
    if [[ -z "${!v:-}" ]]; then
        echo "Error: $v not set" >&2
        usage
        exit 1
    fi
done

# Etherscan verification args, forwarded to both forge broadcasts. Empty unless --verify was passed.
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

echo "==> [1/2] Deploying AutomataDcapAttestationFee entrypoint (profile layer1o)..."
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

echo "==> [2/2] Deploying the proof verifiers wired to the entrypoint (profile layer1)..."
stack_log=$(DCAP_ATTESTATION="$ATTESTATION" FOUNDRY_PROFILE=layer1 forge script \
    "script/layer1/core/${SCRIPT_CLASS}.s.sol:${SCRIPT_CLASS}" \
    --fork-url "$FORK_URL" --broadcast --legacy ${verify_args[@]+"${verify_args[@]}"} 2>&1 \
    | tee /dev/stderr)

MAINNET_VERIFIER=$(echo "$stack_log" \
    | grep -oE 'MainnetVerifier deployed: 0x[0-9a-fA-F]{40}' \
    | grep -oE '0x[0-9a-fA-F]{40}' | tail -1)
if [[ -z "$MAINNET_VERIFIER" ]]; then
    echo "Error: could not parse the deployed MainnetVerifier address" >&2
    exit 1
fi

echo ""
echo "==> ${DISPLAY_NAME} proof stack deployed:"
echo "    ATTESTATION     (AutomataDcapAttestationFee): $ATTESTATION"
echo "    MainnetVerifier (proof aggregator):           $MAINNET_VERIFIER"
echo "    (the SGX / Risc0 / SP1 tier addresses are in the log above)"
echo ""
echo "==> This deploys no inbox. Point a Shasta inbox's proofVerifier at the MainnetVerifier,"
echo "    then verify end-to-end."
if [[ "$NETWORK" == "hoodi" ]]; then
    echo "    (companion Hoodi verifier, PR #21917):"
    echo "    ./script/layer1/verifiers/verify_hoodi_deployment.sh --inbox <INBOX> --attestation $ATTESTATION"
fi
echo ""
echo "==> Then configure the SGX allowlist + register instances (separate step):"
echo "    ./script/layer1/verifiers/configure_sgx_verifier.sh --help"
