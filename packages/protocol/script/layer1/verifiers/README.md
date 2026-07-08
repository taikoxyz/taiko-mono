# SGX Verifier Configuration

This directory contains scripts to configure the SGX Verifier after deployment.

## Files

- **[ConfigureSgxVerifier.s.sol](./ConfigureSgxVerifier.s.sol)** - Solidity script that configures the
  SGX verifier's trusted MRENCLAVE/MRSIGNER allowlist, registers instances, and toggles
  local-report enforcement.
- **[configure_sgx_verifier.sh](./configure_sgx_verifier.sh)** - Bash wrapper for easier usage.

> **What changed:** TCB info and QE identity are **no longer configured on-chain by Taiko**. They
> are sourced from Automata's on-chain PCCS through the DCAP attestation entrypoint. SGX
> attestation is provided by the pinned `@automata-network/automata-dcap-attestation` dependency,
> called via `IDcapAttestation`. As a result the old `--qeid` / `--tcb` flags and the
> `ATTESTATION_ADDRESS` / `PEM_CERTCHAIN_ADDRESS` variables have been removed. The
> MRENCLAVE/MRSIGNER allowlist now lives directly on `SgxVerifier` (previously on
> `AutomataDcapV3Attestation`).

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
MRENCLAVE=0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef \
forge script script/layer1/verifiers/ConfigureSgxVerifier.s.sol:ConfigureSgxVerifier \
  --fork-url https://ethereum-hoodi-rpc.publicnode.com \
  --broadcast \
  --legacy
```

## Configuration Options

### Set MR_ENCLAVE

Trust a new MR_ENCLAVE value:

```bash
--mrenclave 0xYOUR_MRENCLAVE_HASH
```

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

### Register SGX Instance

Register an instance from a raw Intel DCAP quote (the quote is verified on-chain via the DCAP
attestation entrypoint, which reads Intel collateral from on-chain PCCS):

```bash
--quote 0x03000200000000000a000f00939a7233f79c4ca9940a0db3957f060712ce6af1...
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
- `dev-shasta` / `dev-shasta-sgxreth`
- `dev-shasta-sgxgeth`

### Tolba Testnet

- `tolba-pacaya` / `tolba-pacaya-sgxreth`
- `tolba-pacaya-sgxgeth`
- `tolba-shasta` / `tolba-shasta-sgxreth`
- `tolba-shasta-sgxgeth`

### Transition

- `transition-shasta-sgxreth`
- `transition-shasta-sgxgeth`

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
  --quote 0x<rawQuoteHex>
```

### Example 4: Using the Forge Script Directly

```bash
PRIVATE_KEY=$PRIVATE_KEY \
SGX_VERIFIER_ADDRESS=0x... \
SET_MRENCLAVE=true \
SET_MRSIGNER=true \
MRENCLAVE=0x... \
MRSIGNER=0x... \
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
- `toggleLocalReportCheck()` - Toggle MRENCLAVE/MRSIGNER allowlist enforcement
- `registerInstance(bytes _rawQuote)` - Register an SGX instance from a raw Intel DCAP quote

> Note: TCB info and QE identity are no longer configured on-chain by Taiko; they are sourced from
> Automata's on-chain PCCS. SGX attestation is provided by the pinned
> `@automata-network/automata-dcap-attestation` dependency, called via `IDcapAttestation`.

## Deployment

Deploy the Taiko proof-verification stack for **Ethereum Hoodi or Mainnet** — a fresh Taiko-owned
`AutomataDcapAttestationFee` entrypoint plus the proof verifiers (2 SGX + Risc0 + SP1 +
`MainnetVerifier`) wired to it — with [deploy_proof_stack.sh](./deploy_proof_stack.sh):

```bash
PRIVATE_KEY=0x... CONTRACT_OWNER=0x... \
./script/layer1/verifiers/deploy_proof_stack.sh --network hoodi   # or: --network mainnet
```

