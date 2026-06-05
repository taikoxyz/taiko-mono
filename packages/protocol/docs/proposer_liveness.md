# Proposer Liveness: Forced Empty Blocks, ETH-Bonded Slashing, and Fast Takeover

This document specifies how Taiko enforces proposer liveness at 1-second block time
without relying on a subjective `Blacklist` or owner-managed allowlist. It composes
with the existing preconfirmation lookahead (`LookaheadStore`), the preconfirmation
safety/liveness faults (`PreconfSlasherL1`), and the Universal Registry Contract
(URC) collateral pool.

The design is the answer to a single question:

> **How do we make a missing block as accountable as a wrong block?**

Today, every existing fault in `PreconfSlasher` (`packages/protocol/contracts/shared/preconf/IPreconfSlasher.sol`)
requires a **signed `Preconfirmation` object** to challenge. A preconfer who simply
goes dark and signs nothing produces no slashable evidence. This document closes
that gap.

---

## 1. Problem statement and design choices

### 1.1 Liveness gaps the existing design does not cover

`PreconfSlasherL1` slashes four faults
(`packages/protocol/contracts/shared/preconf/IPreconfSlasher.sol:27-43`):

- `MissedSubmission` — preconfer signed a preconfirmation but did not submit it.
- `MissingEOP` — last preconfirmation in a window lacks the `eop` flag.
- `RawTxListHashOrAnchorBlockMismatch` — submitted batch differs from signed promise.
- `InvalidEOP` — non-terminal preconfirmation has `eop == true`.

All four require a signed `Preconfirmation` to anchor the challenge. None covers
the **silent operator** who signs nothing and produces nothing. None covers
**intra-window underutilization**: a window deadline of `endOfSubmissionWindowTimestamp`
is enforced only in the sense that the proposer loses exclusivity after it; nothing
verifies that the window was actually filled with L2 blocks at the protocol's
target block rate.

The chain-level liveness backstop today is the `allowsPermissionless` flag in
`Inbox.propose` (`packages/protocol/contracts/layer1/core/impl/Inbox.sol:620-622`),
which opens proposing to anyone once a forced inclusion is older than:

```
forcedInclusionDelay × permissionlessInclusionMultiplier
```

On mainnet, `MainnetInbox.sol` sets `576 × 160 ≈ 25.6 hours`. That is a
catastrophic-failure backstop, not a real-time liveness mechanism. At a 1-second
block target it permits 92,000 missed blocks before any handoff.

### 1.2 Design decisions

This document commits to two design choices that simplify the rest of the system:

1. **Force empty blocks.** Every L2 second must be filled by a block, even when
   no transactions are queued. Detection of a missed block becomes purely structural:
   a gap is any second without a block, with no off-chain demand signal required.
2. **Liveness bond denominated in ETH, held in URC collateral.** The bond
   composes with the existing `PreconfSlasher`/`LookaheadSlasher` collateral
   pool, removes the TAIKO-token coupling for proposer participation, and shares
   the same `ISlasher` routing mechanism via `UnifiedSlasher`.

These choices imply four components, which the rest of this document specifies.

---

## 2. Architecture overview

| Component | Layer | Purpose |
|---|---|---|
| **A. Dense-derivation rule** | Derivation / protocol | Every L2 second has a block. Makes "missing" detectable. |
| **B. `LivenessSlasher`** | URC slasher (ETH-bonded) | Debits URC collateral on a successful gap challenge. |
| **C. `GapSlash` fault** | Challenge protocol | Objective on-chain proof of an L2 timestamp gap, with L1-censorship exception. |
| **D. Fast takeover** | Inbox | Real-time handoff when the chain head goes stale. |

**A**, **B**, **C** form the **accountability layer** (retroactive). **D** is the
**liveness layer** (real-time). They share a single piece of state:
`Proposal.endOfSubmissionWindowTimestamp` (`IInbox.sol:66`), which attributes
every L2 second to exactly one operator.

```
   ┌─────────────────────────── L2 timeline ───────────────────────────┐
   │   window of operator A           │   window of operator B          │
   │  (deadline = T_A)                │  (deadline = T_B)               │
   │                                                                    │
   │   ─■─■─■─■─■─■─■─■─■─■─■─■─■─    │   ─■─■─■─?─?─?─■─■─■─...        │
   │   dense, every second filled     │   gap in B's window  ↑          │
   │                                              GapSlash applies to B │
   └────────────────────────────────────────────────────────────────────┘
```

---

## 3. Terminology and actors

### 3.1 Roles

- **Assignee** — the operator whose URC-committer address is the expected
  proposer for the current submission window, derived from `LookaheadStore`.
- **Rescuer** — any address that lands a proposal during a *takeover* window,
  bypassing the assignee.
- **Challenger** — any address that submits `GapEvidence` to `LivenessSlasher`;
  receives URC's challenger payout from the slashed collateral.

Rescuer and challenger may be the same address. The system makes this the common
path via the atomic takeover-with-slash flow in §7.

### 3.2 New constants

In addition to the existing constants in `LibPreconfConstants.sol`:

```solidity
uint256 internal constant LIVENESS_COMMITMENT_TYPE = 2;
// PRECONF_COMMITMENT_TYPE = 0, LOOKAHEAD_COMMITMENT_TYPE = 1 already exist.

uint48  internal constant TAKEOVER_DELAY       = 24 seconds; // ≈ 2 L1 slots
uint48  internal constant TAKEOVER_OPEN_DELAY  = 48 seconds; // ≈ 4 L1 slots
uint48  internal constant MAX_GAP              = 4 seconds;  // jitter tolerance
uint256 internal constant PER_SECOND_PENALTY   = 0.001 ether;
uint256 internal constant MAX_PER_WINDOW_SLASH = 2 ether;
uint256 internal constant MIN_URC_COLLATERAL   = 5 ether;
```

Calibration guidance is in §10. These are starting values, not protocol invariants.

---

## 4. Component A — Dense-derivation rule (forced empty blocks)

### 4.1 Current timestamp rule

From `packages/protocol/docs/Derivation.md` §timestamp validation:

> Lower bound:
> `lowerBound = max(parent.metadata.timestamp + 1, proposal.timestamp - TIMESTAMP_MAX_OFFSET, SHASTA_FORK_TIME)`

This makes L2 block timestamps **monotone**, not **dense**. A manifest with
`blocks[0].timestamp = parent.timestamp + 60` is legal: there are 59 missing
seconds between the parent and `blocks[0]`, but no rule says they must be filled.

### 4.2 New rule: dense timestamps

The rule becomes:

```
For each i in [1, manifest.blocks.length):
    require(blocks[i].timestamp == blocks[i-1].timestamp + BLOCK_TIME_TARGET);

For the first block of a derivation source:
    require(blocks[0].timestamp == parent.metadata.timestamp + BLOCK_TIME_TARGET);

For the last block of an operator's terminal source in a window:
    require(blocks[N-1].timestamp == endOfSubmissionWindowTimestamp
         || nextSource.firstBlockTs == blocks[N-1].timestamp + BLOCK_TIME_TARGET);
```

