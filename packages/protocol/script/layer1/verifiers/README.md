# SGX Verifier Configuration

This directory contains scripts to configure the SGX Verifier after deployment.

## Files

- **[ConfigureSgxVerifier.s.sol](./ConfigureSgxVerifier.s.sol)** - Solidity script that configures the
  SGX verifier's trusted MRENCLAVE/MRSIGNER allowlist, SecureSgxVerifier attribute policy,
  registers instances, and toggles local-report enforcement.
- **[configure_sgx_verifier.sh](./configure_sgx_verifier.sh)** - Bash wrapper for easier usage.
- **[deploy_sgx_verifiers_with_existing_automata.sh](./deploy_sgx_verifiers_with_existing_automata.sh)** -
  Deploys geth/reth `SecureSgxVerifier` contracts when the network already has Automata DCAP
  attestation infrastructure.
- **[deploy_devnet_sgx_own_pccs.sh](./deploy_devnet_sgx_own_pccs.sh)** - Devnet wrapper that deploys a
  self-hosted Automata DCAP/PCCS stack, then deploys the geth/reth `SecureSgxVerifier` contracts.

> **What changed:** TCB info and QE identity are **no longer configured on-chain by Taiko**. They
> are sourced from Automata's on-chain PCCS through the DCAP attestation entrypoint. SGX
> attestation is provided by the pinned `@automata-network/automata-dcap-attestation` dependency,
> called via `IDcapAttestation`. As a result the old `--qeid` / `--tcb` flags and the
> `ATTESTATION_ADDRESS` / `PEM_CERTCHAIN_ADDRESS` variables have been removed. The
> MRENCLAVE/MRSIGNER allowlist now lives directly on `SgxVerifier` (previously on
> `AutomataDcapV3Attestation`).

## Workflow Overview

There are two deployment paths and one post-deployment configuration path:

- Use `deploy_sgx_verifiers_with_existing_automata.sh` for Hoodi/mainnet-style networks where
  Automata already provides the DCAP attestation contracts. This deploys only Taiko-owned geth/reth
  `SecureSgxVerifier` contracts.
- Use `deploy_devnet_sgx_own_pccs.sh` for devnets that need their own Automata DCAP/PCCS stack. This
  deploys the Automata stack, loads SGX collateral, then deploys Taiko-owned geth/reth
  `SecureSgxVerifier` contracts.
- Use `configure_sgx_verifier.sh` after either deployment path to trust MRENCLAVE/MRSIGNER values,
  configure `SecureSgxVerifier` ATTRIBUTES policies, and register raw SGX quotes.

The default configuration path is fail-closed: local MRENCLAVE/MRSIGNER checks are on, `--mrenclave`
also sets the default `SecureSgxVerifier` ATTRIBUTES policy when no policy exists yet, and quote
registration still verifies DCAP collateral through Automata's attestation entrypoint.

## Quick Start

### Using the Bash Wrapper (Recommended)

```bash
PRIVATE_KEY=$PRIVATE_KEY \
FORK_URL=https://ethereum-hoodi-rpc.publicnode.com \
./script/layer1/verifiers/configure_sgx_verifier.sh \
  --env tolba-pacaya \
  --mrsigner $LATEST_MRSIGNER \
  --mrenclave $LATEST_MRENCLAVE
```

### Direct Forge Script Usage

For more control, use the forge script directly:

```bash
PRIVATE_KEY=$PRIVATE_KEY \
SGX_VERIFIER_ADDRESS=0x... \
SET_MRENCLAVE=true \
MRENCLAVE=0xYOUR_MRENCLAVE_HASH \
forge script script/layer1/verifiers/ConfigureSgxVerifier.s.sol:ConfigureSgxVerifier \
  --fork-url https://ethereum-hoodi-rpc.publicnode.com \
  --broadcast \
  --legacy
```

## Deploy SecureSgxVerifier With Existing Automata

