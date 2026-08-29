# Seat-Market Freeze Repair Design

**Status:** approved design for independent specification review

**Scope:** the seat-based perpetual reverse auction, premium accounting, migration, economic
configuration, bond release, and duty-history reclamation

**Implementation gate:** no Solidity implementation may begin until this repair is integrated into
the complete LaTeX specification, executable models, vectors, and circulated PDF and a final freeze
audit reports no critical or high defect.

## 1. Objective and non-negotiable properties

This repair keeps the seat-based design and its continuous reverse auction. It does not introduce
fixed auction windows, relayers, caller-selected winners, or a seatless fallback.

The repaired protocol must preserve all of the following:

1. Proof submission, canonical commit, forced recovery, recovery revision, and migration readiness
   never depend on a seat, operator, premium balance, or Market call.
2. Settlement alone owns the canonical roster, service intervals, duties, successor selection,
   recovery, migration state, and retained duty history.
3. AggregatorSeatMarket alone owns pending offers, native-ETH SLA bonds, premium custody, terminal
   credits, and reserve accounting.
4. Every canonical transition is bounded and performs no external call.
5. Every noncanonical economic transition is atomic or leaves the relevant component unchanged.
6. Each bond has exactly one terminal destination: its owner or the penalty sink.
7. Premium is never created, double credited, returned before it is proven unearned, or made
   spendable before its specified claim-maturity boundary.
8. Omitted maintenance can disable optional seat economics but cannot stop chain progress.
9. Every target, generation, term, duty, stage, reserve, and credit is exactly domain-bound.
10. All production parameters remain rejected while the economic profile is uncalibrated.

## 2. Alternatives considered

### 2.1 Patch the existing overloaded enums

This would retain one tranche enum containing location, liability, refund-accounting, and terminal
withdrawal states. It minimizes textual changes but leaves transitions such as
`REFUND_CREDIT -> RELEASE_REQUESTED` structurally expressible. It is rejected because later paths can
again overwrite an already-accounted refund or treat a stale Market duty cache as authority.

### 2.2 Put every bond through delayed release

This would send displaced pending offers, generation purges, stage cancellations, and installed
terms through one request/finalize pipeline. It is safe but needlessly locks never-installed bonds,
creates release records with no liability to challenge, and makes migration cleanup depend on more
maintenance. It is rejected.

### 2.3 Immediately settle every atomic healthy close

An atomic L1 handover can safely close Settlement, credit Market, and roll back all descendant L1
withdrawals together on a reorg. That is sufficient for canonical-L1 conservation. It is not
equivalent to the stronger promised property that an arbitrary payout cannot spend the value during
`PREMIUM_CLAIM_DELAY_SECONDS`: a payout can forward a one-confirmation withdrawal to a fast bridge,
exchange, or offchain counterparty that does not reverse its credit after the source reorg.

The protocol keeps the stronger property. A healthy close therefore credits only the mature prefix,
returns only proven unearned funding, and retains a closed tail until the claim delay expires.

### 2.4 Selected architecture

The selected design uses orthogonal offer location, tranche usage, bond disposition, and premium
reserve state. It also unifies direct and promoted primary tenure and runway. The extra runway
contains a funded handover-execution interval, so tenure expiry cannot race funding expiry and
invalidate an already staged challenger.

## 3. Authority and call graph

### 3.1 Settlement

Settlement is authoritative for:

- the installed primary and at most three installed standbys;
- immutable seat-term bindings and responsibility intervals;
- minimum-tenure, service-eligibility, funding, duty, failover, and slash timestamps;
- one staged-handover commitment and its invalidation tombstone;
- successor selection and duty disposition;
- `seatGeneration`, migration arm/abort state, and retained duty history; and
- a local reusable flag for each fixed duty-ring cell.

Canonical Settlement code never calls Market. If optional seat state is unavailable, stale, full, or
economically unmaintained, canonical code closes the affected economics to vacancy and continues.

### 3.2 AggregatorSeatMarket

Market is a protocol-lifetime, non-proxy L1 contract. It owns:

- four shared waiting-capacity cells, at most one of which may be held by the staged offer;
- one staged-offer record and its premium reserve;
- immutable offer, tranche, seat-term binding, reserve, and credit records;
- native-ETH bond escrow and premium buckets; and
- append-only exact Settlement authorizations installed through Release Manager.

Market has no migration coordinator and exposes no `armMigration` or `abortMigration` method. It
cannot mutate canonical chain state, choose a proof, select a candidate, or call an operator-controlled
target.

### 3.3 Release Manager and target reads

The non-proxy `ActiveSettlementRouter` is the protocol-lifetime root of the Settlement authority
graph. It immutably owns the shared migration gate, forced queue, inbox-apply router, and a read-only
`L1HeaderOracle` modeling the authenticated EIP-2935/system-history source, with exact immutable
`{address, runtimeHash, configurationHash}`. Bootstrap, `PREACTIVE` validation, activation, every
consensus read, and rollback validate and preserve those three values plus exact object identity. Every active,
`PREACTIVE`, and historical Settlement history and live Protocol must identity-alias those exact
objects; copy-equal, target-owned, or substituted sources fail closed. The Protocol's oracle,
queue/router, gate, and Settlement bindings are immutable during ordinary execution. EVM
`block.number` and `block.timestamp`, represented by one exact environment `Clock` in the model, and
the router-owned header oracle are the only time and L1-header authorities. A caller never supplies
an authoritative activation block, timestamp, header, or raw canonical core.

Release Manager owns the append-only target-authorization registry and executes Market rotation
against activation receipts read from the exact Router. The Router is the sole durable activation-
receipt store, including the successor index keyed by an old authorization ID; Release Manager has
no receipt mirror or recording fallback. Historical targets remain authenticated through their
immutable authorization and exact router-root graph. Their closed allowed surface is premium
accrual, premium-credit claim, reserve reconciliation, breach enforcement, installed release,
bond-credit claim, and duty-history safety/reclamation. Their closed forbidden surface is new
insertion or requote, stage/apply/expiry, new session or ingress, and every other install-side or
new-economic transition.