With `BLOCK_TIME_TARGET = 1 second`, this forces every L2 second to be covered by
a block. The trailing-block rule pins the **end** of a window: an operator who
stops short of their deadline produces a violating manifest.

### 4.3 Soft penalty: default-manifest replacement

The existing penalty for malformed sources in `Derivation.md` already applies:
**any block outside `[lowerBound, proposal.timestamp]` causes the entire
derivation source to be replaced with a default manifest.** Reuse this:

- A non-dense manifest replaces the source with a default manifest that **fills
  the missing seconds with empty blocks at 1s cadence**.
- The defaulter loses any MEV they would have collected from the malformed source.
- This is **additive** to the explicit slash via `GapSlash` (§6). Soft incentive
  on top of bond loss.

### 4.4 DA cost mitigation: run-length encoding (RLE) of empty blocks

A 144-second window at 1s block time = 144 manifest entries. A naive encoding
(`BlockParams` is ~102 bytes per `packages/protocol/contracts/layer2/core/Anchor.sol:29-39`)
costs ~15 KB per window. A blob is ~128 KB → ~8 windows per blob, which is
sustainable but wasteful when most blocks are empty.

Introduce a manifest run extension:

```solidity
/// @notice Represents a run of empty blocks at the protocol block-time cadence.
/// @dev    The run's first block may carry anchor fields; subsequent blocks
///         in the run inherit zero-anchor (no L1 sync inside the run).
struct EmptyBlockRun {
    uint16  count;            // number of empty blocks
    uint48  startTimestamp;   // L2 timestamp of the first block in the run
    uint48  anchorBlockNumber; // L1 anchor for the first block (0 to skip)
    bytes32 anchorBlockHash;
    bytes32 anchorStateRoot;
}
```

A 144-block empty window encodes as **a single ~88-byte run** instead of ~15 KB.

### 4.5 Anchor cadence interaction

`ShastaAnchor` performs L1 state synchronization on anchored blocks. The RLE
form must respect anchor cadence. Two acceptable shapes:

- **Sparse anchor mode.** Only the first block of a run carries anchor data;
  the cadence rule is "at least one anchor per N blocks", and runs must be
  split at anchor boundaries. Slightly more complex encoding.
- **Free anchor mode.** Runs may be of any length; anchors arrive whenever the
  proposer chooses to break a run with a non-empty block. Simplest, but may
  delay L1-state visibility on L2 under sustained empty-run conditions.

Implementation choice is left to the L2 anchor specification; the slashing
logic in §6 is agnostic to anchor placement.

---

## 5. Component B — ETH liveness bond via URC

### 5.1 Slasher contract

`LivenessSlasher` implements `ISlasher.slash(commitment, evidence, challenger)`
with the same shape as `PreconfSlasherL1`
(`packages/protocol/contracts/layer1/preconf/impl/PreconfSlasherL1.sol:29-66`):

```solidity
function slash(
    ISlasher.Commitment calldata _commitment,
    bytes calldata _evidence,
    address _challenger
) external view returns (uint256 slashAmount_);
```

The contract is `view`-only with respect to its own state; URC performs the
collateral debit and challenger payout after the call.

Atomicity is provided by URC's `slashCommitment` entrypoint. Within a single
call frame, URC verifies the operator's opt-in to `livenessSlasher`, invokes
`LivenessSlasher.slash` (via `UnifiedSlasher.delegatecall`), debits the
returned `slashAmount_` from the operator's collateral, and credits the
challenger. There is no two-step settlement and no inter-tx window in which
the verified-but-unsettled slash can be front-run. This is the same pattern
already used by `PreconfSlasherL1` and `LookaheadSlasher`; reentrancy is
gated by URC's own slash-pending checks per operator.

### 5.2 Routing through `UnifiedSlasher`

Extend `UnifiedSlasher.slash`
(`packages/protocol/contracts/layer1/preconf/impl/UnifiedSlasher.sol:39-82`) with
a third branch:

```solidity
} else if (_commitment.commitmentType == LibPreconfConstants.LIVENESS_COMMITMENT_TYPE) {
    (bool success, bytes memory data) = livenessSlasher.delegatecall(
        abi.encodeWithSelector(
            ILivenessSlasher.slash.selector, _commitment, _evidence, _challenger
        )
    );
    if (!success) {
        assembly { returndatacopy(0, 0, returndatasize()); revert(0, returndatasize()) }
    }
    slashAmount_ = abi.decode(data, (uint256));
}
```

### 5.3 Operator opt-in

Each operator already opts in to two URC slasher commitments today (`preconfSlasher`
and `lookaheadSlasher`, per `preconfirmation_lookahead.md` §2). Liveness adds a
third opt-in:

- **`livenessSlasher`** — ECDSA committer key. May reuse the **preconf committer**
  key for the same operator; no additional key custody required.
- Opt-in must occur **before** the operator is eligible for inclusion in a
  posted lookahead — `LookaheadStore._validateLookaheadOperator` is extended to
  require all three opt-ins for the operator to be a valid lookahead entry.

### 5.4 Bond sizing

A single URC ETH collateral pool backs all three slashers. Suggested minima:

| Parameter | Value | Rationale |
|---|---|---|
| `MIN_URC_COLLATERAL` | 5 ETH | Survives one safety fault (1 ETH) + multiple liveness slashes before drain. |
| `MAX_PER_WINDOW_SLASH` | 2 ETH | Cap per gap challenge; multiple bad windows still possible before exhaustion. |
| `PER_SECOND_PENALTY` | 0.001 ETH | A full 144-second window no-show ≈ 0.144 ETH. A 24-second stall ≈ 0.024 ETH. |

The hard invariant on `PER_SECOND_PENALTY`:

> `PER_SECOND_PENALTY > expected_per_second_MEV`

Otherwise, "go dark, sign nothing, save L1 gas, return after the window" is
profitable. Calibrate against measured L2 MEV per second at 1s block time.

### 5.5 Decoupling from Inbox's existing liveness bond

`Inbox.Config.livenessBond` (`IInbox.sol:26`) and `LibBonds.settleLivenessBond`
(`packages/protocol/contracts/layer1/core/libs/LibBonds.sol:143-170`) remain
scoped to **prover liveness** (late proving), unchanged. The mainnet value of
`0` per `MainnetInbox.sol:39` ("During prover whitelist, bonds are not necessary")
continues to apply to prover bonds only.

Proposer liveness lives **entirely in URC**. No new field is added to
`Inbox.Config`.

---

## 6. Component C — `GapSlash` fault

### 6.1 Commitment payload

Unlike preconfirmation slashing, the commitment for `LivenessSlasher` is **not
signed per-window**. It is derived from on-chain state:

```solidity
struct LivenessCommitment {
    uint48  epochTimestamp;
    bytes26 lookaheadHash;   // matches LookaheadStore's stored hash for the epoch
}
```

This is the single most important difference from `PreconfSlasherL1`. A silent
operator who never signs anything still has an implicit commitment: their
presence in a posted lookahead. The lookahead is the commitment. There is
nothing for a defaulter to withhold.

### 6.2 Evidence — single fault type: `NoProposal`

The slasher recognizes exactly one fault: the assigned operator made zero
proposals in their window. The original draft of this design enumerated
three fault types (`InternalGap`, `ShortTrailingGap`, `NoProposal`), but
the dense-derivation rule and its default-manifest replacement (§4.2,
§4.3) guarantee on-chain L2 history is structurally dense **after
derivation**. There is therefore no on-chain "internal gap" or
"trailing gap" to point at — those failure modes are absorbed by the
soft penalty (loss of MEV from default-replaced sources). Only the
**fully silent operator** leaves a trace the slasher can verify on-chain,
because in that case no source exists to default-replace.

This collapse has a useful corollary: the slasher needs **no L2 block
timestamps**. It works entirely from `Proposal.timestamp` (L1) and
`Proposal.proposer`, both already on-chain. Open question §14.5 (L2
timestamp authentication) is resolved — no protocol struct change is
required.

```solidity
struct GapEvidence {
    uint48              windowStart;     // From lookahead.
    uint48              windowEnd;       // From lookahead.
    address             expectedProposer;
    LookaheadSlot[]     lookahead;       // Opens the committed lookaheadHash.
    uint256             slotIndex;       // Index of expectedProposer in lookahead.

    // Non-existence proof: two proposals from the ring buffer that bracket
    // the operator's window without containing any of the operator's own
    // proposals. Linked via parentProposalHash (already in the Proposal struct)
    // so the verifier can show they are adjacent in the canonical sequence.
    Inbox.Proposal      lastProposalBefore;   // Last proposal with timestamp < windowStart.
    Inbox.Proposal      firstProposalAfter;   // First proposal with timestamp >= windowStart;
                                              // its proposer must != expectedProposer, or this
                                              // proposal must itself have timestamp >= windowEnd
                                              // (full silent window).
    bytes32             lastProposalBeforeHash;
    bytes32             firstProposalAfterHash;

    // Adjacency proof: parentProposalHash chain showing nothing sits between
    // lastProposalBefore and firstProposalAfter.
    // (omitted struct detail; in practice this is just
    //  firstProposalAfter.parentProposalHash == lastProposalBeforeHash.)

    // Censorship excision is performed automatically on-chain in §6.4 —
    // the challenger does NOT supply a missed-slot list, so they cannot
    // omit legitimately missed L1 slots to bias the slash.
}
```

### 6.3 Verification flow

`LivenessSlasher.slash` performs:

1. **Commitment integrity.** Check `_commitment.lookaheadHash` equals
   `LookaheadStore.getLookaheadHash(_commitment.epochTimestamp)`.
2. **Lookahead opening.** Decode `lookahead` from evidence; verify
   `bytes26(keccak256(abi.encode(epochTimestamp, lookahead))) == lookaheadHash`.
3. **Window derivation.** Compute `windowStart`, `windowEnd`, and
   `expectedProposer` from `lookahead[slotIndex]` using the same logic
   as `LookaheadStore._determineProposerContext`.
4. **Ring-buffer membership.** Verify both `lastProposalBefore` and
   `firstProposalAfter` are stored at their declared ring-buffer slots,
   matching their declared hashes.
5. **Adjacency.** Verify
   `firstProposalAfter.parentProposalHash == lastProposalBeforeHash`.
   Together with step 4, this proves no other proposal sits between
   them in the canonical sequence.
