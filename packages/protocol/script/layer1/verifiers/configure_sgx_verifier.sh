#!/bin/bash

# Simple wrapper for ConfigureSgxVerifier.s.sol
#
# Configures the SGX verifier's trusted MRENCLAVE/MRSIGNER allowlist, registers
# SGX instances from raw Intel DCAP quotes, and toggles local-report enforcement.
#
# NOTE: TCB info and QE identity are NO LONGER configured here. They are sourced
# from Automata's on-chain PCCS through the DCAP attestation entrypoint, so the
# old --qeid / --tcb flags (and ATTESTATION_ADDRESS) have been removed.

set -e

usage() {
    cat << 'EOF'
Configure SGX Verifier

Usage:
  PRIVATE_KEY=0x... FORK_URL=https://... ./configure_sgx_verifier.sh [OPTIONS]

Required Environment Variables:
  PRIVATE_KEY           - Private key for signing transactions
  FORK_URL              - RPC URL (e.g., https://ethereum-hoodi-rpc.publicnode.com)
  SGX_VERIFIER_ADDRESS  - SgxVerifier contract address
                          (or supply it via --env NAME)

Options:
  --env NAME                    Load a predefined SGX_VERIFIER_ADDRESS (see list below)
  --mrenclave HASH              Trust MRENCLAVE (0x... format)
  --mrsigner HASH               Trust MRSIGNER (0x... format)
  --unset-mrenclave HASH        Untrust MRENCLAVE
  --unset-mrsigner HASH         Untrust MRSIGNER
  --quote HEX                   Register an SGX instance from a raw Intel DCAP quote
  --toggle-check                Toggle local MRENCLAVE/MRSIGNER allowlist enforcement

Available Environments:
  dev-ontake, dev-pacaya, dev-sgxgeth
  hekla-ontake, hekla-pacaya, hekla-sgxgeth
  tolba-pacaya, tolba-sgxgeth
  mainnet, mainnet-pacaya, mainnet-sgxgeth

Examples:
  # Trust a new MRENCLAVE on a known network:
  PRIVATE_KEY=$PRIVATE_KEY \
  FORK_URL=https://ethereum-hoodi-rpc.publicnode.com \
  ./configure_sgx_verifier.sh \
    --env tolba-pacaya \
    --mrenclave $LATEST_MRENCLAVE

  # Just update MRENCLAVE with an explicit verifier address:
  PRIVATE_KEY=$KEY FORK_URL=$URL \
    SGX_VERIFIER_ADDRESS=0x... \
    ./configure_sgx_verifier.sh --mrenclave 0xdeadbeef...

  # Register an instance from a raw DCAP quote:
  PRIVATE_KEY=$KEY FORK_URL=$URL \
    SGX_VERIFIER_ADDRESS=0x... \
    ./configure_sgx_verifier.sh --quote 0x<rawQuoteHex>

EOF
}

# Load predefined SGX verifier addresses
load_env() {
    case "$1" in
        dev-ontake|dev-ontake-sgxreth)
            export SGX_VERIFIER_ADDRESS=0x6f6E456354A33BDe7B0ED4A10759b79AC0192e68
            ;;
        dev-pacaya|dev-pacaya-sgxreth)
            export SGX_VERIFIER_ADDRESS=0x0Cf58F3E8514d993cAC87Ca8FC142b83575cC4D3
            ;;
        dev-sgxgeth|dev-pacaya-sgxgeth)
            export SGX_VERIFIER_ADDRESS=0x698ceB7EF2E001347B1672389d6ca6aCE04b13C8
            ;;
        hekla-ontake|hekla-ontake-sgxreth)
            echo "Note: ontake in hekla is deprecated"
            export SGX_VERIFIER_ADDRESS=0x532EFBf6D62720D0B2a2Bb9d11066E8588cAE6D9
            ;;
        hekla-pacaya|hekla-pacaya-sgxreth)
            export SGX_VERIFIER_ADDRESS=0xa8cD459E3588D6edE42177193284d40332c3bcd4
            ;;
        hekla-sgxgeth|hekla-pacaya-sgxgeth)
            export SGX_VERIFIER_ADDRESS=0x4361B85093720bD50d25236693CA58FD6e1b3a53
            ;;
        tolba-pacaya|tolba-pacaya-sgxreth)
            export SGX_VERIFIER_ADDRESS=0xd46c13B67396cD1e74Bb40e298fbABeA7DC01f11
            ;;
        tolba-sgxgeth|tolba-pacaya-sgxgeth)
            export SGX_VERIFIER_ADDRESS=0xCdBB6C1751413e78a40735b6D9Aaa7D55e8c038e
            ;;
        mainnet|mainnet-ontake|mainnet-ontake-sgxreth)
            export SGX_VERIFIER_ADDRESS=0xb0f3186FC1963f774f52ff455DC86aEdD0b31F81
            ;;
        mainnet-pacaya|mainnet-pacaya-sgxreth)
            export SGX_VERIFIER_ADDRESS=0x9e322fC59b8f4A29e6b25c3a166ac1892AA30136
            ;;
        mainnet-sgxgeth|mainnet-pacaya-sgxgeth)
            export SGX_VERIFIER_ADDRESS=0x7e6409e9b6c5e2064064a6cC994f9a2e95680782
            ;;
        *)
            echo "Unknown environment: $1"
            echo "Run with --help to see the list of available environments."
            exit 1
            ;;
    esac
    echo "Loaded environment: $1 (SGX_VERIFIER_ADDRESS=$SGX_VERIFIER_ADDRESS)"
}

