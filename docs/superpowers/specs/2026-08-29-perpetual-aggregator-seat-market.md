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
- append-only Settlement-chain/version/address/code-hash/config-hash authorizations created only
  through the release manager.

The release-manager and migration-coordinator addresses are immutable constructor bindings.
Manager authorization/disablement and migration arm/abort reject every other caller.

It has no method that can mutate canonical chain state, select a proof, choose a candidate, or call
an operator-controlled target.

The release manager's append-only authorization is the static tuple:

```text
(settlementChainId, protocolVersion, settlement,
 settlementRuntimeHash, settlementConfigHash, market)
```

It deliberately excludes `seatGeneration`. Generation is mutable local Settlement state. For each
authorization, Market stores a separate monotone generation cache initialized and advanced only by
a permissionless exact-target static read. Offer insertion and requoting perform no Settlement call,
but require the cache to be initialized and the accepted generation to equal it before the quote can
enter ranking. A successful advance atomically removes at most the four old-generation pending
offers and converts their bonds to pull refunds; an old staged offer remains locked until its exact
Settlement tombstone is cancelled. A returned generation below the cache or any malformed target
read fails without mutation. Every stage/install still rechecks the current generation against the
exact authorized Settlement. Incrementing generation on migration arm, including across abort,
therefore invalidates old quotes without requiring a new governance authorization or permitting
refundable stale quotes to displace current offers.

The global four-cell pending book has exactly one `currentInstallationAuthorization`. The first
authorized target becomes current; later authorized targets remain installation-disabled. After a
successful protocol cutover, the release manager uses one atomic Market rotation from the exact old
authorization to an already-authorized new one. Rotation first performs the exact migration-stage
cancellation below when an old stage exists, then purges every old pending offer to pull refunds,
disables old insertion, makes the new authorization current, and leaves the new generation cache
uninitialized. Before any write, Market obtains exact return magic from its immutable release
manager proving that the immutable ActiveRouter currently routes the new authorization's Settlement,
the consumed manifest/generation binds both authorization commitments, the new Settlement is
`ACTIVE`, and the old Settlement is `FROZEN`. Manager identity alone is insufficient. A premature,
canceled, mismatched, or cutover-reorged rotation fails without mutation. If any proof, target read,
accounting delta, or acknowledgement fails, every effect reverts. Historical
premium, refund, breach-enforcement, and release methods remain callable through the disabled old
authorization. A migration abort performs no rotation: the old target remains current, its advanced
generation must be synchronized after Settlement returns to installation-open `ACTIVE`, and
operators must then submit fresh quotes. Generation sync is forbidden while the target is
`MIGRATION_ARMED`, `MIGRATION_READY`, or `FROZEN`; this prevents arm-generation quotes from maturing
into post-abort consent. Thus an old Settlement can neither refill nor displace the new target's
globally bounded book.

### 3.2 `Settlement`

Each immutable Settlement stores only the currently installed economic lineup, per-rank service
terms, at most one staged handover, at most `SEAT_COUNT` unresolved duties, recent duty history, and
immutable breach receipts retained until their tranches are terminal. These values are sufficient
to attribute an outage without calling the market.

Every installed offer creates one immutable `SeatTerm`:

```text
seatTermId
market
settlementChainId
protocolVersion
settlement
settlementRuntimeHash
settlementConfigHash
seatGenerationAtInstall
offerId and bondTrancheId
operator, askWeiPerSecond and payout
installedAt
lineupRevisionAtInstall
```

The local roster is a monotone `lineupRevision` plus one primary and up to three ordered standby
`seatTermId` values. Replacing the active term creates one fresh term and revision; untouched
standby term IDs do not change and are not reinstalled. Every revision satisfies
`primary.ask <= standby[0].ask <= standby[1].ask <= standby[2].ask`; standbys with equal asks are
ordered by ascending immutable pre-stage `offerId`. Promotion moves the next existing standby term to primary once;
it does not create or rebind that term.

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

Each predecessor duty-ring cell retains its own immutable successor record because selection and
service start are distinct:

```text
predecessorDutyId
successorSeatTermId
selectedLineupRevision
selectedAt
state (SELECTED, STARTED, VACATED, or EXCUSED_MIGRATION)
```

Settlement also stores one clearable `currentSuccessorDutyId` pointer. There are at most
`SEAT_COUNT` retained records; the pointer is cleared when the referenced record becomes terminal,
but the per-duty record is not overwritten until its ring cell is separately reclaimable.

