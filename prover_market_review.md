# ProverMarket Review (Updated 2026-03-17)

## Scope

Review of the ProverMarket addition to Taiko's Inbox, with the goal of making proving
permissionless without introducing new privileged choke points.

Files reviewed:
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol` (540 lines)
- `packages/protocol/contracts/layer1/core/impl/Inbox.sol` (751 lines)
- `packages/protocol/contracts/layer1/core/iface/IInbox.sol` (full interface + structs)
- `packages/protocol/contracts/layer1/core/iface/IProverMarket.sol`
- `packages/protocol/contracts/layer1/core/libs/LibBonds.sol`
- `packages/protocol/contracts/layer1/core/libs/LibInboxSetup.sol`
- `packages/protocol/contracts/layer1/core/libs/LibForcedInclusion.sol`
- `packages/protocol/contracts/layer1/core/libs/LibCodec.sol`
- `packages/protocol/contracts/layer1/core/libs/LibBlobs.sol`
- `packages/protocol/contracts/layer1/core/libs/LibHashOptimized.sol`
- `packages/protocol/contracts/shared/common/EssentialContract.sol`
- `packages/protocol/contracts/shared/libs/LibAddress.sol`
- `packages/protocol/contracts/layer1/verifiers/SgxVerifier.sol`
- `packages/protocol/contracts/layer1/verifiers/compose/ComposeVerifier.sol`
- `packages/protocol/contracts/layer1/verifiers/IProofVerifier.sol`
- `packages/protocol/prover-market-design.md`
- `packages/protocol/test/layer1/core/inbox/ProverMarket.t.sol` (36 tests)
- `packages/protocol/test/layer1/core/inbox/InboxProve.t.sol` (22 tests)

Assumptions:
- All pre-ProverMarket logic is already live as the Shasta fork in production.
- Every actor except the DAO (owner of upgradeable contracts) may be malicious.
- A finding is serious if it lets an actor extract value, delay proofs, or halt the chain
  without DAO intervention.

---

## Status of Previous Findings

### Finding 1 (was Critical) -- RESOLVED

**Original**: The market removed Shasta's liveness-enforcement path without a replacement
slashing mechanism.

**Current status**: `_maybeSlashLateProof()` (ProverMarket.sol:461-497) now implements
slashing when `proposalAge >= _permissionlessProvingDelay`. The slashed bond goes to
`rescueRewardPool` (if operator self-proves late) or to the rescue prover's `bondBalances`
(if a third party rescues). The active epoch is cleared on slash (line 491-494). This
matches the design doc's intent.

### Finding 3 (was High) -- RESOLVED

**Original**: `onProposalAccepted()` sent ETH to `feeRecipient` during the proposal path,
creating both revert-based DoS and reentrancy.

**Current status**: Fee accounting is now fully internal balance updates
(ProverMarket.sol:338-344). No external calls in `onProposalAccepted()`. The revert DoS
and reentrancy surfaces are eliminated.

---

## Active Findings

### Finding 2 (Critical): Zero-fee bid creates an irreplaceable epoch

**Severity**: Critical

The reverse auction requires strictly lower fee to outbid:

```solidity
// ProverMarket.sol:223-225
if (state.activeEpochId != 0) {
    require(_feeInGwei < epochs[state.activeEpochId].feeInGwei, BidFeeTooHigh());
}
```

There is no minimum fee, so `feeInGwei = 0` is valid. Once active at 0, no one can
undercut because `uint64` cannot go below 0. The only escapes are:

1. The operator voluntarily calls `exit()`, or
2. The DAO calls `forcePermissionlessMode(true)`.

The `exit()` path now correctly stops new assignments (when exiting with no pending
replacement, `_retireActiveEpoch` sets `activeEpochId = 0` so proposals become
permissionless). However, the operator is not obligated to exit. They can hold the
exclusive position indefinitely at zero fee.

**Attack path**:
1. Attacker bids `feeInGwei = 0`, deposits minimum bond.
2. Becomes active. All proposals are exclusively assigned to them.
3. Attacker proves just fast enough to avoid slashing but extracts no fee (they bid 0).
4. No competitive prover can enter the market without the attacker's cooperation.
5. If attacker stops proving, every proposal must wait `permissionlessProvingDelay` before
   a rescue prover can step in. The attacker gets slashed once, but only `_minBond` worth.

**Impact**: The market becomes a monopoly. Competitive proving is disabled until the DAO
intervenes. This defeats the core goal of permissionless proving.

**Suggested fix**: Either:
- Enforce `_feeInGwei >= 1` (minimal floor), or
- Allow displacement via equal fee + higher bond, or
- Allow `exit()` to be triggered by a third party after a timeout if the operator is
  inactive (e.g., hasn't proved for N proposals).

---

### Finding 4 (High): Degraded mode prevents revert but still creates extended delays

**Severity**: High (downgraded from original Critical -- the revert path is now mitigated)

**Original concern**: The 8-slot displaced queue could overflow and revert
`onProposalAccepted`, halting proposals.

**Current status**: Degraded mode (entered at `_numDisplacedEpochs >= 7`) now prevents the
overflow by stopping new epoch activations (ProverMarket.sol:302-304, 310-313, 321-324).
The revert via `TooManyDisplacedEpochs` should no longer be reachable from
`onProposalAccepted` under normal state transitions.

**Remaining concern**: A deliberate churn attack can force the system into degraded mode:

1. Attacker bids at fee 100, becomes active.
2. Before proofs finalize, attacker (or sybils) bids 99, 98, 97... from fresh addresses.
3. Each proposal triggers displacement of the previous active epoch.
4. After 7 displacements without any proofs finalizing, degraded mode activates.
5. While degraded, ALL new proposals become permissionless (no exclusive prover).

In degraded mode, the chain works but the market's value proposition (competitive exclusive
proving with economic guarantees) is completely bypassed. Provers lose their exclusivity,
proposers get no fee-credit refunds for unproved proposals, and rescue incentives are
weakened.

**Cost of attack**: 8 x `_minBond` in bond deposits (locked but returned after finalization).
No permanent capital loss.

**Suggested direction**:
- Consider a cooldown between bids to limit churn velocity.
- Or make the degraded-mode entry threshold adaptive based on proving throughput.

---

### Finding 5 (High): Batch proof authorization only checks first unfinalized proposal

**Severity**: High

`Inbox.prove()` computes prover authorization based solely on the first newly finalized
proposal:

```solidity
// Inbox.sol:273-281
uint48 firstNewProposalId = uint48(state.lastFinalizedProposalId + 1);
uint48 firstNewProposalTimestamp = commitment.transitions[offset].timestamp;
proposalAge = block.timestamp - firstNewProposalTimestamp;