`syncSeatGeneration` is the offer-book module's sole permissionless Settlement read. It derives the
current authorized target rather than accepting a free address, then performs a gas-capped
`STATICCALL` with exact chain, version, address, runtime hash, configuration hash, return length, and
magic checks. The target may derive phase and generation only from the complete exact router-bound
graph: Router registration/route, History authority, HeaderOracle, migration gate, forced queue,
inbox router, and live Protocol aliases. Offer insertion, requote, pending exit/refund, and pulls
perform no Settlement read.

Other post-install Market operations may authenticate exact permanent Settlement records through
their separately specified bounded static-read interfaces. None accepts a caller-supplied authority
bit or operator identity.

## 4. Orthogonal lifecycle state

### 4.1 Offer location

```text
OfferLocation:
    NONE    = 0
    PENDING = 1
    STAGED  = 2
```

Only `PENDING` occupies a pending cell. Only `STAGED` occupies the single stage. Installation sets
the location to `NONE`; immutable `SeatTerm.offerId` retains the historical binding.

The stage retains the logical capacity of the pending cell from which it was selected. The invariant
is:

```text
pendingCount + stagedCount <= PENDING_COUNT
stagedCount <= 1
```

Staging changes `(pendingCount, stagedCount)` by `(-1, +1)`. While a stage exists, insertion may fill
or replace only the remaining pending capacity; it cannot consume the stage's reserved capacity.
Ordinary expiry or lineup invalidation changes the counts by `(+1, -1)` and therefore always restores
the exact offer without displacing, overwriting, refunding, or allocating a fifth pending entry.

### 4.2 Tranche usage

```text
TrancheUsage:
    OFFER               = 1
    STAGED              = 2
    INSTALLED           = 3
    CLOSED_UNINSTALLED  = 4
```

An installed tranche remains `INSTALLED` as historical usage even after its exact Settlement term
closes. Market does not maintain authoritative `DUTY_BOUND` or `REMOVED` caches, because canonical
duty attachment and closure cannot call Market.

Every tranche stores its immutable operator, bond amount, creation sequence, current offer binding,
installed term ID or zero, release-request timestamp or its explicit unset sentinel, and terminal
bond disposition.

### 4.3 Bond disposition and exact credits

```text
BondDisposition:
    NONE              = 0
    OWNER_CREDITED    = 1
    PENALTY_CREDITED  = 2
```

Terminal credit identity is:

```text
creditId = H(
    "TAIKO_SEAT_BOND_CREDIT_V1",
    marketChainId,
    market,
    trancheId,
    OWNER | PENALTY)
```

Each exact credit stores `beneficiary`, `amount`, and `claimed`. Aggregate credit buckets are
accounting summaries, not authority. Terminalization requires `disposition == NONE`, creates the
one deterministic credit, changes the disposition, and moves the exact bond amount out of
`bondEscrow` in one transition. A claim marks the exact credit claimed before its external transfer.
Claiming does not erase terminal history.

### 4.4 Exact bond transitions

| Event                        | Offer location      | Tranche usage                  | Bond disposition           |
| ---------------------------- | ------------------- | ------------------------------ | -------------------------- |
| Accept offer                 | `NONE -> PENDING`   | create `OFFER`                 | `NONE`                     |
| Pending displacement         | `PENDING -> NONE`   | `OFFER -> CLOSED_UNINSTALLED`  | `NONE -> OWNER_CREDITED`   |
| Pending generation purge     | `PENDING -> NONE`   | `OFFER -> CLOSED_UNINSTALLED`  | `NONE -> OWNER_CREDITED`   |
| Request pending exit         | `PENDING -> NONE`   | `OFFER -> CLOSED_UNINSTALLED`  | remains `NONE` until delay |
| Finalize pending exit        | unchanged           | unchanged                      | `NONE -> OWNER_CREDITED`   |
| Stage                        | `PENDING -> STAGED` | `OFFER -> STAGED`              | unchanged                  |
| Ordinary/lineup stage expiry | `STAGED -> PENDING` | `STAGED -> OFFER`              | unchanged                  |
| Migration stage cancellation | `STAGED -> NONE`    | `STAGED -> CLOSED_UNINSTALLED` | `NONE -> OWNER_CREDITED`   |
| Install                      | `STAGED -> NONE`    | `STAGED -> INSTALLED`          | unchanged                  |
| Request installed release    | unchanged           | remains `INSTALLED`            | unchanged                  |
| Finalize installed release   | unchanged           | remains `INSTALLED`            | `NONE -> OWNER_CREDITED`   |
| Enforce breach               | unchanged           | remains `INSTALLED`            | `NONE -> PENALTY_CREDITED` |

A pending exit removes the offer from ranking and capacity immediately but records
`pendingRefundAt = exitRequestedAt + EXIT_DELAY_SECONDS`. Its bond remains in escrow until a
permissionless finalization at or after that timestamp. A staged offer cannot request exit.

Never-installed tranches never call installed `requestRelease` or `finalizeRelease`. Installed
tranches never use the pending refund path. An installed release request cannot prevent later breach
enforcement; a valid breach terminalizes to the penalty credit instead.

## 5. Premium reserve lifecycle

### 5.1 States and authority

```text
ReserveLifecycle:
    ABSENT       = 0
    UNSTARTED    = 1
    OPEN         = 2
    CLOSED_TAIL  = 3
```

A stored reserve is owned by exactly one `stageId` or `seatTermId`. The model distinguishes the
derived start state `ABSENT | UNSTARTED | STARTED` from whether Settlement reports the term `OPEN` or
`CLOSED`.

Canonical standby promotion intentionally performs no Market call. The first later noncanonical
operation derives `STARTED` from the exact Settlement `SeatService` and lazily initializes Market
metadata. A Market sentinel is never sufficient to treat a canonically promoted service as
unstarted.

### 5.2 Bucket conservation

At all times:

