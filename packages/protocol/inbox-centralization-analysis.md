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

This means the multisig (and any ejecters it appoints) can **selectively censor proposers without a DAO vote**. Operator removal is asymmetric: adding takes 2 epochs, removal is instant. Note: the contract requires `operatorCount > 1` (`PreconfWhitelist.sol:237`), so the last active operator cannot be removed -- this prevents a full halt but still allows selective censorship.

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

Note: the timelock/governor logic lives outside `packages/protocol` and is not verifiable from protocol code alone.

---

## 4. DCAP Attestation Trust Material Is DAO-Gated

**Severity:** Medium (structural gap)
**File:** `contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol`, `contracts/layer1/verifiers/SgxVerifier.sol`

`MainnetVerifier.sol` requires exactly 2 SGX proofs (SGX-GETH + SGX-RETH, or either SGX + a ZK verifier). ZK verifiers (Risc0/SP1) are **not required for liveness** -- two SGX proofs are sufficient. So the DAO-only trust lists in Risc0Verifier and SP1Verifier do not pose a liveness risk.

However, the "permissionless" SGX instance registration path (`SgxVerifier.registerInstance()`) depends on DCAP trust material maintained by the DAO in `AutomataDcapV3Attestation.sol`:

- `setMrSigner()` / `setMrEnclave()` -- control which enclave measurements are trusted (`onlyOwner`)
- `configureTcbInfoJson()` -- configures TCB info for attestation validation (`onlyOwner`)
- `configureQeIdentityJson()` -- configures quoting enclave identity (`onlyOwner`)
- `addRevokedCertSerialNum()` / `removeRevokedCertSerialNum()` -- manage certificate revocation (`onlyOwner`)

So while anyone can call `registerInstance()`, the attestation will only pass if the DAO has configured the correct trust material. If the DAO fails to maintain this (e.g., after Intel TCB updates), permissionless SGX registration stops working, and new instances can only be added via the DAO-only `addInstances()` path.

**SGX instance expiry:** Each SGX instance is valid for 365 days (`SgxVerifier.sol:28`), creating a recurring dependency on either permissionless re-attestation (which requires maintained DCAP trust material) or DAO action via `addInstances()`.

---

## Summary

| #   | Vector                                       | Severity             | Bypasses DAO?    | Escape Hatch                    | Resolution                                     |
| --- | -------------------------------------------- | -------------------- | ---------------- | ------------------------------- | ---------------------------------------------- |
| 1   | Proposer whitelist (multisig ejectorManager) | **High** (temporary) | **Yes**          | Permissionless proposing ~25.6h | Planned: launch permissionless preconfirmation |
| 2   | Prover whitelist (multisig proverManager)    | **High**             | **Yes**          | Permissionless proving 5 days   | Planned: build a prover market                 |
| 3   | Emergency proposals bypass timelock          | **Low**              | N/A (by design)  | Regular proposals use timelock  | By design, no action                           |
| 4   | DCAP trust material is DAO-gated             | **Medium**           | N/A (structural) | DAO can add instances directly  | Yue Wang to confirm and fix                    |
