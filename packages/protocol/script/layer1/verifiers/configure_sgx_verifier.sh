#!/bin/bash

# Simple wrapper for ConfigureSgxVerifier.s.sol
# Replaces the deleted config_dcap_sgx_verifier.sh with a simpler approach

set -e

usage() {
    cat << 'EOF'
Configure DCAP SGX Verifier

Usage:
  PRIVATE_KEY=0x... ./configure_sgx_verifier.sh [OPTIONS]

Required Environment Variables:
  PRIVATE_KEY           - Private key for signing transactions
  FORK_URL              - RPC URL (e.g., https://ethereum-hoodi-rpc.publicnode.com)
  ATTESTATION_ADDRESS   - AutomataDcapV3Attestation contract address
  SGX_VERIFIER_ADDRESS  - SgxVerifier contract address

Options:
  --env NAME                    Load predefined environment (see list below)
  --mrenclave HASH              Set MR_ENCLAVE (0x... format)
  --mrsigner HASH               Set MR_SIGNER (0x... format)
  --unset-mrenclave HASH        Disable MR_ENCLAVE
  --unset-mrsigner HASH         Disable MR_SIGNER
  --qeid PATH                   Configure QE Identity from JSON file
  --tcb PATH                    Configure TCB Info from JSON file (can repeat)
  --quote HEX                   Register instance with quote bytes (requires PEM_CERTCHAIN_ADDRESS)
  --toggle-check                Toggle local enclave report check

Available Environments:
  dev-ontake, dev-pacaya, dev-sgxgeth         - Development networks
  hekla-ontake, hekla-pacaya, hekla-sgxgeth   - Hekla testnet
  tolba-pacaya, tolba-sgxgeth                 - Tolba testnet
  mainnet, mainnet-pacaya, mainnet-sgxgeth    - Mainnet

Examples:
  # Example from the original usage:
  PRIVATE_KEY=$PRIVATE_KEY \
  FORK_URL=https://ethereum-hoodi-rpc.publicnode.com \
  ./configure_sgx_verifier.sh \
    --env tolba-pacaya \
    --qeid /test/layer1/automata-attestation/assets/0923/identity.json \
    --tcb /test/layer1/automata-attestation/assets/0525/tcb_00606A000000.json \
    --tcb /test/layer1/automata-attestation/assets/0525/tcb_00706A100000.json \
    --tcb /test/layer1/automata-attestation/assets/0525/tcb_00706A800000.json \
    --tcb /test/layer1/automata-attestation/assets/0525/tcb_00906ED50000.json \
    --tcb /test/layer1/automata-attestation/assets/0525/tcb_00A067110000.json \
    --tcb /test/layer1/automata-attestation/assets/0525/tcb_30606a000000.json \
    --mrsigner x \
    --mrenclave $LATEST_MRENCLAVE

  # Just update MR_ENCLAVE:
  PRIVATE_KEY=$KEY FORK_URL=$URL \
    ATTESTATION_ADDRESS=0x... \
    ./configure_sgx_verifier.sh --mrenclave 0xdeadbeef...

EOF
}

# Load predefined environments
load_env() {
    case "$1" in
        dev-ontake|dev-ontake-sgxreth)
            export SGX_VERIFIER_ADDRESS=0x6f6E456354A33BDe7B0ED4A10759b79AC0192e68
            export ATTESTATION_ADDRESS=0xACFFB14Ca4b783fe7314855fBC38c50d7b7A8240
            export PEM_CERTCHAIN_ADDRESS=0xF3152569f2f74ec0f3fd0f57C09aCe07adDA7c5D
            ;;
        dev-pacaya|dev-pacaya-sgxreth)
            export SGX_VERIFIER_ADDRESS=0x0Cf58F3E8514d993cAC87Ca8FC142b83575cC4D3
            export ATTESTATION_ADDRESS=0x3b5C873F4B22C96D835D0D15fD6d1b132A068C05
            export PEM_CERTCHAIN_ADDRESS=0xefd45598d2166f9E958bb55b8E78bDEc82684d90
            ;;
        dev-sgxgeth|dev-pacaya-sgxgeth)
            export SGX_VERIFIER_ADDRESS=0x698ceB7EF2E001347B1672389d6ca6aCE04b13C8
            export ATTESTATION_ADDRESS=0xE1eA623b32C352791Bd1Aba23665707C21053492
            export PEM_CERTCHAIN_ADDRESS=0x5B06e1cBc4bc4c3Eb52A9D40F1D49C6513E23B70
            ;;
        hekla-ontake|hekla-ontake-sgxreth)
            echo "Note: ontake in hekla is deprecated"
            export SGX_VERIFIER_ADDRESS=0x532EFBf6D62720D0B2a2Bb9d11066E8588cAE6D9
            export ATTESTATION_ADDRESS=0xC6cD3878Fc56F2b2BaB0769C580fc230A95e1398
            export PEM_CERTCHAIN_ADDRESS=0x08d7865e7F534d743Aba5874A9AD04bcB223a92E
            ;;
        hekla-pacaya|hekla-pacaya-sgxreth)
            export SGX_VERIFIER_ADDRESS=0xa8cD459E3588D6edE42177193284d40332c3bcd4
            export ATTESTATION_ADDRESS=0xC6cD3878Fc56F2b2BaB0769C580fc230A95e1398
            export PEM_CERTCHAIN_ADDRESS=0x08d7865e7F534d743Aba5874A9AD04bcB223a92E
            ;;
        hekla-sgxgeth|hekla-pacaya-sgxgeth)
            export SGX_VERIFIER_ADDRESS=0x4361B85093720bD50d25236693CA58FD6e1b3a53
            export ATTESTATION_ADDRESS=0x84af08F56AeA1f847c75bE08c96cDC4811694595
            export PEM_CERTCHAIN_ADDRESS=0x08d7865e7F534d743Aba5874A9AD04bcB223a92E
            ;;
        tolba-pacaya|tolba-pacaya-sgxreth)
            export SGX_VERIFIER_ADDRESS=0xd46c13B67396cD1e74Bb40e298fbABeA7DC01f11
            export ATTESTATION_ADDRESS=0xebA89cA02449070b902A5DDc406eE709940e280E
            export PEM_CERTCHAIN_ADDRESS=0x3Fb43E1e16B313F8666b21Cd5EB6C4Ab229eB1C5
            ;;
        tolba-sgxgeth|tolba-pacaya-sgxgeth)
            export SGX_VERIFIER_ADDRESS=0xCdBB6C1751413e78a40735b6D9Aaa7D55e8c038e
            export ATTESTATION_ADDRESS=0x488797321FA4272AF9d0eD4cDAe5Ec7a0210cBD5
            export PEM_CERTCHAIN_ADDRESS=0x3Fb43E1e16B313F8666b21Cd5EB6C4Ab229eB1C5
            ;;
        tolba-shasta | tolba-shasta-sgxreth)
            export SGX_VERIFIER_ADDRESS=0x40CcAFC1C2D14bdD70984b221F2b49af5e7C6114
            export ATTESTATION_ADDRESS=0xebA89cA02449070b902A5DDc406eE709940e280E
            export PEM_CERTCHAIN_ADDRESS=0x3Fb43E1e16B313F8666b21Cd5EB6C4Ab229eB1C5
            ;;
        tolba-shasta-sgxgeth)
            export SGX_VERIFIER_ADDRESS=0x8e362ef5140B0b9BE4a1141b6367784b0A7cefB1
            export ATTESTATION_ADDRESS=0x488797321FA4272AF9d0eD4cDAe5Ec7a0210cBD5
            export PEM_CERTCHAIN_ADDRESS=0x3Fb43E1e16B313F8666b21Cd5EB6C4Ab229eB1C5
            ;;
        mainnet|mainnet-ontake|mainnet-ontake-sgxreth)
            export SGX_VERIFIER_ADDRESS=0xb0f3186FC1963f774f52ff455DC86aEdD0b31F81
            export ATTESTATION_ADDRESS=0x8d7C954960a36a7596d7eA4945dDf891967ca8A3
            export PEM_CERTCHAIN_ADDRESS=0x02772b7B3a5Bea0141C993Dbb8D0733C19F46169
            ;;
        mainnet-pacaya|mainnet-pacaya-sgxreth)
            export SGX_VERIFIER_ADDRESS=0x9e322fC59b8f4A29e6b25c3a166ac1892AA30136
            export ATTESTATION_ADDRESS=0x8d7C954960a36a7596d7eA4945dDf891967ca8A3
            export PEM_CERTCHAIN_ADDRESS=0x02772b7B3a5Bea0141C993Dbb8D0733C19F46169
            ;;
        mainnet-sgxgeth|mainnet-pacaya-sgxgeth)
            export SGX_VERIFIER_ADDRESS=0x7e6409e9b6c5e2064064a6cC994f9a2e95680782
            export ATTESTATION_ADDRESS=0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261
            export PEM_CERTCHAIN_ADDRESS=0x02772b7B3a5Bea0141C993Dbb8D0733C19F46169
            ;;
        *)
            echo "Unknown environment: $1"
            echo "Available environments:"
            echo "  dev: dev-ontake, dev-pacaya, dev-sgxgeth"
            echo "  hekla: hekla-ontake, hekla-pacaya, hekla-sgxgeth"
            echo "  tolba: tolba-ontake, tolba-sgxgeth"
            echo "  mainnet: mainnet, mainnet-pacaya, mainnet-sgxgeth"
            exit 1
            ;;
    esac
    echo "Loaded environment: $1"
}

