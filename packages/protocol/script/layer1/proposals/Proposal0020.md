# PROPOSAL-0020: Move the SGX Legs onto a PCCS-Backed, Taiko-Owned DCAP Entrypoint

## Executive Summary

This proposal retires the two SGX verifiers that attest through Taiko's legacy stripped
`AutomataDcapV3Attestation` proxies and replaces them with two fresh `SecureSgxVerifier`s that
attest through a **Taiko-owned upstream `AutomataDcapAttestationFee` entrypoint**, backed by
Automata's on-chain PCCS. The RISC0 and SP1 verifiers are **reused unchanged**, and the Inbox is
re-pointed at a new `ZkRequiredVerifier` that composes the new SGX verifiers with them.

Nothing about the proof _policy_ changes: the new verifier enforces the same rule Proposal0019
established — every accepted combination contains at least one ZK proof, and SGX-GETH + SGX-RETH
alone can never finalize.

**Prerequisite: Proposal0019 must execute first.** This proposal assumes 0019 has already rotated
the RISC0/SP1 trusted image IDs and program keys to raiko2 v0.6.0 on the reused ZK verifiers, run
`init3`, and upgraded the Inbox. Executing 0020 before 0019 would leave the ZK legs trusting the
old raiko2 v0.5.1 IDs and would skip `init3`.

## Why

The live SGX verifiers (`0x41e79EB4…`, `0x9D3C595B…`, deployed by Proposal0017) verify quotes
through Taiko's forked, stripped `AutomataDcapV3Attestation` proxies (`0x0ffa4A62…`, `0x8d7C9549…`).
Those proxies carry no TCB-expiry check and are maintained by Taiko rather than tracking Intel
collateral upstream.

The upstream Automata DCAP entrypoint resolves quotes against Automata's on-chain PCCS router
(`0xE2Cd5aA4…`), which reads Intel's real TCB/QE-identity collateral. That router was unprovisioned
on Ethereum mainnet until **2026-07-10**, when Automata deployed a V2 async-upsert DAO stack behind
it and upserted the collateral; `getStandardTcbEvaluationDataNumber(SGX)` now returns `19` and the
full quote-verification read path resolves. That unblocked this migration.

## What Changes

### 1. A Taiko-owned DCAP entrypoint (already deployed, not an action here)

`AutomataDcapAttestationFee` at `0x49216ad7…`, owned by the DAO controller, fee set to zero
(`getBp() == 0` — required because `registerInstance` is non-payable and forwards zero value), with
its V3 quote verifier `0x560bd80f…` bound to PCCS router `0xE2Cd5aA4…`.

### 2. Two new SGX verifiers (trust established by actions 0–7)

`SecureSgxVerifier` `0xA8A78d00…` (geth) and `0x4bFaB16B…` (reth), both attesting through the
entrypoint above, both owned by the DAO controller, both with registrar
`0x9CBeE534…` (`MULTISIG_ADMIN_TAIKO_ETH`) — the same registrar that operates the current verifiers.

Their allowlists start **empty**, so this proposal must establish the full trust set: the signer,
the raiko2 v0.6.0 measurements, and a per-MRENCLAVE ATTRIBUTES pin. Note the trust surface moved:
on the new stack `setMrSigner` / `setMrEnclave` / `setEnclaveAttributePolicy` are `onlyOwner` **on
the verifier itself**, whereas Proposal0019 rotates measurements on the legacy _attester proxies_.

### 3. A new ZkRequiredVerifier reusing the ZK legs (already deployed)

`ZkRequiredVerifier` `0x06763349…` composes the two new SGX verifiers with the **unchanged**
`RISC0_RETH_VERIFIER 0x059dAF31…` and `SP1_RETH_VERIFIER 0x73A0Db39…`. Because `ComposeVerifier`
holds its sub-verifiers as immutables, changing the SGX legs requires a new instance — the existing
`0x7284aaC0…` cannot be re-pointed. Reusing the ZK verifiers means the raiko2 v0.6.0 image IDs and
program keys that Proposal0019 trusts carry over with no further action.