# Parse arguments
SET_MRENCLAVE=false
SET_MRSIGNER=false
REGISTER_INSTANCE=false
TOGGLE_CHECK=false
MRENCLAVE_ENABLE=true
MRSIGNER_ENABLE=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            usage
            exit 0
            ;;
        --env)
            load_env "$2"
            shift 2
            ;;
        --mrenclave)
            export MRENCLAVE="$2"
            SET_MRENCLAVE=true
            MRENCLAVE_ENABLE=true
            shift 2
            ;;
        --mrsigner)
            export MRSIGNER="$2"
            SET_MRSIGNER=true
            MRSIGNER_ENABLE=true
            shift 2
            ;;
        --unset-mrenclave)
            export MRENCLAVE="$2"
            SET_MRENCLAVE=true
            MRENCLAVE_ENABLE=false
            shift 2
            ;;
        --unset-mrsigner)
            export MRSIGNER="$2"
            SET_MRSIGNER=true
            MRSIGNER_ENABLE=false
            shift 2
            ;;
        --quote)
            export QUOTE_BYTES="$2"
            REGISTER_INSTANCE=true
            shift 2
            ;;
        --toggle-check)
            TOGGLE_CHECK=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required variables
[[ -z "$PRIVATE_KEY" ]] && { echo "Error: PRIVATE_KEY not set"; exit 1; }
[[ -z "$FORK_URL" ]] && { echo "Error: FORK_URL not set"; exit 1; }
[[ -z "$SGX_VERIFIER_ADDRESS" ]] && { echo "Error: SGX_VERIFIER_ADDRESS not set (pass --env NAME or export it)"; exit 1; }

# Warn about removed variables that may linger in the environment from older workflows.
if [[ -n "${ATTESTATION_ADDRESS:-}" || -n "${PEM_CERTCHAIN_ADDRESS:-}" ]]; then
    echo "WARNING: ATTESTATION_ADDRESS/PEM_CERTCHAIN_ADDRESS are no longer used and will be ignored."
fi

# Export configuration flags consumed by ConfigureSgxVerifier.s.sol
export SET_MRENCLAVE=$SET_MRENCLAVE
export SET_MRSIGNER=$SET_MRSIGNER
export REGISTER_INSTANCE=$REGISTER_INSTANCE
export TOGGLE_CHECK=$TOGGLE_CHECK
export MRENCLAVE_ENABLE=$MRENCLAVE_ENABLE
export MRSIGNER_ENABLE=$MRSIGNER_ENABLE

echo "=== Configuration ==="
echo "RPC: $FORK_URL"
echo "SGX Verifier: $SGX_VERIFIER_ADDRESS"
[[ "$SET_MRENCLAVE" == "true" ]] && echo "MRENCLAVE: $MRENCLAVE (enable=$MRENCLAVE_ENABLE)"
[[ "$SET_MRSIGNER" == "true" ]] && echo "MRSIGNER: $MRSIGNER (enable=$MRSIGNER_ENABLE)"
[[ "$REGISTER_INSTANCE" == "true" ]] && echo "Register instance: yes (from raw DCAP quote)"
[[ "$TOGGLE_CHECK" == "true" ]] && echo "Toggle local report check: yes"
echo "===================="

# Run forge script
forge script script/layer1/verifiers/ConfigureSgxVerifier.s.sol:ConfigureSgxVerifier \
    --fork-url "$FORK_URL" \
    --broadcast \
    --legacy \
    -vvv

echo "✓ Configuration complete"
