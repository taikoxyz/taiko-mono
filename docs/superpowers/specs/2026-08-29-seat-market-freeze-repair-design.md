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

- four pending book cells;
- one staged offer and its premium reserve;
- immutable offer, tranche, seat-term binding, reserve, and credit records;
- native-ETH bond escrow and premium buckets; and
- append-only exact Settlement authorizations installed through Release Manager.

Market has no migration coordinator and exposes no `armMigration` or `abortMigration` method. It
cannot mutate canonical chain state, choose a proof, select a candidate, or call an operator-controlled
target.

### 3.3 Release Manager and target reads

Release Manager alone authorizes, disables, and atomically rotates installation targets. Historical
targets remain authorized only for claims, release, enforcement, and history reclamation.

`syncSeatGeneration` is the offer-book module's sole permissionless Settlement read. It derives the
current authorized target rather than accepting a free address, then performs a gas-capped
`STATICCALL` with exact chain, version, address, runtime hash, configuration hash, return length, and
magic checks. Offer insertion, requote, pending exit/refund, and pulls perform no Settlement read.

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

The stage stores selected rank, exact outgoing primary or zero, lineup commitment, and:

```text
handoverAt = max(minimumTenureUntil, now + HANDOVER_DELAY_SECONDS)
stageExpiresAt = handoverAt + STAGE_GRACE_SECONDS
```

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
chain continue.

Primary voluntary exit uses:

```text
primaryExitAt = max(
    exitRequestedAt + EXIT_DELAY_SECONDS,
    minimumTenureUntil)
```

Standby exit also observes its independent minimum standby tenure. A selected successor cannot exit.
An installed exit request never moves or refunds its bond. Until exact roster removal succeeds, the
term remains bonded and retains every existing duty liability. Funding expiry may close service
earlier than the requested exit because the protocol does not require unpaid service; sponsorship
cannot move the immutable requested exit later.

## 7. Fair duty, release, and reclamation

### 7.1 Duty and fail-open behavior

Each installed tranche can secure only one seat term and one duty. Settlement owns a fixed
sequence-tagged duty ring. Every canonical commit scans at most `SEAT_COUNT` unresolved cells and
permanently latches exact qualifying satisfaction on the surviving L1 fork.

If no locally reusable duty cell exists, canonical synchronization closes the affected optional seat
economics to vacancy and creates no new duty. It does not call Market or revert chain progress.

### 7.2 Installed release

Only a tranche with `TrancheUsage.INSTALLED`, `BondDisposition.NONE`, an exact closed Settlement term,
and a refundable terminal duty disposition may request installed release. The request timestamp is
one-shot and cannot reset.

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

Finalization at or after equality rereads exact Settlement state, reconciles and deletes the exact
reserve, then terminalizes the bond to its owner credit. A breached or unresolved duty cannot create
an owner credit.

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
3. no stage, term, open reserve, or closed-tail reserve remains;
4. all release, evidence, reorg, and premium-maturity horizons were enforced; and
5. the terminal tranche can never bind another offer, term, or duty.

`reclaimDutyCell` is a noncanonical Settlement maintenance call that authenticates this predicate and
caches a local reusable flag. Canonical code reads only that flag. Actual withdrawal of any pull
credit is irrelevant, so a beneficiary cannot pin history by refusing to claim.

## 8. Migration

### 8.1 Settlement-local arm and abort

Migration arm begins with leading sync and a mature-best commit. Any already-objective slash is
materialized first. One local atomic transition then:

- increments monotone `seatGeneration`;
- closes active and standby services non-fault;
- terminally excuses any selected-but-not-started successor;
- marks every remaining unresolved duty `SATISFIED` or `EXCUSED_MIGRATION` as appropriate;
- invalidates the exact stage and retains its migration tombstone; and
- makes the Settlement economically vacant.

It performs no Market or ETH call. Abort never lowers generation and never resurrects a term, duty,
successor, quote, or stage. A later active installation begins from the new generation.

Old cached-generation insertions before the next Market sync are inert capital operations: they
cannot stage or install while Settlement is armed and are purged when generation is synchronized or
the target is rotated.

### 8.2 Market synchronization and rotation

Equal generation sync is idempotent. A lower generation, malformed read, armed/non-installable phase,
or wrong authorization fails without Market mutation. A higher active generation atomically purges
at most four old pending offers to exact owner credits and writes the generation cache last. It does
not touch a staged offer; the authenticated tombstone path owns that transition.

Rotation verifies the exact immutable release-manager route, old/new authorization commitments,
consumed manifest and generation, old `FROZEN` phase, and new `ACTIVE` phase before mutation. When an
old stage exists, rotation first performs the identical authenticated migration-stage cancellation.
It then purges old pending offers, disables old insertion, enables new insertion with an uninitialized
generation cache, and writes the current target pointer. Any failure rolls the entire operation back.

Claims, old breach enforcement, release, and history reclamation remain available on every authorized
historical target.

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
- pending-only requote across every nonpending usage/location;
- pending exit freeing capacity but not bond before equality;
- exact before/equality/after quote maturity;
- unified direct/promoted reserve debit and service start;
- monotone funding fuzzing and structurally infeasible poison skipping;
- one-wei-under/equal funding and gross-reserve staging;
- a funded post-tenure interval that survives sync ordering and timestamp skips;
- healthy-close matured/tail/unearned conservation;
- closed-tail maturity before/equal/after and repeated reconciliation;
- canonical promotion followed by lazy start authentication;
- owner-versus-penalty terminal exclusivity under release/breach races;
- exact-credit replay, malicious payout, reentrancy, and forced ETH;
- arm/abort leaving every Market byte, bucket, and ETH balance unchanged;
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