```text
accountedMarketBalance =
    bondEscrow
  + outstandingOwnerBondCredits
  + outstandingPenaltyCredits
  + freePremium
  + reservedPremium
  + outstandingPremiumClaims

actualMarketBalance >= accountedMarketBalance

reservedPremium == sum(live PremiumReserve.reservedWei)
```

Forced ETH above the accounted amount is surplus and creates no credit.

### 5.3 Staging, installation, and promotion

Staging debits exactly:

```text
stageReserveWei = askWeiPerSecond * SEAT_RUNWAY_SECONDS
```

from `freePremium` to a reserve owned by the exact `stageId`. Applying a handover rekeys that record
to the exact `seatTermId` with no accounting delta. Ordinary expiry or lineup invalidation returns
the full unstarted stage reserve to `freePremium`. Migration invalidation does the same before
terminalizing the never-installed bond.

An installed standby remains unstarted and earns nothing. Every promotion reuses its exact untouched
reserve without a debit. Its first later noncanonical economic operation authenticates the exact
Settlement start.

### 5.4 Ordinary accrual

For a started service:

```text
settlementCap = exact bound Settlement.previewPremiumCap(seatTermId)
claimMaturedThrough = 0 if now < PREMIUM_CLAIM_DELAY_SECONDS
                      else now - PREMIUM_CLAIM_DELAY_SECONDS

accrueTo = max(
    lastAccruedAt,
    min(claimMaturedThrough, settlementCap, premiumFundedUntil))

earnedWei = askWeiPerSecond * (accrueTo - lastAccruedAt)
```

Accrual moves `earnedWei` from the exact reserve to the immutable payout's pull credit before any
withdrawal. All arithmetic is checked.

`previewPremiumCap` is a bounded local Settlement view and cannot depend only on a previously
materialized `closedAt`. It returns the earliest applicable cap implied by the surviving canonical
state, including:

- an immutable healthy or migration `closedAt` when present;
- an exact latched `satisfiedAt`;
- the objective `failoverAt` of an attached duty that has missed its qualifying commit;
- `serviceEligibleUntil` when no duty was attached before eligibility ended; and
- the objective `recoveryAt` at which an omitted leading sync would have closed seat economics to
  vacancy because the canonical lag was already due and no duty-ring cell was locally reusable.

If canonical tip/term state already proves that recovery, failover, funding expiry, or ring-full
vacancy should have occurred, the view derives the same cap even when no caller has materialized that
transition. A duty validly attached before `serviceEligibleUntil` keeps its separately funded SLA
tail and uses its satisfaction/failover cap. The view performs no write or Market call, scans only the
fixed seat/duty geometry, and cannot increase a cap because maintenance was omitted.

### 5.5 Healthy handover or healthy installed exit

The exact noncanonical close and Market accounting occur in one revert domain. Let:

```text
a = lastAccruedAt
f = premiumFundedUntil
c = min(authenticatedCloseAt, f)
m = max(a, min(c, now - PREMIUM_CLAIM_DELAY_SECONDS))
```

where subtraction saturates at zero and the transition requires `a <= c <= f`. It allocates:

```text
maturedWei  = ask * (m - a)
tailWei     = ask * (c - m)
unearnedWei = ask * (f - c)

maturedWei + tailWei + unearnedWei == preCloseReserveWei
```

The transition credits `maturedWei`, returns `unearnedWei` to `freePremium`, and rewrites the exact
reserve as `CLOSED_TAIL` containing only `tailWei` with:

```text
reserveMatureAt = c + PREMIUM_CLAIM_DELAY_SECONDS
```

If `tailWei == 0`, it deletes the reserve. Otherwise anyone may reconcile at or after equality,
credit the exact tail once, and delete the reserve. Bond terminalization and history reclamation are
forbidden while that reserve exists.

`authenticatedCloseAt` is produced by the exact authorized Settlement transition and is not a free
caller parameter. No ETH push occurs on close.

### 5.6 Canonical or asynchronous close

Duty completion, failover, funding expiry, ring-full vacancy, and migration close perform no Market
call and leave Market reserve bytes and buckets unchanged. A later Market operation authenticates
the exact permanent Settlement cap. Final reconciliation returns too early before:

```text
reserveMatureAt = settlementCap + PREMIUM_CLAIM_DELAY_SECONDS
```

At or after equality it credits all remaining earned value, returns only proven unearned value, and
deletes the reserve atomically. An unstarted standby has earned zero and returns its full reserve.

## 6. Perpetual reverse auction

### 6.1 Geometry and order

```text
SEAT_COUNT    = 4  // one primary plus three standbys
PENDING_COUNT = 4
MAX_STAGE      = 1

pendingCount + stagedCount <= PENDING_COUNT
```

The auction has no epoch or closing window. A healthy funded primary persists until competitive
handover, voluntary exit, its single duty, funding expiry, or migration.

Pending offers sort by:

1. `askWeiPerSecond` ascending;
2. `eligibleAtTimestamp` ascending;
3. `eligibleAtBlock` ascending;
4. `quoteSequence` ascending; and
5. operator ascending.

A fifth insertion must strictly beat the current worst pending offer under the full order or revert
without retaining funds. A successful displacement atomically creates the displaced owner's bond
credit. A stale target or generation cannot enter, rank, or displace.

### 6.2 Requote

Requote requires all of:

- caller equals the immutable operator;
- exact current offer/tranche binding;
- `OfferLocation.PENDING` and `TrancheUsage.OFFER`;
- no pending exit;
- exact current installation authorization and initialized generation cache;
- nonzero payout and an ask within the immutable maximum; and
- either a lower ask, or the same ask with a different payout.

An ask increase and a no-op revert. Requote retains the tranche creation identity, bond, and escrow;
it replaces the same pending cell with a fresh checked quote sequence/offer ID and resets both
maturity clocks. The superseded quote cannot be used again. No ETH moves and no Settlement call
occurs.

### 6.3 Unified primary tenure and runway

Direct and promoted service use one policy:

```text
SEAT_RUNWAY_SECONDS >=
    MIN_PRIMARY_TENURE_SECONDS
  + HANDOVER_EXECUTION_BUFFER_SECONDS
  + SLA_TAIL_SECONDS

HANDOVER_EXECUTION_BUFFER_SECONDS >=
    HANDOVER_DELAY_SECONDS
  + STAGE_GRACE_SECONDS
  + T_INCLUDE_MAX_SECONDS

SLA_TAIL_SECONDS = DELTA_SLASH_LAG - DELTA_RECOVERY_LAG
```

Every direct or promoted service start sets:

```text
minimumTenureUntil = responsibilityStart + MIN_PRIMARY_TENURE_SECONDS
premiumFundedUntil = responsibilityStart + SEAT_RUNWAY_SECONDS
serviceEligibleUntil = premiumFundedUntil - SLA_TAIL_SECONDS
```

`MIN_STANDBY_TENURE_SECONDS` remains separate because standby waiting is not service. Minimum primary
tenure gates only voluntary primary exit and competitive replacement. Duty completion, failover,
funding expiry, ring-full vacancy, and migration override it.

The common reserve cost `R(ask) = ask * SEAT_RUNWAY_SECONDS` is rank-independent and monotone in ask.
For sorted asks, if the first mature structurally feasible offer is underfunded at one fixed
`freePremium` snapshot, every later offer is also underfunded.

### 6.4 Permissionless bounded staging

Anyone calls `Settlement.stageBest()`. Settlement first performs one bounded leading sync.

- If that sync changes canonical or recovery state, the call returns successful `SYNCED`, performs
  no Market call, and permits only the exact Settlement delta.
- Otherwise Settlement supplies its exact lineup snapshot to Market in the same transaction.

Market owns the maximum-four scan because it owns pending order and `freePremium`. In total order it
skips offers that are immature, stale, exiting, or structurally unable to create one of these exact
transitions:

1. empty roster: install rank zero as direct primary;
2. qualifying improvement: replace only the healthy primary and preserve every standby ID/order;
3. non-replacing ask with fewer than four terms and `ask >= active.ask`: insert at the deterministic
   standby rank; or
4. otherwise: no transition.

The first structurally feasible candidate must satisfy the exact gross reserve debit. Staging never
anticipates release of the outgoing primary's reserve. Caller supplies neither offer nor rank.

Candidate selection, reserve debit, `PENDING -> STAGED`, and Settlement stage recording share one
revert domain. No candidate produces `NO_FEASIBLE_OFFER` with no Market mutation. The first
structurally feasible underfunded candidate produces `UNDERFUNDED` with no mutation; monotonicity
proves later candidates cannot succeed at that snapshot.

The stage stores selected rank, exact outgoing primary or zero, lineup commitment, and one of these
exact deadlines. It does not precommit a final `seatTermId`:

```text
handoverAt =
    max(active.minimumTenureUntil, now + HANDOVER_DELAY_SECONDS)
        if replacing an existing primary
    now + HANDOVER_DELAY_SECONDS
        if filling a vacancy or inserting a standby

stageExpiresAt = handoverAt + STAGE_GRACE_SECONDS
```

Vacancy has no primary tenure to read. Standby insertion does not remove or weaken the serving
primary and therefore never waits for its tenure. A primary's minimum tenure gates only its own
competitive replacement.

The lineup commitment excludes service clocks and prospective-duty fields:

```text
lineupCommitment = H(
    "TAIKO_SEAT_LINEUP_V1",
    lineupRevision,
    primarySeatTermId,
    standbySeatTermIds[0],
    standbySeatTermIds[1],
    standbySeatTermIds[2])
```

Absent cells use fixed zero placeholders. `lineupRevision` advances exactly once for each atomic
roster or role transition, including a compound primary replacement, and never for ordinary healthy
canonical progress that only refreshes a prospective duty base. Therefore such progress cannot
silently stale an otherwise live stage, while any genuine roster/promotion change is observable.

Admission additionally requires:

```text
stageExpiresAt + T_INCLUDE_MAX_SECONDS <= serviceEligibleUntil
```

for a live primary. A later quote cannot replace the stage or reset these times.

### 6.5 Apply and installed exit

Permissionless apply performs another leading sync and requires exact unchanged stage, lineup,
target, generation, health, maturity, and funded headroom. It atomically consumes the Market stage,
closes only an outgoing primary when applicable, installs the selected term, and preserves every
untouched standby ID. A failure reverts this noncanonical handover; the incumbent and canonical
chain continue. Apply is available only while canonical mode is `NORMAL` and the migration gate is
`ACTIVE`. Opening recovery permanently tombstones any surviving stage before returning `SYNCED`, so
a retry cannot consume a healthy-stage snapshot in recovery.

Apply derives the final immutable lifecycle identity only after its actual timestamp is fixed:

```text
installRevision = checked(lineupRevision + 1)
seatTermId = H(
    "TAIKO_SEAT_TERM_V1",
    authorizationCommitment,
    seatGeneration,
    offerId,
    trancheId,
    installedAt,
    installRevision)
```

Market rekeys the exact stage reserve and binds the tranche to that ID in the same revert domain in
which Settlement records the `SeatTerm` and sets `lineupRevision = installRevision`. Applying the
same stage at two different permitted timestamps therefore creates different term identities and
funding intervals. Timestamp, revision, authorization, generation, offer, or tranche substitution
cannot alias the term.

Primary voluntary exit uses:

```text
primaryExitAt = max(
    exitRequestedAt + EXIT_DELAY_SECONDS,
    minimumTenureUntil)
```

Standby exit also observes its independent minimum standby tenure. A selected successor cannot exit.
Only the immutable operator may create the one-shot installed exit request; finalization is
permissionless and performs a mandatory leading canonical sync. If that sync changes canonical or
seat state, finalization returns `SYNCED` with zero Market calls and recomputes occupancy, successor,
duty, and tenure on retry. The request never moves or refunds its bond. Until exact roster removal
succeeds, the term remains bonded and retains every existing duty liability. Funding expiry may
close service earlier than the requested exit because the protocol does not require unpaid service.
The installed term has one fixed runway: later sponsorship funds future admission and cannot extend
that term or move its immutable requested-exit deadline later.