6. **Non-membership of `expectedProposer`.** Verify both of:
   - `lastProposalBefore.timestamp < windowStart`,
   - `firstProposalAfter.proposer != expectedProposer` **or**
     `firstProposalAfter.timestamp >= windowEnd`
     (the latter covers the "fully silent window" case, in which the
     next observed proposal lies past the window's end).

   Note that `firstProposalAfter.timestamp` may legitimately fall
   inside or after `[windowStart, windowEnd]`; both are accepted as
   long as the proposer is not `expectedProposer`. The closing proposal
   is whoever broke the silence (rescuer, next-window operator, or any
   later proposer).
7. **Raw gap.**
   ```
   closingTs = min(firstProposalAfter.timestamp, windowEnd)
   rawGap    = closingTs - windowStart
   ```
   All timestamps are L1 (the `Proposal.timestamp` field). The cap at
   `windowEnd` ensures the slash is bounded by the window length even
   when the closing proposal lies in a later window.

   This formulation measures the **actual** silent duration, not the
   worst-case full window. It prevents strategic-delay inflation, where
   a next-window assignee could otherwise wait close to
   `TAKEOVER_OPEN_DELAY` to grow their own rescuer payout (the slash
   now scales with real staleness only, and a competing late rescuer
   who posts earlier strictly reduces the slash a delayer would receive).
7. **Censorship exception (automatic).** Iterate every L1 slot in
   `[gapStart, gapEnd]` aligned to `SECONDS_IN_SLOT = 12`. For each slot
   timestamp `ts`, call `LibPreconfUtils.getBeaconBlockRootAt(ts)`; if
   the returned root is `bytes32(0)`, subtract `SECONDS_IN_SLOT` from
   `rawGap` to obtain `effectiveGap`. The challenger does not supply
   the missed-slot list; the slasher enumerates and verifies all
   relevant slots directly from EIP-4788 beacon roots. See §6.4 for
   gas cost analysis and rationale.
8. **Threshold.** `require(effectiveGap > MAX_GAP, NoFault)`.
9. **Penalty.**
   `slashAmount = min(effectiveGap * PER_SECOND_PENALTY, MAX_PER_WINDOW_SLASH)`.
10. **Return.** URC debits the operator's collateral and credits the challenger
    per URC's own challenger-payout rule.

### 6.4 Censorship exception, in detail

This reuses the EIP-4788 pattern already present in `PreconfSlasherL1`
(`packages/protocol/contracts/layer1/preconf/impl/PreconfSlasherL1.sol:88-92`):

```solidity
if (LibPreconfUtils.getBeaconBlockRootAt(preconfirmation.submissionWindowEnd) == bytes32(0)) {
    return slashAmount.livenessFault; // L1 missed slot -> liveness, not safety
}
```

Here the exception is stronger: **excised**, not downgraded. An operator
hit by an Ethereum missed-slot run **owes nothing** for the excised
interval.

**The excision is computed automatically on-chain by `LivenessSlasher`,
not supplied by the challenger.** The slasher walks every L1 slot in
`[gapStart, gapEnd]` (aligned to `SECONDS_IN_SLOT`), calls
`getBeaconBlockRootAt(ts)` for each, and subtracts `SECONDS_IN_SLOT`
from `rawGap` whenever the returned root is `bytes32(0)`. This makes
the excision tamper-proof: a challenger cannot inflate `rawGap` by
omitting legitimately missed L1 slots, and an honest operator hit by
L1 turbulence cannot be slashed simply because no third party knew to
include the right slots in evidence.

**Gas bound.** Each EIP-4788 read is a single CALL to the beacon-roots
precompile (~5–10 k gas including memory and return decoding). The
loop is `O(gapDurationSeconds / SECONDS_IN_SLOT)` iterations:

| Gap length | Iterations | Approx. gas |
|---|---|---|
| 24 s (one takeover window) | 2 | ~20 k |
| 144 s (full lookahead window) | 12 | ~120 k |
| Worst-case epoch boundary | 32 | ~320 k |

All bounded by `MAX_PER_WINDOW_SLASH`'s structural cap on window length;
no unbounded loop. The cost is paid by the challenger or, in the
atomic-slash-on-takeover path (§7.2), folded into the rescuer's
`Inbox.propose` transaction. Acceptable given how infrequently
`LivenessSlasher.slash` is expected to fire.

EIP-4788 is the single oracle for "was L1 alive at second T",
consistent with the rest of the preconfirmation system.

### 6.5 What `GapSlash` catches, and what other mechanisms cover

| Failure mode | `PreconfSlasher` | Soft penalty (§4.3) | `GapSlash` |
|---|---|---|---|
| Operator signs a preconfirmation, fails to submit it. | ✓ `MissedSubmission` | — | — |
| Operator signs, submits a batch whose contents differ from the signed preconf. | ✓ `RawTxListHashOrAnchorBlockMismatch` | — | — |
| Operator omits the `eop` flag on the terminal block. | ✓ `MissingEOP` | — | — |
| Operator submits a sparse manifest (skips L2 seconds inside their window). | — | ✓ source replaced; MEV lost | — (subsumed) |
| Operator stops short of `endOfSubmissionWindowTimestamp` (partial window). | — | ✓ next operator or default fills the tail; MEV lost | — (subsumed) |
| **Operator goes fully silent: zero proposals in window.** | ✗ no signed object | — (no source to replace) | ✓ `NoProposal` |

The two middle rows are why §6.2 collapses to a single fault: §4.3's
default-manifest replacement *and* the next operator's dense rule
*and* the rescuer's takeover all conspire to keep L2 history dense.
Any "gap" that would justify slashing a partially-silent operator is
already paid for in MEV they could not collect. Only the fully-silent
case (no source ever submitted) leaves an on-chain object the slasher
can verify.

---

## 7. Component D — Fast takeover

### 7.1 Two-stage trigger in `Inbox.propose`

Today, `Inbox.propose` runs the proposer check unconditionally unless
`allowsPermissionless` is true
(`packages/protocol/contracts/layer1/core/impl/Inbox.sol:540-570`). The fast
takeover inserts a head-staleness check **before** the existing logic:

```solidity
uint48 sinceLast = uint48(block.timestamp) - $.coreState.lastProposalTimestamp;
bool stale = sinceLast > LibPreconfConstants.TAKEOVER_DELAY;
bool dead  = sinceLast > LibPreconfConstants.TAKEOVER_OPEN_DELAY;

uint48 endOfSubmissionWindowTimestamp;
if (result.allowsPermissionless || dead) {
    // Anyone may propose. Existing behavior, just reached faster.
    endOfSubmissionWindowTimestamp = 0;
} else if (stale) {
    // Next-window assignee may step in early.
    endOfSubmissionWindowTimestamp =
        _proposerChecker.checkProposerForTakeover(msg.sender, _lookahead);
} else {
    // Normal path.
    endOfSubmissionWindowTimestamp =
        _proposerChecker.checkProposer(msg.sender, _lookahead);
}
```

`checkProposerForTakeover` is a new method on `IProposerChecker`. Its
implementation in `LookaheadStore` accepts the **next** lookahead entry's
committer in addition to the current one. The existing
`_determineProposerContext` already computes the next-entry window; the
takeover method exposes that branch directly.

**Window assignment in the takeover path.** The rescuer inherits the
**remainder of the delinquent assignee's window**, not a fresh window of
their own. Concretely:

- `stale` path: `endOfSubmissionWindowTimestamp = originalAssignee.windowEnd`
  (the lookahead entry the delinquent operator was assigned to). The
  rescuer's window of exclusivity ends when the delinquent operator's
  would have. After that, normal lookahead-driven proposing resumes for
  whoever the next entry assigns.
- `dead` path: `endOfSubmissionWindowTimestamp = 0`. Anyone may propose
  a single batch; the next `propose` call re-runs `checkProposer` from
  scratch.

This means the rescuer does not take on indefinite responsibility — they
fill the gap, hold the window until its natural end, and hand off
normally. No oversized bond exposure beyond what the original assignee
would have faced.

### 7.2 Atomic slash on takeover

The takeover transaction may include `GapEvidence` for the delinquent
assignee. `Inbox.propose` then calls into URC atomically, but **wraps the
call in `try/catch` so that takeover liveness is never blocked by a slash
failure**:

```solidity
if ((stale || dead) && _slashData.length > 0) {
    try IRegistry(urc).slashCommitment(
        _slashRegistrationRoot,
        livenessSlasherCommitment,
        _slashData
    ) returns (uint256 /* slashedAmount */) {
        // ok — payout credited per URC's split rule
    } catch {
        // slash failed (e.g., collateral already exhausted by a prior
        // slash in the same block, or the operator's URC opt-in changed).
        // The takeover proceeds regardless; a separate challenger can
        // retry the slash later if any collateral remains.
        emit AtomicSlashFailed(_slashRegistrationRoot);
    }
}
```

Without this wrapping, the optional slash becomes a griefing surface: a
malicious challenger could front-run the rescuer's takeover with a
standalone slash that drains the delinquent operator below the threshold,
making URC's atomic slash revert, and reverting the entire takeover —
preventing the rescuer from posting and prolonging the chain stall. The
`try/catch` makes liveness restoration unconditionally the priority and
the slash purely opportunistic.

**Failed atomic slashes do not lose the fault.** When the atomic slash
reverts (caught by `try/catch`), the takeover proposal still lands but
the operator is *not* slashed in that transaction. The fault remains
slashable via the standard standalone path: anyone may file a separate
`LivenessSlasher.slash` transaction against the same `NoProposal`
evidence at any later time, subject only to the operator's URC
collateral still having value left. The `AtomicSlashFailed` event is
the public signal that a standalone retry is available. In practice
this matters only when URC reverts for a deterministic state reason
(e.g., a same-block prior drain); cases where a delinquent operator's
collateral has been fully consumed are already the terminal economic
outcome.

Effects in the happy path:

- URC executes `LivenessSlasher.slash` against the delinquent operator's
  collateral.
- URC's own challenger-payout rule credits a fraction of the slashed amount to
  the **rescuer** (= the address calling `propose`).
- No separate challenge transaction. No off-chain MEV race for challengers.

Recommended payout split, mirroring `LibBonds.settleLivenessBond`
(`packages/protocol/contracts/layer1/core/libs/LibBonds.sol:143-170`): 50%
rescuer / 50% burn. Final split is determined by URC's settlement contract;
this document does not prescribe URC-internal behavior.

### 7.3 Original assignee re-entry after `stale`

The original window assignee is **not** rejected during `stale` or `dead`.
They retain the right to propose throughout their window, but any late
proposal must comply with the dense-timestamp rule (§4.2): the manifest's
first block must sit at `parent.timestamp + BLOCK_TIME_TARGET`, and all
intermediate seconds must be filled (RLE empty-block encoding, §4.4, makes
this cheap). A late re-entering assignee thus **backfills the gap with
empty blocks** rather than skipping it.

The retroactive `GapSlash` applies for any gap that occurred before
re-entry: `ShortTrailingGap` if the silence pushed the operator's last
block before `windowEnd`, or `NoProposal` if they had no on-time
proposal at all (with the late re-entry serving as `closingProposal`,
§6.3).

If the late re-entry is a **dense L2 backfill** (every silent second
backfilled with an empty or transaction-bearing block at the correct
L2 timestamp), `InternalGap` evaluates to zero — there are no missing
L2 seconds in the historical record. This is intentional: from a
derivation perspective, the chain history is whole. The cost of the
spike-and-lull pattern is then bounded by three forces, in order of
decreasing strength:

1. **The fast takeover threshold.** Any L1-silence interval ≥
   `TAKEOVER_DELAY` opens the door for a rescuer to step in (§7.1)
   with atomic slash + dense backfill of their own. Spike-and-lull
   above 24 s is racing the rescuers and loses the window.
2. **Honest-operator MEV parity.** Order flow that arrives during a
   23 s silence is the *same* order flow available to honest 1 s-block
   operation; aggregating it into a late batch does not produce extra
   MEV in expectation, only different transaction ordering. The
   `PER_SECOND_PENALTY > MEV/s` invariant is unaffected.
3. **User-experienced staleness.** Even a 23 s repeated stall is a
   poor UX that causes order flow to route around the operator's L2;
   self-imposed market pressure.

A dedicated L1-cadence fault type was considered for this case and
rejected: L1 blocks arrive every 12 s, so any threshold below
`TAKEOVER_DELAY` would slash honest operators who legitimately batch
across L1 slots, and any threshold above `TAKEOVER_DELAY` is
structurally subsumed by the takeover trigger. Spike-and-lull below
24 s is therefore an acknowledged minor liveness degradation, not a
slashable fault.

This is deliberate. Forbidding re-entry would force a takeover for every
transient network hiccup. Allowing re-entry under the dense rule means:

- Honest assignees recover from brief outages at the cost of a gap-proportional
  slash; the chain head stays close to live.
- A "spike-and-lull" strategy — go silent for 23s, post a minimal batch to
  reset `lastProposalTimestamp`, repeat — pays `GapSlash` every cycle *and*
  earns zero MEV from the backfilled empty blocks. It is strictly dominated
  by honest behavior.
- Takeover by next-window assignees (after `TAKEOVER_DELAY`) or anyone
  (after `TAKEOVER_OPEN_DELAY`) remains available if the original truly
  goes silent.

### 7.4 Parameter rationale

| Parameter | Suggested | Lower bound | Upper bound |
|---|---|---|---|
| `TAKEOVER_DELAY` | 24 s (~2 L1 slots) | > expected single L1 reorg depth | < 4 L1 slots |
| `TAKEOVER_OPEN_DELAY` | 48 s (~4 L1 slots) | `TAKEOVER_DELAY + 1 L1 slot` | < `forcedInclusionDelay` |
| `MAX_GAP` | 4 s | > expected propagation jitter | « `TAKEOVER_DELAY` |
| `PER_SECOND_PENALTY` | 0.001 ETH | > observed per-second MEV | `MAX_PER_WINDOW_SLASH / window_size` |

Lower-bound reasoning: `TAKEOVER_DELAY` must exceed typical L1 reorg depth or a
shallow reorg could induce a false takeover. Upper-bound: it must remain well
inside `forcedInclusionDelay × permissionlessInclusionMultiplier` so the
takeover path triggers before the catastrophic-failure backstop.

---

## 8. Operator state machine

```
Window W: operator O is assigned. Window timestamps: [T_start, T_end].

╭─ Honest path ───────────────────────────────────────────────────────────╮
│  O posts proposals s.t. every L2 second in [T_start, T_end] has a block.│
│  → Dense derivation passes; no fault; full MEV; no takeover.            │
╰─────────────────────────────────────────────────────────────────────────╯

╭─ Sparse path (gaps inside window) ──────────────────────────────────────╮
│  O posts but skips L2 seconds (or stops short of T_end).                │
│  → Derivation default-replaces the malformed source (lost MEV).         │
│  → Any challenger calls LivenessSlasher.slash(GapEvidence{InternalGap}).│
│  → URC debits O's collateral; challenger paid.                          │
╰─────────────────────────────────────────────────────────────────────────╯

╭─ Silent path (no proposals) ────────────────────────────────────────────╮
│  O posts nothing.                                                        │
│  At sinceLast > TAKEOVER_DELAY (24 s):                                  │
│    → Next-window assignee may step in via checkProposerForTakeover.     │
│    → They may attach GapEvidence{NoProposal} for atomic slash + payout. │
│  At sinceLast > TAKEOVER_OPEN_DELAY (48 s):                             │
│    → Permissionless: anyone may propose. Same atomic slash path.        │
╰─────────────────────────────────────────────────────────────────────────╯

╭─ L1 censorship path ────────────────────────────────────────────────────╮
│  O tries; L1 has missed slots inside [T_start, T_end].                  │
│  → Challenger files GapEvidence; slasher auto-excises missed L1 slots.  │
│  → Censorship exception (§6.4) cancels the punished interval.           │
│  → effectiveGap ≤ MAX_GAP → NoFault; O is not punished.                 │
╰─────────────────────────────────────────────────────────────────────────╯
```

---

## 9. Composition with existing slashers

| Slasher | Triggers on | Bond source |
|---|---|---|
| `PreconfSlasherL1` | Signed `Preconfirmation` violated. | URC collateral. |
| `LookaheadSlasher` | Posted lookahead diverges from beacon truth. | URC collateral. |
| **`LivenessSlasher`** (new) | L2 timestamp gap inside an attributed window. | URC collateral. |
| `LibBonds.settleLivenessBond` | Late *proving* (`Inbox.sol:680-692`). | Inbox `_bondToken` (kept TAIKO-scoped). |

Three of the four share the URC collateral pool via `UnifiedSlasher`. A serially
bad operator pays through all three until collateral is exhausted, at which
point they cease to be a valid URC operator and fall out of lookahead
eligibility naturally (`LookaheadStore._validateLookaheadOperator`).

The fourth (`settleLivenessBond` for late proving) remains scoped to *provers*,
not proposers, and continues to live in Inbox-managed bond storage.

**URC collateral debit ordering.** URC maintains a single ETH collateral pool
per operator across all three slashers. When multiple slashes target the same
operator (e.g., a safety fault challenge filed in the same block as a liveness
takeover-with-slash), URC debits in transaction order from the same pot. Once
collateral falls below `MIN_URC_COLLATERAL`, the operator becomes ineligible
for inclusion in newly-posted lookaheads — `LookaheadStore._validateLookaheadOperator`
must check current collateral against `MIN_URC_COLLATERAL` at lookahead build
time. Operators already present in an unexpired posted lookahead remain there
until the lookahead window passes; their next-window inclusion is what falls
off. This produces a natural decay of bad operators from the schedule without
any subjective intervention.

---

## 10. Why this enables removing the `Blacklist`

The existing `Blacklist` (`packages/protocol/contracts/layer1/preconf/iface/IBlacklist.sol`)
exists to remove URC operators for **subjective faults** — anything the
objective slashers do not catch. Once `GapSlash` covers liveness and the
existing slashers cover safety, the residual set of "subjective" faults
shrinks to whatever is left after:

| Fault category | Mechanism after this design |
|---|---|
| Submitted wrong batch contents | `PreconfSlasherL1.RawTxListHashOrAnchorBlockMismatch` |
| Submitted batch with wrong `eop` flag | `PreconfSlasherL1.InvalidEOP` / `MissingEOP` |
| Failed to submit signed preconfirmation | `PreconfSlasherL1.MissedSubmission` |
| Posted incorrect lookahead | `LookaheadSlasher` |
| **Silent operator (no signing, no submission)** | **`LivenessSlasher.GapSlash` (this doc)** |
| **Sparse submission inside window** | **`LivenessSlasher.GapSlash` (this doc)** |
| **Stalls chain head (no submission for ≥ 24 s)** | **Fast takeover (§7) + atomic slash** |

After this design lands, the `Blacklist` covers no fault that an objective
slasher does not already cover. The remaining argument for keeping it is
emergency response to novel faults — which is precisely what URC's per-slasher
opt-in/opt-out and Taiko's UUPS upgrade mechanism already address, without
requiring a standing overseer set.

**Recommended sequencing for blacklist removal** is in §13.

---

## 11. Parameter calibration

### 11.1 `MAX_GAP`

Set above expected jitter, below `TAKEOVER_DELAY`. Suggested starting value
`4 seconds`. The dominant source of jitter is the L1 / L2 phase mismatch: at
1-second L2 blocks, a single L1 slot (12 s) carries 12 L2 blocks, and
boundary effects can produce a momentary perceived gap of 1–2 s at window
edges. `4 s` clears those without false-positive on missed-L1-slot scenarios
(those are excised by the censorship exception, not by `MAX_GAP`).

**Calibration test:** measure the distribution of `t_blockN+1 - t_blockN`
across historical L2 derivation. Choose `MAX_GAP` at the 99.9% percentile of
the honest distribution.

**Soft-launch (monitor-only mode).** Until measured jitter data are available
under live mainnet conditions, deploy `LivenessSlasher` with a `slashingEnabled`
flag (governance-controlled) defaulting to `false`. With the flag off,
`LivenessSlasher.slash` performs full evidence verification and returns the
computed `slashAmount_`, but URC's debit step is short-circuited (e.g., the
slasher returns `0` to URC while emitting a `WouldSlash` event with the true
amount). Watchtowers, operators, and the protocol team observe the false-positive
rate against real traffic for a tuning period before any collateral is at risk.
The flag flips on no earlier than milestone M3 (§13), after parameter calibration
against observed data.

