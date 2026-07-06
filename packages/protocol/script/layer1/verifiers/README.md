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

## See Also

- [enclave-attribute-policies.md](./enclave-attribute-policies.md) - Canonical `_mask` / `_expected`
  profiles for `SecureSgxVerifier.setEnclaveAttributePolicy`, with the rationale behind each value.
- [SgxVerifier.sol](../../../contracts/layer1/verifiers/SgxVerifier.sol)
- [SecureSgxVerifier.sol](../../../contracts/layer1/verifiers/SecureSgxVerifier.sol)
- [InsecureSgxVerifier.sol](../../../contracts/layer1/verifiers/InsecureSgxVerifier.sol)
- [IDcapAttestation.sol](../../../contracts/layer1/verifiers/IDcapAttestation.sol)

## Deployment Verification

After deploying the Taiko Hoodi proof stack, verify it end-to-end (read-only, no key) with
[VerifyHoodiDeployment.s.sol](./VerifyHoodiDeployment.s.sol) via its wrapper:

```bash
./script/layer1/verifiers/verify_hoodi_deployment.sh \
  --inbox 0xShastaInboxProxy \
  --attestation 0xAutomataDcapAttestationFee \
  --pccs 0xPccsRouter   # optional
```

It self-discovers the rest of the tree from the two roots
(`inbox → MainnetVerifier → {sgxReth, sgxGeth, risc0, sp1}` and
`attestation → V3QuoteVerifier → PCCS`) and asserts:

- **Entrypoint:** Taiko-owned, fee `bp == 0`, wired to a v3 quote verifier, and live (an empty
  quote is rejected via `verifyAndAttestOnChain`).
- **SGX verifiers (×2):** the strict `SecureSgxVerifier` (rejects out-of-date TCB), pointed at the
  shared entrypoint, on `TAIKO_HOODI`, Taiko-owned, `checkLocalEnclaveReport == true`, 24h validity
  delay.
- **Risc0 / SP1 tiers:** correct chain id and owner, with deployed sub-verifiers (SP1 remote gateway
  is the #21907 v6.1 verifier).
- **MainnetVerifier:** TDX/OP tiers disabled, four active tiers distinct and non-zero, and the inbox
  points at it.

The report tags each check `[PASS]` / `[FAIL]` / `[WARN]`. Advisories (`[WARN]`, e.g. the
MRENCLAVE/MRSIGNER allowlist not yet populated by `ConfigureSgxVerifier`) do not fail the run; any
`[FAIL]` makes the script exit non-zero.

> **Migration gate.** Until `DeployShastaHoodi` is rewired from the legacy codesize-170 Automata
> proxies to the new `AutomataDcapAttestationFee` (deployed via `DeployAutomataDcapAttestation` +
> `DCAP_ATTESTATION`), the SGX-verifier → entrypoint checks will fail by design — the script doubles
> as a readiness gate for that migration.
