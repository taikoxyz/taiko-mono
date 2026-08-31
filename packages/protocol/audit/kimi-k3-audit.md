# Solidity Security Audit — `packages/protocol/contracts`

**Auditor:** Kimi K3 (AI-assisted manual audit)
**Date:** 2026-07-21
**Repository:** taiko-mono
**Scope:** All non-test Solidity contracts under `packages/protocol/contracts/` (~113 files across `layer1/`, `layer2/`, `shared/`)

## Methodology

Five parallel deep-dive audit passes, each reading all in-scope files end-to-end plus inherited/base contracts:

1. **Bridge & signals** — `shared/bridge/*`, `shared/signal/*`, `shared/libs/LibTrieProof.sol`, `LibAddress.sol`
2. **Vaults** — `shared/vault/*` (ERC20/721/1155 vaults, bridged tokens, base vaults)
3. **L1 core** — `layer1/core/*` (Inbox, ProverWhitelist, all libs), `layer1/mainnet/MainnetInbox.sol`, `layer1/devnet/DevnetInbox.sol`
4. **Proof verifiers** — `layer1/verifiers/*` (SGX, Risc0, SP1, compose verifiers, devnet verifiers)
5. **Shared infra / L2 / governance** — `shared/common/*`, `shared/fork-router/*`, `shared/governance/*`, `shared/libs/*`, `layer2/*`, `layer1/mainnet/*`, `layer1/preconf/*`

Focus: exploitable bugs only (reentrancy, fund theft/loss, proof forgery, access-control bypass, replay, cross-chain message spoofing). Gas/style/improvement suggestions were explicitly excluded. The single reported finding was independently re-verified against the source.

## Executive Summary

**No Critical or High exploitable bugs found.** One Low severity griefing issue identified, plus two informational design notes.

The codebase shows the hallmarks of multiple prior professional audits: checks-effects-interactions is followed consistently, all fund-moving entry points are `nonReentrant`, message status machines revert on no-op transitions, proof commitments bind all security-relevant fields, and privilege boundaries (resolver, golden touch, bridge context) are enforced via immutables rather than spoofable storage.

## Findings

### L-01 (Low) — Permissionless `acceptOwnershipOf` enables governance-message griefing

**Files:**
- `packages/protocol/contracts/shared/governance/Controller.sol:42-44`
- `packages/protocol/contracts/layer2/governance/DelegateController.sol:49`

**Description:**

`acceptOwnershipOf(address)` is callable by anyone:

```solidity
/// @dev This function is callable by anyone to accept ownership without going through
/// the TaikoDAO.
function acceptOwnershipOf(address _contractToOwn) external nonReentrant {
    Ownable2StepUpgradeable(_contractToOwn).acceptOwnership();
}
```

**Attack scenario:**

The DAO sends an L1→L2 governance message whose action batch includes `acceptOwnership()` on some contract (as `msg.sender = DelegateController`) followed by actions that depend on that ownership. A griefer front-runs message processing by calling `acceptOwnershipOf(target)` directly. The ownership transfer completes, but the in-batch `acceptOwnership()` call now reverts (`OwnableUnauthorizedAccount` — no pending transfer remains), reverting the **entire** message.

Because `DelegateController.onMessageInvocation` enforces strictly increasing execution IDs:

```solidity
require(executionId == 0 || executionId == ++lastExecutionId, InvalidTxId());
```

the failed message must be re-sent with the same ID, so subsequent queued governance messages are head-of-line blocked until the DAO re-proposes a corrected batch from L1.

**Impact:** Griefing only — no fund theft or privilege escalation. Cost to attacker is one cheap call; cost to the DAO is a wasted cross-chain governance roundtrip. Not permanently exploitable: the grief only works once per ownership transfer, and the DAO can omit the redundant step on retry. Rated **Low**.

**Recommended fixes (either):**
- Make `acceptOwnershipOf` owner-only, or
- Swallow the "no pending owner" failure mode inside batched execution (e.g., try/catch around `acceptOwnership` when routed through `_executeActions`).

