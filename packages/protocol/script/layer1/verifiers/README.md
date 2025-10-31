# SGX Verifier Configuration

This directory contains scripts to configure the DCAP SGX Verifier after deployment.

## Files

- **[ConfigureSgxVerifier.s.sol](./ConfigureSgxVerifier.s.sol)** - Solidity script that extends `AttestationBase` to configure the SGX verifier
- **[configure_sgx_verifier.sh](./configure_sgx_verifier.sh)** - Bash wrapper for easier usage

## Quick Start

### Using the Bash Wrapper (Recommended)

The bash wrapper provides the same interface as the original script:

```bash
PRIVATE_KEY=$PRIVATE_KEY \
FORK_URL=https://ethereum-hoodi-rpc.publicnode.com \
./script/layer1/verifiers/configure_sgx_verifier.sh \
  --env tolba-ontake \
  --qeid /test/layer1/automata-attestation/assets/0923/identity.json \
  --tcb /test/layer1/automata-attestation/assets/0525/tcb_00606A000000.json \
  --tcb /test/layer1/automata-attestation/assets/0525/tcb_00706A100000.json \
  --mrsigner x \
  --mrenclave $LATEST_MRENCLAVE
```

### Direct Forge Script Usage

For more control, use the forge script directly:

```bash
PRIVATE_KEY=$PRIVATE_KEY \
ATTESTATION_ADDRESS=x \
SGX_VERIFIER_ADDRESS=x \
SET_MRENCLAVE=true \
MRENCLAVE=0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef \
forge script script/layer1/verifiers/ConfigureSgxVerifier.s.sol:ConfigureSgxVerifier \
  --fork-url https://ethereum-hoodi-rpc.publicnode.com \
  --broadcast \
  --legacy
```

## Configuration Options

### Set MR_ENCLAVE

Enable a new MR_ENCLAVE value:

```bash
--mrenclave 0xYOUR_MRENCLAVE_HASH
```

Disable an MR_ENCLAVE value:

```bash
--unset-mrenclave 0xYOUR_MRENCLAVE_HASH
```

### Set MR_SIGNER

Enable a new MR_SIGNER value:

```bash
--mrsigner 0xYOUR_MRSIGNER_HASH
```

Disable an MR_SIGNER value:

```bash
--unset-mrsigner 0xYOUR_MRSIGNER_HASH
```

### Configure QE Identity

```bash
--qeid /test/layer1/automata-attestation/assets/0923/identity.json
```

### Configure TCB Info

You can specify multiple TCB files:

```bash
--tcb /test/layer1/automata-attestation/assets/0525/tcb_00606A000000.json \
--tcb /test/layer1/automata-attestation/assets/0525/tcb_00706A100000.json \
--tcb /test/layer1/automata-attestation/assets/0525/tcb_00706A800000.json
```

### Register SGX Instance

```bash
--quote 0x03000200000000000a000f00939a7233f79c4ca9940a0db3957f060712ce6af1...
```

## Predefined Environments

Use `--env` to load predefined contract addresses:

### Development Networks

- `dev-ontake` / `dev-ontake-sgxreth` - Dev network with sgx-reth
- `dev-pacaya` / `dev-pacaya-sgxreth` - Dev network Pacaya fork with sgx-reth
- `dev-sgxgeth` / `dev-pacaya-sgxgeth` - Dev network with sgx-geth

### Hekla Testnet

- `hekla-ontake` / `hekla-ontake-sgxreth` - Hekla Ontake fork with sgx-reth (deprecated)
- `hekla-pacaya` / `hekla-pacaya-sgxreth` - Hekla Pacaya fork with sgx-reth
- `hekla-sgxgeth` / `hekla-pacaya-sgxgeth` - Hekla with sgx-geth

### Tolba Testnet

- `tolba-ontake` / `tolba-pacaya` / `tolba-pacaya-sgxreth` - Tolba with sgx-reth
- `tolba-sgxgeth` / `tolba-pacaya-sgxgeth` - Tolba with sgx-geth

### Mainnet

- `mainnet` / `mainnet-ontake` / `mainnet-ontake-sgxreth` - Mainnet Ontake with sgx-reth
- `mainnet-pacaya` / `mainnet-pacaya-sgxreth` - Mainnet Pacaya fork with sgx-reth
- `mainnet-sgxgeth` / `mainnet-pacaya-sgxgeth` - Mainnet with sgx-geth

Example:

```bash
--env tolba-ontake
```

This automatically sets:

- `ATTESTATION_ADDRESS` - AutomataDcapV3Attestation contract
- `SGX_VERIFIER_ADDRESS` - SgxVerifier contract
- `PEM_CERTCHAIN_ADDRESS` - PEMCertChainLib library

## Environment Variables

### Required

- `PRIVATE_KEY` - Private key for signing transactions
- `FORK_URL` - RPC URL for the target network
- `ATTESTATION_ADDRESS` - AutomataDcapV3Attestation contract address
- `SGX_VERIFIER_ADDRESS` - SgxVerifier contract address

