# Perpetual Aggregator Seat Market Design

**Status:** Approved direction: continuous reverse auction

**Purpose:** Replace Slot Chain v2.25's undefined auction-seat pointer with an implementable,
permissionless, bounded, non-exclusive service market.

**Normative precedence:** This specification is a normative amendment to Slot Chain v2.25. Until
the LaTeX, Appendix transition table, executable models, golden vectors, and PDF are regenerated to
match it, the design is internally inconsistent and Solidity implementation is blocked. Where the
v2.25 seat pointer, 3,600-second immediate-burn rule, or seat transition ordering conflicts with
this document, this document controls.

## 1. Safety Boundary

The aggregator seat is an economic availability obligation and public coordination role. It is not
a consensus authority.

- Anyone may post data, submit a normal or recovery proof, call `sync`, open or roll recovery,
  settle a valid candidate, or enforce an SLA record.
- Candidate validity, ordering, proof beneficiary, canonical settlement, forced ingress, recovery,
  and migration never require a seat signature or seat transaction sender.
- An empty offer book, vacant active seat, absent standbys, exhausted premium funding, broken market
  maintenance, or delayed economic enforcement changes no safety or chain-liveness bound.
- The market, premium ledger, bond ledger, operator, and payout address are never called from a
  canonical proof commit or recovery-opening path.

The protocol therefore remains permissionless while retaining a concrete primary and standby
service roster with objective accountability.

## 2. Why the Market Is Transparent

A genuinely sealed continuous auction is impossible under the selected bounded-state trust model.
Hidden commitments cannot be ranked until reveal; reveal periods recreate fixed auctions, an
unbounded commitment set creates unbounded storage, a bounded set is cheaply fillable, and threshold
decryption introduces a new trusted liveness dependency.

The perpetual auction is consequently a transparent standing reverse-ask market. Operators compete
to accept the lowest ETH-denominated availability premium. Updating an ask loses its existing
maturity. L1 ordering and offer visibility are explicit economic fairness residuals, not consensus
risks.

## 3. Components

### 3.1 `AggregatorSeatMarket`

`AggregatorSeatMarket` is a protocol-lifetime, non-proxy L1 contract. It owns:

- the bounded standing-offer book;
- native-ETH SLA bonds;
- free and reserved premium funding;
- accrued premium and refund pull credits;
- installed immutable seat-term and bond-tranche records;
- delayed release requests and asynchronous slash enforcement; and
- append-only Settlement-version/address/code-hash/config-hash authorizations created only through
  the release manager.

It has no method that can mutate canonical chain state, select a proof, choose a candidate, or call
an operator-controlled target.

### 3.2 `Settlement`

Each immutable Settlement stores only the currently installed economic lineup, per-rank service
terms, at most one staged handover, at most `SEAT_COUNT` unresolved duties, recent duty history, and
immutable breach receipts retained until their tranches are terminal. These values are sufficient
to attribute an outage without calling the market.

Every installed offer creates one immutable `SeatTerm`:

```text
seatTermId
market
protocolVersion
settlement
settlementCodeHash
settlementConfigHash
offerId and bondTrancheId
operator, askWeiPerSecond and payout
installedAt
```

The local roster is a monotone `lineupRevision` plus one primary and up to three ordered standby
`seatTermId` values. Replacing the active term creates one fresh term and revision; untouched
standby term IDs do not change and are not reinstalled. Every revision satisfies
`primary.ask <= standby[0].ask <= standby[1].ask <= standby[2].ask`. Promotion moves the next
existing standby term to primary once; it does not create or rebind that term.

When a term becomes primary, Settlement creates its separate `SeatService`:

```text
seatTermId
lineupRevisionAtStart
responsibilityStart
closedAt (one-shot, initially infinity)
minimumTenureUntil
premiumFundedUntil
serviceEligibleUntil
```

The five final fields are stored only when a term first becomes primary; an unpromoted standby has
no responsibility interval. A term is promoted at most once.
`responsibilityStart` is immutable. `premiumFundedUntil` may only increase while that rank is
primary. `closedAt` changes at most once from infinity to an exact handover, exit, duty-success,
failover, funding-expiry, or migration timestamp. New duties may arise only in the half-open interval
`[responsibilityStart, min(closedAt, serviceEligibleUntil))`; a duty created inside that interval
survives unchanged through its terminal deadline even if the service interval later closes.