### 11.2 `PER_SECOND_PENALTY`

Set above per-second MEV. At a target block time of 1 second, with current
mainnet preconf MEV estimates, `0.001 ETH/s` is a starting point. Revisit
quarterly against measured operator revenue per second.

**Invariant:**
```
PER_SECOND_PENALTY × MAX_GAP < expected_per_window_honest_revenue
PER_SECOND_PENALTY                > expected_per_second_MEV
```

The first inequality ensures honest operators are not bankrupted by jitter
at the slash threshold. The second ensures going dark is unprofitable.

### 11.3 `TAKEOVER_DELAY` / `TAKEOVER_OPEN_DELAY`

Both must exceed the deepest plausible L1 reorg, otherwise a transient
re-org could trigger a false takeover and produce a spurious slash. 2 and 4
L1 slots (24 s, 48 s) give a comfortable margin while still keeping the
worst-case stall to <1 minute. Below 24 s, false-positive risk grows quickly.

**Blob propagation tradeoff.** `lastProposalTimestamp` advances only when
a proposal is accepted on L1, which requires the blob to be included in
an L1 block. Blob-bearing transactions typically take 1–2 L1 slots to
land under normal congestion, occasionally longer under blob-fee spikes.
An honest operator whose blob transaction is in-flight in the L1 mempool
but not yet mined can therefore appear silent past `TAKEOVER_DELAY` and
be subject to takeover-with-slash even though they were diligently
attempting to propose. The 24 s threshold gives roughly one L1-slot of
slack beyond the typical blob-inclusion latency, but operators on
congested L1 conditions may legitimately be slashed for what is, in
substance, an L1-mempool delay rather than malicious silence. The
safety/liveness tradeoff here favors liveness — the chain head matters
more to users than perfectly attributing blame — but the parameter
should be revisited if observed blob-inclusion latency moves up.

