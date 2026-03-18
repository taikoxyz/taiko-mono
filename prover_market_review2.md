# ProverMarket Review 2

_Date: 2026-03-18_

## Scope and methodology

This review treats the deployed code as the de facto specification and ignores the old design doc.

Primary files inspected:
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol`
- `packages/protocol/contracts/layer1/core/impl/Inbox.sol`
- `packages/protocol/contracts/shared/libs/LibAddress.sol`

Threat model used for this review:
- The DAO / owner is trusted not to act maliciously, but emergency paths should still be economically correct.
- Every proposer and prover may be malicious or colluding.
- A finding is severe if it can halt proposals, break proving liveness, let a prover profit from non-performance, or permanently corrupt bond / fee accounting.

This document is sorted by severity and focuses on **current** bugs, risks, and game-theoretic failures in the code.

---

## Critical

### 1. Active prover can halt all proposals by rejecting ETH

**Severity:** Critical

**Code path:**
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:361`
- `packages/protocol/contracts/shared/libs/LibAddress.sol:52`

`onProposalAccepted()` sends the proposal fee directly to the active prover:

```solidity
prv.sendEtherAndVerify(feeConsumed, _SEND_ETHER_GAS_LIMIT);
```

`sendEtherAndVerify` reverts if the receiver rejects ETH. That means the active prover can win the market with a contract whose `receive()` or `fallback()` always reverts, and from that point every proposal that owes a fee to that prover reverts.

**Attack sketch:**
1. Malicious prover bids and becomes active.
2. Their prover address is a contract that rejects ETH.
3. Any future `Inbox.propose()` that reaches `onProposalAccepted()` reverts while trying to pay the prover.
4. Proposal inclusion is halted until the prover exits, gets displaced, or governance intervenes.

**Impact:**
- Proposal-path liveness depends on an untrusted external ETH receiver.
- This is a direct chain-halt vector.
- The current design still has a proposal-path revert surface even though the market is supposed to be liveness-preserving.

**Fix direction:**
- Never transfer ETH to arbitrary provers on proposal acceptance.
- Move proposer payments into internal escrow / balances and pay on proof, not on assignment.
- Proposal acceptance should only mutate internal accounting.

---

### 2. `forcePermissionlessMode(true)` skips settlement entirely and can permanently strand bond accounting

**Severity:** Critical

**Code path:**
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:425`
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:447`
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:611`

When `permissionlessReason == 1`, `onProofAccepted()` does **nothing**:

```solidity
if (state.permissionlessReason != 1) {
    stateChanged = _settleProof(...);
    ...
}
```

That means proofs finalized while forced permissionless mode is enabled do not:
- release reserved bond,
- slash late provers,
- retire insolvent terms,
- release degraded-mode escrow.

Because proof settlement is only attempted for the newly finalized range, once the protocol finalizes those proposals while in forced mode, their corresponding market accounting is never revisited.

**Attack / failure sketch:**
1. A term has outstanding assigned proposals and reserved bond.
2. The protocol enables `forcePermissionlessMode(true)` to recover liveness.
3. Rescue provers finalize the stalled proposals.
4. The market skips all accounting for those finalized proposals.
5. Reserved bond for those proposals stays reserved forever, and delinquent provers escape slashing.

**Impact:**
- The emergency path can permanently corrupt market accounting.
- Honest rescue behavior can still leave prover balances stuck.
- The emergency switch disables accountability exactly when accountability matters most.

**Fix direction:**
- Forced permissionless mode must bypass **authorization only**, not settlement.
- `onProofAccepted()` must always release bond and settle slashes / rewards for finalized assigned proposals.
- The only thing emergency mode should relax is who may submit the proof.

---

### 3. Up-front fee payment plus fixed late-proof slash creates positive EV for malicious non-performance

**Severity:** Critical

**Code path:**
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:353`
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:625`

The active prover gets paid when proposals are accepted, before proving any work:

```solidity
uint256 feeWei = uint256(term.feeInGwei) * 1 gwei;
...
prv.sendEtherAndVerify(feeConsumed, _SEND_ETHER_GAS_LIMIT);
```

But late proving only applies a fixed slash once per accepted late proof:

```solidity
uint64 slashAmount =
    _slashPerProofGwei < acct.bondBalance ? _slashPerProofGwei : acct.bondBalance;