## Informational Notes (not exploitable)

### I-01 — Inbox permissionless-fallback config knobs never enforced

`_permissionlessProvingDelay` and `_permissionlessInclusionMultiplier` in `packages/protocol/contracts/layer1/core/impl/Inbox.sol` are validated and stored but never checked in `prove`/`propose`; permissionless fallback paths are disabled in code. If the prover whitelist fails, recovery requires owner intervention, not the automatic 5-day fallback the config comments imply. Liveness/design note only.

### I-02 — Intermediate transition metadata not verified on L1

`prove()` checks the parent block hash and the last proposal's ring-buffer hash, but per-proposal metadata (proposer, timestamps) for intermediate proposals in a batch is only bound via the proof commitment hash. Correct by design, but the L1 contract alone cannot detect wrong intermediate metadata; this rests entirely on verifier correctness.

## Coverage — Key Attack Classes Verified Clean

| Area | Attack classes ruled out |
|---|---|
| `shared/bridge/Bridge.sol` | Double-release via process/retry/recall (status machine with no-op reverts); relayer fee overcharge (capped at `message.fee`); insufficient-gas griefing (`invalid()` burns all gas post-call); reentrancy via `onMessageInvocation` (global `nonReentrant` + bridge/signal-service targets blocked); recall stealing (pays only `srcOwner`, requires proof of dest-chain failure) |
| `shared/signal/SignalService.sol` | Proof forgery (root must match stored checkpoint; account fixed to remote signal service; empty proofs only consult proof-gated cache); cache poisoning; use of `SecureMerkleTrie` neutralizes the Optimism #4845 off-by-one |
| `shared/vault/*` | Bridged-vs-canonical token misclassification (`ctoken.chainId` checks); mint/burn asymmetry (balance-delta accounting covers fee-on-transfer deposits); ERC777/callback reentrancy (all entry points `nonReentrant`); fake-bridge context spoofing (`onlyFromNamed(B_BRIDGE)`); OZ `BridgedERC721.burn` ownership gap (explicitly checked); migration double-supply (outbound tokens can't be minted) |
| `layer1/core/Inbox.sol` + libs | Wrong-parent transition attach (offset math proven safe); commitment hash malleability (`EfficientHashLib` layout verified word-for-word vs `abi.encode`); bond drain / slash evasion (minBond retention + withdrawal-delay interlock); forced-inclusion skip (shared 10-item cap between check and consumption); ring-buffer aliasing; codec decode divergence (over-reads yield zeros that fail downstream) |
| `layer1/verifiers/*` | SGX signature replay (commitment / chainId / verifier address / instance all in signed digest); stale or third-party quote registration (256-block freshness gate + one-shot `addressRegistered`); DEBUG enclaves (dedicated check + forbidden-attribute floor); MRENCLAVE re-trust after revocation (permanent revocation mappings); ZK image-ID swap (block image id committed in verified public input); compose threshold bypass (strict verifier-ID ordering; `ZkRequiredVerifier` structurally requires a ZK proof — TEE-only forgery path closed); `OpVerifier` dummy unreachable in production path (fail-closed zero address) |
| Shared infra / L2 / governance | Init re-run (`_disableInitializers` in constructor); resolver hijack (`__resolver` immutable); ForkRouter re-routing (immutable forks, pure selector routing); Anchor state injection (golden-touch gated, ancestors hash chained from real `blockhash`es); DelegateController source spoofing (bridge context verified against immutables); preconf rotation index desync (swap-delete verified); `delegateBySig` vote inflation (non-voting accounts read as 0) |

## Limitations

- This was a manual/AI-assisted code audit, not formal verification or fuzzing. No code was changed and no test suite was run.
- Remaining risk most likely lives in cross-component assumptions (e.g., off-chain proof generation matching `LibPublicInput` hashing, KZG blob handling in clients) and deployment configuration, rather than in-contract logic.
- Trusted roles (owner, authorized checkpoint syncer, golden touch address, prover whitelist admin) were treated as out of scope per their documented trust model.
