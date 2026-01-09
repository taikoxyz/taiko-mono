#!/bin/sh

# This script deploys and sets up the Surge CCIP State Store contract
set -e

# Deployer private key
export PRIVATE_KEY=${PRIVATE_KEY:-"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"}

# Network configuration
export FORK_URL=${FORK_URL:-"http://localhost:8545"}

# Contract owner configuration (who will receive ownership after setup)
export CONTRACT_OWNER=${CONTRACT_OWNER:-"0x70997970C51812dc3A010C7d01b50e0d17dc79C8"}

# Automata DCAP Attestation contract address
# Mainnet: 0x95175096a9B74165BE0ac84260cc14Fc1c0EF5FF
# Holesky: 0xbD50489847c9E8B3594E69E4f003fEe7017F7676
export AUTOMATA_DCAP_ATTESTATION=${AUTOMATA_DCAP_ATTESTATION:-"0x95175096a9B74165BE0ac84260cc14Fc1c0EF5FF"}

# Trusted params configuration
# ---------------------------------------------------------------
# Index for storing trusted params (can have multiple configs)
export TRUSTED_PARAMS_INDEX=${TRUSTED_PARAMS_INDEX:-0}

# TEE TCB SVN (16 bytes, stored as bytes32 for env var, only first 16 bytes used)
# Example: 0x07010300000000000000000000000000 (padded to 32 bytes for env)
export TEE_TCB_SVN=${TEE_TCB_SVN:-"0x0701030000000000000000000000000000000000000000000000000000000000"}

# PCR Bitmap - determines which PCRs to verify
# Example: 47632 = 0xba10 (checks PCRs 4, 9, 11)
export PCR_BITMAP=${PCR_BITMAP:-47632}

# MrSeam - base64 encoded (48 bytes when decoded)
# Example from test: SbZvqkUdGeu9vok3G42vK2WqOYTskBEDQ+ni7sEWrwiFD6IOOxqpqHTXemU4Dufm
export MR_SEAM_BASE64=${MR_SEAM_BASE64:-"SbZvqkUdGeu9vok3G42vK2WqOYTskBEDQ+ni7sEWrwiFD6IOOxqpqHTXemU4Dufm"}

# MrTd - base64 encoded (48 bytes when decoded)
# Example from test: JzgoxGJS/L3YrS3ZBxMCIrA0ZtUqKRHXDBpZUIlda9GuRR04LVqbG0wO0OWumj29
export MR_TD_BASE64=${MR_TD_BASE64:-"JzgoxGJS/L3YrS3ZBxMCIrA0ZtUqKRHXDBpZUIlda9GuRR04LVqbG0wO0OWumj29"}

# PCRs - comma-separated base64 encoded values (32 bytes each when decoded)
# Example: m/fm85ufw335zLyWEVvlr2cp1ON/wdkSy3CRse2SKd4=,J4VjU5l9Cwgf/vVSxEemxX8R/dLLmFXIF6x+6Ns1IK0=
export PCRS_BASE64=${PCRS_BASE64:-"m/fm85ufw335zLyWEVvlr2cp1ON/wdkSy3CRse2SKd4=,J4VjU5l9Cwgf/vVSxEemxX8R/dLLmFXIF6x+6Ns1IK0=,jUhHReFtySAraFU+CRLcSEGyPXaBHcBVQgvJ5yiJ58k="}

# Instance registration configuration (via attestation)
# ---------------------------------------------------------------
# Path to JSON file containing attestation data for registerInstance
# The JSON file should contain:
# {
#   "attestationDocument": {
#     "attestation": {
#       "tpmQuote": {
#         "quote": "0x...",
#         "rsaSignature": "0x...",
#         "pcrs": ["0x...", "0x...", ...] // 24 bytes32 values
#       }
#     },
#     "instanceInfo": {
#       "attestationReport": "0x...",
#       "runtimeData": {
#         "raw": "0x...",
#         "hclAkPub": {
#           "exponentRaw": 0,
#           "modulusRaw": "0x..."
#         }
#       }
#     },
#     "userData": "0x..."
#   },
#   "pcrs": [
#     {"index": 0, "digest": "0x..."},
#     {"index": 1, "digest": "0x..."},
#     ...
#   ],
#   "pcrsLength": 24,
#   "nonce": "0x..."
# }
export ATTESTATION_FILE_PATH=${ATTESTATION_FILE_PATH:-"./script/layer1/surge/ccip/sample_attestation.json"}

# Foundry configuration
# ---------------------------------------------------------------
export FOUNDRY_PROFILE=${FOUNDRY_PROFILE:-"layer1"}

# Broadcast transactions
export BROADCAST=${BROADCAST:-false}

# Verify smart contracts
export VERIFY=${VERIFY:-false}

# Log level
export LOG_LEVEL=${LOG_LEVEL:-"-vvv"}

# Block gas limit
export BLOCK_GAS_LIMIT=${BLOCK_GAS_LIMIT:-200000000}

# Parameterize broadcasting
BROADCAST_ARG=""
if [ "$BROADCAST" = "true" ]; then
    BROADCAST_ARG="--broadcast"
fi

# Parameterize verification
VERIFY_ARG=""
if [ "$VERIFY" = "true" ]; then
    VERIFY_ARG="--verify"
fi

forge script ./script/layer1/surge/ccip/DeployAndSetupSurgeCCIP.s.sol:DeployAndSetupSurgeCCIP \
    --fork-url $FORK_URL \
    $BROADCAST_ARG \
    $VERIFY_ARG \
    --ffi \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY \
    --block-gas-limit $BLOCK_GAS_LIMIT