```

A malicious prover can accumulate fees across many assigned proposals and still face only a fixed penalty when a rescuer eventually proves the range.

**Game-theory failure:**
- Revenue scales with the number of assigned proposals.
- Penalty is fixed per late settlement event.
- If `assigned_fees > expected_slash + proving_cost`, rational non-performance is profitable.

**Attack sketch:**
1. A prover wins a term at a fee that looks competitive.
2. They accept many proposals and collect fees up front.
3. They stop proving.
4. After expiry, a rescuer proves the range and the delinquent prover loses only the fixed slash.
5. If the term accumulated enough fees, the malicious prover still comes out ahead.

**Impact:**
- The core economic mechanism does not make honest proving the dominant strategy.
- A rational malicious prover can choose to sell liveness risk to the protocol.

**Fix direction:**
- Pay on proof from escrow, not on assignment.
- Make the penalty scale with the liability created by the term, not with the existence of a proof event.
- At minimum, slash should be based on assigned proposal count or unpaid liability, not a flat constant.

---

## High

### 4. A prover can self-outbid into degraded mode with minimal capital because bids do not lock term-level stake

**Severity:** High

**Code path:**
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:227`
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:240`
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:264`
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:327`

`bid()` only checks that the bidder's `bondBalance >= _minBondGwei`. It does **not** lock a separate bid bond or term stake.

The same prover can also replace their own pending term without satisfying the pending-term undercut rule:

```solidity
if (state.pendingTermId != 0 && terms[state.pendingTermId].prover != msg.sender) {
    require(...);
}
```

And an active prover may bid against their own active term as long as they undercut it.

**Attack sketch:**
1. A prover becomes active.
2. The same prover repeatedly places lower bids against themselves.
3. Each new proposal retires the old active term and activates the prover's next self-bid.
4. `cap.unprovenTermCount` rises toward the degraded threshold.
5. The system enters `permissionlessReason == 2` without meaningful competitive pressure or new stake.

**Why this matters:**
- One prover can churn the market into degraded mode using one balance sheet.
- The code sells new exclusivity terms without requiring fresh collateral to back each term transition.
- The degraded-mode valve is supposed to protect liveness from churn, but the churn itself is cheap to manufacture.

**Fix direction:**
- Lock explicit stake per active/pending term.
- Prevent same-prover rebids from manufacturing new terms unless they genuinely improve price and re-post stake.
- Add an activation / replacement cooldown or minimum service interval before the same prover can rotate itself again.

---

### 5. Batch proving enforces exclusivity only for the first overlapped term

**Severity:** High

**Code path:**
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:404`
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:609`
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:615`
- `packages/protocol/contracts/layer1/core/impl/Inbox.sol:265`

Authorization is derived from `firstNewProposalId` only. `_settleProof()` finds a single `firstTermId` and checks only that prover during the exclusive window.

This means a batch can span multiple terms, but only the first overlapped term is used to decide whether the caller is authorized.

**Attack sketch:**
1. Term A owns the first proposals in the unfinalized range.
2. Term B owns later proposals in the same batch.
3. Term A's prover submits a large batch covering both A and B.
4. The batch passes authorization because the first proposal belongs to A.
5. Term B's exclusivity is bypassed.

**Impact:**
- Exclusivity is sold per term, but enforced per batch prefix.
- Later terms in a batch can be front-run or bypassed by the earlier term's prover.
- This weakens bidding incentives because exclusivity is not actually what bidders are buying.

**Fix direction:**
- Settlement must iterate over every distinct term overlapped by the batch.
- If per-term auth is too expensive, restrict exclusive-window batches to a single term.

---

### 6. Late-proof slashing only penalizes the first overlapped term in a batch

**Severity:** High

**Code path:**
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:609`
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:625`

The same first-term-only logic is used for slashing. If a late rescue proof spans multiple delinquent terms, only the first overlapped term is slashed.

**Attack sketch:**
1. Two adjacent terms both miss their proving windows.
2. A rescuer finalizes both in one batch.
3. Only the first delinquent term is penalized.
4. Later delinquent terms can escape accountability.

