# Surge Protocol Deployment Guide

This document describes the deployment sequence for the Surge protocol on both L1 and L2.

> **Prerequisite**: It is assumed that the genesis/chainspec file for the L2 network has already been generated.

---

## Deployment Overview

| Step | Script                  | Network | Description                                         |
| ---- | ----------------------- | ------- | --------------------------------------------------- |
| 1    | `DeploySurgeL1.s.sol`   | L1      | Deploy all L1 contracts                             |
| 2    | Verifier setup scripts  | L1      | Configure prover image IDs                          |
| 3    | `AcceptOwnership.s.sol` | L1      | Accept pending L1 ownership transfers               |
| 4    | `SetupSurgeL2.s.sol`    | L2      | Register L1 contracts and setup delegate controller |
| 5    | `AcceptOwnership.s.sol` | L2      | Accept pending L2 ownership transfers               |

---

## Step 1: Deploy L1 Contracts

**Script**: `script/layer1/surge/DeploySurgeL1.s.sol`  
**Shell wrapper**: `script/layer1/surge/deploy_surge_l1.sh`

### What it deploys

#### Rollup Contracts

- **Inbox** (proxy) - Main rollup contract for proposing and proving batches
- **Proof Verifier** (`SurgeVerifier`) - Routes proofs to internal verifiers
- **Codec** (`SurgeCodec` - it is only used by offchain components) - Encoding/decoding for inputs
- **SurgeTimelockController** (if `USE_TIMELOCK=true`) - Timelocked admin for protocol contracts

#### Shared Contracts

- **SharedResolver** - Cross-contract discovery
- **SignalService** - Cross-chain signal relay
- **Bridge** - Cross-chain messaging
- **ERC20Vault** - ERC20 token bridging
- **ERC721Vault** - ERC721 token bridging
- **ERC1155Vault** - ERC1155 token bridging
- **BridgedERC20/721/1155** - Bridged token implementations (clone pattern)

#### Preconf Contracts

- **PreconfWhitelist** - Whitelisted preconfirmation operators store

#### Internal Verifiers (optional)

- **Risc0Verifier** (if `DEPLOY_RISC0_RETH_VERIFIER=true`)
- **SP1Verifier** (if `DEPLOY_SP1_RETH_VERIFIER=true`)
- **ProofVerifierDummy** (if `USE_DUMMY_VERIFIER=true`) - A single dummy verifier that accepts ECDSA signatures from a trusted signer, used in place of real internal verifiers for devnet testing

### Ownership Configuration

The `CONTRACT_OWNER` environment variable specifies the intended owner of all contracts.

When `USE_TIMELOCK=true`, a `SurgeTimelockController` is deployed and becomes the effective owner of all contracts. The timelock's proposers/executors are configured via environment variables.

When `USE_TIMELOCK=false`, `CONTRACT_OWNER` is used directly (typically an EOA for devnet or external DAO/multisig for production).

#### Contracts with immediate ownership (`owner = effective owner`)

These contracts have their ownership set directly during deployment:

- SignalService
- Bridge
- ERC20Vault
- ERC721Vault
- ERC1155Vault
- PreconfWhitelist

#### Contracts with pending ownership (`pendingOwner = effective owner`)

These contracts use the 2-step ownership transfer pattern and require manual acceptance:

- **Proof Verifier** (`SurgeVerifier`)
- **Inbox** (SurgeInbox proxy)
- **SharedResolver**
- **Risc0Verifier** (if deployed and `USE_DUMMY_VERIFIER=false`)
- **SP1Verifier** (if deployed and `USE_DUMMY_VERIFIER=false`)

> **Note**: When `USE_DUMMY_VERIFIER=true`, the `ProofVerifierDummy` is used as the internal verifier and does not require ownership acceptance (it has no owner).

> ⚠️ The pending owner must explicitly accept ownership in **Step 3**. When using timelock, the `SurgeTimelockController.acceptOwnership(address[])` function can be called permissionlessly.

### Environment Variables