The market accepts a premium cap, breach, or release statement only from the exact permanent
Settlement address, version, code/config hashes, seat term, duty, and bond tranche recorded when the
term was installed.
The currently routed Settlement cannot forge an old version's breach.

## 4. Bounded Standing Book

Protocol-lifetime geometry is one active rank, three standby ranks, and four pending offers:

```text
SEAT_COUNT = 4
PENDING_COUNT = 4
BOOK_SIZE = 8
```

These are immutable constants of this market deployment. A later release that changes capacity
must deploy a new market; the old market becomes installation-disabled but remains available for
claims, releases, and enforcement. Operators must explicitly quote into the new market.

Each standing offer contains:

```text
offerId
operator
payout
askWeiPerSecond
bondTrancheId
eligibleAtTimestamp
eligibleAtBlock
offerSequence
exitRequestedAt
status
acceptedSettlementVersion
acceptedSettlement
acceptedSettlementCodeHash
acceptedSettlementConfigHash
acceptedSeatGeneration
```

Every offer escrows a distinct full native-ETH `SLA_BOND`. A tranche is single-service-term and
single-duty: once installed it cannot secure a later term, and once a recovery duty attaches
it can never receive another duty. One operator has at most one standing or installed offer per
tranche. An operator must explicitly bind its quote to the exact Settlement version, address,
runtime hash, configuration hash, and current seat generation it accepts.

Waiting offers rank by:

1. `askWeiPerSecond` ascending;
2. `eligibleAtTimestamp` ascending;
3. `eligibleAtBlock` ascending;
4. `offerSequence` ascending; and
5. operator address ascending as a final total-order tie break.

An offer that cannot fill a free pending cell or strictly beat the worst pending offer reverts
without retaining funds. Displacement converts the old offer's bond into a pull refund; no ETH push
occurs. A lower ask or payout change is a new quote and resets both maturity clocks. Raising an ask
in place is forbidden. A live active or standby term cannot be evicted by a new pending quote.
An offer in `STAGED` status occupies its existing bounded cell, is non-displaceable and non-exitable,
and returns to pending or exits to pull refund only through the exact stage-expiry transition.

On release migration, pending offers bound to the old Settlement are permissionlessly purgeable
and cannot occupy or enter the target book. A target offer requires a fresh operator signature or
transaction accepting the target identity; authorization of target code by the release manager is
not operator consent.

The book is not claimed to be a globally enumerable fair order book. A Sybil may occupy all entries,
but every entry requires a distinct fully funded slashable tranche and gains no consensus power.

## 5. Premium Funding and Solvency

The market procures availability rather than selling consensus privilege. The active operator earns
its pay-as-bid `askWeiPerSecond`. Standbys earn no premium until promoted, but their first promoted
service runway is reserved before installation so canonical failover never creates an unfunded
obligation.

Before a lineup or newly filled rank becomes effective, the market reserves:

```text
requiredPremium =
    activeAskWeiPerSecond * ACTIVATION_RUNWAY_SECONDS
  + sum(standbyAskWeiPerSecond * PROMOTION_RUNWAY_SECONDS)
```

over every installed standby, with checked multiplication and an immutable maximum ask. Every rank
has a segregated reserve. Insufficient free premium creates no term or lineup change; it never blocks
settlement. A zero-ask volunteer still posts the full SLA bond.

The profile pins:

```text
SLA_TAIL_SECONDS = DELTA_SLASH_LAG - DELTA_RECOVERY_LAG
ACTIVATION_RUNWAY_SECONDS >= MIN_ACTIVE_TENURE + SLA_TAIL_SECONDS
PROMOTION_RUNWAY_SECONDS >= MIN_PROMOTED_SERVICE + SLA_TAIL_SECONDS
serviceEligibleUntil = premiumFundedUntil - SLA_TAIL_SECONDS
```

No new duty may attach unless its computed `slashAt <= premiumFundedUntil`. Funding expiry closes
only future service eligibility; a duty created before that cutoff and its tranche remain live
through `slashAt` and the release horizon.

Premium accrues lazily and only through authenticated service time:

```text
settlementCap = exact bound Settlement.previewPremiumCap(seatTermId)
claimMaturedThrough = max(0, now - PREMIUM_CLAIM_DELAY)
accrueTo = min(claimMaturedThrough, settlementCap, premiumFundedUntil)
earned   = activeAskWeiPerSecond * (accrueTo - lastAccruedAt)
```