**Impact:**
- A prover can profit by making sure their term is not the first delinquent segment in the batch.
- Rescue rewards and slashing become path-dependent instead of liability-dependent.

**Fix direction:**
- Slash every overlapped term whose exclusive window has expired and whose assigned proposals were newly finalized by the batch.
- Slashing and reward accounting must be interval-aware.

---

### 7. Degraded mode currently waives exclusivity for all proofs, not just for newly permissionless proposals

**Severity:** High

**Code path:**
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:399`
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:400`

`canSubmitProof()` immediately returns `true` whenever `permissionlessReason != 0`:

```solidity
if (state.permissionlessReason != 0) return true;
```

That means degraded mode (`permissionlessReason == 2`) does not just stop assigning new exclusivity. It also opens proving for already-assigned proposals that are still inside their original exclusive windows.

**Impact:**
- Previously assigned terms lose exclusivity as soon as the market enters degraded mode.
- Bidders can pay / stake for exclusivity and then lose it because of unrelated churn pressure.
- A malicious churner can intentionally force degraded mode to break other provers' exclusive rights.

**Fix direction:**
- Distinguish between:
  - new proposals that should be born permissionless while degraded, and
  - old assigned proposals that should still honor their original exclusive windows.
- Permissionlessness should be attached to proposal intervals, not just a global mode bit.

---

### 8. The bounded 3-term walk is unsound because the current state machine can reach `active + 3 retired` terms

**Severity:** High

**Code path:**
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:327`
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:340`
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:656`
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:676`

Several helpers assume that at most 3 relevant terms need to be walked:
- `_findTermForProposal()` walks at most 3 terms.
- `_releaseReservedBond()` walks at most 3 terms.

But on the proposal that pushes `unprovenTermCount` to 3, the code sets degraded mode **and then still activates the pending term in the same call**. This can create a live state with:
- 1 active term, plus
- 3 retired but still relevant unproven terms.

In that state, a 3-step backward walk from the active term cannot reach the oldest retired term.

**Impact:**
- The oldest retired term may not be found for authorization.
- Its reserved bond may never be released when its proposals are finalized.
- Its late liabilities may escape proper settlement.

**Fix direction:**
- Do not rely on an undersized fixed walk bound for settlement correctness.
- Either cap the reachable chain length to match the walk bound exactly, or iterate over explicit interval metadata for every overlapped term.

---

## Medium

### 9. Disabling forced permissionless mode can route degraded-mode escrow to the owner

**Severity:** Medium

**Code path:**
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:467`
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:475`

When `forcePermissionlessMode(false)` is called, any remaining degraded-mode escrow is computed and sent to `msg.sender`:

```solidity
if (remaining > 0) {
    msg.sender.sendEtherAndVerify(remaining, _SEND_ETHER_GAS_LIMIT);
}
```

Even with an honest DAO, this is the wrong economic sink. Those funds came from proposers and were meant to compensate future proof submitters, not governance.

**Impact:**
- Emergency toggles can misroute user-paid funds.
- If the owner key is ever compromised, this becomes a direct extraction path.

**Fix direction:**
- Emergency mode should never redirect escrow to the owner.
- Preserve the escrow until it is either paid to a valid proof submitter or refunded via an explicit, interval-aware refund rule.

---

### 10. A pending bidder can raise its own fee before activation when no active term exists

**Severity:** Medium

**Code path:**
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:240`
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:248`

If there is no active term and the caller already owns the pending slot, the pending-term undercut check is skipped and the EWMA cap is also skipped because it only applies when both active and pending are zero.

This lets the same pending prover rewrite its own pending fee upward before activation.

**Attack sketch:**
1. Prover bids a low fee and becomes pending.
2. Before activation, the same prover re-bids a much higher fee.
3. The next proposal activates the higher-priced term.

**Impact:**
- Pending quotes are not credible commitments.
- Off-chain users can read a pending fee that the same prover can later worsen without competition.

**Fix direction:**
- A prover updating its own pending term should only be allowed to lower price or strengthen stake, never raise price.
- Better: represent each prover with a single standing quote instead of minting a fresh term on every bid.

---

### 11. Proposal-path refund still depends on an external call to the proposer

**Severity:** Medium