At failover, a new roster revision moves the selected standby term to primary and compacts the
remaining standbys, but no `SeatService` exists for that primary while the selection is `SELECTED`.
The selected term remains installed, bonded, non-exitable, and ineligible for staging or another
promotion. Only the qualifying cure commit or the next usable recovery revision may change it to
`STARTED` and create its one service interval; that transition clears only the current pointer, so
the successor's later duty may select the next standby. An unusable/late revision changes it to
`VACATED` and, in one local non-fault roster revision, removes/closes the selected term and every
remaining standby, records each exact `termRemovedAt`, and leaves the roster empty. Their Market
reserves and bonds remain locked byte-for-byte until noncanonical reconciliation/release.
Migration performs the same full-lineup closure with `EXCUSED_MIGRATION`. No other transition may
clear the pointer or overwrite a retained record.

Every rule that says the seat becomes `vacant` uses one bounded local `closeLineupVacant` transition:
it increments `lineupRevision`, closes the served primary at the rule's objective effective time,
removes the primary and every remaining standby, records each term's actual `termRemovedAt` and
reason, invalidates any stage as `INVALIDATED_LINEUP`, and leaves an empty roster. It never calls
Market or changes ETH/accounting. Market reserves/bonds remain locked until exact later
reconciliation/release. This same transition is used for unusable successor, no-duty funding expiry,
duty-ring exhaustion, and any successor funding failure; none may leave hidden standbys behind.

The market accepts a premium cap, breach, or release statement only from the exact Settlement
chain, permanent address, version, code/config hashes, seat term, duty, and bond tranche recorded
when the term was installed.
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
quoteSequence
exitRequestedAt
status
acceptedSettlementChainId
acceptedSettlementVersion
acceptedSettlement
acceptedSettlementRuntimeHash
acceptedSettlementConfigHash
acceptedSeatGeneration
```

`exitRequestedAt` is `UINT64_MAX` when no exit has been requested. Exit intent is orthogonal to
offer location/status, but an exit-requested pending offer is infeasible for staging and application;
it can only finish its delayed refund. A staged offer cannot newly request exit. Installed terms
record their own exit request without changing installed/promotable status. Zero is a valid timestamp
and is never an unset sentinel.

Every offer escrows a distinct full native-ETH `SLA_BOND`. A tranche is single-service-term and
single-duty: once installed it cannot secure a later term, and once a recovery duty attaches
it can never receive another duty. One operator has at most one standing or installed offer per
tranche. An operator must explicitly bind its quote to the exact Settlement chain, version,
address, runtime hash, configuration hash, and current seat generation it accepts.

Offer insertion authenticates only the manager-authorized static target tuple and its initialized
Market generation cache; it records the operator's accepted generation and performs no Settlement
call. The target must also be the sole installation-enabled current authorization, and the accepted
generation must equal its cache. Anyone may call `syncSeatGeneration` with an
exact-target view before insertion; initialization or a monotone advance is atomic, and an advance
purges every bounded pending quote from the prior generation before a current quote can rank.
The exact target must report installation-open `ACTIVE`; migration/frozen phases fail without
changing the cache or book.
Leading sync at staging and the atomic install path independently read the exact authorized
Settlement generation. Thus a stale quote cannot enter or displace the current pending book, while
the insertion path remains isolated from Settlement failures.

Waiting offers rank by:

1. `askWeiPerSecond` ascending;
2. `eligibleAtTimestamp` ascending;
3. `eligibleAtBlock` ascending;
4. `quoteSequence` ascending; and
5. operator address ascending as a final total-order tie break.

An offer that cannot fill a free pending cell or strictly beat the worst pending offer reverts
without retaining funds. Displacement converts the old offer's bond into a pull refund; no ETH push
occurs. A lower ask or payout change is a new quote and resets both maturity clocks. Raising an ask
in place is forbidden. A live active or standby term cannot be evicted by a new pending quote.
An offer in `STAGED` status occupies its existing bounded cell, is non-displaceable and non-exitable,
and returns to pending or exits to pull refund only through the exact stage-expiry transition.

On release migration, the first successful generation sync makes pending offers bound to the old
generation refundable and removes them from the book in one bounded transition. The old staged
offer is handled only through its authenticated migration tombstone. No current-generation offer
can enter before that sync, and no old-generation offer can enter after it. V1 offer insertion is a
direct operator transaction:
`operator = msg.sender`; relayed signatures are out of scope. A target offer therefore requires a
fresh direct transaction accepting the target identity. Authorization of target code by the release
manager is not operator consent.

The book is not claimed to be a globally enumerable fair order book. A Sybil may occupy all entries,
but every entry requires a distinct fully funded slashable tranche and gains no consensus power.

### 4.1 Deterministic identities and commitments

All fields below use the fixed widths in the normative encoding appendix. `H(domain, fields)` is
legacy Keccak-256 over the ASCII domain followed by the fixed-width packed fields. The static target
tuple is always encoded inline in the order from section 3.1; no dynamic ABI encoding or silent
narrowing is permitted.

```text
authorizationCommitment = H("slot-chain-seat-authorization-v1",
  settlementChainId, protocolVersion, settlement,
  settlementRuntimeHash, settlementConfigHash, market)