It broadcasts two transactions: `DeployAutomataDcapAttestation` (under `FOUNDRY_PROFILE=layer1o`) to
deploy the entrypoint, then the network's proof-stack script — `DeployHoodiProofStack` /
`DeployMainnetProofStack` (under `FOUNDRY_PROFILE=layer1`) — with `DCAP_ATTESTATION` set to that
entrypoint, so both `SecureSgxVerifier`s are constructed pointing at it. `--network` selects the
`PCCS_ROUTER` default and RPC:

| `--network` | `PCCS_ROUTER` default (Automata on-chain PCCS)     | validity delay |
| ----------- | -------------------------------------------------- | -------------- |
| `hoodi`     | `0x8e480c9879F1Db31dC209e5f4d239d5126e6e07B`       | 1 hour         |
| `mainnet`   | `0xE2Cd5aA44a0896D683684B8EA15eB54B269fC933`       | 24 hours       |

> **Mainnet `PCCS_ROUTER`:** `0xE2Cd5aA4…` is Automata's official Ethereum Mainnet PCCSRouter, but it
> comes from Automata's latest deployment registry (the pinned v1.1.0 has no mainnet entry). Confirm
> its Automata version is interface-compatible with Taiko's pinned `V3QuoteVerifier` before a
> production run. Export `PCCS_ROUTER` to override.

The SGX registrar (the only address allowed to `registerInstance`) is configurable via the
`SGX_REGISTRAR` env, defaulting to the deployer — set it to a durable multisig, or to the zero
address for permissionless registration.

On Mainnet the underlying RiscZero Groth16 and SP1 Plonk verifiers are **redeployed fresh** by
default; on Hoodi they default to the known verifiers. Override either with the `R0_GROTH16` /
`SP1_PLONK` env to wrap an existing verifier instead (e.g. the live mainnet `0x8EaB2D97…` /
`0x3B604117…`).

> **Redeployed R0/SP1 versions:** a fresh mainnet RiscZero verifier is pinned to the repo's
> `@risc0/contracts` `ControlID`, and SP1 to `@sp1-contracts/v6.1.0` — confirm these match mainnet's
> raiko prover versions before a production run (or set `R0_GROTH16` / `SP1_PLONK` to reuse the live
> ones).

Add `--verify` (with `ETHERSCAN_API_KEY` set) to verify the deployed contracts on Etherscan; both
broadcasts forward it. forge auto-resolves the Etherscan v2 endpoint — set `VERIFIER_URL` to
override if needed.

> The SGX verifiers point at the new Taiko-owned entrypoint (the #21827 shared-entrypoint model).
> `SgxVerifier`'s `automataDcapAttestation` is immutable, so this is a fresh deploy of the SGX
> verifiers, not an in-place upgrade.

This deploys **only the proof-verification contracts** — no inbox / signal service / whitelists. For
the full Shasta system use `DeployShastaHoodi` / `DeployShastaMainnet` (which also consume
`DCAP_ATTESTATION`). To put the proof stack into use, point a Shasta inbox's `proofVerifier` at the
deployed `MainnetVerifier`.

The operational flow is **deploy → verify → configure**:

1. `deploy_proof_stack.sh --network <net>` — deploy the entrypoint + proof verifiers (above).
2. `verify_hoodi_deployment.sh` — assert the wiring, once an inbox points at the `MainnetVerifier`
   (the command the deploy script prints). Ships in the companion Hoodi deployment verifier,
   [PR #21917](https://github.com/taikoxyz/taiko-mono/pull/21917).
3. [configure_sgx_verifier.sh](./configure_sgx_verifier.sh) — trust the MRENCLAVE/MRSIGNER allowlist
   and register SGX instances (a separate operational step).

## See Also

- [enclave-attribute-policies.md](./enclave-attribute-policies.md) - Canonical `_mask` / `_expected`
  profiles for `SecureSgxVerifier.setEnclaveAttributePolicy`, with the rationale behind each value.
- [SgxVerifier.sol](../../../contracts/layer1/verifiers/SgxVerifier.sol)
- [SecureSgxVerifier.sol](../../../contracts/layer1/verifiers/SecureSgxVerifier.sol)
- [InsecureSgxVerifier.sol](../../../contracts/layer1/verifiers/InsecureSgxVerifier.sol)
- [IDcapAttestation.sol](../../../contracts/layer1/verifiers/IDcapAttestation.sol)
