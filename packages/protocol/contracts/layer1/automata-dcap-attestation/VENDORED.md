# Vendored: Automata DCAP Attestation (v1.1.0)

This directory and its sibling `../automata-on-chain-pccs/` are a **vendored copy of the
upstream, audited Automata DCAP attestation stack**, placed side-by-side with the legacy
`../automata-attestation/` implementation. The legacy tree is left untouched.

## Source

| Vendored path | Upstream repo | Ref | Upstream path |
|---|---|---|---|
| `automata-dcap-attestation/` | `automata-network/automata-dcap-attestation` | tag **v1.1.0** (commit `9c96312`) | `evm/contracts/` |
| `automata-on-chain-pccs/` | `automata-network/automata-on-chain-pccs` | submodule pinned by v1.1.0 | `src/` (library subset only — see below) |

Both upstream repos are MIT licensed (preserved in each file's SPDX header).

## Audit status

Trail of Bits audited the **v1.0** codebase (engagement began 2025-01-06, ~8 engineer-weeks),
covering the DCAP Attestation EVM contracts and On-Chain PCCS. `v1.1.0` is the latest **stable**
release and incorporates the audit's remediation (a PCCS Router timestamp-validity issue). The
`v1.1.1-alpha-*` tags are pre-release and were intentionally **excluded**.

> Caveat: releases `v1.0.1`–`v1.1.0` also include post-audit feature work (TCB-evaluation-number
> support, V5 quotes). If strict "exact audited commit" parity is required, pin to `v1.0.0`
> instead.

## Adaptations (why this is not a byte-for-byte copy)

1. **On-chain PCCS — use Automata's deployed instance.** Per the migration decision, Taiko points
   the verifier at Automata's already-deployed PCCS (router + collateral DAOs) at runtime, so only
   the **pure helper/type libraries** from `automata-on-chain-pccs` are vendored:
   `Common.sol`, `helpers/{EnclaveIdentityHelper,FmspcTcbHelper,PCKHelper,X509Helper,X509CRLHelper}.sol`,
   `utils/{Asn1Decode,BytesUtils,DateTimeUtils,P256Verifier}.sol`.
   The stateful DAOs and `PCCSRouter.sol` are **not** vendored: they import OpenZeppelin **5.x**
   (`@openzeppelin/contracts/utils/Pausable.sol`) and `solady/auth/OwnableRoles.sol`, which are
   incompatible with taiko-mono's OpenZeppelin **4.9.6**.
   - `interfaces/IPCCSRouter.sol`: the `CA` enum import was repointed from `bases/PcsDao.sol` to
     `Common.sol` (identical definition) to avoid pulling in a DAO.
2. **ZK-coprocessor interfaces.** `AttestationEntrypointBase.sol` imports `IRiscZeroVerifier` and
   `ISP1Verifier`. These were repointed to locally-vendored, byte-compatible minimal interfaces
   under `zk/risc0/` and `zk/sp1/`, to avoid remapping collisions with taiko-mono's existing
   `@risc0/contracts/` and `@sp1-contracts/` remappings. The ZK route is unused (Taiko performs
   on-chain SGX attestation only).

## Remappings added (`packages/protocol/foundry.toml`)

```
@automata-network/on-chain-pccs/=contracts/layer1/automata-on-chain-pccs/
solady/auth/=node_modules/solady/src/auth/
```

All other imports (`solady/utils/*`, `openzeppelin/contracts/*`) resolve via existing remappings.

## Consumer migration

`contracts/layer1/verifiers/SgxVerifier.sol` was migrated to the new entrypoint:

- `registerInstance` now takes a **raw quote** (`bytes calldata`) and calls
  `IDcapAttestation.verifyAndAttestOnChain`, instead of the pre-parsed
  `V3Struct.ParsedV3QuoteStruct` + `verifyParsedQuote`.
- The trusted **MRENCLAVE/MRSIGNER allowlist** (`checkLocalEnclaveReport`, `trustedUserMrEnclave`,
  `trustedUserMrSigner`, `setMrEnclave`, `setMrSigner`, `toggleLocalReportCheck`) and the
  **TCB-status acceptance policy** were relocated here from `AutomataDcapV3Attestation`, because the
  generic Automata entrypoint verifies quote authenticity + TCB status but does not enforce
  enclave-identity policy.

## Security fix included

- **The SGX DEBUG-attribute gap is FIXED.** `registerInstance` now rejects any quote whose enclave
  report has the DEBUG attribute bit set (revert `SGX_DEBUG_ENCLAVE`). DEBUG is bit 1 of the
  little-endian SGX ATTRIBUTES flags, read from the authenticated enclave-report body at raw-quote
  offset `HEADER_LENGTH + 48`. The check is unconditional (debug enclaves are never trustworthy
  on-chain, since their memory — including the in-enclave signing key — is host-accessible).

## NOT done (follow-ups)

- A unit test asserting the DEBUG-enclave revert should be added with the test migration below
  (the existing SgxVerifier test suite must be migrated to the raw-quote flow first).
- **Deployment scripts** (`DeployProtocolOnL1`, `DeployShastaContracts`, `ConfigureSgxVerifier`)
  still deploy/wire the legacy attestation contract; they must be updated to deploy
  `AutomataDcapAttestationFee` + a `V3QuoteVerifier` pointed at Automata's deployed PCCS router
  (per-chain addresses), then `setQuoteVerifier`.
- **Tests** (`test/layer1/automata-attestation/*`, `test/layer1/verifiers/SgxVerifier.t.sol`) use the
  old parsed-quote API and need migration to the raw-quote flow.
- If Automata's deployed entrypoint charges a verification **fee**, `registerInstance` must forward
  `msg.value`.