`previewPremiumCap` is a local view that caps vesting at the earliest of `closedAt`, a latched
duty-success time, or the objective `failoverAt` of a missed duty. If canonical lag already implies
that a duty/failover should exist but no one has called `sync`, the view derives the same cap directly
from the stored canonical tip and term; omission of a maintenance transaction cannot increase
vesting. If the local duty ring has no reusable cell, it instead caps at the objective `recoveryAt`
when canonical sync would fail the economics open to vacancy. It cannot write state or call the
market. The reorg-safe claim delay is at least
`REORG_STABILITY_SECONDS`. Thus lazy processing cannot let an operator withdraw premium past an
objectively terminated service term.

Accrual moves value from the rank's reserved premium to the payout's pull credit. It creates no IOU.
Anyone may top up free premium and run a separate maintenance transaction to monotonically extend
the active rank's installed funded interval before `serviceEligibleUntil`. Extension updates market
reserve and the exact bound Settlement term in one revert domain; a partial extension cannot exist.
If no extension lands,
new responsibility ends non-fault at `serviceEligibleUntil`; unused tail funding remains reserved
only for an existing duty and otherwise returns to free premium. The economic seat then becomes
vacant until a later term is installed.

Global accounting maintains:

```text
accounted = bondEscrow + bondRefundCredits + freePremium + reservedPremium
          + premiumClaims + funderRefundCredits + penaltySinkCredit

address(market).balance >= accounted
```

Forced ETH is surplus only. Every claim is pull-based and uses checks-effects-interactions.
Penalties cannot fund the duty or recovery episode that created them.

## 6. Event-Driven Handover

The auction has no epochs. An active term persists indefinitely while funded and duty-free unless
it is competitively displaced, exits, incurs its single duty, or is non-fault terminated by
migration.

### 6.1 Maturity and improvement

A challenger becomes eligible only after both immutable timestamp and L1-block delays. It may
replace the active rank only if it improves the ask by at least:

```text
max(MIN_ASK_IMPROVEMENT_WEI,
    ceil(activeAskWeiPerSecond * MIN_ASK_IMPROVEMENT_BPS / 10_000))
```

The active rank remains protected until `minimumTenureUntil`. These rules prevent same-block and
one-wei churn without creating a fixed auction window.

### 6.2 Staging

Anyone may stage the objectively best mature pending offer. Installed standbys never participate in
ordinary competitive handover; the sorted-lineup invariant guarantees that none is cheaper than the
active when installed or promoted, and reserving them exclusively for incident promotion avoids a
term being simultaneously staged and canonically promoted. Staging:

1. performs a leading bounded Settlement synchronization;
2. stops if synchronization changed canonical/recovery state;
3. requires no migration arm and no already-provable missed seat duty;
4. atomically moves the pending candidate to `STAGED`, reserves its required active runway, and
   makes its tranche non-displaceable/non-exitable;
5. records the exact selected rank and current lineup commitment; and
6. fixes `handoverAt = max(minimumTenureUntil, now + HANDOVER_DELAY_SECONDS)` and
   `stageExpiresAt = handoverAt + STAGE_GRACE_SECONDS`.

Only one handover is staged. A later lower ask remains pending for the next handover and cannot reset
the staged clock. The caller cannot choose a weaker offer. After `stageExpiresAt`, anyone may cancel
the exact unchanged stage, release its premium reservation, and return its offer to pending or its
requested-exit bond to pull refund. Expiry never changes incumbent tenure, duty, or responsibility.

### 6.3 Applying

Anyone may apply the handover after `handoverAt`. Application is a noncanonical maintenance
transaction. It:

1. performs another leading sync;
2. requires normal/healthy state, no migration arm, the exact staged offer, and unchanged maturity;
3. requires the chain to have at least `HANDOVER_HEADROOM` before the first recovery/failover duty
   threshold;
4. calls the market to consume the exact already-reserved offer/rank;
5. closes the outgoing half-open responsibility interval;
6. creates the incoming active `SeatTerm`, increments `lineupRevision`, and leaves every untouched
   standby term ID unchanged; and
7. keeps the ordered live standbys immutable for any incident already observed before that write.

Any market/funding failure reverts only handover. The existing seat and consensus continue. An
unappliable stage cannot persist past its bounded expiry.

Vacancies and standby positions use the same delayed matching machinery. A new pending offer cannot
front-run promotion from the already installed standby order.

### 6.4 Exit

Active exit becomes effective no earlier than both minimum tenure and `EXIT_DELAY`. Standby/pending
exit uses its own delay. A request only records the earliest finalization time; it does not remove
eligibility or unlock funds.