bondTrancheId = H("slot-chain-seat-tranche-id-v1",
  settlementChainId, market, trancheCreationSequence, operator, slaBondWei)

offerId = H("slot-chain-seat-offer-id-v1",
  authorizationCommitment, acceptedSeatGeneration, bondTrancheId,
  operator, payout, askWeiPerSecond, eligibleAtTimestamp,
  eligibleAtBlock, quoteSequence)

seatTermId = H("slot-chain-seat-term-id-v1",
  authorizationCommitment, seatGenerationAtInstall, offerId, bondTrancheId,
  installedAt, lineupRevisionAtInstall)

lineupCommitment = H("slot-chain-seat-lineup-v1",
  lineupRevision, primarySeatTermId, standbySeatTermIds[0..2])

stageId = H("slot-chain-seat-stage-id-v1",
  authorizationCommitment, seatGeneration, offerId, outgoingSeatTermId,
  lineupCommitment, selectedRank, handoverAt, stageExpiresAt)

dutyId = H("slot-chain-seat-duty-id-v1",
  authorizationCommitment, seatTermId, lineupRevision, bondTrancheId, operator,
  rank, episode, eligibleRecoveryRevision, baseCanonicalHash, startingSequence,
  targetTipSlot, assignedAt, failoverAt, slashAt)

receiptId = H("slot-chain-seat-breach-id-v1",
  authorizationCommitment, dutyId, seatTermId, bondTrancheId, recordedAt)
```

Every tranche stores an immutable monotone `trancheCreationSequence` and its current live
`quoteSequence`/`offerId` binding. Requoting consumes a new monotone `quoteSequence` and `offerId`
but retains the original tranche ID only after the old quote is atomically terminated and the
current binding is replaced. Two live offers never share a tranche. Every counter is checked before
hashing. The identifier domains above exclude their own
result. Mutable record commitments use separate `...-record-v1` domains, include the derived ID and
all current state fields, and are never interpreted as the ID. Golden vectors cover cross-chain,
cross-version, cross-generation, field-mutation, maximum-width, and replay cases.

## 5. Premium Funding and Solvency

The market procures availability rather than selling consensus privilege. The active operator earns
its pay-as-bid `askWeiPerSecond`. Standbys earn no premium until promoted, but their first promoted
service runway is reserved before installation so canonical failover never creates an unfunded
obligation.

Each stage/term owns one segregated `PremiumReserve` with owner ID, purpose (`STAGE_ACTIVE`,
`STAGE_STANDBY`, `PRIMARY`, `STANDBY`, or `DUTY_TAIL`), `reservedWei`, `lastAccruedAt`, and—only
after service starts—`premiumFundedUntil`. `lastAccruedAt` and `premiumFundedUntil` are
`UINT64_MAX` while unstarted. The aggregate target below is the exact admission-time debit, not a
perpetual invariant and not an amount charged again on every lineup revision:

```text
requiredPremium =
    activeAskWeiPerSecond * primaryRunwaySecondsAtStart
  + sum(standbyAskWeiPerSecond * PROMOTION_RUNWAY_SECONDS)

primaryRunwaySecondsAtStart =
    ACTIVATION_RUNWAY_SECONDS  // direct/vacancy/competitive primary installation
    or PROMOTION_RUNWAY_SECONDS // promotion of a pre-funded standby