### 4. A new Inbox implementation (action 8)

`MainnetInbox` `0x05C9620F…`. `Inbox._proofVerifier` is immutable, so re-pointing the Inbox requires
a new implementation. It is identical to Proposal0019's implementation (`0x5253D4C9…`) in **every**
Config field except `proofVerifier`; this was verified against both deployments on-chain and is
asserted at deploy time by `DeploySgxSwapProofStack`.

## Action Order

| #   | Target                 | Call                                                                     |
| --- | ---------------------- | ------------------------------------------------------------------------ |
| 0   | `0xA8A78d00…` SGX-geth | `setMrSigner(MR_SIGNER, true)`                                           |
| 1   | `0xA8A78d00…` SGX-geth | `setMrEnclave(SGXGETH_MR_ENCLAVE, true)`                                 |
| 2   | `0xA8A78d00…` SGX-geth | `setEnclaveAttributePolicy(SGXGETH_MR_ENCLAVE, mask, expected)`          |
| 3   | `0x4bFaB16B…` SGX-reth | `setMrSigner(MR_SIGNER, true)`                                           |
| 4   | `0x4bFaB16B…` SGX-reth | `setMrEnclave(SGXRETH_NON_EDMM_MR_ENCLAVE, true)`                        |
| 5   | `0x4bFaB16B…` SGX-reth | `setMrEnclave(SGXRETH_EDMM_MR_ENCLAVE, true)`                            |
| 6   | `0x4bFaB16B…` SGX-reth | `setEnclaveAttributePolicy(SGXRETH_NON_EDMM_MR_ENCLAVE, mask, expected)` |
| 7   | `0x4bFaB16B…` SGX-reth | `setEnclaveAttributePolicy(SGXRETH_EDMM_MR_ENCLAVE, mask, expected)`     |
| 8   | `0x6f21C543…` Inbox    | `upgradeTo(0x05C9620F…)`                                                 |

## Deployed Addresses

Deployed 2026-07-16 at mainnet block 25543404 by `script/layer1/verifiers/deploy_sgx_swap.sh`.

| Contract                                  | Address                                      |
| ----------------------------------------- | -------------------------------------------- |
| `AutomataDcapAttestationFee` (entrypoint) | `0x49216ad7d4DbafbE2F14525a863E621e2041ECB6` |
| `V3QuoteVerifier`                         | `0x560bd80fa0C0109954f0a8EFacb06779df397072` |
| `SecureSgxVerifier` (geth)                | `0xA8A78d008b5745dd8487A8E912cD3d5A8618b496` |
| `SecureSgxVerifier` (reth)                | `0x4bFaB16Bd9DA86bF6498a640B4d076eF4Ef5dfaA` |
| `ZkRequiredVerifier`                      | `0x0676334976D6578229829fAf92fb72Bd9378995b` |
| `MainnetInbox` (new impl)                 | `0x05C9620F9cc7154Ab1a47029014960e673586138` |

Reused unchanged: `RISC0_RETH_VERIFIER 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b`,
`SP1_RETH_VERIFIER 0x73A0Db393ef87ce781ac7957bE10D6628432100F`.

Superseded (no action targets them; orphaned once the Inbox points at the new verifier):
`ZkRequiredVerifier 0x7284aaC0…`, `SGXGETH_VERIFIER 0x41e79EB4…`, `SGXRETH_VERIFIER 0x9D3C595B…`.

> **Note on orphaned contracts.** An earlier, partially-failed deployment attempt left unreferenced
> contracts on mainnet: entrypoint `0x55862381…`, SGX-geth `0xe78129f8…`, P256 `0x03Fad3a6…`, and
> V3QuoteVerifier `0xFf269552…`. Three of that run's four transactions were dropped by the RPC, so
> the stack was never completed and nothing references it. **It is not used by this proposal** and
> can be ignored; the live addresses are the table above.