For Hoodi/mainnet-style deployments where Automata DCAP attestation infrastructure already exists,
deploy only the two Taiko-owned `SecureSgxVerifier` contracts:

```bash
PRIVATE_KEY=$PRIVATE_KEY \
RPC_URL=https://ethereum-hoodi-rpc.publicnode.com \
NETWORK=hoodi \
./script/layer1/verifiers/deploy_sgx_verifiers_with_existing_automata.sh
```

`NETWORK=hoodi` and `NETWORK=mainnet` load the known geth/reth Automata proxy addresses and the
Taiko chain ID. For a custom shared Automata entrypoint, set `TAIKO_CHAIN_ID` and
`AUTOMATA_DCAP_ATTESTATION`; for separate entrypoints, set
`SGX_GETH_AUTOMATA_DCAP_ATTESTATION` and `SGX_RETH_AUTOMATA_DCAP_ATTESTATION`.

This script is deploy-only. It does not upload collateral, set MRENCLAVE/MRSIGNER, set
`SecureSgxVerifier` attribute policies, or register an instance. Run `configure_sgx_verifier.sh`
against each deployed verifier after the real geth/reth quotes are available.

## Deploy Devnet With Self-Hosted PCCS

For a devnet that needs its own Automata DCAP/PCCS stack, use the devnet wrapper and set
`TAIKO_CHAIN_ID` to the Taiko L2 chain ID, not the L1 RPC chain ID:

```bash
DEVNET_ENV=<devnet-env-file> \
SGX_BOOTSTRAP_JSON=<sgx-bootstrap-json> \
TAIKO_CHAIN_ID=167001 \
./script/layer1/verifiers/deploy_devnet_sgx_own_pccs.sh
```

The wrapper fails closed when `TAIKO_CHAIN_ID` is omitted. Only set
`ALLOW_RPC_CHAIN_ID_AS_TAIKO_CHAIN_ID=true` for environments where the RPC chain ID is intentionally
the Taiko chain ID being proven.

`DEVNET_ENV` must set `PRIVATE_KEY` and `RPC_URL`. `SGX_BOOTSTRAP_JSON` must point to a local SGX
bootstrap JSON containing a quote, unless `SGX_BOOTSTRAP_URL` or `FMSPC` is supplied for collateral
setup. To register real geth/reth instances during the same run, set `REGISTER_SECURE_SGX=true` and
provide `SGX_GETH_BOOTSTRAP_JSON`, `SGX_RETH_BOOTSTRAP_JSON`, or both depending on
`REGISTER_SECURE_SGX_TARGET`.

The self-hosted PCCS path pins the default Automata checkouts to reviewed commits. Override
`AUTOMATA_PCCS_REF` or `AUTOMATA_DCAP_REF` only when intentionally testing a different upstream
revision. If the target chain lacks the RIP-7212 P256 precompile, `deploy_automata_dcap.sh` records
the deployed Daimo P256 address in its summary and the devnet wrapper passes it into
`setup_sgx_pccs_extras.sh` for the versioned PCCS DAO constructors.

`setup_sgx_pccs_extras.sh` defaults to `FMSPC_TCB_UPLOAD_MODE=direct-storage` only as a devnet gas-cap
workaround for SGX FMSPC TCB info. Use `FMSPC_TCB_UPLOAD_MODE=dao` when the target chain can fit the
DAO upsert path and you want the Intel signature verification to happen through the Automata DAO call.

## Configuration Options

### Set MR_ENCLAVE

Trust a new MR_ENCLAVE value:

```bash
--mrenclave 0xYOUR_MRENCLAVE_HASH
```

For `SecureSgxVerifier`, `configure_sgx_verifier.sh` also sets the default ATTRIBUTES policy for
this MRENCLAVE when no policy exists yet:

```text
mask     = 0xffffffffffffffff0000000000000000
expected = 0x05000000000000000000000000000000
```