Every exact roster removal records one immutable `termRemovedAt`, including replacement, voluntary
exit, satisfaction, failover, funding expiry, ring-full vacancy, and migration. A healthy voluntary
primary exit starts exact `standby[0]` atomically at removal under the common service-start policy;
it creates no `SelectionRecord`. Any already-activated predecessor duty remains independent retained
history. Funding expiry, by contrast, continues to use the selected-but-unstarted path below.

Leading sync orders an apparently healthy primary expiry behind every duty that was objectively due
through the cutoff. After replaying any already-accepted valid normal best that has matured, it
derives `recoveryAt` from the resulting immutable canonical tip before inspecting stored duty state.
If no such replay refreshed the interval and `recoveryAt < serviceEligibleUntil` with the strict
recovery boundary passed, sync must attach and process that duty, including any already-objective
failover or breach; it cannot launder the liability into a healthy expiry. Healthy expiry is
available only when `recoveryAt >= serviceEligibleUntil`, and closes the outgoing premium cap
exactly at `serviceEligibleUntil`.

Service start allocates no duty and consumes no ring cell. It stores an immutable prospective base
sequence/tip, target tip, and recovery/failover/slash thresholds for the next interval. A qualifying
ordinary canonical commit at or before the prospective recovery boundary keeps the primary serving
and rolls that prospective base to the newly adopted canonical tip. The same is true when a valid
normal best was accepted on time, became mature, and maintenance was then omitted: synchronization
replays that already-mature adoption first even if wall time crossed the old prospective
failover/slash thresholds, then evaluates the refreshed interval. It never fabricates an old duty.
A candidate submitted only after strict recovery cannot obtain this treatment because submit's
leading sync first materializes the miss.

Canonical synchronization performs exactly one fixed four-cell pass. If a mature normal adoption is
attempted, no seat write precedes successful canonical-history adoption. After adoption, that pass
applies objective failover/slash to already-activated duties before considering cure, captures the
first reusable cell and whether an SLA miss survives, and performs prospective/selection work in
constant time. Without a commit the same pass runs without cure eligibility. A commit after an
activated duty's strict failover first fixes the predecessor cap and may then satisfy it; a commit
after strict slash can advance canonical state but cannot cure `BREACHED`. Failed history adoption
restores the complete Settlement state, including counters and events.

A valid recovery submission uses only an O(1) round/mode preflight before history adoption and then
that single four-cell outcome-before-cure pass; it does not run a separate no-cure sync scan first.
An invalid recovery candidate instead runs ordinary sync exactly once, so due maintenance still
materializes and returns `SYNCED`. Satisfying a retained `FAILED_OVER` duty starts a successor only
when the current selection's exact `predecessorDutyId` equals that cured duty ID. An older duty can
never promote a successor selected for a later duty or for healthy expiry.

Every public canonical sync and composed Market/Settlement call is one rollback domain over the
exact bound Settlement history, forced queue, inbox router, migration gate, and Market where
applicable. The bound history must share those exact authority objects and point back to the live
Settlement before the first write. A failed transition restores each object in place and preserves
all aliases; it cannot replace authoritative collaborators with deep-copied lookalikes.

After that valid healthy close, sync moves exact `standby[0]` into the existing
selected-but-unstarted path with its identity, order, and reserve unchanged. It never starts service
merely because delayed maintenance materialized the expiry. The next qualifying canonical commit or
next usable recovery revision starts it at that event's canonical timestamp, with fresh thresholds
derived after selection and the normal runway/proof checks; failure vacates the full lineup. No
standby also means vacancy. This uniform delayed-start rule is never backdated and never assigns a
successor liability for an outage predating its responsibility. Canonical expiry/selection/promotion
makes no Market call; later Market reconciliation authenticates the permanent records.

A selected-but-unstarted successor created by healthy expiry counts as seatless for the existing
`DELTA_FINAL_LAG` / `G_MAX` permissionless recovery trigger. The selected pointer must not suppress
recovery. If lag is already strictly beyond that trigger when expiry is materialized, the same
leading sync also opens recovery without starting the successor. A later usable revision starts it
with fresh thresholds; an unusable revision vacates the full lineup. Thus absence of a normal commit
or forced ingress cannot lock the selected term or duty geometry indefinitely.

The common canonical-local usability predicate requires the exact canonical witness, required code
preimages, ready profile and configuration, feasible runway, and checked fresh-threshold arithmetic.
Both a qualifying commit and a recovery revision must pass it before assigning successor liability.

Successor selection is retained in an immutable standalone record with a unique `selectionId`, exact
term/tranche/offer binding, selection revision/time, and source `DUTY_FAILOVER` or
`HEALTHY_EXPIRY`. A duty-backed selection additionally binds the predecessor duty ID; a healthy
expiry selection has no predecessor duty and allocates no fake duty or ring cell. Start, exit lock,
recovery, replay protection, and history queries authenticate this record and its source.

## 7. Fair duty, release, and reclamation

### 7.1 Duty and fail-open behavior

Each installed tranche can secure only one seat term and one duty. Settlement owns a fixed
sequence-tagged duty ring. Every canonical commit scans at most `SEAT_COUNT` unresolved cells and
permanently latches exact qualifying satisfaction on the surviving L1 fork.

A prospective duty is allocated only after strict `now > recoveryAt`; equality remains curable and
does not consume a cell. If the one fixed scan finds no reusable cell, the same synchronization
vacates optional seat economics at objective `recoveryAt` and immediately opens recovery with the
SLA cause. It creates no duty, calls no Market function, and never delays core recovery to `G_MAX`.

The maximum duty sequence remains allocatable. The next strict prospective activation returns the
structured `SEQUENCE_EXHAUSTED` outcome and follows the same fail-open result as ring exhaustion: it
closes optional economics at objective `recoveryAt`, records `termRemovedAt` at the actual sync,
opens recovery immediately with the SLA cause, and creates no duty. It never reverts canonical
progress or backdates removal to responsibility start.

