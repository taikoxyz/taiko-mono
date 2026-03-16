# Remaining Points of Centralization in Protocol Inbox

Analysis of the Shasta Inbox contract (`packages/protocol/contracts/layer1/core/impl/Inbox.sol`) and its dependency graph. Actions controlled by the TaikoDAO (token-weighted governance) are considered decentralized by design and are not flagged here. This report focuses on vectors that bypass DAO governance or represent structural risks.

---

## Governance Structure

```
TKO token holders (vote)
    → TaikoDAO (governor)
        → MainnetDAOController (execution proxy, onlyOwner)
            → All L1 protocol contracts
            → Bridge → DelegateController → All L2 contracts

Multisig (MULTISIG_ADMIN_TAIKO_ETH, 0x9CBeE534...)
    → ejectorManager role (PreconfWhitelist)
    → proverManager role (ProverWhitelist)
```

The multisig holds operational roles that act **independently of the DAO** -- no token vote required.

---

## 1. Multisig Controls Proposer Whitelist

**Severity:** High (temporary -- permissionless preconf planned)
**File:** `contracts/layer1/preconf/impl/PreconfWhitelist.sol`

The multisig (`MULTISIG_ADMIN_TAIKO_ETH`) is the immutable `ejectorManager`. It can:

- Appoint ejecters via `setEjecter()` -- no DAO vote needed
- Ejecters can instantly remove operators via `removeOperator()` / `removeOperatorByAddress()` -- no delay
- Ejecters can add operators via `addOperator()` (2-epoch activation delay)

This means the multisig (and any ejecters it appoints) can **censor proposers without a DAO vote**. Operator removal is asymmetric: adding takes 2 epochs, removal is instant.

**Escape hatch:** Permissionless proposing activates after ~25.6 hours if forced inclusions go unprocessed.

**Planned mitigation:** Permissionless preconfirmation is planned, which would remove the dependency on the whitelisted operator set. This has external dependencies and is not yet implemented. Once live, the `_proposerChecker` can be swapped (via new Inbox deployment) to a permissionless implementation, eliminating this vector.

---

## 2. Multisig Controls Prover Whitelist

**Severity:** High
**File:** `contracts/layer1/core/impl/ProverWhitelist.sol`

The multisig (`MULTISIG_ADMIN_TAIKO_ETH`) is the immutable `proverManager`. It can:

- Add/remove provers via `whitelistProver()` -- no DAO vote needed

While the whitelist is active (`proverCount > 0`), only whitelisted provers can submit proofs immediately. Non-whitelisted provers must wait 5 days per proposal.

**Escape hatch:** Permissionless proving after 5 days. Removing all provers (`proverCount == 0`) disengages the whitelist entirely.

---

## 3. Emergency DAO Proposals Have No Timelock

**Severity:** Low (by design for critical bug fixes)
**File:** `contracts/layer1/mainnet/MainnetDAOController.sol`

Regular DAO proposals go through a timelock, giving users an exit window before changes take effect. However, emergency proposals bypass the timelock and execute immediately via `MainnetDAOController.execute()`. This is intentional -- it allows the DAO to respond quickly to critical bugs.

The trade-off is that an emergency proposal can perform any owner action (including contract upgrades) with no delay, which could be abused if the emergency proposal process is compromised.

---

## 4. No Permissionless Fallback for Proof Verification

**Severity:** Medium (structural gap)
**File:** `contracts/layer1/verifiers/SgxVerifier.sol`, `Risc0Verifier.sol`, `SP1Verifier.sol`

The protocol has permissionless fallbacks for proposing (~25.6h) and proving (5 days). However, there is **no equivalent fallback for proof verification**. If all verifier programs/instances are untrusted (whether by DAO action, DAO inaction on expiring SGX instances, or a bug), proofs cannot be verified and the chain halts.

**SGX instance expiry:** Each SGX instance is valid for 365 days from registration (`SgxVerifier.sol:28`, enforced at line 186 via `block.timestamp <= validSince + INSTANCE_EXPIRY`). This is a security measure to protect against side-channel attacks by forcing periodic key rotation. After expiry, the instance must be re-attested and registered with a new address.

There are two paths to register SGX instances:

- **Owner-only:** `addInstances()` -- DAO adds trusted instances directly (instant validity)
- **Permissionless:** `registerInstance()` -- anyone can register an instance by submitting a valid DCAP remote attestation quote, verified on-chain via `AutomataDcapAttestation` (line 113-124)

The permissionless `registerInstance()` path partially mitigates the governance dependency for SGX -- anyone running a valid SGX enclave can self-register without DAO action. However, Risc0Verifier and SP1Verifier have **no equivalent permissionless registration** -- their trusted program lists (`setImageIdTrusted`, `setProgramTrusted`) are strictly `onlyOwner`.

---

## 5. Operator Blacklist Overseers

**Severity:** Low
**File:** `contracts/layer1/preconf/impl/LookaheadStore.sol`

The DAO appoints overseers who can blacklist operators from proposing. While this is DAO-controlled, the overseers themselves operate without per-action governance oversight once appointed. An overseer could blacklist operators unilaterally.

**Escape hatch:** Permissionless proposing fallback (~25.6h) still applies.

---

## Summary

| #   | Vector                                       | Severity             | Bypasses DAO?         | Escape Hatch                    | Resolution                                     |
| --- | -------------------------------------------- | -------------------- | --------------------- | ------------------------------- | ---------------------------------------------- |
| 1   | Proposer whitelist (multisig ejectorManager) | **High** (temporary) | **Yes**               | Permissionless proposing ~25.6h | Planned: launch permissionless preconfirmation |
| 2   | Prover whitelist (multisig proverManager)    | **High**             | **Yes**               | Permissionless proving 5 days   | Planned: build a prover market                 |
| 3   | Emergency proposals bypass timelock          | **Low**              | N/A (by design)       | Regular proposals use timelock  | By design, no action                           |
| 4   | No permissionless fallback for verification  | **Medium**           | N/A (structural)      | None                            | Yue Wang to confirm and fix                    |
| 5   | Overseer blacklisting                        | **Low**              | Partially (delegated) | Permissionless proposing ~25.6h | By design, no action                           |