**Code path:**
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:379`

Excess ETH is refunded synchronously to the proposer:

```solidity
if (excess > 0) {
    _proposer.sendEtherAndVerify(excess);
}
```

This is not as bad as the active-prover payout issue because a proposer mostly harms itself, but it still means proposal acceptance depends on another untrusted ETH receiver.

**Impact:**
- Contract-based proposers can accidentally or intentionally make their own proposals revert via refund failure.
- Proposal acceptance remains coupled to external payment plumbing.

**Fix direction:**
- Track proposer credits internally and require exact payment or debit from credit.
- Avoid all arbitrary ETH sends on the proposal hot path.

---

## Low

### 12. Market-empty and permissionless-gap transitions are hard to monitor on-chain

**Severity:** Low

**Code path:**
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:315`
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:340`

The state machine can move into effectively permissionless gaps, especially when an active term exits and no replacement activates, but there is no dedicated event describing that transition.

**Impact:**
- Off-chain bidders and operators have to infer important mode transitions indirectly.
- This increases operational risk and slows competitive response.

**Fix direction:**
- Emit explicit events when:
  - the market has no active exclusive prover,
  - proposals are being born permissionless,
  - degraded mode changes,
  - forced permissionless mode changes.

---

## Overall assessment

The current implementation has a workable term skeleton, but its current economics and accounting are not production-safe.

The biggest blockers are:
1. proposal-path ETH-transfer DoS,
2. emergency-mode settlement bypass,
3. pay-on-assignment with fixed slash,
4. cheap self-churn into degraded mode,
5. first-term-only batch enforcement.

If this market is meant for production, the next revision should prioritize:
- no external ETH sends on proposal acceptance,
- pay-on-proof escrow,
- real locked stake for active/pending terms,
- per-term batch settlement,
- emergency modes that relax authorization without skipping accounting.

---

## Recommended redesign

This section describes the recommended production direction for the prover market, given the
constraints agreed during review:

- keep the overall market structure instead of replacing it entirely,
- allow moderate redesign of `ProverMarket`, `Inbox`, and the interface between them,
- optimize for **liveness first**,
- harden the design specifically against malicious proposers and malicious provers.

### Redesign goals

The redesigned market should satisfy the following invariants:

1. **Proposal acceptance must never depend on arbitrary external ETH receivers.**
   The proposal hot path should only update internal accounting.

2. **No prover should ever have positive expected value from taking assignments and then not
   proving them.**
   The protocol should make honest proving the dominant strategy.

3. **Emergency and degraded modes must only change authorization for future proving, not skip
   accounting for existing obligations.**
   Once a proposal is assigned and funded, its escrow and liability must settle deterministically.

4. **Exclusivity, liability release, and slashing must be enforced for every term overlapped by a
   proof batch.**
   The first proposal in a batch cannot act as a proxy for the entire range.

5. **Bids must represent real economic commitment.**
   A prover must not be able to churn terms, rewrite pending prices, or force degraded mode
   without posting additional locked stake or enduring explicit friction.

6. **Underfunded proposals must not create unpaid proving obligations.**
   If the proposer does not fund proving, the chain should stay live but the proposal should not be
   privately assigned to a prover expecting payment.

---

### 1. Core model: keep terms, change settlement economics

The recommended redesign keeps the **active term / pending term** structure, because it is a
reasonable way to express exclusive proving rights for a moving proposal stream.

However, the economic meaning of a term should change:

- a term is **not** an up-front revenue stream,
- a term is a temporary right to claim funded proving work,
- that right is backed by locked stake and per-proposal liability,
- revenue is earned only when proofs are actually delivered.

In other words: the market should sell a prover an **exclusive proving option**, not an
up-front cash coupon.

This preserves the current architecture while fixing the strongest game-theory failure in the
existing implementation.

---

### 2. Replace pay-on-proposal with escrowed pay-on-proof

#### Current problem

Today the active prover is paid at proposal acceptance time, before performing any work. That is
the root cause of both:

- the proposal-path ETH-transfer DoS, and
- the malicious-prover positive-EV non-performance problem.

#### Recommended mechanism

Each proposal should move through one of two states at acceptance time:

1. **Funded + assigned**
   - there is an active term,
   - the proposer has enough fee credit to fund the quoted fee,
   - the proposal is assigned to that term,
   - the fee is moved into **escrow** for that proposal interval,
   - the prover gets nothing yet.

2. **Unfunded / permissionless-from-birth**
   - the proposer does not have enough fee credit,
   - the proposal is still accepted for liveness,
   - but it is **not** assigned to the active term,
   - it is immediately permissionless,
   - no private proving obligation is created.

#### Consequences

- Proposal acceptance never sends ETH to the active prover.
- Proposal acceptance never refunds ETH to the proposer.
- A malicious proposer cannot create unpaid exclusive work for a prover.
- A malicious prover cannot collect cash and then disappear.

#### Payment flow

The cleanest production version is:

- add proposer fee-credit accounting,
- `Inbox.propose()` either consumes exact `msg.value` or debits stored credit,
- any surplus becomes **credit**, not an immediate refund,
- proof payouts become **claimable balances** withdrawable via a pull pattern.

This removes arbitrary ETH sends from the hot path entirely.

---

### 3. Split prover stake into two roles

The existing code has only one loosely enforced bond balance. That is not enough.

The redesign should split prover collateral into two logically separate pieces.

#### A. Quote / activation stake

This is stake locked while a prover owns the pending or active term.

Purpose:
- make market participation economically credible,
- make churn costly,
- prevent self-outbid term-spamming with one free balance check.

Rules:
- a prover may hold at most one market position at a time:
  - one pending term, or
  - one active term,
  - but not stacked self-generated future terms.
- updating your own pending quote may only:
  - lower the fee, or
  - increase stake,
  - never raise price.
- an active prover should not be able to mint a second future term for itself just by rebidding.
  If it wants to change price, it should publish a next quote that becomes eligible only after the
  current term retires.

This removes the cheap self-churn path that can currently drive degraded mode.

#### B. Assignment liability stake

This is stake reserved as proposals are assigned to the active term.

Purpose:
- scale the prover's downside with the amount of work and fee liability they accumulate,
- ensure that larger fee streams require larger reserved collateral,
- make late proving or non-proving unprofitable.

Recommended rule per proposal:

```text
reserved_liability_per_proposal = max(baseBondPerProposal, feeQuote * collateralMultiplier)
```

where `collateralMultiplier` is chosen so that the prover's loss from missing the deadline is
strictly larger than the fee they could have earned by delaying.

This is much better than a flat slash constant because it ties liability to the value at risk.

---

### 4. Make underfunded proposals permissionless instead of unpaid obligations

This is the main malicious-proposer hardening.

#### Current problem

Under the current structure, the market tries to keep liveness while still treating the active
term as entitled to the proposal. That only works if the proposer can always pay and the prover can
always be paid on the hot path. Both assumptions are unsafe.

#### Recommended rule

If the proposer does not fully fund the quoted proving fee, then:

- the proposal is still accepted,
- the proposal is **not** assigned to the active term,
- no prover liability is reserved,
- the proposal is born permissionless,
- an event should signal that the proposal bypassed the exclusive market due to insufficient funds.

#### Why this is the right liveness-first trade-off

- the chain never halts because a proposer forgot to fund proving,
- the active prover is never forced into uncompensated exclusive work,
- malicious proposers cannot weaponize underfunding to create toxic obligations,
- the market only controls proposals that are actually paid for.

This does mean a malicious or low-quality proposer can choose not to buy exclusive proving. That is
acceptable in a liveness-first design; it is far better than forcing honest provers to absorb
unfunded obligations.

---

### 5. Redesign proof authorization around the full batch, not the first proposal

The current interface is too weak because it gives the market only:

- `firstNewProposalId`,
- `lastProposalId`,
- a single age value derived from the first newly finalized proposal.

That is not enough information to reason correctly about multiple overlapped terms.

#### Recommended authorization rule

Before proof verification, `Inbox` should ask the market to authorize the **entire proof range**.

Conceptually:

```text
authorizeProof(caller, firstNewProposalId, lastProposalId, proofContext)
```

The market should then iterate over every distinct assigned interval overlapped by the batch.

The batch is authorized if, for every overlapped interval:

- it was permissionless from birth, or
- its exclusivity has expired, or
- the caller is the assigned prover for that interval.

If the batch overlaps multiple still-exclusive intervals owned by different provers, the market
should reject the batch. The caller must either:

- split the proof into smaller batches, or
- wait for the earlier exclusive windows to expire.

#### Why this is the right trade-off

It preserves batching whenever it is actually safe, but it does not sacrifice correctness to keep
all possible batch shapes valid.

That is the right production posture. If a batch shape cannot be safely authorized, the protocol
should reject it rather than silently stealing exclusivity from one prover to benefit another.

---

### 6. Redesign settlement to operate per interval

After proof verification, the market should settle **every overlapped funded interval** in the
batch.

For each overlapped interval, settlement should do all of the following:

1. release reserved liability stake for the newly finalized proposals in that interval,
2. determine whether the interval was proven on time or late,
3. compute the payout destination,
4. compute the slash amount,
5. update the active / retired term state if the prover becomes undercollateralized.

#### Recommended payout logic

**If the assigned prover proves on time:**
- credit the interval's escrowed fee to the assigned prover's claimable balance.

**If a different prover proves after expiry:**
- slash the assigned prover,
- credit the escrowed fee to the rescue prover,
- credit some or all of the slash bounty to the rescue prover.

**If the assigned prover proves late themselves:**
- still slash them,
- credit them at most the escrowed fee,
- do **not** credit them the rescue bounty.

This preserves a strong incentive to prove on time while still giving the delinquent prover a path
to finish the work if rescuers are absent.

#### Recommended slashing rule

Slashing should scale with liability, not with the existence of a proof event.

The simplest production rule is:

```text
late_slash = sum(reserved_liability_per_proposal for late proposals being newly finalized)
```

This is much better than a flat `slashPerProof` constant because:

- it scales with the amount of exclusive work the prover consumed,
- it naturally penalizes larger delinquent intervals more than smaller ones,
- it removes the current incentive to accumulate many fees and absorb one fixed slash.

---

### 7. Emergency and degraded modes should affect only future assignment

This is the main control-plane redesign.

#### Forced permissionless mode

When governance forces permissionless mode:

- new proposals are born permissionless,
- new exclusivity is not assigned,
- but **existing funded assigned intervals still settle normally**,
- late slashing still applies,
- reserved stake still releases,
- rescue rewards still pay out,
- no escrow is ever redirected to the owner.

The emergency switch should only relax **who may prove**, not erase the accounting of prior
obligations.

#### Degraded mode

Degraded mode should remain an automatic safety valve, but its semantics should be narrower:

- it stops granting **new** exclusive assignments,
- it does **not** cancel exclusivity already sold to existing funded intervals,
- it does **not** skip settlement,
- it does **not** globally make all old proposals permissionless.

In other words, degraded mode should be modeled as:

```text
future_assignment_mode = permissionless
existing_interval_mode = unchanged
```

That preserves liveness without retroactively breaking the market contract with already assigned
provers.

---

### 8. Replace global-mode inference with explicit interval state

The existing design relies too much on global flags like `permissionlessReason` and on backward
walks from the current active term. That is fragile.

The redesign should make assignment state explicit per interval:

- funded + assigned to `termId`, or
- permissionless from birth.

This does **not** require storing a full record for every proposal if gas becomes a concern.
The implementation can still store interval boundaries efficiently.

What matters is that settlement and authorization no longer have to infer correctness from:

- the current active term,
- a small retired-term walk bound,
- and a single global permissionless bit.

The safest production mindset is: if settlement correctness depends on a bounded inference trick,
the inference trick should not be the source of truth.

---

### 9. Malicious proposer analysis under the redesign

Under the redesigned system, a malicious proposer can still try to be disruptive, but their power
is intentionally narrowed.

#### Attack: refuse to fund proving

**Result under redesign:**
- proposal still lands,
- proposal becomes permissionless,
- no exclusive prover is harmed,
- no unpaid private obligation is created.

This is acceptable. A proposer is choosing not to purchase exclusive proving service.

#### Attack: use a refund-rejecting contract as proposer

**Result under redesign:**
- irrelevant on the hot path,
- no synchronous refund is attempted,
- surplus remains in proposer credit.

This attack disappears.

#### Attack: overpay or manipulate fee plumbing to cause reverts

**Result under redesign:**
- no external ETH sends occur during proposal acceptance,
- accounting is internal,
- proposal acceptance does not depend on untrusted receiver behavior.

This attack disappears.

#### Residual proposer power

The proposer can still:
- choose whether to fund proving,
- choose whether to use the exclusive market at all,
- create low-value permissionless proposals.

That is acceptable in a liveness-first system. The protocol should not try to force private service
onto unfunded users.

---

### 10. Malicious prover analysis under the redesign

This is the most important game-theory improvement.

#### Attack: bid, collect fees, then disappear

**Result under redesign:**
- impossible in the current form,
- fee is escrowed, not paid up front,
- no proof means no payout,
- late proof triggers liability-scaled slashing.

This attack is no longer positive EV.

#### Attack: self-outbid repeatedly to push the market into degraded mode

**Result under redesign:**
- a prover cannot stack future terms against itself for free,
- quote updates are monotonic improvements only,
- churn requires real locked stake or is structurally disallowed.

This attack becomes expensive or impossible.

#### Attack: exploit batch boundaries to steal other provers' exclusivity

**Result under redesign:**
- authorization runs over all overlapped intervals,
- conflicting still-exclusive owners force batch splitting or delay,
- no prover gets to use the first interval as a key for the rest of the batch.

This attack disappears.

#### Attack: wait for forced permissionless mode to avoid slashing

**Result under redesign:**
- forced mode does not bypass settlement,
- prior assigned intervals still slash if late,
- emergency activation no longer erases prover accountability.

This attack disappears.

#### Attack: hold exclusivity while undercollateralized

**Result under redesign:**
- every new assignment consumes real reserved liability,
- if the prover cannot support the next assignment, the term retires before assignment,
- if slashing leaves them undercollateralized, the term is retired and future proposals stop being
  assigned to it.

This makes insolvency self-limiting instead of contagious.

---

### 11. Concrete contract-level changes

The redesign likely requires the following code changes.

#### `ProverMarket`

- remove all proposal-path ETH sends,
- add proposer fee-credit accounting,
- add claimable ETH balances for provers / rescuers,
- lock explicit stake for pending / active participation,
- reserve per-proposal liability that scales with fee,
- store explicit funded-assigned vs permissionless interval state,
- replace first-term-only settlement with interval iteration,
- make forced permissionless mode bypass authorization only.

#### `Inbox`

- pass full proof-range context to the market before proof verification,
- make the single post-verify `onProofAccepted()` call perform both range-aware authorization and settlement,
- call a range-aware settlement hook after proof verification,
- treat market funding failure as “proposal accepted but permissionless,” not as a proposal revert.

#### `IProverMarket`

The interface should evolve away from “single first proposal age” semantics and toward
range-aware semantics.

At a high level, the market needs enough information to answer two questions correctly:

1. **Who is allowed to prove this exact range right now?**
2. **How should escrow, slash, and stake be settled across every funded interval in this range?**

If the interface cannot express those questions, it is too weak for a production exclusivity
market.

---

### 12. Rollout priority

The changes should be implemented in this order.

#### Phase 1: liveness blockers

- remove proposal-path ETH sends,
- stop forced mode from skipping settlement,
- prevent owner siphoning of degraded-mode escrow.

These are the fastest high-value safety wins.

#### Phase 2: economic hardening

- escrowed pay-on-proof,
- liability-scaled slashing,
- explicit pending/active stake,
- monotonic self-update rules for bids.

This phase fixes the core game theory.

#### Phase 3: batch correctness

- range-aware authorization,
- range-aware settlement,
- explicit interval state for funded vs permissionless proposals.

This phase makes exclusivity and slashing actually match the sold product.

---

### 13. Bottom line

The current implementation is close to a useful market skeleton, but not yet a production-safe
economic system.

The recommended production design is:

- **keep** the term-based market structure,
- **replace** pay-on-assignment with escrowed pay-on-proof,
- **require** real locked stake for both participation and assignment liability,
- **treat** underfunded proposals as permissionless from birth,
- **settle** proofs per funded interval, not per first proposal,
- **ensure** emergency modes never skip accounting for old obligations.

That is the best moderate-redesign path to a market that remains live under attack and is not
economically attractive to abuse.