```

All multiplication is checked against an immutable maximum ask. Insufficient free premium creates
no stage, term, or lineup change; it never blocks settlement. A zero-ask volunteer posts the full
SLA bond, needs no reserve, and uses `UINT64_MAX` for both funding/service-eligibility sentinels.

Every reserve transition is atomic and uses these exact deltas:

- staging a direct primary debits `ask * ACTIVATION_RUNWAY_SECONDS` from `freePremium` into that
  stage owned by `stageId`; staging a standby insertion debits `ask * PROMOTION_RUNWAY_SECONDS`;
- applying a stage atomically rekeys that exact `stageId` reserve to `seatTermId` without another
  debit;
- expiring/canceling a never-served stage returns its entire reserve to `freePremium`;
- canonical promotion changes only Settlement: it records `responsibilityStart` and
  `premiumFundedUntil = responsibilityStart + PROMOTION_RUNWAY_SECONDS` while Market reserve bytes
  and bucket totals remain unchanged. The first later noncanonical accrue/reconcile authenticates
  that exact service and may rekey the reserve purpose with zero accounting delta;
- extending an active term moves exactly `ask * extensionSeconds` from free to that term and
  advances `premiumFundedUntil` by exactly `extensionSeconds` in the same revert domain;
- accrual moves exactly `earned` from that term's reserve to `premiumClaims` before any withdrawal;
- a noncanonical healthy handover/exit first settles earned premium through the authenticated cap,
  moves it to claims, and returns only the remainder to free premium;
- a canonical duty, failover, ring-full vacancy, or migration close performs no market call and
  frees nothing; a later reconciliation authenticates the stable Settlement cap, moves earned value
  to claims, retains any live duty tail, and only then returns the proven unearned remainder; and
- standby exit returns its full never-earned reserve only in the same transaction that removes the
  exact roster term. A selected successor cannot take this transition.

Before `finalizeRelease` can change any installed tranche to `RELEASED`, or breach enforcement can
change a duty-bound tranche to `SLASHED`, Market performs the exact closed-reserve reconciliation in
the same atomic transaction. A never-started standby reserve has earned zero and is returned in full
to `freePremium`. For a started service, Market authenticates the permanent Settlement cap/disposition,
accrues the earned amount to the immutable payout's claim credit, returns only proven unearned value
to `freePremium`, and deletes the term/tail reserve. Failure reverts the terminal tranche transition.
Pending/refundable offers have no premium reserve. Market exposes
`isDutyHistorySafe(dutyId, seatTermId, bondTrancheId)`, true only for the retained exact binding when
the tranche is `RELEASED` or `SLASHED` and no stage, term, or duty-tail reserve remains. Settlement's
noncanonical duty-cell reclamation must authenticate this exact predicate before overwriting the
retained duty record. Pull credits are independent of the reclaimed cell, so later claims remain
available.

Terminal reconciliation never bypasses delayed accrual. For a started service with a live reserve,
define `reserveMatureAt = settlementCap + PREMIUM_CLAIM_DELAY_SECONDS` with checked addition. Release
finalization and breach enforcement return too early while `block.timestamp < reserveMatureAt`.
At equality, `claimMaturedThrough >= settlementCap`, so ordinary accrual credits the full earned cap,
frees only the remainder, and can delete the reserve. If no reserve exists (including a zero-ask
term), or the reserve belongs to a never-started standby, `reserveMatureAt = 0`. A canonical breach receipt may still be recorded immediately after the
strict slash threshold; only Market's asynchronous economic enforcement waits for reserve maturity.

At all times `reservedPremium` equals the sum of live stage/term/tail reserve records. In addition:

```text
unstarted stage/standby reservedWei = ask * its frozen runway
started open service reservedWei = ask * (premiumFundedUntil - lastAccruedAt)
closed unreconciled reserve remains byte-for-byte unchanged
```

The second equality is restored after every accrual/extension; canonical closure deliberately
retains the third state until authenticated reconciliation. Repeated handover, stage expiry,
promotion, delayed claim, and migration reconciliation cannot double-reserve value or free a
liability.

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
claimMaturedThrough = 0 if now < PREMIUM_CLAIM_DELAY
                      else now - PREMIUM_CLAIM_DELAY
accrueTo = max(lastAccruedAt,
               min(claimMaturedThrough, settlementCap, premiumFundedUntil))
earned   = activeAskWeiPerSecond * (accrueTo - lastAccruedAt)
```

Accrual rejects an unstarted reserve; service start first replaces both `UINT64_MAX` sentinels in
the Settlement-authenticated view. The `max` prevents underflow before the claim delay matures.