# Parse arguments
SET_MRENCLAVE=false
SET_MRSIGNER=false
CONFIG_QEID=false
CONFIG_TCB=false
REGISTER_INSTANCE=false
TOGGLE_CHECK=false
TCB_PATHS=""
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
        --qeid)
            export QEID_PATH="$2"
            CONFIG_QEID=true
            shift 2
            ;;
        --tcb)
            if [[ -z "$TCB_PATHS" ]]; then
                TCB_PATHS="$2"
            else
                TCB_PATHS="$TCB_PATHS,$2"
            fi
            CONFIG_TCB=true
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
[[ -z "$ATTESTATION_ADDRESS" ]] && { echo "Error: ATTESTATION_ADDRESS not set"; exit 1; }
[[ -z "$SGX_VERIFIER_ADDRESS" ]] && { echo "Error: SGX_VERIFIER_ADDRESS not set"; exit 1; }

# Export configuration flags
export SET_MRENCLAVE=$SET_MRENCLAVE
export SET_MRSIGNER=$SET_MRSIGNER
export CONFIG_QEID=$CONFIG_QEID
export CONFIG_TCB=$CONFIG_TCB
export REGISTER_INSTANCE=$REGISTER_INSTANCE
export TOGGLE_CHECK=$TOGGLE_CHECK
export MRENCLAVE_ENABLE=$MRENCLAVE_ENABLE
export MRSIGNER_ENABLE=$MRSIGNER_ENABLE
export TCB_PATHS="$TCB_PATHS"

echo "=== Configuration ==="
echo "RPC: $FORK_URL"
echo "Attestation: $ATTESTATION_ADDRESS"
echo "SGX Verifier: $SGX_VERIFIER_ADDRESS"
[[ "$SET_MRENCLAVE" == "true" ]] && echo "MRENCLAVE: $MRENCLAVE (enable=$MRENCLAVE_ENABLE)"
[[ "$SET_MRSIGNER" == "true" ]] && echo "MRSIGNER: $MRSIGNER (enable=$MRSIGNER_ENABLE)"
[[ "$CONFIG_QEID" == "true" ]] && echo "QEID: $QEID_PATH"
[[ "$CONFIG_TCB" == "true" ]] && echo "TCB files: $(echo $TCB_PATHS | tr ',' '\n' | wc -l) file(s)"
echo "===================="

# Run forge script
forge script script/layer1/verifiers/ConfigureSgxVerifier.s.sol:ConfigureSgxVerifier \
    --fork-url "$FORK_URL" \
    --broadcast \
    --legacy \
    -vvv

echo "✓ Configuration complete"