### 11.4 `MIN_URC_COLLATERAL`

Set high enough that a single operator can absorb the worst-case combined
slash from all three slashers without becoming insolvent mid-fault:

```
MIN_URC_COLLATERAL ≥ MAX_PRECONF_SAFETY_SLASH
                   + MAX_LOOKAHEAD_SLASH
                   + MAX_PER_WINDOW_SLASH
```

Current `PreconfSlasherL1.getSlashAmount` returns `1 ETH` safety / `0.5 ETH`
liveness; `LookaheadSlasher` defines its own; `MAX_PER_WINDOW_SLASH` is
`2 ETH` per §5.4. Sum ≈ `5 ETH`, matching the recommended floor.

---

## 12. Contract changes

### 12.1 New files

| File | Purpose |
|---|---|
| `contracts/layer1/preconf/iface/ILivenessSlasher.sol` | Slasher interface, `LivenessCommitment`, `GapEvidence`, `GapKind`. |
| `contracts/layer1/preconf/impl/LivenessSlasher.sol` | Verification logic per §6.3. |

### 12.2 Modified files

| File | Change |
|---|---|
| `contracts/layer1/preconf/libs/LibPreconfConstants.sol` | Add constants from §3.2. |
| `contracts/layer1/preconf/impl/UnifiedSlasher.sol` (`:39-82`) | Add third routing branch for `LIVENESS_COMMITMENT_TYPE`. |
| `contracts/layer1/preconf/iface/IProposerChecker.sol` | Add `checkProposerForTakeover`. |
| `contracts/layer1/preconf/impl/LookaheadStore.sol` | Implement `checkProposerForTakeover`; require liveness opt-in in `_validateLookaheadOperator`. |
| `contracts/layer1/core/iface/IInbox.sol` (`:99-109`) | Extend `ProposeInput` with optional `bytes slashData`, `bytes32 slashRegistrationRoot`. |
| `contracts/layer1/core/impl/Inbox.sol` (`:206, :540-570`) | Insert two-stage takeover branch per §7.1; optional atomic URC slash per §7.2. |
| `contracts/layer2/core/Anchor.sol` (`:25-40`) | Support `EmptyBlockRun` decoding and anchor-on-run-start. |
| `docs/Derivation.md` (timestamp section) | Replace monotone rule with dense rule §4.2; document RLE encoding §4.4. |