`previewPremiumCap` is a local view that caps vesting at the earliest of `closedAt`, a latched
duty-success time, or the objective `failoverAt` of a missed duty. Without a live duty it also caps
at `serviceEligibleUntil`; with a duty attached before eligibility ended, the satisfaction/failover
cap governs the separately funded SLA tail. If canonical lag already implies
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
new responsibility ends non-fault at `serviceEligibleUntil`. Without a live duty, local sync uses
the full-lineup vacancy transition above, and `previewPremiumCap` derives the same objective cap even
before sync; the tail and standby reserves remain locked until noncanonical reconciliation. With a
live duty, unused tail funding remains reserved through its terminal deadline. A later seat requires
new delayed terms.

Global accounting maintains:

```text
accounted = bondEscrow + bondRefundCredits + freePremium + reservedPremium
          + premiumClaims + penaltySinkCredit

address(market).balance >= accounted
```

Forced ETH is surplus only. Every claim is pull-based and uses checks-effects-interactions.
Penalties cannot fund the duty or recovery episode that created them.

Premium top-ups are irrevocable protocol sponsorship, not refundable deposits. The protocol does
not track funder shares and has no `funderRefundCredits`; this avoids spending a pooled refundable
balance without a well-defined owner. Premium payouts, bond refunds, and the immutable penalty
sink each use separate authenticated pull functions.

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

Anyone may stage the objectively best mature **feasible** pending offer. Settlement scans the four
pending offers in their total market order and chooses the first offer for which one rank transition
in the table below is valid; the caller cannot choose. An infeasible lower ask is skipped and cannot
poison a valid standby insertion or other feasible transition. Installed standbys never participate in
ordinary competitive handover; the sorted-lineup invariant guarantees that none is cheaper than the
active when installed or promoted, and reserving them exclusively for incident promotion avoids a
term being simultaneously staged and canonically promoted. Staging:

1. performs a leading bounded Settlement synchronization;
2. stops if synchronization changed canonical/recovery state;
3. requires no migration arm and no already-provable missed seat duty;
4. atomically moves the pending candidate to `STAGED`, reserves its rank-specific runway, and
   makes its tranche non-displaceable/non-exitable;
5. records the exact selected rank and current lineup commitment; and
6. fixes `handoverAt = max(active.minimumTenureUntil, now + HANDOVER_DELAY_SECONDS)` for an active
   replacement and `handoverAt = now + HANDOVER_DELAY_SECONDS` for vacancy/standby insertion, then
   `stageExpiresAt = handoverAt + STAGE_GRACE_SECONDS`.

Only one handover is staged. A later lower ask remains pending for the next handover and cannot reset
the staged clock. The caller cannot choose a weaker offer. After `stageExpiresAt`, anyone may cancel
the exact still-`STAGED` record even if its lineup commitment is now stale, release its premium
reservation, and return its offer to pending. The operator may request exit only after that
transition. Expiry never changes incumbent tenure, duty, or responsibility.

The roster is always a contiguous sorted prefix of four ranks. For lineup length `n`, rank selection
is deterministic:

| Situation                                                                                               |                                                    `selectedRank` | Required effect at apply                                                                                   |
| ------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------: | ---------------------------------------------------------------------------------------------------------- |
| Vacant lineup (`n=0`)                                                                                   |                                                                 0 | Install the candidate as primary and start direct-primary service.                                         |
| Candidate satisfies active improvement, including when `n=4`                                            |                                                                 0 | Close/remove only the old primary; install candidate as primary; preserve every standby term ID and order. |
| Candidate does not replace active, `n<4`, and `ask >= active.ask`                                       | First insertion index in `[1,n]` under `(ask, offerId)` ascending | Insert as standby and shift later term IDs right without reinstalling them.                                |
| Candidate is cheaper than active but misses improvement, or candidate does not replace active and `n=4` |                                                              none | Staging reverts without reserving funds.                                                                   |

The `SeatStage` stores `uint8 selectedRank`, the exact outgoing primary ID or zero, and the current
lineup commitment. Rank tampering, a vacancy change, any promotion/exit, or any lineup revision makes
application fail. A local roster revision marks the retained stage `INVALIDATED_LINEUP` without a
Market call. Anyone may immediately call noncanonical `cancelInvalidatedStage` to authenticate that
tombstone, release the reserve, return the offer to pending, and clear the tombstone atomically; if
omitted, ordinary expiry can perform the same cancellation after `stageExpiresAt`. Migration instead
uses `INVALIDATED_MIGRATION` and makes the old-generation offer purgeable/refundable. An incident
always consumes the already installed standby order before any pending/staged quote.