## Open Item — the ATTRIBUTES pin

`ENCLAVE_ATTRIBUTE_MASK` / `ENCLAVE_ATTRIBUTE_EXPECTED` in `Proposal0020.s.sol` are **not yet set**.
They must come from the ATTRIBUTES field of a real raiko2 v0.6.0 SGX quote — **bytes `[96:112]` of
the raw quote** (`HEADER_LENGTH` 48 + report-body offset 48). The mask must cover
`0x32000000000000000000000000000000` (DEBUG | PROVISION_KEY | EINITTOKEN_KEY) and `expected` must
clear those bits.

While they are zero, `buildL1Actions` reverts with `AttributePolicyNotSet()`, so this proposal
cannot produce executable action data — the pin cannot ship unset. Setting a pin later bumps the
policy version and **revokes every instance registered under the previous pin**, so it must be
correct on first execution.

## Post-Execution Steps (operational, not DAO actions)

1. The registrar `0x9CBeE534…` calls `registerInstance(rawQuote)` on **both** new SGX verifiers with
   fresh raiko2 v0.6.0 quotes. This cannot happen before execution: registration fail-closes with
   `SGX_ATTRIBUTE_POLICY_NOT_SET` until the DAO has set the pin.
2. Until instances are registered, **no SGX leg can verify**. Finalization continues on the
   `RISC0 + SP1` combination, which `ZkRequiredVerifier` accepts. Provers must be able to produce
   that pair for the duration of the window.

## Verification

```bash
# Print the action data (reverts until the ATTRIBUTES pin is set)
P=0020 pnpm proposal

# Fork-simulate the L1 actions
P=0020 pnpm proposal:dryrun:l1
```

Independent cross-checks against mainnet:

```bash
# The new verifier composes the new SGX legs with the REUSED ZK legs
cast call 0x0676334976D6578229829fAf92fb72Bd9378995b 'sgxGethVerifier()(address)'
cast call 0x0676334976D6578229829fAf92fb72Bd9378995b 'sgxRethVerifier()(address)'
cast call 0x0676334976D6578229829fAf92fb72Bd9378995b 'risc0RethVerifier()(address)'
cast call 0x0676334976D6578229829fAf92fb72Bd9378995b 'sp1RethVerifier()(address)'

# Both SGX verifiers attest through the Taiko-owned entrypoint, DAO-owned, feeless
cast call 0xA8A78d008b5745dd8487A8E912cD3d5A8618b496 'automataDcapAttestation()(address)'
cast call 0x4bFaB16Bd9DA86bF6498a640B4d076eF4Ef5dfaA 'automataDcapAttestation()(address)'
cast call 0x49216ad7d4DbafbE2F14525a863E621e2041ECB6 'owner()(address)'   # DAO controller
cast call 0x49216ad7d4DbafbE2F14525a863E621e2041ECB6 'getBp()(uint16)'    # 0

# The entrypoint's V3 verifier reads Automata's provisioned PCCS router
cast call 0x560bd80fa0C0109954f0a8EFacb06779df397072 'pccsRouter()(address)'
cast call 0xE2Cd5aA44a0896D683684B8EA15eB54B269fC933 'getStandardTcbEvaluationDataNumber(uint8)(uint32)' 0

# The new Inbox impl differs from Proposal0019's ONLY in proofVerifier
cast call 0x05C9620F9cc7154Ab1a47029014960e673586138 'getConfig()((address,address,address,address,address,uint64,uint64,uint48,uint48,uint48,uint48,uint48,uint8,uint16,uint64,uint64,uint8))'
cast call 0x5253D4C91e80b880DdB54B78E74082Abe066F6b9 'getConfig()((address,address,address,address,address,uint64,uint64,uint48,uint48,uint48,uint48,uint48,uint8,uint16,uint64,uint64,uint8))'
```

## Security Contacts

security@taiko.xyz