### 12.3 Client changes

| Package | Change |
|---|---|
| `taiko-client/proposer/proposer.go` (`:392-411`) | Produce dense manifests; emit `EmptyBlockRun` when no txs are queued; observe head staleness and opportunistically post a takeover with attached slash evidence when the assignee is silent. |
| `taiko-client-rs/crates/proposer` | Same. |
| `urcindexer-rs` | Index `livenessSlasher` opt-ins alongside existing preconf/lookahead opt-ins. |

---

## 13. Roll-out sequencing

The design is intentionally splittable into four milestones, in order of
increasing surface area and decreasing reversibility.

### M1 — Substrate (monitor-only)

- Deploy `LivenessSlasher` + extend `UnifiedSlasher` (`§5.1, §5.2`).
- Require `livenessSlasher` opt-in in `_validateLookaheadOperator`.
- `slashingEnabled = false` (§11.1 soft-launch): full verification runs, no
  collateral debit.
- **No** dense-derivation rule yet. **No** takeover in `Inbox`.

Validates URC routing, bond pool composition, the commitment model, and the
gap-detection false-positive rate against live mainnet traffic before any
collateral is at risk.

### M2 — Forced empty blocks + RLE

- Implement dense-derivation rule (§4.2) under a feature flag.
- Add `EmptyBlockRun` to `Anchor.sol` and derivation.
- Update `taiko-client` to produce dense manifests.

Validates DA cost at 1-second block time before slashing teeth turn on.

### M3 — Fast takeover + atomic slash

- Implement `checkProposerForTakeover` and `Inbox.propose` two-stage trigger (§7.1).
- Implement optional atomic URC slash on takeover (§7.2).

This is the real-time liveness layer. After M3, chain head stalls > 24 s
trigger automatic handoff with bond loss.

### M4 — Retire `Blacklist`

After M1–M3 have been live for ≥ 1 month with non-trivial URC operator set:

- Verify no fault has occurred that required subjective intervention.
- Deprecate `Blacklist` overseer role; freeze `addOverseers` / `removeOverseers`.
- Remove `Blacklist` lookups from `LookaheadStore._validateLookaheadOperator`.

---

## 14. Open questions

The following are intentionally not specified by this document and require
either measurement, governance choice, or upstream coordination.

### 14.1 `MAX_GAP` floor under bad L1 weather

Historical mainnet missed-slot rate hovers around 0.5–1%. Three consecutive
missed L1 slots are rare but not impossible. The censorship exception is
**fully on-chain and automatic** (§6.4); the slasher itself enumerates the
gap range and queries EIP-4788 beacon roots, so the slashed operator
cannot be cheated by a challenger omitting legitimate missed L1 slots.

What remains open is **calibration of `MAX_GAP` against measured jitter**.
At 1-second L2 block time, with L1 censorship excised, the residual
gap distribution is dominated by propagation noise around L1 slot
boundaries. Until devnet/mainnet measurements are available, the soft-launch
mode in §11.1 covers the calibration risk: false-positives are observed
without collateral debit before `slashingEnabled` flips on.

### 14.2 Anchor cadence vs. RLE empty runs

Two acceptable shapes (§4.5). The choice is part of the L2 anchor specification
and depends on how stale L1 state visibility can be tolerated on L2 during
prolonged empty-run periods. Defer to the anchor-side specification.

### 14.3 Challenger payout split

URC's `ISlasher` returns a single `slashAmount`; the split between rescuer,
burn, and any treasury is URC-internal. Three options:

- Accept URC's default split.
- Wrap `LivenessSlasher` with a Taiko-side router that intercepts the
  payout and re-splits per `LibBonds`-style 50/50.
- Negotiate with URC upstream for per-slasher configurable split.

The choice affects (a) how attractive being a rescuer is and (b) the deflationary
profile of the bond. The 50/50 mirroring of `LibBonds.settleLivenessBond` is a
sane default.

### 14.4 URC commitment-authentication model for unsigned-by-default faults

URC's standard slashing entrypoint (`IRegistry.slashCommitment`) authenticates a
**signed** commitment from the operator before invoking the slasher. The existing
`PreconfSlasherL1` flow fits this model: the operator signs each `Preconfirmation`
during normal operation, and the slasher punishes safety/liveness violations of
something the operator signed.

`LivenessSlasher` as specified above breaks that pattern: the "commitment" is the
*lookahead hash* (derived from on-chain state, not signed per-window by the
assignee). A silent operator never signs anything, so there is no per-window
signed payload for URC to authenticate before calling the slasher.

The atomic slash in §7.2 requires this to be reconciled before implementation.
Four candidates, each with tradeoffs:

- **A. Standing opt-in as the signed commitment.** The operator's `livenessSlasher`
  opt-in signature (already required by §5.3) acts as a standing commitment
  authorizing slashing for *any* future window in which the operator appears in
  a posted lookahead. URC validates the opt-in signature once at slash time;
  per-window evidence proves lookahead membership + gap. This is the cleanest
  fit if URC supports a registration-bound slash entry. Requires verifying URC's
  API does in fact accept this shape (the current `slashCommitment(registrationRoot,
  SignedCommitment, evidence)` signature suggests it may not, in which case
  upstream change is needed).
- **B. Per-window pre-signed commitments.** Each operator pre-signs an "I will
  produce during window W" attestation as part of opting into the lookahead. The
  lookahead poster aggregates and posts these. A silent operator who refuses to
  pre-sign simply isn't included in the lookahead — moving the problem from "we
  can't slash silence" to "we can't include silent operators," which is a
  weaker but acceptable property if lookahead inclusion is genuinely permissionless.