### Optional

- `PEM_CERTCHAIN_ADDRESS` - Required only for registering instances with quotes
- `MRENCLAVE_ENABLE` - Set to `false` to disable instead of enable (default: `true`)
- `MRSIGNER_ENABLE` - Set to `false` to disable instead of enable (default: `true`)

## Examples

### Example 1: Full Configuration (Original Workflow)

This replicates the original workflow shown in the task description:

```bash
PRIVATE_KEY=$PRIVATE_KEY \
FORK_URL=https://ethereum-hoodi-rpc.publicnode.com \
./script/layer1/verifiers/configure_sgx_verifier.sh \
  --env tolba-ontake \
  --qeid /test/layer1/automata-attestation/assets/0923/identity.json \
  --tcb /test/layer1/automata-attestation/assets/0525/tcb_00606A000000.json \
  --tcb /test/layer1/automata-attestation/assets/0525/tcb_00706A100000.json \
  --tcb /test/layer1/automata-attestation/assets/0525/tcb_00706A800000.json \
  --tcb /test/layer1/automata-attestation/assets/0525/tcb_00906ED50000.json \
  --tcb /test/layer1/automata-attestation/assets/0525/tcb_00A067110000.json \
  --tcb /test/layer1/automata-attestation/assets/0525/tcb_30606a000000.json \
  --mrsigner x \
  --mrenclave $LATEST_MRENCLAVE
```

### Example 2: Update Only MR_ENCLAVE

```bash
PRIVATE_KEY=$PRIVATE_KEY \
FORK_URL=https://ethereum-hoodi-rpc.publicnode.com \
ATTESTATION_ADDRESS=x \
SGX_VERIFIER_ADDRESS=x \
./script/layer1/verifiers/configure_sgx_verifier.sh \
  --mrenclave x
```

### Example 3: Configure TCB Info Only

```bash
PRIVATE_KEY=$PRIVATE_KEY \
FORK_URL=https://ethereum-hoodi-rpc.publicnode.com \
./script/layer1/verifiers/configure_sgx_verifier.sh \
  --env hekla-ontake \
  --tcb /test/layer1/automata-attestation/assets/0525/tcb_00606A000000.json
```

### Example 4: Using Forge Script Directly

For advanced users who want full control:

```bash
PRIVATE_KEY=$PRIVATE_KEY \
ATTESTATION_ADDRESS=x \
SGX_VERIFIER_ADDRESS=x \
SET_MRENCLAVE=true \
SET_MRSIGNER=true \
CONFIG_QEID=true \
CONFIG_TCB=true \
MRENCLAVE=x \
MRSIGNER=x \
QEID_PATH=/test/layer1/automata-attestation/assets/0923/identity.json \
TCB_PATHS="/test/layer1/automata-attestation/assets/0525/tcb_00606A000000.json,/test/layer1/automata-attestation/assets/0525/tcb_00706A100000.json" \
forge script script/layer1/verifiers/ConfigureSgxVerifier.s.sol:ConfigureSgxVerifier \
  --fork-url https://ethereum-hoodi-rpc.publicnode.com \
  --broadcast \
  --legacy \
  -vvv
```

## Differences from Original Script

The new implementation has these key differences:

1. **Simpler Architecture**: Directly extends `AttestationBase` instead of using a separate `SetDcapParams.s.sol`
2. **Cleaner Code**: Leverages existing test utilities for JSON parsing
3. **Better Maintainability**: Uses the same code path as tests
4. **Same Interface**: Bash wrapper maintains backward compatibility

## Troubleshooting

### Gas Issues

If transactions fail with out-of-gas errors, increase the gas limit:

```bash
forge script ... --gas-limit 10000000
```

### JSON Parsing Errors

Ensure TCB and QE Identity JSON files:

- Are in the correct format
- Exist at the specified paths
- Are readable by the Foundry VM

### Permission Errors

Ensure the private key corresponds to:

- The owner of `AutomataDcapV3Attestation` (for TCB/QE/MR configuration)
- Any account with ETH (for instance registration via `registerInstance`)

## Contract Functions Called

The script interacts with these contract functions:

### AutomataDcapV3Attestation

- `setMrEnclave(bytes32 _mrEnclave, bool _trusted)` - Configure MR_ENCLAVE
- `setMrSigner(bytes32 _mrSigner, bool _trusted)` - Configure MR_SIGNER
- `configureQeIdentityJson(EnclaveId memory qeIdentityInput)` - Configure QE Identity
- `configureTcbInfoJson(string memory fmspc, TCBInfo memory tcbInfoInput)` - Configure TCB Info

### SgxVerifier

- `registerInstance(ParsedV3QuoteStruct memory _attestation)` - Register SGX instance

## See Also

- [AutomataDcapV3Attestation.sol](../../../contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol)
- [SgxVerifier.sol](../../../contracts/layer1/verifiers/SgxVerifier.sol)
- [AttestationBase.sol](../../../test/layer1/automata-attestation/AttestationBase.sol)