Set `AUTO_ATTRIBUTE_POLICY_ON_MRENCLAVE=false` to disable this behavior, or pass
`--attribute-policy` explicitly to use a different policy. The wrapper skips the default when the
MRENCLAVE already has a non-zero policy version, so a repeated `--mrenclave` does not bump the policy
version and revoke existing instances.

Untrust an MR_ENCLAVE value:

```bash
--unset-mrenclave 0xYOUR_MRENCLAVE_HASH
```

### Set MR_SIGNER

Trust a new MR_SIGNER value:

```bash
--mrsigner 0xYOUR_MRSIGNER_HASH
```

Untrust an MR_SIGNER value:

```bash
--unset-mrsigner 0xYOUR_MRSIGNER_HASH
```

### Set SecureSgxVerifier Attribute Policy

`SecureSgxVerifier` fails closed until an ATTRIBUTES policy is configured for the quoted MRENCLAVE.
The strict production policy normally pins the FLAGS bytes to `INIT | MODE64BIT` and leaves XFRM
unchecked:

```bash
--attribute-policy 0xYOUR_MRENCLAVE_HASH 0xffffffffffffffff0000000000000000 0x05000000000000000000000000000000
```

### Register SGX Instance

Register an instance from a raw Intel DCAP quote (the quote is verified on-chain via the DCAP
attestation entrypoint, which reads Intel collateral from on-chain PCCS):

```bash
--quote 0x<rawQuoteHex>
```

### Toggle Local Report Check

Enforcement of the MRENCLAVE/MRSIGNER allowlist is **on by default** (fail-closed): until at least
one MRENCLAVE and one MRSIGNER are trusted, no instance can register. Toggle it:

```bash
--toggle-check
```

## Predefined Environments

Use `--env` to load a predefined `SGX_VERIFIER_ADDRESS`:

### Development Networks

- `dev-ontake` / `dev-ontake-sgxreth`
- `dev-pacaya` / `dev-pacaya-sgxreth`
- `dev-sgxgeth` / `dev-pacaya-sgxgeth`

### Hekla Testnet

- `hekla-ontake` / `hekla-ontake-sgxreth`
- `hekla-pacaya` / `hekla-pacaya-sgxreth`
- `hekla-sgxgeth` / `hekla-pacaya-sgxgeth`

### Tolba Testnet

- `tolba-pacaya` / `tolba-pacaya-sgxreth`
- `tolba-sgxgeth` / `tolba-pacaya-sgxgeth`

### Mainnet

- `mainnet` / `mainnet-ontake` / `mainnet-ontake-sgxreth`
- `mainnet-pacaya` / `mainnet-pacaya-sgxreth`
- `mainnet-sgxgeth` / `mainnet-pacaya-sgxgeth`

Example:

```bash
--env tolba-pacaya
```

This automatically sets `SGX_VERIFIER_ADDRESS`.

## Environment Variables

### Required

- `PRIVATE_KEY` - Private key for signing transactions
- `FORK_URL` - RPC URL for the target network
- `SGX_VERIFIER_ADDRESS` - SgxVerifier contract address (or supply via `--env`)

### Optional

- `MRENCLAVE_ENABLE` - Set to `false` to untrust instead of trust (default: `true`)
- `MRSIGNER_ENABLE` - Set to `false` to untrust instead of trust (default: `true`)
- `ATTRIBUTE_POLICY_MRENCLAVE`, `ATTRIBUTE_POLICY_MASK`, `ATTRIBUTE_POLICY_EXPECTED` - Values used
  by `SET_ATTRIBUTE_POLICY=true` when configuring `SecureSgxVerifier` directly through Forge.

## Examples

### Example 1: Update Only MR_ENCLAVE

```bash
PRIVATE_KEY=$PRIVATE_KEY \
FORK_URL=https://ethereum-hoodi-rpc.publicnode.com \
SGX_VERIFIER_ADDRESS=0x... \
./script/layer1/verifiers/configure_sgx_verifier.sh \
  --mrenclave 0x...
```