- **C. Lookahead poster's signed commitment binds operators.** Reuse the
  `LOOKAHEAD_COMMITMENT_TYPE` signed commitment as the slashable authentication.
  Requires URC to support "this signed commitment authorizes slashing a third
  party," which is unconventional and likely not supported.
- **D. Upstream URC change.** Add a `slashRegistration(registrationRoot, evidence)`
  entry that authorizes the slasher based purely on the operator's slasher
  opt-in, no per-instance signed commitment. Cleanest model; requires upstream
  coordination with `eth-fabric/urc`.

Option **A** is preferred if URC's existing API already supports it (this needs
verification against the URC source vendored at `eth-fabric/urc`). If not,
**D** is the right long-term answer, with **B** as a fallback if upstream
coordination is slow.

### 14.5 Authenticated on-chain source for L2 block timestamps — RESOLVED

**Resolution: not needed.** The earlier draft of this design (commits
prior to `7b01e95`) used L2 block timestamp bookends (`firstL2BlockTs`,
`lastL2BlockTs`) on `Proposal` to verify `InternalGap` and
`ShortTrailingGap` faults. The §6.2 simplification to a single
`NoProposal` fault eliminated those evidence paths entirely. The slasher
now uses only `Proposal.timestamp` (L1) and `Proposal.proposer`, both
already present in the existing `Inbox.Proposal` struct
(`packages/protocol/contracts/layer1/core/iface/IInbox.sol:60-79`).

No protocol struct change is required for slashing. (Other workstreams —
e.g., MEV analytics, off-chain monitoring tools — may still want L2
timestamp bookends in `Proposal` for their own reasons; that decision
is independent of this design.)

The original concern (raised by automated review of the earlier draft)
was correct: even adding `firstL2BlockTs`/`lastL2BlockTs` would have
been problematic, because the default-manifest replacement (§4.3) makes
the *effective* on-chain L2 history diverge from what the proposer
declared in the bookends. Slashing on the declared bookends would have
slashed for gaps that don't exist on the chain. Eliminating that whole
class of evidence sidesteps the issue.

### 14.6 Lookahead-opening calldata cost in `GapEvidence`

The `GapEvidence` payload (§6.2) carries the full `LookaheadSlot[]` for
the relevant epoch so the slasher can reconstruct the committed
`lookaheadHash`. For a densely-populated epoch (up to 32 slots) plus
sparse-array overhead, this can dominate the slash transaction's calldata
cost and discourage rescuers from attaching evidence atomically (§7.2).

Two mitigations to consider:

- **Merkle proof against stored lookahead root.** Have `LookaheadStore`
  store the Merkle root of `LookaheadSlot[]` (in addition to or instead
  of the current `bytes26` keccak hash). `GapEvidence` then carries only
  the operator's single slot plus a log-depth Merkle proof. Slash cost
  becomes O(log N) in lookahead size rather than O(N).
- **Stored slot-by-slot lookahead.** Have `LookaheadStore` keep the
  individual slot entries on-chain (one storage slot per entry) instead
  of just the hash. Trades steady-state storage cost for slash-time
  calldata savings — likely the wrong tradeoff at current lookahead sizes,
  but worth re-evaluating if lookahead density grows.

Prefer the Merkle approach. The change is local to `LookaheadStore` and
`GapEvidence` and does not affect the broader slashing model.

### 14.7 Per-block proving load under dense empty-block cadence

Forcing an L2 block every second (§4.2) approximately doubles the L2
block count relative to a 2-second target and ~8x increases it relative
to the current observed sparse cadence. Each empty block still requires
a block header, a state root commitment, and a state-transition proof
slot in the proving pipeline. RLE (§4.4) addresses DA cost but does not
reduce the proving surface — each empty block in a run is still a
proven state transition.

Open work to scope:

- Measure prover gas and prove-time impact under dense empty-block load
  on devnet at the target cadence.
- If proving load is the dominant cost driver, consider a
  protocol-level "compressed empty-run state transition" (single proof
  covering N empty blocks at constant gas) — analogous in spirit to RLE
  but on the proving side rather than the DA side.

This is not a blocker for the slashing design but is a concrete
deliverable for whoever sequences the 1-second cutover (§14.8).

### 14.8 BLOCK_TIME_TARGET migration from 2 s to 1 s

Today `BLOCK_TIME_TARGET = 2 seconds` (`Derivation.md` constants table). The
design above assumes 1 s. The dense-derivation rule §4.2 is written in terms
of `BLOCK_TIME_TARGET`, so the cutover is parametric; what changes is:

- DA cost (doubles per window) — addressed by §4.4 RLE.
- `MAX_GAP` and `PER_SECOND_PENALTY` should be revisited at the new cadence.
- Proving load (§14.7) needs measurement at the new cadence.
- **`TIMESTAMP_MAX_OFFSET` must be narrowed.** Today's value (Hoodi
  `1536` ≈ 25 min, Mainnet `6144` ≈ 102 min) was set to absorb wide
  off-cadence batching; the dense rule (§4.2) renders large offsets
  meaningless and exploitable. After the cutover, `TIMESTAMP_MAX_OFFSET`
  should be at most a small multiple of one lookahead-window length
  (e.g., 384 s, one epoch), with the dense-timestamp rule taking
  precedence wherever they would conflict. A wide
  `TIMESTAMP_MAX_OFFSET` permits a proposer to push their L2
  timestamps far from the L1 proposal timestamp; the dense rule alone
  does not catch that drift, only its internal density. Narrowing
  `TIMESTAMP_MAX_OFFSET` makes the two rules consistent.

Migration is a separate fork operation; this document specifies the steady-state
behavior at the chosen cadence and is correct for either value of
`BLOCK_TIME_TARGET` once `TIMESTAMP_MAX_OFFSET` is set consistently.

---

## 15. Summary

| Concern | Status before | Status after |
|---|---|---|
| Silent operator (no signing, no submission) | Unslashable. | Slashable via `GapSlash` `NoProposal` fault (uses only on-chain L1 `Proposal.timestamp` and `Proposal.proposer`; no L2 timestamp authentication needed). |
| Sparse intra-window submission | Unslashable. | Soft penalty only: source replaced with default empty blocks (§4.3); operator loses MEV from the replaced portion. |
| Chain head stall | Permissionless mode opens after 25.6 h. | Permissionless mode opens after 48 s. |
| Liveness bond denomination | TAIKO (Inbox-managed); currently 0. | ETH in URC collateral, shared with safety bonds. |
| `Blacklist` overseers | Required for any fault outside the existing slasher set. | Redundant; deprecation path in §13 (M4). |
| L1 missed-slot attribution | Downgrades preconf fault to liveness fault. | Excises gap time entirely; honest operator owes nothing. |

The system continues to require only Ethereum validators (URC-registered) to
participate, but no longer requires owner-curated whitelists, owner-appointed
overseers, or signed-promise evidence for liveness accountability. Every
remaining gate is either an objective on-chain check or an opt-in to a slasher
backed by ETH collateral.