_checkProverMarket(
    msg.sender, firstNewProposalId, firstNewProposalTimestamp, proposalAge
);
```

And in ProverMarket:

```solidity
// ProverMarket.sol:370-376
uint48 epochId = proposalEpochs[_firstNewProposalId];
if (epochId == 0) return;
require(_caller == epochs[epochId].operator, NotAuthorizedProver());
```

**Problem**: If a batch covers proposals from multiple epochs, only the first epoch's
operator is checked. The exclusive windows of all subsequent epochs in the batch are
bypassed.

**Scenario**:
- Epoch A (operator: Alice) owns proposals 5-7
- Epoch B (operator: Bob) owns proposals 8-12
- Proposals 1-4 are already finalized

If Alice submits a batch proof covering proposals 5-12:
- Authorization checks proposal 5 -> epoch A -> Alice is operator -> passes
- Proposals 8-12 are finalized by Alice, bypassing Bob's exclusivity entirely
- Bob invested bond for exclusive proving rights that were never honored

**Worse scenario**: If proposal 5 is old enough that `proposalAge >=
_permissionlessProvingDelay`, then ANYONE can batch-prove 5-12, even if proposals 8-12
are well within Bob's exclusive window:

```solidity
// ProverMarket.sol:367
if (_proposalAge >= uint256(_permissionlessProvingDelay)) return;
```

**Impact**: Exclusivity guarantees are broken for all but the first proposal in a batch.
This undermines the market's economic model -- provers bid and lock bond for exclusivity
they may not actually receive.

**Suggested fix**: Either:
- Check authorization for each distinct epoch in the batch (gas-expensive but correct), or
- Restrict batch proofs during exclusive windows to single-epoch batches, or
- Accept this as a design trade-off and document it clearly (provers should prove
  promptly; batching older proposals with newer ones is an acceptable race condition).

---

### Finding 6 (High): Batch proof slashing only penalizes first epoch

**Severity**: High (closely related to Finding 5)

`_maybeSlashLateProof()` only inspects `proposalEpochs[_firstNewProposalId]`:

```solidity
// ProverMarket.sol:473-474
uint48 epochId = proposalEpochs[_firstNewProposalId];
if (epochId == 0) return;
```

If a rescue prover batch-proves proposals 5-12 where:
- Epoch A (proposals 5-7) missed its window -> slashed
- Epoch B (proposals 8-12) ALSO missed its window -> NOT slashed

Epoch B's bond remains intact despite failing its proving obligation. The rescue prover
only receives Epoch A's slashed bond + the rescue pool.

**Impact**: Provers can strategically delay proving so that their epoch is not the first
unfinalized one. If another epoch's proposals come first in the batch, only that earlier
epoch gets slashed. The later epoch escapes accountability.

**Attack path**:
1. Epoch A owns proposals 5-7, Epoch B owns proposals 8-12.
2. Both miss their windows.
3. Rescue prover proves 5-12 in one batch.
4. Epoch A is slashed. Epoch B is not.
5. Epoch B's bond is eventually released normally via `_releaseDisplacedBonds`.

**Suggested fix**: Iterate over all distinct epochs in the batch and slash each one that
missed its window. This adds gas cost proportional to the number of epoch transitions in
a batch, which is bounded by `MAX_DISPLACED_EPOCHS`.

---

### Finding 7 (Medium): `forcePermissionlessMode` disables slashing entirely

**Severity**: Medium

When the DAO enables permissionless mode:

```solidity
// ProverMarket.sol:469
if (_state.permissionlessMode || _proposalAge < uint256(_permissionlessProvingDelay)) {
    return;
}
```

This bypasses `_maybeSlashLateProof` completely. Any epoch that missed its window while
permissionless mode is active escapes slashing.

**Scenario**:
1. Active prover collects fees for proposals 100-200 but doesn't prove.
2. Protocol enters a crisis; DAO enables `forcePermissionlessMode(true)`.
3. Rescue provers prove proposals 100-200.
4. `_maybeSlashLateProof` returns early due to `permissionlessMode == true`.
5. The delinquent prover's bond is never slashed; it's eventually released via
   `_releaseDisplacedBonds`.

**Impact**: Permissionless mode creates a perverse incentive -- provers are better off if
the DAO triggers it, since they escape slashing. In extreme cases, a prover could lobby
for or manufacture conditions that lead to permissionless mode activation.

**Suggested fix**: Decouple permissionless proving from slashing. `permissionlessMode`
should allow anyone to prove, but `_maybeSlashLateProof` should still slash epochs that
missed their window regardless of the mode.

---

### Finding 8 (Medium): Slash amount is fixed at `_minBond` regardless of liability

**Severity**: Medium

The entire epoch bond is slashed on a late proof:

```solidity
// ProverMarket.sol:477
uint64 slashedAmount = epoch.bondedAmount;
```

And `epoch.bondedAmount` always equals `_minBond` (set at bid time, line 248). This means:

1. The slash is the same whether the epoch missed the window for 1 proposal or 1000.
2. A prover assigned to many proposals risks only `_minBond` total, not per-proposal.
3. If the fee revenue from many proposals exceeds `_minBond`, the prover profits from
   intentionally not proving and getting slashed.

**Economic analysis**: If epoch fee is F gwei/proposal and the epoch was assigned N
proposals, total revenue = N * F. Total penalty = _minBond. For the prover, not-proving is
profitable whenever `N * F > _minBond` (adjusted for rescue prover claiming rescue pool).

The design doc acknowledges this (prover-market-design.md:171-172): "up-front fee
reservation is only acceptable if the missed-proof slash is materially larger than the fee
itself." The implementation relies on `_minBond` being set appropriately at deployment, but
this is not enforced in code.

**Suggested direction**: Consider scaling the bond requirement with the number of assigned
proposals, or settling fees only after proof submission (pay-on-proof instead of
pay-on-reserve).

---

### Finding 9 (Medium): Exited epoch with no replacement creates silent permissionless gap

**Severity**: Medium

When the active operator calls `exit()` and there is no pending replacement:

1. `exit()` sets `activeEpochExiting = true` (ProverMarket.sol:279).
2. On next `onProposalAccepted`, `activeEpochExiting` triggers `_retireActiveEpoch`
   (line 315), setting `activeEpochId = 0`.
3. Since `pendingEpochId == 0`, no activation happens.
4. Line 334: `activeId != 0` is false, so the proposal is NOT assigned to any epoch.
5. `proposalEpochs[proposalId]` remains 0.

This means the proposal is permissionless from birth -- anyone can prove it immediately.
This is correct behavior, but there is no event or signal to off-chain systems that the
market has fallen into a "no active prover" state. Proposals silently become
permissionless without any `DegradedModeUpdated` or similar signal.

Additionally, the exiting epoch's already-assigned proposals are moved to the displaced
queue, but they retain their exclusive windows. So the exiting operator keeps exclusivity
for old proposals while new proposals are wide open. This creates an asymmetry that could
confuse monitoring.

**Suggested fix**: Emit an event when the market falls into the "no active epoch" state
so off-chain systems can detect it and bidders can respond.

---

### Finding 10 (Low): `_actualProver` and `_finalizedAt` are unused in `onProofAccepted`

**Severity**: Low / Informational

```solidity
// ProverMarket.sol:391-392
_actualProver; // unused but part of interface
_finalizedAt; // unused but part of interface
```

Similarly, `_proposalTimestamp` is unused in `beforeProofSubmission` (line 361).

These unused parameters suggest the interface was designed for richer logic that isn't
implemented yet. The interface should either be trimmed or the TODO for using these
parameters should be documented.

---

## Test Coverage Gaps

The existing test suite covers happy paths well but lacks adversarial scenarios. Missing
tests that should be added before shipping:

1. **Zero-fee lock-in**: Bid `feeInGwei = 0`, verify no one can outbid, verify `exit()`
   works as only escape hatch, verify operator can hold position indefinitely.

2. **Batch proof authorization across epochs**: Prove a batch spanning two epochs, verify
   that only the first epoch's operator is checked (documents current behavior or tests
   the fix).

3. **Batch proof slashing across epochs**: Prove a late batch spanning two epochs that
   both missed their windows, verify slashing behavior for each epoch.

4. **Forced permissionless mode + slashing interaction**: Enable `forcePermissionlessMode`,
   prove a late proposal, verify whether slashing occurs.

5. **Deliberate churn to degraded mode**: 8 sequential bids without proof finalization,
   verify degraded mode activation and recovery path.

6. **Exit with no replacement**: Active operator exits with no pending bid, verify next
   proposals are permissionless and subsequent bid re-establishes market.

7. **Economic profitability of non-proving**: Set up N assigned proposals where
   `N * fee > _minBond`, verify the economic outcome for the delinquent prover vs rescue
   prover.

8. **Rescue prover reward accumulation**: Multiple late-self-proofs filling
   `rescueRewardPool`, then a rescue prover claims the accumulated pool.

9. **Bond release after slashing**: Epoch is slashed, then its proposals are finalized.
   Verify bond is not double-released via `_releaseDisplacedBonds`.

10. **Concurrent proposal and proof race**: `onProposalAccepted` and `onProofAccepted`
    interleaving (proposer and prover in same block), verify state consistency.

---

## Architecture Assessment

### What works well

1. **Epoch model**: Clean separation between bidding (pending), serving (active), and
   settling (displaced) states. The lifecycle is well-defined.

2. **Internal balance accounting**: Fees and bonds tracked via mappings, no ETH transfers
   on the critical proposal path. This eliminates reentrancy and revert-DoS risks in the
   hot path.

3. **Degraded mode**: Hysteresis-based safety valve (enter at 7, exit at 0) prevents
   proposal-path reverts from queue overflow. Good design.

4. **Rescue prover incentive**: The `rescueRewardPool` accumulation + immediate payout
   creates a meaningful incentive for third parties to rescue the chain.

5. **Immutable config**: Constructor immutables for inbox, bond token, min bond, and
   permissionless delay. No governance-mutable parameters that could be changed to game
   the market.

### Design tensions

1. **Pay-on-reserve vs pay-on-proof**: The current model pays the prover at proposal time,
   before they've done any work. This front-loads revenue and back-loads accountability.
   The slash is the only check, and it's fixed-size. A pay-on-proof model would align
   incentives better but adds complexity.

2. **Single-proposal authorization for batches**: The market assigns exclusivity
   per-proposal, but Inbox proves in batches. These two granularities don't align cleanly.
   The current approach checks only the first proposal, which creates the issues in
   Findings 5 and 6.

3. **Permissionless delay as the universal fallback**: The `_permissionlessProvingDelay` is
   the safety net for every failure mode (operator disappears, zero-fee lock, degraded
   mode). This means every failure mode imposes the same delay on finalization. There's no
   graduated response.

---

## Summary Table

| # | Finding | Severity | Status |
|---|---------|----------|--------|
| 1 | No slashing mechanism | Critical | **RESOLVED** |
| 2 | Zero-fee irreplaceable epoch | Critical | **OPEN** (exit path fixed, zero-fee still possible) |
| 3 | CEI violation / reentrancy in fee path | High | **RESOLVED** |
| 4 | Displaced queue overflow / degraded mode abuse | High | **OPEN** (revert fixed, churn attack remains) |
| 5 | Batch proof auth only checks first epoch | High | **NEW** |
| 6 | Batch proof slashing only penalizes first epoch | High | **NEW** |
| 7 | `forcePermissionlessMode` disables slashing | Medium | **NEW** |
| 8 | Slash amount fixed at `_minBond` regardless of liability | Medium | **NEW** |
| 9 | No event for "market empty" state | Medium | **NEW** |
| 10 | Unused interface parameters | Low | **NEW** |