### Example 2: Trust both MRENCLAVE and MRSIGNER on a known network

```bash
PRIVATE_KEY=$PRIVATE_KEY \
FORK_URL=https://ethereum-hoodi-rpc.publicnode.com \
./script/layer1/verifiers/configure_sgx_verifier.sh \
  --env tolba-pacaya \
  --mrenclave 0x... \
  --mrsigner 0x...
```

### Example 3: Register an SGX instance from a raw quote

```bash
PRIVATE_KEY=$PRIVATE_KEY \
FORK_URL=https://ethereum-hoodi-rpc.publicnode.com \
SGX_VERIFIER_ADDRESS=0x... \
./script/layer1/verifiers/configure_sgx_verifier.sh \
  --attribute-policy 0x<mrEnclave> 0xffffffffffffffff0000000000000000 0x05000000000000000000000000000000 \
  --mrenclave 0x<mrEnclave> \
  --mrsigner 0x<mrSigner> \
  --quote 0x<rawQuoteHex>
```

### Example 4: Using the Forge Script Directly

```bash
PRIVATE_KEY=$PRIVATE_KEY \
SGX_VERIFIER_ADDRESS=0x... \
SET_MRENCLAVE=true \
SET_MRSIGNER=true \
SET_ATTRIBUTE_POLICY=true \
MRENCLAVE=0x... \
MRSIGNER=0x... \
ATTRIBUTE_POLICY_MRENCLAVE=0x... \
ATTRIBUTE_POLICY_MASK=0xffffffffffffffff0000000000000000 \
ATTRIBUTE_POLICY_EXPECTED=0x05000000000000000000000000000000 \
forge script script/layer1/verifiers/ConfigureSgxVerifier.s.sol:ConfigureSgxVerifier \
  --fork-url https://ethereum-hoodi-rpc.publicnode.com \
  --broadcast \
  --legacy \
  -vvv
```

## Troubleshooting

### Gas Issues

If transactions fail with out-of-gas errors, increase the gas limit:

```bash
forge script ... --gas-limit 10000000
```

### Permission Errors

Ensure the private key corresponds to:

- The owner of `SgxVerifier` (for MRENCLAVE/MRSIGNER configuration and the local-report toggle)
- Any account with ETH (for instance registration via `registerInstance`)

## Contract Functions Called

The script interacts with these `SgxVerifier` functions:

- `setMrEnclave(bytes32 _mrEnclave, bool _trusted)` - Configure trusted MRENCLAVE
- `setMrSigner(bytes32 _mrSigner, bool _trusted)` - Configure trusted MRSIGNER
- `setEnclaveAttributePolicy(bytes32 _mrEnclave, bytes16 _mask, bytes16 _expected)` - Configure the
  `SecureSgxVerifier` ATTRIBUTES pin for a trusted MRENCLAVE
- `toggleLocalReportCheck()` - Toggle MRENCLAVE/MRSIGNER allowlist enforcement
- `registerInstance(bytes _rawQuote)` - Register an SGX instance from a raw Intel DCAP quote

> Note: TCB info and QE identity are no longer configured on-chain by Taiko; they are sourced from
> Automata's on-chain PCCS. SGX attestation is provided by the pinned
> `@automata-network/automata-dcap-attestation` dependency, called via `IDcapAttestation`.

## See Also

- [SgxVerifier.sol](../../../contracts/layer1/verifiers/SgxVerifier.sol)
- [SecureSgxVerifier.sol](../../../contracts/layer1/verifiers/SecureSgxVerifier.sol)
- [InsecureSgxVerifier.sol](../../../contracts/layer1/verifiers/InsecureSgxVerifier.sol)
- [IDcapAttestation.sol](../../../contracts/layer1/verifiers/IDcapAttestation.sol)