After the delay, a pending offer exits entirely inside the market. An installed active or standby
uses one noncanonical atomic finalization transaction: Settlement performs leading sync and any
active health/tenure checks, consumes the exact market exit authorization, removes the term in a
new roster revision, and only then makes its reserve/bond eligible for delayed release. Until that
transaction succeeds, the term remains fully bonded and eligible for promotion. A staged term
cannot finalize exit until ordinary stage expiry or invalidated-stage cancellation. An exit request
cannot erase a duty, receipt, staged cutoff, or tranche reservation.

## 7. Fair SLA State Machine

The v2.25 immediate-burn rule is replaced. It was unsound because deterministic tier-3 recovery was
unavailable until the same instant at which the seat was punished for missing it.

The release pins three ordered lag thresholds:

```text
DELTA_RECOVERY_LAG
DELTA_FAILOVER_LAG
DELTA_SLASH_LAG
```

and enforces:

```text
DELTA_FAILOVER_LAG
  >= DELTA_RECOVERY_LAG + WORST_CASE_RECOVERY_SECONDS

DELTA_SLASH_LAG
  >= DELTA_RECOVERY_LAG + WORST_CASE_RECOVERY_SECONDS
   + REORG_STABILITY_SECONDS
```

With the current candidate geometry, the prototype values are:

```text
DELTA_RECOVERY_LAG = 1,200 seconds
WORST_CASE_RECOVERY_SECONDS = 2,164 seconds
DELTA_FAILOVER_LAG = 3,600 seconds
REORG_STABILITY_SECONDS = 1,800 seconds
DELTA_SLASH_LAG = 5,164 seconds
```

These remain production calibration inputs until the real proof benchmarks pass.

For a stalled canonical core with frozen `oldTipSlot` and `startingSequence`, Settlement derives:

```text
tipTime       = GENESIS_TIMESTAMP + oldTipSlot
recoveryAt    = tipTime + DELTA_RECOVERY_LAG
failoverAt    = tipTime + DELTA_FAILOVER_LAG
slashAt       = tipTime + DELTA_SLASH_LAG
targetTipSlot = oldTipSlot + DELTA_RECOVERY_LAG
```

All additions are checked in their declared widths. A threshold is missed only when
`block.timestamp > threshold`; a valid commit included at exactly the threshold cures it.
Permissionless `sync` first commits an already-mature valid normal best, if any, before deciding
that the lag threshold has been crossed. A satisfying commit must have
`newSequence > startingSequence` and `newTipSlot >= targetTipSlot`; advancing only one nearly empty
slot cannot discharge the duty. No caller timestamp or delayed maintenance transaction may move
these primary-duty instants.

### 7.1 Recovery duty

When canonical lag first exceeds `DELTA_RECOVERY_LAG`, Settlement first commits any already-mature
valid normal best; otherwise it opens permissionless recovery and creates one duty for the active
term. If a forced head opened recovery earlier, crossing the recovery-lag threshold attaches
the same duty inside the existing recovery episode. A force-only cause never resets, pauses, or
erases the timer.

Each duty stores:

```text
dutyId
seatTermId
lineupRevision
bondTrancheId
operator and rank
episode and eligible recovery revision
baseCanonicalHash and starting sequence
targetTipSlot
assignedAt
failoverAt
slashAt
satisfiedAt
status
```

Every canonical commit performs one fixed scan of at most `SEAT_COUNT` unresolved local duties. For
each satisfied target, the first such commit permanently latches `satisfiedAt=block.timestamp`.
Late catch-up cannot erase a missed deadline; an orphaned commit loses its latch with the L1 reorg.
Attaching the duty consumes that rank's single-duty tranche forever: once the duty succeeds or
reaches failover, the service term closes and the tranche remains retained only for release or
slash. It cannot receive a second duty or be silently renewed.

Duties use a fixed sequence-tagged ring. A separate noncanonical `reclaimDutyCell` transaction may
authenticate the exact market tranche as `RELEASED` or `SLASHED` after its reorg margin and cache a
local reusable flag. Canonical code never queries the market; it reuses only a locally flagged cell.
At most `SEAT_COUNT` predecessor/current duties may be simultaneously unresolved for one installed
lineup. If no cell is locally safe to reuse, canonical synchronization and recovery still proceed:
Settlement sets the term's `closedAt` to the objective `recoveryAt`, closes the economic lineup to
vacant, and creates no duty. Omitted reclamation or ring
exhaustion may disable optional seat economics but can never revert proof submission, recovery
opening, or canonical commit.