### 6.3 Applying

Anyone may apply the handover after `handoverAt`. Application is a noncanonical maintenance
transaction. It:

1. performs another leading sync;
2. requires normal/healthy state, no migration arm, the exact staged offer, and unchanged maturity;
3. requires the chain to have at least `HANDOVER_HEADROOM` before the first recovery/failover duty
   threshold;
4. calls the market to consume the exact already-reserved offer/rank;
5. closes the outgoing half-open responsibility interval only for an active replacement;
6. creates the incoming `SeatTerm` at the frozen rank, increments `lineupRevision`, and leaves every
   untouched term ID unchanged; and
7. keeps the ordered live standbys immutable for any incident already observed before that write.

Any market/funding failure reverts only handover. The existing seat and consensus continue. An
unappliable stage cannot persist past its bounded expiry.

Vacancies and standby positions use the same delayed matching machinery. A new pending offer cannot
front-run promotion from the already installed standby order.

### 6.4 Exit

Active exit becomes effective no earlier than both minimum tenure and `EXIT_DELAY`. Standby/pending
exit uses its own delay. A request only records the earliest finalization time; it does not remove
eligibility or unlock funds.

Exact installed exit times are:

```text
pendingFinalizeAt = exitRequestedAt + EXIT_DELAY_SECONDS
standbyFinalizeAt = max(exitRequestedAt + EXIT_DELAY_SECONDS,
                        installedAt + MIN_STANDBY_TENURE_SECONDS)
directPrimaryFinalizeAt = max(exitRequestedAt + EXIT_DELAY_SECONDS,
                              minimumTenureUntil)
promotedPrimaryFinalizeAt = max(exitRequestedAt + EXIT_DELAY_SECONDS,
                                responsibilityStart + MIN_PROMOTED_SERVICE_SECONDS)
```

An installed standby remains promotable before `standbyFinalizeAt`. If it is promoted first, its
request is evaluated under the promoted-primary formula; a matured pending exit request can never
be carried into installation because staging rejects it.

After the delay, a pending offer exits entirely inside the market. An installed active or standby
uses one noncanonical atomic finalization transaction: Settlement performs leading sync and any
active health/tenure checks, consumes the exact market exit authorization, removes the term in a
new roster revision, and only then makes its reserve/bond eligible for delayed release. Until that
transaction succeeds, the term remains fully bonded and eligible for promotion. A staged term
cannot finalize exit until ordinary stage expiry or invalidated-stage cancellation. An exit request
cannot erase a duty, receipt, staged cutoff, selected-successor lock, or tranche reservation. A
standby removal compacts later standbys without changing their term IDs. A healthy active exit
promotes the existing first standby and starts its normal service atomically at the exit timestamp;
if none exists the roster becomes vacant. A `SELECTED` incident successor cannot exit or be removed
until it starts or is terminally vacated/excused by the rules in sections 7 and 9.

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

DELTA_SLASH_LAG >= DELTA_FAILOVER_LAG
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

`REORG_STABILITY_SECONDS` protects the nominal worst-case recovery completion point
`DELTA_RECOVERY_LAG + WORST_CASE_RECOVERY_SECONDS`; it is not a promise that every cure submitted
after operational failover receives a full reorg-stability interval before `slashAt`. A qualifying
commit included exactly at `slashAt` still cures the duty, but that satisfaction remains provisional
until the independent release/evidence reorg horizon passes. If the curing L1 commit is reorganized
out before then, the satisfaction latch rolls back with it and the canonical duty may again produce
a breach receipt. This exact-equality behavior is deliberate and must be covered by reorg tests.

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
delayed term is required. This is the full-lineup `VACATED` closure from section 3.2, not retention
of inaccessible standbys. A commit at exactly `promotedFailoverAt` cures the promoted duty.

When a primary duty is satisfied before failover, its single-duty term closes at `satisfiedAt` and
the next pre-funded standby starts normal service at that same commit timestamp with
`premiumFundedUntil = satisfiedAt + PROMOTION_RUNWAY_SECONDS`; it has no inherited duty. If the
primary is cured after failover but before a successor duty exists, the terminated primary remains
closed and the already-selected successor likewise starts normal service at the cure commit. Only
an outage still open when the next revision begins creates the round-bound promoted duty above. If
no standby exists, or its funding inequality fails, the seat becomes vacant. A lineup therefore
supplies at most four sequential single-duty service terms, with one retained successor record per
predecessor duty and a cleared current pointer after every start. Replenishment requires new delayed
term installations with fresh tranches.