### 7.2 Installed release

Only a tranche with `TrancheUsage.INSTALLED`, `BondDisposition.NONE`, an exact closed Settlement term,
and a refundable terminal duty disposition may request installed release. Anyone may request release
for an eligible tranche. The request is one-shot/idempotent: it records the first timestamp and no
caller can reset or postpone it.

```text
dispositionStableAt =
    0                                      if no disposition timestamp
    dispositionAt + REORG_STABILITY_SECONDS otherwise

evidenceSafeAt =
    0 if never installed
    lastLiabilityAt
      + EVIDENCE_DELAY_SECONDS
      + REORG_STABILITY_SECONDS otherwise

finalizeReleaseAt = max(
    releaseRequestedAt + RELEASE_CHALLENGE_SECONDS,
    dispositionStableAt,
    evidenceSafeAt)

reserveMatureAt =
    0                                      if absent or truly unstarted
    settlementCap + PREMIUM_CLAIM_DELAY_SECONDS otherwise

ownerTerminalAt = max(finalizeReleaseAt, reserveMatureAt)
```

For an installed term, `lastLiabilityAt` is the maximum of immutable `termRemovedAt`, the applicable
service closure/responsibility basis, and any bound duty's `slashAt`. Delayed synchronization can
therefore lengthen, but never shorten, the evidence-safe release horizon.

Anyone may finalize at or after equality. Finalization rereads exact Settlement state, reconciles and
deletes the exact reserve, then terminalizes the bond only to the immutable operator's owner credit;
the caller cannot redirect it. A breached or unresolved duty cannot create an owner credit. An
uncooperative operator therefore cannot pin a terminal duty cell by refusing either release call.

### 7.3 Breach enforcement

A breach receipt may be recorded after the strict slash boundary without calling Market. Economic
enforcement waits until:

```text
penaltyTerminalAt = max(
    breachReceipt.recordedAt + REORG_STABILITY_SECONDS,
    reserveMatureAt)
```

It rereads the exact receipt and binding, reconciles and deletes the reserve, then terminalizes the
bond to the immutable penalty sink. It may override an earlier release request but can never override
an already terminal bond disposition.

### 7.4 Duty-history safety

Market exposes one monotone exact predicate:

```text
isDutyHistorySafe(dutyId, seatTermId, trancheId)
```

It is true only when:

1. the retained exact three-way binding matches;
2. the bond disposition is `OWNER_CREDITED` or `PENALTY_CREDITED`;
3. no live offer, stage, or roster occupancy uses the tranche, and no open or closed-tail reserve
   remains;
4. all release, evidence, reorg, and premium-maturity horizons were enforced; and
5. the terminal tranche can never bind another offer, term, or duty.

The immutable closed `SeatTerm` and exact three-way historical binding remain queryable forever;
their retention is required, not forbidden. Because terminal disposition is monotone and
terminalization already authenticated Settlement closure, the safety predicate is also monotone.

`reclaimDutyCell` is a noncanonical Settlement maintenance call with a mandatory leading canonical
sync. If that sync changes canonical recovery or seat state, the call returns `SYNCED`, performs no
Market call, and permits only the exact Settlement delta; the caller may retry reclamation afterward.
This prevents a late reclamation from turning an objectively ring-full recovery vacancy into a
retroactively attached duty or increasing `previewPremiumCap`. Otherwise reclamation authenticates
the exact Market safety predicate and caches a local reusable flag. Canonical code reads only that
flag. Actual withdrawal of any pull credit is irrelevant, so a beneficiary cannot pin history by
refusing to claim.

## 8. Migration

### 8.1 Globally authorized Settlement-local arm and abort

The non-proxy `ActiveSettlementRouter` remains the sole protocol-lifetime migration gate and owns
that exact immutable shared gate object. Its exact word binds `(routerGeneration,
activeProtocolVersion, targetProtocolVersion, targetManifestHash, phase)`. Every History and
Protocol must identity-alias the Router's gate, header oracle, forced queue, and inbox router before
bootstrap, arm, abort, activation, canonical recording, or rollback. Only
`ProtocolVersionManager` may consume the delayed exact arm or cancel manifest. Its Router, Release
Manager, Market identity, governance, and exact positive arm/cancel delays are immutable deployment
bindings.

Seat migration arm is not an independently callable Settlement function. In the same transaction and
revert domain as the globally authorized router `ACTIVE -> ARMED` transition, ProtocolVersionManager
first validates the exact current router word and delayed manifest, writes the exact ARMED word, and
then calls the exact old Settlement's manager-only completion callback. Settlement requires the
immutable manager caller, rereads the router word, and requires exact equality of router generation,
old/target versions, manifest hash, and `ARMED` phase. Any mismatch or local failure reverts the
global arm and every component delta.

The manager-only completion callback is explicitly not an ordinary state-mutating wrapper. It runs
the same bounded leading-sync logic internally but does not externally return the generic `SYNCED`
early-return status. If leading sync commits a mature candidate or changes mode, the callback
recomputes all seat inputs from the resulting local state and continues in the same transaction until
the local arm below is complete. No caller-supplied pre-sync lineup, duty, or stage snapshot survives
that change.

After that single leading sync and any mature-best commit, every already-objective slash is
materialized. The callback stores the exact router-generation/manifest binding and performs one local
transition that:

- increments monotone `seatGeneration`;
- closes active and standby services non-fault;
- terminally excuses any selected-but-not-started successor;
- marks every remaining unresolved duty `SATISFIED` or `EXCUSED_MIGRATION` as appropriate;
- invalidates the exact stage and retains its migration tombstone; and
- makes the Settlement economically vacant.

It performs no Market or ETH call. Exactly one local arm may consume a router generation; it checkedly
increments `seatGeneration` once. It then returns an exact fixed-length `SEAT_ARMED_MAGIC` response
binding the router generation, old/target versions, target manifest hash, and resulting
`seatGeneration`. ProtocolVersionManager must validate every field and the magic before its outer
arm call may succeed. A generic `SYNCED` value, empty/trailing returndata, or a partial binding always
reverts the global transition.