### 7.2 Operational failover

If the duty is not satisfied by `failoverAt`, anyone records an incident using local Settlement
writes, terminates the primary for future service, caps its premium at `failoverAt`, and selects
the next installed standby. No bond is burned yet. `previewPremiumCap` returns this objective cap
even before the incident-recording transaction is sent.

The promoted standby never inherits the expired duty. Its segregated premium reserve was locked at
lineup installation. At predecessor failover it becomes the selected successor, but its service and
premium do not start until the next recovery revision actually opens and exposes a usable tier-3
round. For an outage that has made no qualifying progress, the promoted duty is fixed as:

```text
promotedAssignedAt = GENESIS_TIMESTAMP + nextRound.roundStartSlot
promotedTargetTipSlot = nextRound.escapeSlot
promotedFailoverAt = promotedAssignedAt + WORST_CASE_RECOVERY_SECONDS
promotedSlashAt = promotedFailoverAt + REORG_STABILITY_SECONDS
promotedPremiumFundedUntil = promotedAssignedAt + PROMOTION_RUNWAY_SECONDS
```

The successor's `SeatService` starts at `promotedAssignedAt`. The new revision and deterministic
tier-3 proof are available within `WORST_CASE_RECOVERY_SECONDS`; model vectors must prove the round's
actual `expiresAt` and inclusion bound are compatible with `promotedFailoverAt`. Also,
`promotedSlashAt <= promotedPremiumFundedUntil` must hold. The contract does not roll a round early
and invalidate an already-generated proof. If the next revision is opened or processed too late for
that inequality or full proof runway, the standby is not framed: the seat becomes vacant and a new
delayed term is required. A commit at exactly `promotedFailoverAt` cures the promoted duty.

When a primary duty is satisfied before failover, its single-duty term closes at `satisfiedAt` and
the next pre-funded standby starts normal service at that same commit timestamp with
`premiumFundedUntil = satisfiedAt + PROMOTION_RUNWAY_SECONDS`; it has no inherited duty. If the
primary is cured after failover but before a successor duty exists, the terminated primary remains
closed and the already-selected successor likewise starts normal service at the cure commit. Only
an outage still open when the next revision begins creates the round-bound promoted duty above. If
no standby exists, or its funding inequality fails, the seat becomes vacant. A lineup therefore
supplies at most four sequential single-duty service terms; replenishment requires new delayed term
installations with fresh tranches.

### 7.3 Final slash

If the original duty is still unsatisfied at `slashAt`, Settlement records a permanent unique
`BreachReceipt`. If recovery landed after failover but by slash time, the primary remains terminated
but its bond is not slashed. This is the reorg-stability cure interval.

Canonical paths never call the market. Later, anyone presents the exact duty/receipt to the market.
The market verifies it directly against the exact authorized permanent Settlement and then moves
the matching tranche once from bond escrow to `penaltySinkCredit`. Enforcement is idempotent and
cannot affect canonical progress.

## 8. Bond Release

An offer or seat term requests release, then waits through an immutable challenge period. Final
release requires:

- no live, standby, staged, or pending term using the tranche;
- no unresolved duty;
- every last duty/final responsibility deadline plus evidence and reorg margins to have passed; and
- direct authentication from the exact bound permanent Settlement that every retained duty is
  terminal, including its immutable `satisfiedAt`, `failoverAt`, `slashAt`, and receipt status.

An objectively failed duty must be materialized as a terminal breach before release; absence of a
receipt is never treated as success. A receipt arriving during the challenge period blocks release,
and `finalizeRelease` repeats the exact Settlement read rather than trusting cached market state.
Withdrawal cannot race a late permissionless enforcement transaction. Every single-duty tranche
has an absolute release horizon derived from its finite duty; recovery cannot lock capital forever.

## 9. Migration

Migration arming begins with the ordinary leading sync and mature-best commit. Any duty already
objectively slashable is materialized first. The same atomic local transition then:

- increments the monotone `seatGeneration`, permanently invalidating every old pending quote;
- closes every active/standby service term non-fault at the arm timestamp;
- marks each remaining unresolved duty `EXCUSED_MIGRATION` (or `SATISFIED` if the leading commit met
  it), which is terminal and non-slashable;
- invalidates the local staged handover while retaining an exact stage tombstone; and
- makes the Settlement economically vacant.