### 7.3 Final slash

Once `block.timestamp > slashAt`, Settlement records a permanent unique `BreachReceipt` if the
original duty is still unsatisfied. At exact equality, a qualifying commit still cures. If recovery
landed after failover but by slash time, the primary remains terminated but its bond is not slashed.
This late-cure interval is shorter than
`REORG_STABILITY_SECONDS` under the prototype values; safety comes from retaining the tranche and
rechecking the canonical Settlement disposition through the separate release/evidence reorg
horizon, not from treating the entire failover-to-slash interval as finalized.

Canonical paths never call the market. Later, anyone presents the exact duty/receipt to the market.
The market verifies it directly against the exact authorized permanent Settlement, atomically
reconciles/deletes any closed term or duty-tail reserve as specified above, and only then moves the
matching tranche once from bond escrow to `penaltySinkCredit`. Enforcement is idempotent and cannot
affect canonical progress. Before `settlementCap + PREMIUM_CLAIM_DELAY_SECONDS` it returns too early;
a reconciliation failure leaves both reserve and tranche unchanged.

## 8. Bond Release

An offer or seat term requests release, then waits through an immutable challenge period. Final
release uses exact timestamps returned by the bound Settlement:

```text
dispositionAt =
    satisfiedAt                 if SATISFIED
    breachReceipt.recordedAt    if BREACHED
    migrationArmTimestamp       if EXCUSED_MIGRATION
    0                           if the tranche never had a duty

dispositionStableAt =
    dispositionAt + REORG_STABILITY_SECONDS   if dispositionAt != 0
    0                                         otherwise

lastLiabilityAt =
    0                                         if never installed
    termRemovedAt                              if installed but never served
    max(termRemovedAt, service.closedAt)       if served without a duty
    max(termRemovedAt, service.closedAt,
        duty.slashAt)                          if duty-bound

evidenceSafeAt =
    0                                         if lastLiabilityAt == 0
    lastLiabilityAt + EVIDENCE_DELAY_SECONDS
                    + REORG_STABILITY_SECONDS  otherwise

finalizeReleaseAt = max(
    releaseRequestedAt + RELEASE_CHALLENGE_SECONDS,
    dispositionStableAt,
    evidenceSafeAt)

reserveMatureAt =
    0                                           if no live reserve or reserve never started
    settlementCap + PREMIUM_CLAIM_DELAY_SECONDS otherwise

terminalReleaseAt = max(finalizeReleaseAt, reserveMatureAt)
```

All additions are checked. Release is allowed only at `block.timestamp >= terminalReleaseAt` and
requires:

- no live, standby, staged, or pending term using the tranche;
- no unresolved duty;
- the refund disposition is exactly never-duty, `SATISFIED`, or `EXCUSED_MIGRATION`—never
  `BREACHED` or `SLASHED`;
- direct authentication from the exact bound permanent Settlement that every retained duty is
  terminal, including its immutable `satisfiedAt`, `failoverAt`, `slashAt`, and receipt status.

`requestRelease` itself is permissionless and accepted only after a pending offer is refundable or
an installed term has been removed and its duty (if any) has one of the refundable terminal
dispositions above. It is one-shot, cannot reset any deadline, and never replaces a live
installed/duty lifecycle state. `finalizeRelease` is also permissionless and credits only the
immutable recorded operator's pull-refund balance; the caller cannot redirect value. An objectively failed duty must be
materialized as a terminal breach; absence of a receipt is never treated as success. A breached
tranche can only be idempotently moved to `penaltySinkCredit` (including atomically from a release
attempt), and can never create an operator refund. A receipt arriving during the challenge period
blocks release, and `finalizeRelease` repeats the exact Settlement read rather than trusting cached
market state. It atomically reconciles/deletes any closed term or duty-tail reserve before changing
the tranche to `RELEASED`; failure leaves the release unfinalized and the duty unreclaimable.
Withdrawal cannot race a late permissionless enforcement transaction. Every single-duty tranche
has a finite terminal-capital horizon derived from its duty: anyone may materialize a breach after
strict `slashAt`, enforce it asynchronously, or finalize a satisfied/excused release after the
terminal formula above. An uncooperative operator cannot pin a duty cell by refusing to request or finalize
release. Omitted maintenance cannot make recovery or canonical settlement wait.