```bash
# Required
PRIVATE_KEY          # Deployer private key
CONTRACT_OWNER       # Address that will own all contracts
L2_CHAIN_ID          # Chain ID of the L2 network

# Verifier Configuration
USE_DUMMY_VERIFIER=false           # Use ProofVerifierDummy for internal verifiers (devnet testing)
DUMMY_VERIFIER_SIGNER=0x...        # Signer address for ProofVerifierDummy (required if USE_DUMMY_VERIFIER=true)
DEPLOY_RISC0_RETH_VERIFIER=true    # Deploy/enable RISC0 verifier
DEPLOY_SP1_RETH_VERIFIER=true      # Deploy/enable SP1 verifier

# Bond Configuration
BOND_TOKEN=0x0...0                 # Bond token address (zero address for native ETH)
MIN_BOND=0                         # Minimum bond amount in gwei
LIVENESS_BOND=128000000000         # Liveness bond amount in gwei (128 ETH)
WITHDRAWAL_DELAY=3600              # Withdrawal delay in seconds (1 hour)

# Inbox Configuration
PROVING_WINDOW=7200                # Proving window in seconds (2 hours)
MAX_PROOF_SUBMISSION_DELAY=14400   # Max delay between consecutive proofs (4 hours)
RING_BUFFER_SIZE=16000             # Proposal hash ring buffer size
BASEFEE_SHARING_PCTG=75            # Basefee sharing percentage
MIN_FORCED_INCLUSION_COUNT=1       # Min forced inclusions to process
FORCED_INCLUSION_DELAY=0           # Forced inclusion delay (seconds)
FORCED_INCLUSION_FEE_IN_GWEI=10000000  # Base fee (0.01 ETH)
FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD=50  # Queue size for fee doubling
MIN_CHECKPOINT_DELAY=384           # Min checkpoint delay (1 epoch)
PERMISSIONLESS_INCLUSION_MULTIPLIER=5

# Finalization Streak Configuration
MAX_FINALIZATION_DELAY_BEFORE_STREAK_RESET=14400  # Max delay before streak resets (4 hours)

# Rollback Configuration
MAX_FINALIZATION_DELAY_BEFORE_ROLLBACK=604800     # Max delay before rollback allowed (7 days)

# SurgeVerifier Configuration
NUM_PROOFS_THRESHOLD=2             # Min distinct proofs for finalization

# Timelock Configuration (if USE_TIMELOCK=true)
USE_TIMELOCK=false                       # Deploy SurgeTimelockController as owner
TIMELOCK_MIN_DELAY=86400                 # Min delay for timelock proposals (1 day)
TIMELOCK_MIN_FINALIZATION_STREAK=604800  # Min streak before execution allowed (7 days)
TIMELOCK_PROPOSERS=0x...,0x...           # Comma-separated proposer addresses
TIMELOCK_EXECUTORS=0x...,0x...           # Comma-separated executor addresses
```

### Running the deployment

```bash
cd packages/protocol

# Simulation (dry run)
./script/layer1/surge/deploy_surge_l1.sh

# Broadcast transactions
BROADCAST=true ./script/layer1/surge/deploy_surge_l1.sh

# With contract verification
BROADCAST=true VERIFY=true ./script/layer1/surge/deploy_surge_l1.sh
```

### Output

Deployment addresses are written to `deployments/deploy_l1.json`. The following contracts are included:

- `empty_impl` - Empty implementation for proxy initialization
- `surge_inbox` - SurgeInbox proxy address
- `surge_inbox_impl` - SurgeInbox implementation address
- `surge_verifier` - SurgeVerifier address
- `surge_codec` - SurgeCodec address
- `surge_timelock` - SurgeTimelockController address (if `USE_TIMELOCK=true`)
- `shared_resolver` - SharedResolver proxy address
- `signal_service` - SignalService proxy address
- `bridge` - Bridge proxy address
- `erc20_vault` - ERC20Vault proxy address
- `erc721_vault` - ERC721Vault proxy address
- `erc1155_vault` - ERC1155Vault proxy address
- `bridged_erc20` - BridgedERC20 implementation address
- `bridged_erc721` - BridgedERC721 implementation address
- `bridged_erc1155` - BridgedERC1155 implementation address
- `preconf_whitelist` - PreconfWhitelist proxy address
- `proof_verifier_dummy` - ProofVerifierDummy address (if `USE_DUMMY_VERIFIER=true`)
- `risc0_groth16_verifier` - Risc0 Groth16 verifier (if deployed and `USE_DUMMY_VERIFIER=false`)
- `risc0_verifier` - Risc0Verifier address (if deployed and `USE_DUMMY_VERIFIER=false`)
- `succinct_verifier` - Succinct verifier (if deployed and `USE_DUMMY_VERIFIER=false`)
- `sp1_verifier` - SP1Verifier address (if deployed and `USE_DUMMY_VERIFIER=false`)

---

## Step 2: Configure Verifier Image IDs

After deploying the internal verifiers (Risc0Verifier, SP1Verifier), you must configure them with the correct prover image IDs.

> **Note**: The specific scripts for this step depend on your prover implementation. Consult the prover documentation for the image ID configuration process.

Each internal verifier needs its respective image ID set before proofs can be verified.

---

## Step 3: Accept L1 Ownership

**Script**: `script/layer1/surge/AcceptOwnership.s.sol`  
**Shell wrapper**: `script/layer1/surge/accept_ownership.sh`

### Purpose

Accept pending ownership for contracts that use the 2-step ownership transfer pattern (Ownable2Step).

### Contracts requiring ownership acceptance

From Step 1, the following contracts have `CONTRACT_OWNER` as their `pendingOwner`:

- Proof Verifier (`SurgeVerifier`) address
- Inbox proxy address
- SharedResolver address
- Risc0Verifier address (if deployed and `USE_DUMMY_VERIFIER=false`)
- SP1Verifier address (if deployed and `USE_DUMMY_VERIFIER=false`)

> **Note**: When `USE_DUMMY_VERIFIER=true`, the `ProofVerifierDummy` is used and does not require ownership acceptance.

### Ownership Acceptance Methods

The script supports two modes:

1. **Direct Acceptance**: When `CONTRACT_OWNER` is an EOA, calls `acceptOwnership()` directly on each contract
2. **Intermediate Contract**: When `CONTRACT_OWNER` is a `SurgeTimelockController`, use it as the intermediate contract to accept ownership of all contracts in one call (permissionless)

### Environment Variables

```bash
PRIVATE_KEY            # Private key (must be pending owner for direct, any EOA for intermediate)
CONTRACT_ADDRESSES     # Comma-separated list of contract addresses
INTERMEDIATE_CONTRACT  # (Optional) SurgeTimelockController address for batch acceptance
FORK_URL               # L1 RPC URL
BROADCAST              # Set to "true" to execute transactions
```

### Running the script

```bash
cd packages/protocol

# Simulation
./script/layer1/surge/accept_ownership.sh

# Broadcast
BROADCAST=true ./script/layer1/surge/accept_ownership.sh
```

---

## Step 4: Setup L2 Contracts

**Script**: `script/layer2/surge/SetupSurgeL2.s.sol`  
**Shell wrapper**: `script/layer2/surge/setup_surge_l2.sh`

### What it does

1. **Verifies L2 registrations** - Confirms all L2 contracts are properly registered in the L2 SharedResolver
2. **Registers L1 contracts** - Adds L1 contract addresses to the L2 SharedResolver:
   - L1 Bridge
   - L1 SignalService
   - L1 ERC20Vault
   - L1 ERC721Vault
   - L1 ERC1155Vault
3. **Deploys DelegateController** - Creates a new DelegateController that will be the owner of L2 contracts
4. **Initiates ownership transfer** - Initiates ownership transfers of L2 contracts to the DelegateController:
   - Bridge
   - ERC20Vault
   - ERC721Vault
   - ERC1155Vault
   - SignalService
   - TaikoAnchor
   - SharedResolver

> ⚠️ These ownership transfers are **initiated only**. The DelegateController must accept ownership in **Step 5**.

### Environment Variables

```bash
# Script Configuration
PRIVATE_KEY          # Private key of current L2 contract owner

# L1 Configuration (from Step 1 deployment output)
L1_CHAINID           # L1 chain ID
L1_BRIDGE            # L1 Bridge address
L1_SIGNAL_SERVICE    # L1 SignalService address
L1_ERC20_VAULT       # L1 ERC20Vault address
L1_ERC721_VAULT      # L1 ERC721Vault address
L1_ERC1155_VAULT     # L1 ERC1155Vault address

# L1 Owner Configuration
L1_OWNER             # L1 DAO/Security Council/EOA that controls the DelegateController
```

### Running the script

```bash
cd packages/protocol

# Set L1 addresses from Step 1 deployment
export L1_BRIDGE="0x..."
export L1_SIGNAL_SERVICE="0x..."
export L1_ERC20_VAULT="0x..."
export L1_ERC721_VAULT="0x..."
export L1_ERC1155_VAULT="0x..."
export L1_OWNER="0x..."  # Same as CONTRACT_OWNER from Step 1

# Simulation
FOUNDRY_PROFILE=layer2 ./script/layer2/surge/setup_surge_l2.sh

# Broadcast
FOUNDRY_PROFILE=layer2 BROADCAST=true ./script/layer2/surge/setup_surge_l2.sh
```

### Output

The DelegateController address is written to `deployments/setup_l2.json`.

---

## Step 5: Accept L2 Ownership

**Script**: `script/layer1/surge/AcceptOwnership.s.sol`  
**Shell wrapper**: `script/layer1/surge/accept_ownership.sh`

### Purpose

Accept pending ownership for L2 contracts via the DelegateController. The DelegateController has an `acceptOwnership(address[])` function that can be called permissionlessly.

### Contracts requiring ownership acceptance on L2

From Step 4, the following contracts have the DelegateController as their `pendingOwner`:

- Bridge
- ERC20Vault
- ERC721Vault
- ERC1155Vault
- SignalService
- TaikoAnchor
- SharedResolver

### Environment Variables

```bash
PRIVATE_KEY            # Private key of any funded L2 account (permissionless call)
CONTRACT_ADDRESSES     # Comma-separated list of L2 contract addresses (from genesis/chainspec)
INTERMEDIATE_CONTRACT  # DelegateController address (from Step 4 output)
FORK_URL               # L2 RPC URL
BROADCAST              # Set to "true" to execute transactions
```

### Running the script

```bash
cd packages/protocol

# Simulation
./script/layer1/surge/accept_ownership.sh

# Broadcast
BROADCAST=true ./script/layer1/surge/accept_ownership.sh
```

---

## Summary Checklist

- [ ] Genesis/chainspec file generated
- [ ] **Step 1**: L1 contracts deployed (`DeploySurgeL1.s.sol`)
- [ ] **Step 2**: Verifier image IDs configured
- [ ] **Step 3**: L1 ownership accepted (`AcceptOwnership.s.sol`)
- [ ] **Step 4**: L2 contracts configured (`SetupSurgeL2.s.sol`)
- [ ] **Step 5**: L2 ownership accepted (`AcceptOwnership.s.sol` via DelegateController)

---