No market or ETH call occurs. Later premium/release reads recognize the exact local closure and
excuse. Migration arming blocks new staging, applying, premium extension, and offer installation but
does not block premium/refund claims, old breach enforcement, or duty-cell reclamation.

Anyone may call noncanonical `cancelInvalidatedStage`. The market authenticates the exact bound
Settlement's migration tombstone, releases the stage-only premium reservation, marks the offer
purgeable/refundable, and atomically calls the exact Settlement to acknowledge and clear that
tombstone. Until this succeeds the tombstone remains queryable; failure cannot strand canonical
state or resurrect the stage. An abort retains the incremented `seatGeneration` and may accept only
fresh generation-bound quotes after the old tombstone clears.

At proof-first cutover:

- the old Settlement is already economically vacant;
- every old satisfied, excused, or breached duty remains verifiable only through that permanent old
  Settlement;
- the target Settlement begins economically vacant;
- no target inherits old confiscation authority or can rewrite old satisfaction;
- old-target pending offers become purgeable/refundable and can never be installed into the target;
- target installation requires an operator's fresh quote explicitly bound to the target version,
  address, runtime hash, and configuration hash, followed by the ordinary maturity and handover; and
- a failed cutover or delayed abort leaves canonical protocol state unchanged but never resurrects
  consumed seat terms, duties, or the invalidated stage; the old Settlement remains economically
  vacant and requires fresh exact-target quotes after abort.

Seat state and ETH are not moved between Settlement implementations. This removes token/ETH calls
from migration and prevents governance from resetting or fabricating historical liability.

## 10. Required Adversarial Tests

The implementation must cover at least:

- same-block and one-wei undercut takeover;
- quote improvement retaining old maturity;
- active repricing upward;
- standby promotion without a segregated premium runway;
- repeated duties or seat terms reusing one tranche;
- roster revision mutating or reinstalling an untouched standby term;
- exit/outbid responsibility laundering;
- one tranche reused across overlapping seat terms;
- pending-book Sybil saturation;
- live standby eviction and promotion front-running;
- market refund before atomic standby/active roster removal;
- offer withdrawal after learning a staged cutoff;
- staged handover replacement/reset grief;
- staged offer or premium reservation wedging the only stage;
- migration stage invalidation stranding its bond or premium reserve;
- handover into an already-stale chain;
- force-only recovery immunizing or resetting a duty;
- late catch-up erasing a missed duty;
- promotion onto an expiring recovery round;
- late primary cure leaving the selected successor in limbo;
- premium underfunding and funding expiry;
- premium withdrawal before an unmaterialized objective failover;
- withdrawal front-running breach enforcement;
- release finalization before a missed duty is materialized;
- duty-ring exhaustion blocking canonical recovery;
- canonical duty-cell reclamation calling the market;
- current router/target Settlement forging an old breach;
- reorg of handover, satisfaction, failover, or breach;
- migration resetting duty history;
- migration making an old duty impossible to satisfy and then slashable;
- migration abort resurrecting a consumed term;
- old-target offers being installed against a new target without operator consent;
- pre-arm generation quotes resurrecting after migration abort;
- malformed market/static-call return data; and
- every market, funding, premium, slash, or claim failure leaving proof submission and canonical
  recovery unaffected.

## 11. Release Parameters

The executable profile must freeze and validate all non-geometric parameters below. Book and rank
capacities are immutable market bytecode constants; changing them requires a new market and fresh
operator opt-in.

It validates:

- the expected market bytecode's book, active, standby, pending, staged, and duty-ring capacities;
- native-ETH bond floor/amount and maximum ask;
- absolute and relative minimum ask improvements;
- timestamp and block maturity delays;
- minimum active/standby tenure;
- handover, exit, pending-match, release-challenge, evidence, and claim horizons;
- premium activation runway and funding policy;
- per-standby promotion runway, `SLA_TAIL_SECONDS`, and the minimum-tenure/runway inequalities;
- premium claim delay and exact `previewPremiumCap` semantics;
- handover health headroom;
- recovery, failover, slash, and reorg-stability thresholds;
- deterministic offer, seat-term, lineup-revision, duty, satisfaction, incident, and breach
  encodings;
- monotone seat-generation encoding and invalidation rules;
- premium and penalty sinks;
- seat-term/duty history-ring capacities; and
- exact market/Settlement configuration and runtime hashes.

Calibration of premium funding, SLA bond size, and proof-performance timing remains a production
gate. Test fixtures must be marked tainted and production profile finalization must reject them.