## 9. Migration

Migration arming begins with the ordinary leading sync and mature-best commit. Any duty already
objectively slashable is materialized first. The same atomic local transition then:

- increments the monotone `seatGeneration`, permanently invalidating every old pending quote;
- closes every active/standby service term non-fault at the arm timestamp;
- terminally marks any selected-but-not-started successor `EXCUSED_MIGRATION` and preserves its
  predecessor/term binding for release authentication;
- marks each remaining unresolved duty `EXCUSED_MIGRATION` (or `SATISFIED` if the leading commit met
  it), which is terminal and non-slashable;
- invalidates the local staged handover while retaining an exact stage tombstone; and
- makes the Settlement economically vacant.

No market or ETH call occurs. Later premium/release reads recognize the exact local closure and
excuse. Migration arming blocks new staging, applying, premium extension, and offer installation but
does not block premium/refund claims, old breach enforcement, or duty-cell reclamation.

Anyone may call noncanonical `cancelInvalidatedStage`. The market authenticates the exact bound
Settlement's migration tombstone, deletes the exact stage reserve and moves its full `reservedWei`
from `reservedPremium` to `freePremium`, changes the staged offer to `REFUNDABLE`, changes its tranche
from `STAGED` to `REFUND_CREDIT`, moves the exact bond amount from `bondEscrow` to
`bondRefundCredits`, and atomically calls the exact Settlement to acknowledge and clear that
tombstone. It accrues no premium. The manager's installation rotation invokes this identical
transition atomically if an old stage exists before purging pending offers or changing the current
authorization. Until cancellation succeeds the tombstone remains queryable; any target-read,
bucket, or acknowledgement failure reverts the cancellation/rotation completely. Repetition cannot
credit the reserve or bond twice. An abort retains the incremented `seatGeneration`, does not rotate,
and may accept only quotes submitted after a successful post-abort `ACTIVE` generation sync.

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
- operator impersonation or unauthorized manager/coordinator transition;
- five-key tie ordering and independent timestamp/block maturity boundaries;
- infeasible cheapest offer poisoning a feasible later standby fill;
- wrong-chain authorization, quote, premium-cap, breach, and release replay;
- stale-generation refundable offers repeatedly displacing mature current offers before staging;
- an old but historically authorized Settlement refilling the global pending book after cutover;
- installation rotation re-included after a canceled or reorged cutover;
- an arm-generation quote maturing during migration and installing immediately after abort;
- quote improvement retaining old maturity;
- repeated requotes changing tranche identity or creating a second live binding;
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
- selected-rank tampering and insertion into every vacancy position;
- staged offer or premium reservation wedging the only stage;
- migration stage invalidation stranding its bond or premium reserve;
- handover into an already-stale chain;
- force-only recovery immunizing or resetting a duty;
- late catch-up erasing a missed duty;
- promotion onto an expiring recovery round;
- late primary cure leaving the selected successor in limbo;
- selected-successor exit/removal before service start;
- three sequential failovers overwriting predecessor successor history;
- unusable successor leaving hidden standbys or blocking later reinstallation;
- premium underfunding and funding expiry;
- unsynchronized funding expiry overpaying or leaving hidden standby liabilities;
- premium withdrawal before an unmaterialized objective failover;
- pre-delay accrual underflow and canonical promotion mutating Market reserve bytes;
- repeated handover/promotion/expiry double-reserving or prematurely freeing premium;
- withdrawal front-running breach enforcement;
- release finalization before a missed duty is materialized;
- breached tranche releasing bond value to its operator;
- duty-ring exhaustion blocking canonical recovery;
- a satisfied/excused operator refusing to initiate release and permanently pinning a duty cell;
- release or slash followed by duty-cell reuse before closed premium reserve reconciliation;
- breach enforcement deleting premium before the full Settlement cap is claim-matured;
- never-served standby or served-no-duty release becoming terminal before reserve reconciliation;
- canonical duty-cell reclamation calling the market;
- current router/target Settlement forging an old breach;
- reorg of handover, satisfaction, failover, or breach;
- exact-slash equality cure reorg followed by breach/enforcement/release;
- migration resetting duty history;
- migration making an old duty impossible to satisfy and then slashable;
- migration abort resurrecting a consumed term;
- old-target offers being installed against a new target without operator consent;
- pre-arm generation quotes resurrecting after migration abort;
- pending-exit installation or standby/promotion tenure bypass;
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