Abort is likewise reachable only through the matured exact global cancel-manifest transaction. In
one revert domain ProtocolVersionManager validates and marks that router generation canceled, writes
the exact old-version `ACTIVE` router word, and calls the old Settlement's manager-only abort
completion callback. Settlement authenticates the immutable manager, canceled generation,
old/target versions, target manifest, and new ACTIVE word. It runs the required bounded post-abort
sync internally, recomputes local inputs after any commit/mode change, records the exact local abort,
and returns fixed-length `SEAT_ABORTED_MAGIC` bound to the canceled tuple and retained
`seatGeneration`. ProtocolVersionManager validates that complete response; `SYNCED` alone never
acknowledges abort. Any mismatch or incomplete callback reverts the global abort. Abort never lowers
`seatGeneration` and never resurrects a term, duty, successor, quote, or stage. A later active
installation begins from the incremented seat generation.

Each post-abort response fault is tested in one retained fixture: the faulting transaction restores
the complete router/Protocol graph, clearing that fault permits exactly one authenticated cleanup,
and replay is rejected. This authenticated post-abort stage/tombstone cleanup never restores
consumed economics.

The existing global statement that cancellation changes no reservation or liability state remains
true for pre-arm builder/queue liabilities, but must not be read as restoring consumed seat state:
seat closures, excuses, generation increment, and stage tombstone created by the atomic arm remain
terminal across abort.

Old cached-generation insertions before the next Market sync are inert capital operations: they
cannot stage or install while Settlement is armed and are purged when generation is synchronized or
the target is rotated.

Activation accepts only a registered, independently constructed `PREACTIVE` target with the exact
router-owned authority aliases and completely empty non-imported transient state: no local
canonical-history entries, active/recovery context, candidates, sessions, seat terms/services/
duties/stages, tombstones, events, or aliased mutable containers. The exact sentinels are History
`currentSequence = -1`, `lastCanonicalBlock = 0`, and unset Router authority; Protocol
`seatGeneration = 0`, lineup revision, duty sequence, scan/query/GC counters all zero; and exactly
four default empty, reusable duty cells. Only immutable target configuration, the new Market
authorization binding, and the exact Router-shared authority aliases may already exist. The target
imports the exact proven admission version/root with the canonical core; queue capacity is immutable
profile configuration and must equal the old target. No other mutable predecessor state imports.
Its canonical
writer derives the core and block from the exact live Protocol plus environment `Clock`; only the
exact Router may install an imported initial history row. Raw public canonical/import writers do not exist. Activation and
rollback preserve every identity alias, switch old to `FROZEN` and successor to `ACTIVE`, and are
independent of Market availability or mutation.

### 8.2 Market synchronization and rotation

Equal generation sync is idempotent. A lower generation, malformed read, armed/non-installable phase,
or wrong authorization fails without Market mutation. A higher active generation atomically purges
at most four old pending offers to exact owner credits and writes the generation cache last. It does
not touch a staged offer; the authenticated tombstone path owns that transition.

Every successful Router activation writes one immutable receipt binding `routerGeneration`, old/new
protocol versions, old/new target addresses, target manifest, resulting `seatGeneration`, old/new
authorization IDs, activation block, and the optional exact migration `stageId` plus
`lineupCommitment`. It is keyed by router generation and manifest and indexed as the unique successor
of the old authorization ID. Rotation validates every payload field. That successor index is
valid even when aborted arms consumed intervening router generations. Market catch-up is O(1) per
call: `current_authorization_id` is the single installation pointer and rotation cursor, and one call
may consume exactly the receipt whose `old_authorization_id` equals that cursor. There is no separate
`currentInstallationTarget` state and no receipt scan.

Rotation verifies the exact immutable Release Manager/Router route, receipt, old/new authorization
commitments, old `FROZEN` phase, and receipt successor phase before mutation. When an old stage
exists, rotation first performs the identical authenticated migration-stage cancellation. It then
purges old pending offers, disables old insertion, installs the successor authorization, resets the
generation cache to `None`, advances `current_authorization_id`, and marks that receipt consumed.
If the successor is an intermediate `FROZEN` hop, it remains insertion-disabled with cache `None`;
the next call consumes one further successor receipt. Only the exact `ACTIVE` tip is enabled and may
resynchronize generation. Any failure rolls the complete Market/authorization/accounting state back.

On every authorized historical target, premium accrual and credit claim, reserve reconciliation,
breach enforcement and penalty claim, installed release and owner claim, and duty-history safety/
reclamation remain available. New insert/requote, stage/apply/expiry, session, and ingress surfaces
remain unavailable.

## 9. Economic profile

### 9.1 Asset-safe units and sinks

The profile uses asset-specific units:

```text
native amount = wei
native rate   = wei/second
builder amount = builder-lease-token atomic units
```

Builder fields are named `leasePerWindowAtomic`, `maximumBondAtomic`, and
`reporterRewardCapAtomic`. The token's exact chain, address, runtime hash, and decimals are profile
bound. Reporter reward comes from the slashed builder token:

```text
reporterReward = min(reporterRewardCapAtomic, builderSlashAmount)
builderPenalty = builderSlashAmount - reporterReward
```

There is one top-level source of sinks. Each sink binds `{asset, address}`. Builder penalty uses the
builder lease token; data rent, seat penalty, and forced expiry use native ETH. A nested
`dataSession.rentSink` is forbidden.

### 9.2 Production validation

A `CALIBRATED` profile must validate all existing arithmetic and at least:

```text
PREMIUM_CLAIM_DELAY_SECONDS >= REORG_STABILITY_SECONDS

SEAT_RUNWAY_SECONDS >=
    MIN_PRIMARY_TENURE_SECONDS
  + HANDOVER_EXECUTION_BUFFER_SECONDS
  + SLA_TAIL_SECONDS

HANDOVER_EXECUTION_BUFFER_SECONDS >=
    HANDOVER_DELAY_SECONDS
  + STAGE_GRACE_SECONDS
  + T_INCLUDE_MAX_SECONDS

SLA_BOND_WEI >=
    MAX_ASK_WEI_PER_SECOND * PREMIUM_CLAIM_DELAY_SECONDS

SLA_BOND_WEI >=
    MAX_ASK_WEI_PER_SECOND * MIN_PRIMARY_TENURE_SECONDS
  + MAX_AVOIDED_SERVICE_COST_WEI
  + COLLUSION_SAFETY_MARGIN_WEI
```

All additions and multiplications are checked. Production validation rejects missing/unknown keys,
wrong unit strings, wrong sink assets, zero required identities, inconsistent chain IDs, malformed
decimal strings, and every `UNCALIBRATED` or null required field.

The last two inequalities bound, respectively, cheap closed-tail capital grief and the direct
protocol subsidy available when one economic actor intentionally fails a predecessor to promote its
own maximum-ask standby. They do not claim to price unbounded external harm.

## 10. Executable model and test requirements

### 10.1 Required artifacts

The same commit series must create or update:

- `packages/protocol/docs/preconfirmation-v2/seat-market-model.py`;
- `packages/protocol/docs/preconfirmation-v2/test-seat-market.py`;
- `packages/protocol/docs/preconfirmation-v2/test-settlement-window.py`;
- `packages/protocol/docs/preconfirmation-v2/economic-profile.example.json`;
- `packages/protocol/docs/preconfirmation-v2/settlement-window-model.py`;
- `packages/protocol/docs/preconfirmation-v2/commitment-model.py`;
- `packages/protocol/docs/preconfirmation-v2/tex/main.tex`;
- `packages/protocol/docs/preconfirmation-v2/slot-chain-spec.pdf`;
- `packages/protocol/docs/preconfirmation-v2/README.md`; and
- `script/slotchain/check-slot-chain-docs.sh`.

### 10.2 Minimum transition coverage

Tests cover every allowed state edge above and reject every other edge. Required composed cases
include:

- fifth-offer displacement and full deterministic ordering;
- stage from a full pending book, insertion/displacement while staged, then ordinary expiry and
  lineup invalidation, proving `pendingCount + stagedCount <= 4` throughout;
- pending-only requote across every nonpending usage/location;
- pending exit freeing capacity but not bond before equality;
- exact before/equality/after quote maturity;
- unified direct/promoted reserve debit and service start;
- monotone funding fuzzing and structurally infeasible poison skipping;
- one-wei-under/equal funding and gross-reserve staging;
- empty-roster staging without a tenure read and standby insertion before incumbent tenure expiry;
- a funded post-tenure interval that survives sync ordering and timestamp skips;
- healthy-close matured/tail/unearned conservation;
- closed-tail maturity before/equal/after and repeated reconciliation;
- omitted sync past objective recovery/failover/funding expiry cannot increase `previewPremiumCap` or
  withdrawable premium, including the ring-full vacancy cap;
- canonical promotion followed by lazy start authentication;
- owner-versus-penalty terminal exclusivity under release/breach races;
- four satisfied/excused operators refusing all actions cannot prevent permissionless release
  request, finalization, and later duty-cell reuse;
- exact-credit replay, malicious payout, reentrancy, and forced ETH;
- arm/abort leaving every Market byte, bucket, and ETH balance unchanged;
- router/local arm and abort mismatch, duplicate-generation, wrong-manifest, wrong-version, wrong
  phase, unauthorized caller, and partial-transition rollback;
- arm with a mature candidate committed by leading sync, and abort whose internal sync changes mode,
  proving that only the exact completion magic can commit the global gate transition;
- strict target-read fault injection: revert, OOG, short, long, wrong magic, chain, runtime, config,
  phase, and generation;
- rotation with stage cancellation and pending purge as one rollback domain;
- credit claim independence from duty reclamation;
- full duty ring failing open to vacancy; and
- every threshold, checked arithmetic boundary, and fixed-loop maximum.

### 10.3 Model result semantics

Ordinary non-success results leave the complete component state equal to its pre-call deep copy.
`SYNCED` is a successful maintenance outcome, not an error: it permits only the exact leading-sync
Settlement delta and requires byte-for-byte unchanged Market state and accounting.

## 11. Normative integration and freeze gate

The complete LaTeX document is the normative source after integration. This repair document becomes
non-normative design history at that point. The generated PDF and executable artifacts must describe
the identical protocol.

Integration deletes every superseded occurrence of:

- `DELTA_FINAL_LAG` as the seat SLA trigger;
- immediate seat termination/burn;
- Market migration coordinator and Market arm/abort;
- distinct activation and promotion runway fields;
- `REFUND_CREDIT -> RELEASE_REQUESTED`; and
- any globally independent or caller-selectable Settlement seat arm/abort path, plus any statement
  that migration cancellation restores seat terms, duties, generation, or stage state; and
- any statement that every Round-8 function avoids Settlement while generation sync reads it.

The documentation checker must fail if old terms remain, required new terms are absent, model counts
or generated hashes are stale, the committed PDF differs from the LaTeX build, references fail, or
the economic example is accepted while uncalibrated.

The PDF is rebuilt from `tex/main.tex`, text-extracted to check semantic presence/absence, and rendered
for visual inspection of the auction, premium state machine, migration, release, reclamation, and
parameter pages.

Solidity begins only after:

1. every old and new executable model passes;
2. the cross-artifact checker passes;
3. no independent adversarial specification review reports a critical or high defect;
4. LaTeX and PDF are identical in substance;
5. the schema deterministically rejects uncalibrated deployment; and
6. all accepted trust and economic trade-offs are explicit.

This gate establishes an implementation-ready design. Production deployment remains separately
blocked on measured proof timing, gas and economic calibration, byte-exact profile/manifest/verifier
artifacts, independent implementation reproduction, formal/state-machine verification, operations
readiness, and external security review.
