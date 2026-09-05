# Round 1 Micro-Plan: Normative Seat and Economic Alignment

> **Round type:** Documentation, executable-model, schema, and generated-artifact change only.
> No Solidity, deployment, storage-layout, or production-path contract change is permitted.

**Parent plan:** `docs/superpowers/plans/2026-08-29-slot-chain-contract-implementation.md`, Round 1
**Normative amendment:** `docs/superpowers/specs/2026-08-29-perpetual-aggregator-seat-market.md`
**Commit:** `docs(protocol): integrate perpetual reverse auction design`

## 1. Outcome and hard gate

This round replaces every undefined or superseded aggregator-seat rule in Slot Chain v2.25 with
one internally consistent, executable perpetual reverse-ask market and freezes a machine-readable
economic-profile schema. At the end of the round:

- LaTeX, the tracked circulation PDF, README, commitment vectors, the settlement model, the seat-market model, and
  Python unit tests describe the same state machine;
- the old immediate 3,600-second seat burn and time-windowed auction no longer appear as live
  normative rules;
- all capital paths have a named owner, asset, accounting bucket, formula input, sink, and release
  condition;
- every unmeasured monetary input remains explicitly `null` and the example profile remains
  `UNCALIBRATED` and production-invalid; and
- `npx --yes pnpm@9.15.9 slotchain:docs:check` reproduces the PDFs and runs every model/test
  deterministically; pnpm 11 is explicitly unsupported by the current frozen lockfile.

Solidity work is blocked until this round is independently reviewed and committed. A passing model
is regression evidence, not a production-readiness claim.

## 2. Scope boundaries

### In scope

- Transparent perpetual reverse asks, one primary, three immutable-order standbys, and four pending
  offers.
- Native-ETH offer bonds, premium reserves, pull credits, penalty sink credit, solvency, forced-ETH
  surplus, and bounded storage geometry.
- Immutable seat terms, roster revisions, staged handover, exits, responsibility intervals,
  single-duty tranches, duty-ring fail-open behavior, recovery/failover/slash thresholds,
  successor runway, delayed enforcement/release, and migration isolation.
- Builder lease collateral, data rent/session bond, forced-envelope deposits, reward classes/caps,
  and their profile inputs.
- Exact seat commitment encodings and golden vectors needed by later Solidity rounds.
- Deterministic PDF and documentation checks.

### Out of scope

- Solidity ABIs, selectors, storage slots, packing, runtime hashes, CREATE addresses, or deployment.
- Choosing production values for `SLA_BOND`, premiums, rents, fee coefficients, reward caps, or
  proof-cost coefficients without measurements.
- Proof circuits, verifier keys, fork decoder code, client conformance, testnet operations, or
  external audits.
- Any modification to `packages/protocol/contracts`, `test`, `script` outside the documentation
  check script listed below, Foundry configuration, or a live Inbox/Bridge/vault path.

## 3. Protocol-visible schema frozen by this round

Round 1 creates no Solidity ABI and therefore has no EVM storage layout. It instead freezes the
logical record grammar that later ABI/storage micro-plans must implement without reinterpretation.
All integers are unsigned, all additions and multiplications are checked, and no encoder may
silently narrow.

### 3.1 Scalar widths

| Meaning                                                                         | Frozen representation                                                 |
| ------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| IDs and commitments                                                             | `bytes32`                                                             |
| Address/operator/payout/contract/sink                                           | 20 bytes; nonzero unless explicitly nullable in the uncalibrated JSON |
| Settlement chain ID                                                             | `uint256`                                                             |
| Protocol version, seat generation, lineup revision, tranche/quote/duty sequence | `uint64`                                                              |
| Timestamps, L1 block numbers, L2 slots, episode and recovery revision           | `uint64`                                                              |
| Rank and status discriminants                                                   | `uint8`                                                               |
| Ask in wei/second                                                               | `uint128`, bounded by the profile maximum                             |
| Bond, premium, deposit, credit, rent, reward, and accounting totals             | `uint256`                                                             |
| Basis points                                                                    | `uint16`, at most 10,000                                              |

### 3.2 Fixed capacities and clocks

```text
SEAT_COUNT                 = 4
PRIMARY_COUNT              = 1
STANDBY_COUNT              = 3
PENDING_COUNT              = 4
BOOK_SIZE                  = 8  // installed plus pending, never eight pending
DELTA_RECOVERY_LAG         = 1,200 seconds
WORST_CASE_RECOVERY_SECONDS= 2,164 seconds (prototype, production-uncalibrated)
DELTA_FAILOVER_LAG         = 3,600 seconds
REORG_STABILITY_SECONDS    = 1,800 seconds
DELTA_SLASH_LAG            = 5,164 seconds
SLA_TAIL_SECONDS           = 3,964 seconds
```

Thresholds are missed only when `block.timestamp > threshold`; a qualifying commit at equality
cures. The following relations are normative and executable:

```text
DELTA_FAILOVER_LAG >= DELTA_RECOVERY_LAG + WORST_CASE_RECOVERY_SECONDS
DELTA_SLASH_LAG >= DELTA_RECOVERY_LAG
                  + WORST_CASE_RECOVERY_SECONDS
                  + REORG_STABILITY_SECONDS
DELTA_SLASH_LAG >= DELTA_FAILOVER_LAG
SLA_TAIL_SECONDS = DELTA_SLASH_LAG - DELTA_RECOVERY_LAG
ACTIVATION_RUNWAY_SECONDS >= MIN_ACTIVE_TENURE_SECONDS + SLA_TAIL_SECONDS
PROMOTION_RUNWAY_SECONDS >= MIN_PROMOTED_SERVICE_SECONDS + SLA_TAIL_SECONDS
serviceEligibleUntil = premiumFundedUntil - SLA_TAIL_SECONDS
newDuty.slashAt <= premiumFundedUntil
```

Only the first five timing values above are prototype values. The economic JSON marks proof timing
and every dependent runway as uncalibrated until real measurements validate them.

The 1,800-second reorg interval is measured after nominal worst-case recovery completion, not after
operational failover. A qualifying cure at exact `slashAt` is allowed but remains provisional until
the independent release/evidence reorg horizon. A reorg of that L1 commit rolls back its satisfaction
latch and may expose the duty to breach materialization; tests must cover that trace.

### 3.3 Record grammar and ownership

Later contracts may pack these records differently only if decoding is identical. Field order is
normative for commitment hashing.

```text
MarketAuthorizationV1(
  uint256 settlementChainId,
  uint64 protocolVersion,
  address settlement,
  bytes32 settlementRuntimeHash,
  bytes32 settlementConfigHash,
  address market
)

SeatGenerationCacheV1(
  bytes32 authorizationCommitment,
  uint64 cachedSeatGeneration,
  uint8 initialized,
  uint8 installationEnabled
)

SeatInstallationStateV1(
  bytes32 currentAuthorizationCommitment
)

BondTrancheV1(
  bytes32 bondTrancheId,
  uint64 trancheCreationSequence,
  address operator,
  uint256 amountWei,
  uint8 state,
  bytes32 seatTermId,
  bytes32 dutyId,
  uint64 releaseRequestedAt,
  bytes32 currentOfferId,
  uint64 currentQuoteSequence
)

SeatOfferV1(
  bytes32 offerId,
  address operator,
  address payout,
  uint128 askWeiPerSecond,
  bytes32 bondTrancheId,
  uint64 eligibleAtTimestamp,
  uint64 eligibleAtBlock,
  uint64 quoteSequence,
  uint64 exitRequestedAt,
  uint8 status,
  MarketAuthorizationV1 acceptedTarget,
  uint64 acceptedSeatGeneration
)

SeatTermV1(
  bytes32 seatTermId,
  address market,
  MarketAuthorizationV1 target,
  uint64 seatGenerationAtInstall,
  bytes32 offerId,
  bytes32 bondTrancheId,
  address operator,
  address payout,
  uint128 askWeiPerSecond,
  uint64 installedAt,
  uint64 lineupRevisionAtInstall
)

SeatLineupV1(
  uint64 lineupRevision,
  bytes32 primarySeatTermId,
  bytes32[3] standbySeatTermIds
)

SeatServiceV1(
  bytes32 seatTermId,
  uint64 lineupRevisionAtStart,
  uint64 responsibilityStart,
  uint64 closedAt,
  uint64 minimumTenureUntil,
  uint64 premiumFundedUntil,
  uint64 serviceEligibleUntil
)

SeatStageV1(
  bytes32 stageId,
  bytes32 offerId,
  bytes32 outgoingSeatTermId,
  bytes32 lineupCommitment,
  uint8 selectedRank,
  uint64 handoverAt,
  uint64 stageExpiresAt,
  uint64 seatGeneration,
  uint8 status
)

SeatSuccessorV1(
  bytes32 predecessorDutyId,
  bytes32 successorSeatTermId,
  uint64 selectedLineupRevision,
  uint64 selectedAt,
  uint8 status
)

SeatTermDispositionV1(
  bytes32 seatTermId,
  uint64 termRemovedAt,
  uint8 reason
)

PremiumReserveV1(
  bytes32 ownerId,
  uint8 purpose,
  uint128 askWeiPerSecond,
  uint256 reservedWei,
  uint64 lastAccruedAt,
  uint64 premiumFundedUntil
)

SeatDutyV1(
  bytes32 dutyId,
  bytes32 seatTermId,
  uint64 lineupRevision,
  bytes32 bondTrancheId,
  address operator,
  uint8 rank,
  uint64 episode,
  uint64 eligibleRecoveryRevision,
  bytes32 baseCanonicalHash,
  uint64 startingSequence,
  uint64 targetTipSlot,
  uint64 assignedAt,
  uint64 failoverAt,
  uint64 slashAt,
  uint64 satisfiedAt,
  uint8 status
)

BreachReceiptV1(
  bytes32 receiptId,
  bytes32 dutyId,
  bytes32 seatTermId,
  bytes32 bondTrancheId,
  uint64 recordedAt,
  MarketAuthorizationV1 target
)
```

`closedAt`, `satisfiedAt`, `exitRequestedAt`, `releaseRequestedAt`, `termRemovedAt`, and an unstarted
reserve's `lastAccruedAt`/`premiumFundedUntil` use `UINT64_MAX` as the unset/infinity sentinel. Zero
is never used as an unset timestamp. Exit intent is orthogonal to offer status, but an
exit-requested pending offer is infeasible for staging, a staged offer cannot newly request exit,
and installed terms use the tenure-aware formulas from the amendment. Empty lineup cells use
`bytes32(0)` and are excluded from ordering.

State discriminants are frozen as:

```text
OfferStatus:   PENDING=1, STAGED=2, INSTALLED=3,
               REFUNDABLE=4, REFUNDED=5, PURGEABLE=6
TrancheState:  ESCROWED=1, STAGED=2, INSTALLED=3, DUTY_BOUND=4,
               RELEASE_REQUESTED=5, RELEASED=6, SLASHED=7, REFUND_CREDIT=8
DutyStatus:    OPEN=1, SATISFIED=2, FAILED_OVER=3, BREACHED=4,
               EXCUSED_MIGRATION=5
StageStatus:   NONE=0, STAGED=1, INVALIDATED_LINEUP=2,
               INVALIDATED_MIGRATION=3, CLEARED=4
SuccessorStatus: NONE=0, SELECTED=1, STARTED=2, VACATED=3,
                 EXCUSED_MIGRATION=4
ReservePurpose: STAGE_ACTIVE=1, STAGE_STANDBY=2, PRIMARY=3, STANDBY=4,
                DUTY_TAIL=5
TermRemovalReason: HEALTHY_HANDOVER=1, HEALTHY_EXIT=2, DUTY_SATISFIED=3,
                   DUTY_FAILOVER=4, UNUSABLE_SUCCESSOR=5,
                   NO_DUTY_FUNDING_EXPIRY=6, DUTY_RING_EXHAUSTED=7,
                   SUCCESSOR_FUNDING_FAILURE=8, MIGRATION=9
```

The LaTeX appendix and `commitment-model.py` must distinguish immutable identifier derivation from
mutable record commitments. `H` prepends the ASCII domain and then fixed-width packed fields. ID
inputs never include their own result. Exact ID domains are:

```text
slot-chain-seat-tranche-id-v1
slot-chain-seat-offer-id-v1
slot-chain-seat-term-id-v1
slot-chain-seat-stage-id-v1
slot-chain-seat-duty-id-v1
slot-chain-seat-breach-id-v1
```

Their inputs, in order, are exactly those in amendment section 4.1. Record domains are:

```text
slot-chain-seat-authorization-v1
slot-chain-seat-generation-cache-v1
slot-chain-seat-installation-state-v1
slot-chain-seat-tranche-record-v1
slot-chain-seat-offer-record-v1
slot-chain-seat-term-record-v1
slot-chain-seat-lineup-v1
slot-chain-seat-service-v1
slot-chain-seat-stage-record-v1
slot-chain-seat-successor-v1
slot-chain-seat-term-disposition-v1
slot-chain-seat-premium-reserve-v1
slot-chain-seat-duty-record-v1
slot-chain-seat-breach-record-v1
```

Each hash prepends its ASCII domain and uses the field widths/order above. Nested target structs are
encoded inline, not as dynamic ABI encoding. Record commitments include the already-derived ID plus
all state fields, while the ID derivation excludes mutable state/status. `commitment-model.py` must
pin empty, ordinary, maximum-width, cross-chain, cross-version, cross-generation,
migration-excused, selected-successor, and breached vectors; assert every one-bit/one-field mutation
changes the affected hash; and prove requote/replay cannot create two live records for one ID.

### 3.4 Authority and seal matrix

| Object                                                                   | Initial state                                                                    | Sole writer/authority                                                                                                                                                                                                                                                                                       | Terminal behavior                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ------------------------------------------------------------------------ | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Market authorization, current-installation pointer, and generation cache | Authorization absent; pointer zero; cache uninitialized/disabled                 | Delayed `ProtocolVersionManager` appends the exact static tuple. The first becomes current; later targets stay disabled until exact manager rotation. Permissionless exact-target sync initializes or monotonically advances only the current cache while its Settlement reports installation-open `ACTIVE` | Exactly one authorization is installation-enabled. Advance purges at most four old pending offers. Successful cutover rotation first executes the exact migration-stage cancellation and bond/reserve deltas if needed, then purges old pending, disables old insertion, enables new, and leaves the new cache uninitialized; every failure rolls back the whole rotation. Abort does not rotate or permit armed-phase sync. Historical claims/enforcement remain; migration arm's generation increment survives abort without a governance write |
| Operator offer consent                                                   | Absent                                                                           | Direct transaction with `msg.sender == operator`; relayed signatures are out of scope for V1                                                                                                                                                                                                                | Any ask/payout/target change creates a new quote and resets both maturity clocks                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| Seat term                                                                | Absent                                                                           | Noncanonical exact Market/Settlement handover                                                                                                                                                                                                                                                               | Immutable, one tranche, promoted at most once                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Lineup revision                                                          | Vacant                                                                           | Settlement noncanonical roster transition                                                                                                                                                                                                                                                                   | Monotone; untouched standby term IDs never change                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| Selected successor                                                       | One retained record per predecessor duty plus one clearable current-duty pointer | Settlement local failover selects only installed standby zero                                                                                                                                                                                                                                               | Non-exitable while selected; cure/usable-next-revision starts it and clears only the pointer; late runway vacates the full lineup; migration excuses it; retained history remains in the duty ring                                                                                                                                                                                                                                                                                                                                                |
| Seat duty/receipt                                                        | Absent                                                                           | Settlement canonical local writes                                                                                                                                                                                                                                                                           | One duty per tranche; terminal disposition never reopens                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| Stage tombstone                                                          | None                                                                             | Migration arm invalidates; exact Market cancellation acknowledges                                                                                                                                                                                                                                           | Cleared exactly once; abort never resurrects the stage                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Migration generation                                                     | Current exact value                                                              | Settlement migration arm                                                                                                                                                                                                                                                                                    | Monotone even after abort; old quotes remain invalid                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |

No seat, Market call, premium balance, reward state, or operator identity is a prerequisite for
proof submission, canonical commit, forced recovery, recovery revision, or migration readiness.

### 3.5 Rank and selected-successor transitions

The roster is a contiguous ask-sorted prefix. A stage freezes exactly one transition:

| Pre-state                                                                                                           | Selected rank/effect                                                                                 | Forbidden alternatives                             |
| ------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| Empty roster                                                                                                        | Rank 0; direct-primary reserve/service                                                               | Nonzero rank                                       |
| Healthy active; qualifying improvement, including a full four-term lineup                                           | Rank 0; close only outgoing primary, preserve standby IDs/order                                      | Demoting outgoing primary or reinstalling standbys |
| Healthy active; no replacement; fewer than four terms; candidate ask at least active ask                            | First standby insertion rank under pre-stage-known `(ask, offerId)` ascending; shift later IDs right | Creating a gap or evicting a live term             |
| Candidate does not replace active and the roster is full, or candidate is cheaper than active but below improvement | No stage                                                                                             | Reserving funds or caller-selected rank            |

The pending scan skips infeasible lower offers and selects the first feasible offer in the full
five-key market order; an infeasible poison-best offer cannot block a later valid standby fill.
Active/standby exit compacts the same prefix. A healthy active exit promotes standby zero and starts
normal service atomically; standby exit never changes a term ID. Incident failover writes a new
revision that moves standby zero to primary plus a successor record keyed by predecessor duty and
sets `currentSuccessorDutyId`, but creates no service.
While selected it cannot exit, stage, rebind, or accrue. A qualifying cure starts normal promoted
service and clears only the current pointer; an open outage at the next usable revision starts the
revision-bound duty and also clears only the pointer, so that duty can later select another standby.
A late/unusable revision closes/removes the selected term and all remaining standbys in one local
revision, records every disposition/removal time, retains Market bytes/funds, and leaves a truly
empty roster; migration performs the analogous full closure/excuse. Any lineup revision invalidates an older stage
commitment, whose reserve can then be recovered only through exact expiry/tombstone cancellation.

## 4. Economic profile JSON schema

`economic-profile.example.json` is a strict example instance. Unknown keys are rejected. Monetary
values are base-10 strings to avoid JavaScript precision loss; unmeasured values are JSON `null`.
Addresses are lowercase `0x` plus 40 hex digits, hashes are lowercase `0x` plus 64 hex digits, or
`null` only while `status` is `UNCALIBRATED`.

Required top-level keys, in this order:

```text
schema, status, profileId, measurementCommit, units, geometry, assets,
builder, dataSession, forcedEnvelope, seat, rewards, sinks
```

The exact structure is:

```json
{
  "schema": "taiko.slot-chain.economic-profile.v1",
  "status": "UNCALIBRATED",
  "profileId": null,
  "measurementCommit": null,
  "units": {
    "amount": "wei",
    "rate": "wei/second",
    "time": "seconds",
    "gas": "gas",
    "size": "bytes",
    "ratio": "basis-points"
  },
  "geometry": {
    "seatCount": 4,
    "standbyCount": 3,
    "pendingCount": 4,
    "bookSize": 8,
    "maxRewardClasses": 16
  },
  "assets": {
    "builderLease": {
      "kind": "ERC20_NO_HOOK",
      "chainId": null,
      "address": null,
      "runtimeHash": null,
      "decimals": null
    },
    "nativeCustody": { "kind": "NATIVE_ETH", "chainId": null }
  },
  "builder": {
    "leasePerWindow": null,
    "maximumBond": "6277101735386680763835789423207666416102355444464034512895",
    "maximumAssignedSlots": 76,
    "evidenceDelaySeconds": 86400,
    "reorgMarginSeconds": 1800,
    "reporterRewardCapWei": null
  },
  "dataSession": {
    "ttlSeconds": 86400,
    "maximumLiveSessions": 1024,
    "refundableBondWei": null,
    "baseRentWei": null,
    "rentPerPublishedByteWei": null,
    "blobBaseFeeMultiplierBps": null,
    "rentSink": null
  },
  "forcedEnvelope": {
    "fixedIngressWei": null,
    "executionWeiPerAccountedGas": null,
    "proofWeiPerAccountedGas": null,
    "permanentWeiPerByte": null,
    "maximumAcceptedFeeWei": null,
    "claimWindowSeconds": 86400
  },
  "seat": {
    "slaBondWei": null,
    "maximumAskWeiPerSecond": null,
    "minimumAskImprovementWeiPerSecond": null,
    "minimumAskImprovementBps": null,
    "quoteMaturitySeconds": null,
    "quoteMaturityBlocks": null,
    "minimumActiveTenureSeconds": null,
    "minimumStandbyTenureSeconds": null,
    "minimumPromotedServiceSeconds": null,
    "handoverDelaySeconds": null,
    "handoverHeadroomSeconds": null,
    "stageGraceSeconds": null,
    "exitDelaySeconds": null,
    "releaseChallengeSeconds": null,
    "evidenceDelaySeconds": null,
    "premiumClaimDelaySeconds": null,
    "activationRunwaySeconds": null,
    "promotionRunwaySeconds": null,
    "recoveryLagSeconds": 1200,
    "worstCaseRecoverySeconds": 2164,
    "failoverLagSeconds": 3600,
    "reorgStabilitySeconds": 1800,
    "slashLagSeconds": 5164
  },
  "rewards": {
    "claimWindowSeconds": 86400,
    "classes": []
  },
  "sinks": {
    "builderPenalty": null,
    "dataRent": null,
    "seatPenalty": null,
    "forcedExpiry": null
  }
}
```

Each reward class is strictly sorted by `classId`, unique, and has exactly:

```text
classId:uint8, name:string, fixedWei:decimal-string,
perExecutionGasWei:decimal-string, perPublishedByteWei:decimal-string,
capWei:decimal-string
```

`classes` may be empty only while uncalibrated. A production-valid profile requires `status` equal
to `CALIBRATED`, non-null `profileId`/`measurementCommit`, every required monetary/identity field,
at least one reward class, and all equations below to pass:

```text
dataRent = baseRentWei
         + publishedBytes * rentPerPublishedByteWei
         + ceil(blobGasUsed * block.blobbasefee * blobBaseFeeMultiplierBps / 10_000)

minimumForcedDeposit = fixedIngressWei
                     + accountedGas * executionWeiPerAccountedGas
                     + accountedGas * proofWeiPerAccountedGas
                     + durableBytes * permanentWeiPerByte

requiredPremium = primaryAsk * primaryRunwaySecondsAtStart
                + sum(standbyAsk[i] * promotionRunwaySeconds)

primaryRunwaySecondsAtStart = activationRunwaySeconds for a direct primary
                            or promotionRunwaySeconds for a promoted standby

minimumAskImprovement = max(minimumAskImprovementWeiPerSecond,
                            ceil(activeAsk * minimumAskImprovementBps / 10_000))

claimMaturedThrough = 0 if now < premiumClaimDelaySeconds
                      else now - premiumClaimDelaySeconds
accrueTo = max(lastAccruedAt,
               min(claimMaturedThrough, settlementCap, premiumFundedUntil))
earned = ask * (accrueTo - lastAccruedAt)

accountedMarketBalance = bondEscrow + bondRefundCredits + freePremium
                       + reservedPremium + premiumClaims + penaltySinkCredit
actualMarketBalance >= accountedMarketBalance

dispositionStableAt = dispositionAt + reorgStabilitySeconds

evidenceSafeAt = lastLiabilityAt + evidenceDelaySeconds + reorgStabilitySeconds

finalizeReleaseAt = max(releaseRequestedAt + releaseChallengeSeconds,
                        dispositionStableAt,
                        evidenceSafeAt)

reserveMatureAt = 0 if no live reserve or reserve never started
                  else settlementCap + premiumClaimDelaySeconds

terminalReleaseAt = max(finalizeReleaseAt, reserveMatureAt)

pendingExitAt = exitRequestedAt + exitDelaySeconds
standbyExitAt = max(pendingExitAt, installedAt + minimumStandbyTenureSeconds)
directPrimaryExitAt = max(pendingExitAt, minimumTenureUntil)
promotedPrimaryExitAt = max(pendingExitAt,
                            responsibilityStart + minimumPromotedServiceSeconds)
```

Every ceiling division is checked and rounds against the payer. Data rent is burned and has no
consensus-coupled reimbursement; separately funded reward classes cannot affect candidate validity
or commit. Forced ETH above accounting is surplus and is never silently assigned to a claimant.
For the release equations, an absent disposition or never-installed liability contributes zero
rather than adding a duration to zero; all other additions are checked, and finalization uses
`now >= terminalReleaseAt`.
`request_release` is permissionless and legal only after the offer is refundable or the installed term has been removed
and its duty is never-used, `SATISFIED`, or `EXCUSED_MIGRATION`. Only then may the exclusive tranche
state become `RELEASE_REQUESTED`; the request is one-shot and cannot reset its clocks. Finalization
is also permissionless and credits only the immutable operator's pull-refund balance.
`BREACHED`/`SLASHED` can never create an operator refund; a breached release attempt returns
`BREACHED` or atomically enforces the penalty.
Premium top-ups are irrevocable protocol sponsorship; the schema exposes no refundable funder share
or credit.

Reserve bucket deltas are frozen as:

| Transition                            | Atomic accounting delta                                                                                                   |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Stage direct primary                  | `freePremium -= ask*activationRunway`; create `STAGE_ACTIVE` reserve for that offer                                       |
| Stage standby insertion               | `freePremium -= ask*promotionRunway`; create `STAGE_STANDBY` reserve                                                      |
| Apply stage                           | Rekey exact owner `stageId` to `seatTermId` as `PRIMARY` or `STANDBY`; no second debit                                    |
| Expire/cancel never-served stage      | Delete reserve; `freePremium += reservedWei`                                                                              |
| Canonically promote standby           | Settlement alone records actual start/funded end; Market reserve bytes and totals do not change                           |
| First post-promotion accrue/reconcile | Authenticate exact Settlement start, initialize/rekey Market metadata with zero bucket delta, then apply ordinary accrual |
| Extend active                         | `freePremium -= ask*extensionSeconds`; term reserve increases by the same amount and funded end advances atomically       |
| Accrue                                | Term reserve decreases by `earned`; `premiumClaims` increases by `earned`                                                 |
| Healthy handover/exit                 | Authenticate cap, accrue first, then return only proven unearned remainder to free                                        |
| Canonical close/failover/migration    | No market delta; retain reserve until noncanonical stable-cap reconciliation                                              |
| Duty tail                             | Retain enough reserve through `slashAt`; after stable terminal disposition reconcile earned and free only the remainder   |
| Standby exit                          | In the same revert domain as roster removal, delete its never-earned reserve and credit free premium                      |

After every row, `reservedPremium == sum(PremiumReserveV1.reservedWei)`. Admission debits are not a
perpetual reserve invariant. Instead, unstarted rows equal `ask*runway`, an open started service
equals `ask*(premiumFundedUntil-lastAccruedAt)` after each accrual/extension, and closed unreconciled
rows remain unchanged. A selected successor cannot take the standby-exit row.
For `INVALIDATED_MIGRATION`, stage cancellation additionally changes the offer `STAGED ->
REFUNDABLE`, tranche `STAGED -> REFUND_CREDIT`, and atomically moves its exact bond from `bondEscrow`
to `bondRefundCredits` before acknowledging the Settlement tombstone. Installation rotation invokes
this same transition first when needed; no partial reserve, bond, pending-purge, or pointer delta may
survive a failed rotation.
For any installed tranche, `finalize_release` must first perform the exact closed-reserve
reconciliation in its atomic transition and delete the stage/term/tail reserve before setting
`RELEASED`; an unstarted standby returns the full reserve to free premium. `enforce_breach` does the
same for a duty-bound tranche before `SLASHED`. The derived view
`is_duty_history_safe(duty_id, seat_term_id, tranche_id)` is true only for the retained exact binding,
a terminal tranche, and no live stage/term/tail reserve. `reclaim_duty_cell` requires that exact view;
terminal tranche state alone is insufficient.

## 5. Executable model design

### 5.1 `seat-market-model.py`

Define these enums/dataclasses with no IO or nondeterministic clock access:

- `OfferStatus`, `TrancheState`, `DutyStatus`, `StageStatus` using the frozen discriminants.
- `TargetAuthorization` (static, without generation), `BondTranche`, `Offer`, `SeatTerm`,
  `SeatLineup`, `SeatService`, `Stage`, `SuccessorSelection`, `Duty`, `BreachReceipt`,
  `SeatTermDisposition`, `PremiumReserve`, `MarketAccounting`, `SeatMarketModel`.
- `Clock(timestamp: int, block_number: int)` passed explicitly to every transition.

Required transition methods:

```text
authorize_target, disable_installation, rotate_installation, sync_generation, insert_offer, requote,
request_offer_exit,
finalize_offer_exit, fund_premium, extend_primary_funding, stage_best,
expire_stage, apply_handover, request_installed_exit, finalize_installed_exit,
attach_primary_duty, latch_qualifying_commit, observe_failover,
open_successor_revision, record_breach, preview_premium_cap, accrue_premium,
reconcile_closed_reserve, request_release, finalize_release, enforce_breach, reclaim_duty_cell,
claim_premium, claim_bond_refund, claim_penalty_credit, arm_migration,
cancel_invalidated_stage, abort_migration
```

The public model API is frozen as Python keyword-only calls. `TransitionResult(code, value=None)`
uses `ResultCode` values `OK`, `NO_FEASIBLE_OFFER`, `INVALID_TARGET`, `STALE_GENERATION`,
`IMMATURE`, `CAPACITY`, `UNDERFUNDED`, `STALE_STAGE`, `HEALTH_BLOCKED`, `EXIT_LOCKED`,
`DUTY_CONFLICT`, `TOO_EARLY`, `NOT_RELEASABLE`, `BREACHED`, `TARGET_READ_FAILED`, and
`UNAUTHORIZED`, and `GENERATION_UNSYNCED`. A non-`OK` result must compare the complete model state equal to a deep copy taken
before the call; invariant/programmer errors alone raise exceptions.

```python
SeatMarketModel(*, profile, market_chain_id: int, market: str,
                release_manager: str, migration_coordinator: str)

authorize_target(*, caller: str, target: TargetAuthorization) -> TransitionResult
disable_installation(*, caller: str, target_commitment: str) -> TransitionResult
rotate_installation(*, caller: str, old_target_commitment: str,
                    new_target_commitment: str, old_target_view: ExactTargetView,
                    new_target_view: ExactTargetView,
                    rotation_view: ExactRotationView,
                    clock: Clock) -> TransitionResult
# First performs the exact authenticated INVALIDATED_MIGRATION stage cancellation, including its
# reserve/bond deltas, when needed; then atomically purges old pending offers, disables old insertion,
# and enables new insertion with an uninitialized generation cache.
sync_generation(*, target_view: ExactTargetView, clock: Clock) -> TransitionResult
# Initializes or monotonically advances the exact authorization cache; an advance atomically
# removes at most four old-generation pending offers and creates their pull-refund credits.
insert_offer(*, caller: str, payout: str, ask: int, bond: int,
             target: TargetAuthorization, accepted_generation: int,
             clock: Clock) -> TransitionResult  # operator=caller; cache equality; no Settlement read
requote(*, offer_id: str, caller: str, payout: str, ask: int,
        accepted_generation: int, clock: Clock) -> TransitionResult
request_offer_exit(*, offer_id: str, caller: str, clock: Clock) -> TransitionResult
finalize_offer_exit(*, offer_id: str, clock: Clock) -> TransitionResult
fund_premium(*, amount: int) -> TransitionResult  # irrevocable sponsorship
stage_best(*, target_view: ExactTargetView, clock: Clock) -> TransitionResult
expire_stage(*, stage_id: str, target_view: ExactTargetView,
             clock: Clock) -> TransitionResult
apply_handover(*, stage_id: str, target_view: ExactTargetView,
               clock: Clock) -> TransitionResult
request_installed_exit(*, seat_term_id: str, caller: str,
                       clock: Clock) -> TransitionResult
finalize_installed_exit(*, seat_term_id: str, target_view: ExactTargetView,
                        clock: Clock) -> TransitionResult
attach_primary_duty(*, target_view: ExactTargetView, duty: Duty,
                    clock: Clock) -> TransitionResult
latch_qualifying_commit(*, sequence: int, tip_slot: int,
                        clock: Clock) -> TransitionResult
observe_failover(*, duty_id: str, clock: Clock) -> TransitionResult
open_successor_revision(*, predecessor_duty_id: str, round_start_slot: int,
                        escape_slot: int, clock: Clock) -> TransitionResult
record_breach(*, duty_id: str, clock: Clock) -> TransitionResult
preview_premium_cap(*, seat_term_id: str,
                    target_view: ExactTargetView, clock: Clock) -> TransitionResult
accrue_premium(*, seat_term_id: str, target_view: ExactTargetView,
               clock: Clock) -> TransitionResult
extend_primary_funding(*, seat_term_id: str, extension_seconds: int,
                       target_view: ExactTargetView, clock: Clock) -> TransitionResult
reconcile_closed_reserve(*, seat_term_id: str, target_view: ExactTargetView,
                         clock: Clock) -> TransitionResult
request_release(*, tranche_id: str,
                target_view: ExactTargetView, clock: Clock) -> TransitionResult
finalize_release(*, tranche_id: str,
                 target_view: ExactTargetView, clock: Clock) -> TransitionResult
enforce_breach(*, receipt_id: str, target_view: ExactTargetView,
               clock: Clock) -> TransitionResult
reclaim_duty_cell(*, duty_id: str, target_view: ExactTargetView,
                  clock: Clock) -> TransitionResult
claim_premium(*, payout: str, amount: int) -> TransitionResult
claim_bond_refund(*, operator: str, amount: int) -> TransitionResult
claim_penalty_credit(*, caller: str, amount: int) -> TransitionResult
arm_migration(*, caller: str, target_view: ExactTargetView,
              clock: Clock) -> TransitionResult
cancel_invalidated_stage(*, stage_id: str, target_view: ExactTargetView,
                         clock: Clock) -> TransitionResult
abort_migration(*, caller: str, target_view: ExactTargetView,
                clock: Clock) -> TransitionResult
```

`ExactTargetView` is immutable test input with `mode`, exact static authorization, current
`seat_generation`, installation phase, lineup/term/service/duty/disposition/tombstone data, and
exact return magic.
`ExactRotationView` is immutable test input from the exact immutable release-manager/router path with
mode, current routed authorization, old/new authorization commitments, consumed manifest/generation,
old `FROZEN` phase, new `ACTIVE` phase, and exact return magic. Rotation validates all fields before
any cancellation, accounting, purge, or pointer write; manager caller identity alone never suffices.
`TargetReadMode` is `OK`, `REVERT`, `OOG`, `SHORT`, `LONG`, `WRONG_MAGIC`, or `WRONG_CHAIN`.
Every market operation that reads Settlement first validates mode, exact chain/static target, and
the operation-specific record; every non-`OK` mode returns `TARGET_READ_FAILED` with no mutation.
`authorize_target`/`disable_installation`/`rotate_installation` require the immutable
`release_manager`; migration
arm/abort require the immutable `migration_coordinator`; and direct offer insertion always derives
`operator` from `caller`. `sync_generation` is permissionless, rejects a decreasing generation,
rejects every phase except installation-open `ACTIVE`, and is the only way to initialize/advance the
separate cache for the sole current installation authorization. Insertion/requote requires that
current target plus exact cache equality and cannot mutate or displace an offer otherwise. A later
authorization is inert until atomic rotation; a disabled historical target remains usable only for
claims/enforcement/release. No API accepts a free operator identity or caller-supplied authority bit.

The economic-profile module exposes exactly:

```python
load_economic_profile(path: str) -> dict
validate_economic_profile(profile: dict, *, production: bool) -> tuple[str, ...]
checked_add_u256(a: int, b: int) -> int
checked_mul_u256(a: int, b: int) -> int
ceil_div_u256(numerator: int, denominator: int) -> int
calculate_data_rent(profile, *, published_bytes, blob_gas_used, blob_base_fee) -> int
calculate_forced_deposit(profile, *, accounted_gas, durable_bytes) -> int
calculate_required_premium(profile, *, primary_ask, primary_promoted,
                           standby_asks) -> int
calculate_minimum_improvement(profile, *, active_ask) -> int
calculate_release_deadlines(profile, *, release_requested_at,
                            term_removed_at, service_closed_at,
                            duty_slash_at, disposition_at) -> tuple[int, int, int]
calculate_terminal_reserve_maturity(profile, *, settlement_cap,
                                    has_live_reserve) -> int
calculate_exit_deadline(profile, *, role, exit_requested_at, installed_at,
                        responsibility_start, minimum_tenure_until) -> int
```

Unknown/missing keys and overflow raise deterministic validation errors; production validation
returns a stable sorted tuple of every blocker and never accepts `UNCALIBRATED` or a null required
field.

Every method returns a value/status and either performs one complete atomic transition or leaves the
model byte-for-byte unchanged. Loops assert their explicit bound: pending scan at most four,
installed/duty scan at most four, total live book cells at most eight.

For every installed tranche, `finalize_release` atomically reconciles/deletes any live reserve before
making it terminal; `enforce_breach` does the same for duty-bound tranches. `reclaim_duty_cell` derives and
authenticates the exact retained binding, terminal tranche, and absence of every live reserve;
terminal tranche status without this history-safe condition returns `NOT_RELEASABLE` unchanged.

The model stores one reserve owner record per live stage/term/tail and asserts after every transition
that `reservedPremium == sum(reserve.reservedWei)`. It also stores exact `dispositionStableAt`,
`evidenceSafeAt`, and `finalizeReleaseAt` derivations. Fork tests take a deep snapshot before the
curing/receipt/enforcement/release branch and prove restoring the parent removes every descendant
effect together.

### 5.2 `settlement-window-model.py`

Replace the current `Seat(operator, penalty_bond, terminated)` and immediate `_activate` burn with
the integrated local subset:

- `SeatTermRef`, `SeatService`, `RecoveryDuty`, `BreachReceipt`, `SeatEconomicsState`;
- `seat_generation`, `lineup_revision`, one primary, three ordered standbys, one stage tombstone,
  per-duty selected-successor history plus one current-successor pointer, and a fixed
  sequence-tagged duty ring;
- `recoveryAt`, `failoverAt`, `slashAt`, and `targetTipSlot` derived only from the frozen canonical
  tip/sequence;
- fixed scans on canonical commit for qualifying satisfaction;
- force-first recovery duty attachment without timer reset;
- successor selection/start on the next usable revision;
- objective no-duty funding-expiry cap at `serviceEligibleUntil`;
- one bounded full-lineup vacancy helper for unusable successor, no-duty funding expiry, ring-full,
  and successor funding failure, recording every removal while leaving Market unchanged; and
- migration arm materialization/excuse/vacancy semantics.

Recovery/proof behavior unrelated to seats must retain its existing assertions. Delete no previous
property unless the Round 1 amendment explicitly supersedes it and the replacement property names
the removed behavior.

### 5.3 `commitment-model.py`

Add pure packed identifier and record encoders plus golden assertions for every seat domain in
section 3.3. Existing
no-argument behavior remains unchanged except for the increased reported property/vector count.
Round 2, not this round, owns generalized `--json` generation; do not add an unrelated CLI here.

## 6. Named tests and required red state

`test-seat-market.py` is created first, before `seat-market-model.py`. Load the hyphenated model
with `importlib.util.spec_from_file_location`. The first focused run must fail because the model or
required records/transitions do not exist; this is the recorded red state. A test may not be marked
expected-failure or skipped.

Minimum named tests:

```text
SeatBookTests.test_geometry_is_four_installed_four_pending
SeatBookTests.test_fifth_pending_offer_displaces_or_reverts_without_growth
SeatBookTests.test_full_five_key_pending_order
SeatBookTests.test_both_maturity_clocks_before_equal_after_boundaries
SeatBookTests.test_requote_resets_timestamp_and_block_maturity
SeatBookTests.test_repeated_requotes_retain_one_tranche_creation_id
SeatBookTests.test_wrong_chain_static_target_rejected_on_insert
SeatBookTests.test_generation_cache_must_be_initialized_before_insert
SeatBookTests.test_stale_generation_is_rejected_without_displacement
SeatBookTests.test_repeated_stale_generation_cannot_reset_honest_maturity
MigrationTests.test_generation_sync_purges_old_pending_without_touching_stage
MigrationTests.test_rotation_disables_old_purges_book_and_enables_new_atomically
MigrationTests.test_rotation_with_old_stage_conserves_bond_and_premium_or_rolls_back
MigrationTests.test_old_target_cannot_reinsert_after_rotation
MigrationTests.test_abort_keeps_old_target_current_at_fresh_generation
MigrationTests.test_armed_phase_cannot_sync_or_mature_abort_generation_quote
MigrationTests.test_premature_canceled_or_reorged_cutover_rotation_is_noop
SeatBookTests.test_offer_operator_is_always_direct_caller
TargetBindingTests.test_unauthorized_manager_and_coordinator_are_noop
SeatBookTests.test_one_wei_undercut_does_not_meet_improvement
SeatBookTests.test_staged_offer_cannot_exit_or_be_replaced
SeatBookTests.test_sybil_book_is_capital_backed_and_bounded
SeatTermTests.test_one_tranche_cannot_back_two_terms
SeatTermTests.test_untouched_standby_term_ids_survive_revision
SeatTermTests.test_live_standby_cannot_be_evicted_or_front_run_promotion
SeatTermTests.test_exit_keeps_term_bonded_and_promotable_until_atomic_removal
SeatTermTests.test_selected_rank_is_deterministic_for_every_vacancy
SeatTermTests.test_equal_ask_rank_uses_offer_id_across_delayed_apply
SeatTermTests.test_full_lineup_qualifying_replacement_preserves_standbys
SeatTermTests.test_full_lineup_rejects_nonreplacing_standby_insertion
SeatTermTests.test_rank_tampering_or_lineup_change_invalidates_apply
SeatStageTests.test_lineup_invalidation_tombstone_recovers_reserve_without_market_call
SeatTermTests.test_infeasible_poison_best_skipped_for_valid_standby_fill
SeatTermTests.test_exit_requested_pending_offer_cannot_install
SeatTermTests.test_standby_and_promoted_exit_tenure_boundaries
PremiumTests.test_each_standby_has_a_segregated_promotion_runway
PremiumTests.test_underfunded_installation_is_fail_open
PremiumTests.test_funding_expiry_closes_only_future_service
PremiumTests.test_unsynchronized_failover_caps_premium
PremiumTests.test_unsynchronized_no_duty_expiry_caps_at_service_eligible
PremiumTests.test_claim_delay_before_service_start_cannot_underflow
PremiumTests.test_canonical_promotion_leaves_market_bytes_unchanged_until_accrual
PremiumTests.test_first_post_promotion_accrual_lazily_initializes_reserve_metadata
PremiumTests.test_forced_eth_is_surplus_not_accounted_credit
PremiumTests.test_market_accounting_is_conserved
PremiumTests.test_repeated_handover_expiry_and_promotion_preserve_reserve_sum
PremiumTests.test_sponsorship_is_irrevocable_and_has_no_funder_credit
DutyTests.test_threshold_equality_cures_and_strictly_greater_misses
DutyTests.test_qualifying_cure_requires_sequence_and_target_tip
DutyTests.test_force_only_recovery_never_resets_or_immunizes_duty
DutyTests.test_one_tranche_receives_at_most_one_duty
DutyTests.test_failover_terminates_without_burn
DutyTests.test_successor_waits_for_next_usable_revision
DutyTests.test_selected_successor_cannot_exit_or_be_removed
DutyTests.test_three_sequential_failovers_retain_per_duty_successor_history
DutyTests.test_unusable_successor_closes_full_lineup_then_allows_reinstallation
DutyTests.test_every_vacancy_reason_closes_full_lineup_and_records_disposition
DutyTests.test_late_revision_or_short_runway_goes_vacant
DutyTests.test_late_primary_cure_does_not_leave_successor_in_limbo
DutyTests.test_cure_by_slash_equality_prevents_burn
DutyTests.test_slash_equality_cure_reorg_rolls_back_before_release
DutyTests.test_breach_receipt_is_unique_and_enforcement_idempotent
DutyTests.test_duty_ring_exhaustion_cannot_block_recovery_or_commit
ReleaseTests.test_release_cannot_front_run_unmaterialized_breach
ReleaseTests.test_breached_tranche_never_releases_to_operator
ReleaseTests.test_exact_disposition_evidence_and_challenge_boundaries
ReleaseTests.test_equality_cure_reorg_rolls_back_enforcement_and_release
ReleaseTests.test_old_exact_settlement_remains_the_only_disposition_source
ReleaseTests.test_uncooperative_operator_cannot_block_permissionless_release_and_reclaim
ReleaseTests.test_release_reconciles_reserve_before_history_safe_reclaim
ReleaseTests.test_slash_reconciles_reserve_before_history_safe_reclaim
ReleaseTests.test_enforcement_waits_for_full_premium_cap_maturity_before_reconcile
ReleaseTests.test_never_served_standby_release_returns_full_reserve_before_terminal
ReleaseTests.test_served_no_duty_close_matures_and_reconciles_before_release
MigrationTests.test_arm_materializes_slashable_and_excuses_other_duties
MigrationTests.test_abort_remains_vacant_and_requires_new_generation_quote
MigrationTests.test_fresh_generation_quote_needs_no_new_manager_authorization
MigrationTests.test_pre_arm_generation_quote_remains_rejected_after_abort
MigrationTests.test_invalidated_stage_tombstone_clears_exactly_once
MigrationTests.test_invalidated_stage_cancellation_accounts_exact_bond_and_reserve
EconomicProfileTests.test_exact_schema_rejects_unknown_or_missing_keys
EconomicProfileTests.test_example_is_explicitly_uncalibrated
EconomicProfileTests.test_production_validation_rejects_every_null_calibration
EconomicProfileTests.test_checked_formula_rounding_and_overflow_boundaries
```

`test-settlement-window.py` is also created in this round (the master plan labels it “Modify”, but
the file does not exist at preflight). It invokes/imports the integrated model and contains:

```text
SettlementSeatTests.test_recovery_opens_at_recovery_lag_not_old_final_lag
SettlementSeatTests.test_mature_best_commits_before_duty_decision
SettlementSeatTests.test_forced_episode_attaches_exactly_one_lag_duty
SettlementSeatTests.test_round_roll_preserves_original_primary_duty
SettlementSeatTests.test_promoted_duty_uses_next_usable_round
SettlementSeatTests.test_failover_persists_selected_successor_before_service
SettlementSeatTests.test_qualifying_commit_latches_only_first_satisfaction
SettlementSeatTests.test_equality_cure_reorg_restores_open_duty
SettlementSeatTests.test_ring_exhaustion_is_economically_vacant_but_live
SettlementSeatTests.test_migration_arm_materializes_then_excuses
SettlementSeatTests.test_canonical_trace_has_no_market_or_payment_callback
```

All adversarial cases in section 10 of the seat-market amendment must map to a named unit test or a
named model property. The review checklist rejects an undocumented “covered by fuzzing” claim.

### 6.1 Adversarial traceability matrix

| Amendment section 10 attack                        | Frozen Round 1 test/property                                                                                                                                                                                                                                                                                                                                                   |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Same-block and one-wei takeover                    | `SeatBookTests.test_same_block_and_one_wei_takeover_rejected`                                                                                                                                                                                                                                                                                                                  |
| Operator/manager/coordinator impersonation         | `SeatBookTests.test_offer_operator_is_always_direct_caller` and `TargetBindingTests.test_unauthorized_manager_and_coordinator_are_noop`                                                                                                                                                                                                                                        |
| Five-key order and dual maturity                   | `SeatBookTests.test_full_five_key_pending_order` and `SeatBookTests.test_both_maturity_clocks_before_equal_after_boundaries`                                                                                                                                                                                                                                                   |
| Infeasible cheapest poison offer                   | `SeatTermTests.test_infeasible_poison_best_skipped_for_valid_standby_fill`                                                                                                                                                                                                                                                                                                     |
| Wrong-chain authorization/quote/cap/breach/release | `TargetBindingTests.test_wrong_chain_rejected_on_every_read_and_write`                                                                                                                                                                                                                                                                                                         |
| Stale-generation refundable-offer displacement     | `SeatBookTests.test_stale_generation_is_rejected_without_displacement`, `SeatBookTests.test_repeated_stale_generation_cannot_reset_honest_maturity`, and `MigrationTests.test_generation_sync_purges_old_pending_without_touching_stage`                                                                                                                                       |
| Old authorized target refills post-cutover book    | `MigrationTests.test_rotation_disables_old_purges_book_and_enables_new_atomically`, `MigrationTests.test_rotation_with_old_stage_conserves_bond_and_premium_or_rolls_back`, `MigrationTests.test_old_target_cannot_reinsert_after_rotation`, and `MigrationTests.test_abort_keeps_old_target_current_at_fresh_generation`                                                      |
| Rotation survives canceled/reorged cutover         | `MigrationTests.test_premature_canceled_or_reorged_cutover_rotation_is_noop`                                                                                                                                                                                                                                                                                                   |
| Arm-generation quote survives abort                | `MigrationTests.test_armed_phase_cannot_sync_or_mature_abort_generation_quote`                                                                                                                                                                                                                                                                                                 |
| Requote retaining old maturity                     | `SeatBookTests.test_requote_resets_timestamp_and_block_maturity`                                                                                                                                                                                                                                                                                                               |
| Requote changes tranche identity/binding           | `SeatBookTests.test_repeated_requotes_retain_one_tranche_creation_id`                                                                                                                                                                                                                                                                                                          |
| Active repricing upward                            | `SeatBookTests.test_active_ask_cannot_increase_in_place`                                                                                                                                                                                                                                                                                                                       |
| Promotion without segregated runway                | `PremiumTests.test_each_standby_has_a_segregated_promotion_runway`                                                                                                                                                                                                                                                                                                             |
| Repeated duty/term tranche reuse                   | `DutyTests.test_one_tranche_receives_at_most_one_duty` and `SeatTermTests.test_one_tranche_cannot_back_two_terms`                                                                                                                                                                                                                                                              |
| Roster mutation/reinstallation                     | `SeatTermTests.test_untouched_standby_term_ids_survive_revision`                                                                                                                                                                                                                                                                                                               |
| Exit/outbid responsibility laundering              | `SeatTermTests.test_exit_or_outbid_cannot_erase_responsibility`                                                                                                                                                                                                                                                                                                                |
| Overlapping terms share tranche                    | `SeatTermTests.test_one_tranche_cannot_back_overlapping_terms`                                                                                                                                                                                                                                                                                                                 |
| Pending-book Sybil saturation                      | `SeatBookTests.test_sybil_book_is_capital_backed_and_bounded`                                                                                                                                                                                                                                                                                                                  |
| Live standby eviction/front-running                | `SeatTermTests.test_live_standby_cannot_be_evicted_or_front_run_promotion`                                                                                                                                                                                                                                                                                                     |
| Refund before atomic roster removal                | `SeatTermTests.test_exit_keeps_term_bonded_and_promotable_until_atomic_removal`                                                                                                                                                                                                                                                                                                |
| Withdrawal after staged cutoff                     | `SeatBookTests.test_staged_offer_cannot_exit_or_be_replaced`                                                                                                                                                                                                                                                                                                                   |
| Stage replacement/reset grief                      | `SeatStageTests.test_later_quote_cannot_replace_or_reset_stage`                                                                                                                                                                                                                                                                                                                |
| Rank tampering/every vacancy                       | `SeatTermTests.test_selected_rank_is_deterministic_for_every_vacancy`, `SeatTermTests.test_equal_ask_rank_uses_offer_id_across_delayed_apply`, `SeatTermTests.test_full_lineup_qualifying_replacement_preserves_standbys`, `SeatTermTests.test_full_lineup_rejects_nonreplacing_standby_insertion`, and `SeatTermTests.test_rank_tampering_or_lineup_change_invalidates_apply` |
| Stage/reserve wedges stage                         | `SeatStageTests.test_expiry_recovers_stage_and_exact_reserve` and `SeatStageTests.test_lineup_invalidation_tombstone_recovers_reserve_without_market_call`                                                                                                                                                                                                                     |
| Migration strands stage funds                      | `MigrationTests.test_invalidated_stage_cancellation_accounts_exact_bond_and_reserve`                                                                                                                                                                                                                                                                                           |
| Handover into stale chain                          | `SeatStageTests.test_apply_requires_leading_sync_and_headroom`                                                                                                                                                                                                                                                                                                                 |
| Force-only immunity/reset                          | `DutyTests.test_force_only_recovery_never_resets_or_immunizes_duty`                                                                                                                                                                                                                                                                                                            |
| Late catch-up erases miss                          | `DutyTests.test_late_catchup_cannot_reopen_failed_service`                                                                                                                                                                                                                                                                                                                     |
| Promotion onto expiring round                      | `DutyTests.test_late_revision_or_short_runway_goes_vacant`                                                                                                                                                                                                                                                                                                                     |
| Late cure leaves successor limbo                   | `DutyTests.test_late_primary_cure_does_not_leave_successor_in_limbo`                                                                                                                                                                                                                                                                                                           |
| Selected-successor exit/removal                    | `DutyTests.test_selected_successor_cannot_exit_or_be_removed`                                                                                                                                                                                                                                                                                                                  |
| Sequential failovers overwrite history             | `DutyTests.test_three_sequential_failovers_retain_per_duty_successor_history`                                                                                                                                                                                                                                                                                                  |
| Unusable successor hides roster                    | `DutyTests.test_unusable_successor_closes_full_lineup_then_allows_reinstallation`                                                                                                                                                                                                                                                                                              |
| Underfunding/funding expiry                        | `PremiumTests.test_underfunded_installation_is_fail_open` and `PremiumTests.test_funding_expiry_closes_only_future_service`                                                                                                                                                                                                                                                    |
| Unsynchronized expiry overpay/hidden standbys      | `PremiumTests.test_unsynchronized_no_duty_expiry_caps_at_service_eligible` and `DutyTests.test_every_vacancy_reason_closes_full_lineup_and_records_disposition`                                                                                                                                                                                                                |
| Premium withdrawal before objective failover       | `PremiumTests.test_unsynchronized_failover_caps_premium`                                                                                                                                                                                                                                                                                                                       |
| Pre-delay underflow/canonical Market mutation      | `PremiumTests.test_claim_delay_before_service_start_cannot_underflow` and `PremiumTests.test_canonical_promotion_leaves_market_bytes_unchanged_until_accrual`                                                                                                                                                                                                                  |
| Reserve double-charge/premature free               | `PremiumTests.test_repeated_handover_expiry_and_promotion_preserve_reserve_sum`                                                                                                                                                                                                                                                                                                |
| Withdrawal front-runs enforcement                  | `ReleaseTests.test_withdrawal_cannot_front_run_breach_enforcement`                                                                                                                                                                                                                                                                                                             |
| Release before breach materialization              | `ReleaseTests.test_release_cannot_front_run_unmaterialized_breach`                                                                                                                                                                                                                                                                                                             |
| Breached tranche refunds operator                  | `ReleaseTests.test_breached_tranche_never_releases_to_operator`                                                                                                                                                                                                                                                                                                                |
| Duty ring blocks canonical progress                | `DutyTests.test_duty_ring_exhaustion_cannot_block_recovery_or_commit`                                                                                                                                                                                                                                                                                                          |
| Operator refusal pins duty ring                    | `ReleaseTests.test_uncooperative_operator_cannot_block_permissionless_release_and_reclaim`                                                                                                                                                                                                                                                                                     |
| Terminal tranche reclaims unreconciled history     | `ReleaseTests.test_release_reconciles_reserve_before_history_safe_reclaim` and `ReleaseTests.test_slash_reconciles_reserve_before_history_safe_reclaim`                                                                                                                                                                                                                        |
| Early enforcement deletes unmatured earned premium | `ReleaseTests.test_enforcement_waits_for_full_premium_cap_maturity_before_reconcile`                                                                                                                                                                                                                                                                                           |
| Non-duty release strands installed reserve         | `ReleaseTests.test_never_served_standby_release_returns_full_reserve_before_terminal` and `ReleaseTests.test_served_no_duty_close_matures_and_reconciles_before_release`                                                                                                                                                                                                       |
| Canonical reclamation calls market                 | `SettlementSeatTests.test_canonical_trace_has_no_market_or_payment_callback`                                                                                                                                                                                                                                                                                                   |
| Current target forges old breach                   | `ReleaseTests.test_old_exact_settlement_remains_the_only_disposition_source`                                                                                                                                                                                                                                                                                                   |
| Handover/satisfaction/failover/breach reorg        | `ReorgTests.test_each_seat_transition_rolls_back_with_parent_snapshot`                                                                                                                                                                                                                                                                                                         |
| Equality cure reorg through release                | `ReleaseTests.test_equality_cure_reorg_rolls_back_enforcement_and_release`                                                                                                                                                                                                                                                                                                     |
| Migration resets duty history                      | `MigrationTests.test_arm_preserves_terminal_duty_history`                                                                                                                                                                                                                                                                                                                      |
| Migration makes duty slashable                     | `MigrationTests.test_arm_materializes_slashable_and_excuses_other_duties`                                                                                                                                                                                                                                                                                                      |
| Abort resurrects term                              | `MigrationTests.test_abort_remains_vacant_and_requires_new_generation_quote`                                                                                                                                                                                                                                                                                                   |
| Old-target install without consent                 | `MigrationTests.test_old_target_quote_cannot_install_against_new_target`                                                                                                                                                                                                                                                                                                       |
| Pre-arm generation resurrects                      | `MigrationTests.test_pre_arm_generation_quote_remains_rejected_after_abort`                                                                                                                                                                                                                                                                                                    |
| Pending-exit/tenure bypass                         | `SeatTermTests.test_exit_requested_pending_offer_cannot_install` and `SeatTermTests.test_standby_and_promoted_exit_tenure_boundaries`                                                                                                                                                                                                                                          |
| Malformed exact-target returndata                  | `TargetBindingTests.test_malformed_revert_short_long_and_wrong_magic_rejected`                                                                                                                                                                                                                                                                                                 |
| Economic failure affects consensus                 | `SettlementSeatTests.test_every_market_failure_is_canonical_fail_open`                                                                                                                                                                                                                                                                                                         |

## 7. File responsibilities and exact commit set

Only these files may be staged in the Round 1 commit:

| File                                                                             | Responsibility                                                                             |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `docs/superpowers/plans/slotchain-round-01-normative-seat-economic-alignment.md` | Reviewed micro-plan and acceptance record                                                  |
| `packages/protocol/docs/preconfirmation-v2/tex/main.tex`                         | Complete normative prose, encodings, ordering, parameters, invariants, alternatives, gates |
| `packages/protocol/docs/preconfirmation-v2/slot-chain-spec.pdf`                  | Byte-identical circulation copy                                                            |
| `packages/protocol/docs/preconfirmation-v2/README.md`                            | Updated actors/status, contents, model commands/counts, build/check instructions           |
| `packages/protocol/docs/preconfirmation-v2/settlement-window-model.py`           | Integrated recovery/duty/failover/migration behavior                                       |
| `packages/protocol/docs/preconfirmation-v2/seat-market-model.py`                 | Standalone bounded market/economic model                                                   |
| `packages/protocol/docs/preconfirmation-v2/commitment-model.py`                  | Seat commitment encoders/vectors                                                           |
| `packages/protocol/docs/preconfirmation-v2/test-seat-market.py`                  | Standalone market/schema/adversarial tests                                                 |
| `packages/protocol/docs/preconfirmation-v2/test-settlement-window.py`            | Integrated settlement-seat tests; created because absent at preflight                      |
| `packages/protocol/docs/preconfirmation-v2/economic-profile.example.json`        | Strict, visibly uncalibrated example instance                                              |
| `packages/protocol/script/slotchain/check-slot-chain-docs.sh`                    | Deterministic model/test/PDF/reference checker                                             |
| `packages/protocol/package.json`                                                 | Adds only `slotchain:docs:check`                                                           |

No generated PNG, Tectonic cache, log, temporary PDF, Python cache, or unrelated formatting change
is committed. `tex/main.pdf` is ignored and ephemeral; the checker builds it only in temporary
directories and it is never part of the staged set.

## 8. TDD execution order

1. Record preflight status and hashes without modifying files.
2. Create the two unit-test files and the exact uncalibrated JSON instance.
3. Run the focused unit command and retain the expected missing-model/schema failure in the round
   notes.
4. Implement the standalone seat-market model until focused market/schema tests pass.
5. Modify the integrated settlement model until its focused tests and all pre-existing assertions
   pass.
6. Add commitment encoders/vectors and run the commitment model.
7. Amend every affected normative LaTeX section; use searches in section 10 below to prove stale
   rules are gone.
8. Update README and implement the documentation check script/package command.
9. Build the PDFs twice from clean temporary directories, compare hashes, copy the deterministic
   source PDF to the circulation path, and visually inspect.
10. Run the complete verification matrix, independent protocol/economic review, and test review.
11. Stage only the exact set in section 7, inspect the staged diff, and commit once.

## 9. Commands and expected results

All commands run from the repository root unless prefixed with `cd packages/protocol`.

### Preflight

```bash
git status --short --branch
git diff --stat
sha256sum packages/protocol/docs/preconfirmation-v2/slot-chain-spec.pdf
cd packages/protocol
python3 docs/preconfirmation-v2/commitment-model.py
python3 docs/preconfirmation-v2/lookahead-model.py
python3 docs/preconfirmation-v2/settlement-window-model.py
npx --yes pnpm@9.15.9 compile:shared
npx --yes pnpm@9.15.9 compile:l1
npx --yes pnpm@9.15.9 compile:l2
npx --yes pnpm@9.15.9 test:shared
npx --yes pnpm@9.15.9 test:l1
npx --yes pnpm@9.15.9 test:l2
```

### Required red run

```bash
cd packages/protocol
python3 -m unittest discover -s docs/preconfirmation-v2 -p 'test-seat-market.py' -v
python3 -m unittest discover -s docs/preconfirmation-v2 -p 'test-settlement-window.py' -v
```

Expected: each command separately exits nonzero. The seat-market test fails on the absent model or
its frozen API; the settlement test imports the existing model successfully and fails on a missing
new seat-duty/successor transition. A syntax or test-discovery error is not an acceptable red state.

### Focused green runs

```bash
cd packages/protocol
python3 -m unittest discover -s docs/preconfirmation-v2 -p 'test-seat-market.py' -v
python3 -m unittest discover -s docs/preconfirmation-v2 -p 'test-settlement-window.py' -v
python3 docs/preconfirmation-v2/seat-market-model.py
python3 docs/preconfirmation-v2/settlement-window-model.py
python3 docs/preconfirmation-v2/commitment-model.py
python3 docs/preconfirmation-v2/lookahead-model.py
python3 -m json.tool docs/preconfirmation-v2/economic-profile.example.json >/dev/null
```

Expected: zero exit; each standalone model ends with `ALL PROPERTIES PASS`; no test is skipped.

### PDF determinism and visual verification

`check-slot-chain-docs.sh` pins:

```text
TZ=UTC
SOURCE_DATE_EPOCH=1787961600
FORCE_SOURCE_DATE=1
```

The script must:

1. require Tectonic exactly `0.17.0` plus Python `pypdf`, failing with a clear dependency error if
   either is absent, then create two independent `mktemp -d` work directories;
2. copy only `tex/main.tex` into each;
3. run `tectonic --keep-logs main.tex` in each with the pinned environment;
4. compare the two generated PDFs with `cmp` and SHA-256;
5. compare the accepted result byte-for-byte with the tracked `slot-chain-spec.pdf`;
6. inspect the Tectonic logs for duplicate-label or unresolved-reference warnings, extract every
   page with `pypdf.PdfReader`, and fail on unresolved `??`, missing references, an empty page-text
   extraction, or stale live phrases listed below; and
7. delete temporary directories through a trap.

If Tectonic does not honor the pinned epoch, the script must fail until deterministic metadata is
achieved; manually copying a nondeterministic PDF is forbidden.

Render and visually inspect every changed page plus its neighbors, the table of contents, actors,
settlement/recovery, economics, security/liveness, implementation, migration, parameter table,
production gates, transition ordering, encodings, model appendix, and invariant checklist. Record:

- A4 page size and unchanged margin/header/footer geometry;
- no clipped tables, equations, code blocks, TikZ nodes, or page numbers;
- no orphaned headings or blank overflow pages;
- identical hashes for both temporary builds and the circulation PDF; and
- expected page count recorded in the Round 1 review note rather than hard-coded before layout.

### Full gate

```bash
cd packages/protocol
npx --yes pnpm@9.15.9 slotchain:docs:check
python3 -m unittest discover -s docs/preconfirmation-v2 -p 'test-*.py' -v
npx --yes pnpm@9.15.9 compile:shared
npx --yes pnpm@9.15.9 compile:l1
npx --yes pnpm@9.15.9 compile:l2
npx --yes pnpm@9.15.9 test:shared
npx --yes pnpm@9.15.9 test:l1
npx --yes pnpm@9.15.9 test:l2
forge fmt --check contracts test script
git diff --check
git status --short
```

Round 1 has no new Solidity storage layout, gas measurement, or code-size threshold. The unchanged
contract profiles are still run because `package.json` changes.

## 10. Stale-rule and consistency audit

The final review must account for every occurrence of these concepts in LaTeX, README, models, and
PDF text:

```text
seat, standby, aggregator, auction, penalty bond, premium, duty, failover,
DELTA_FINAL_LAG, DELTA_RECOVERY_LAG, DELTA_FAILOVER_LAG, DELTA_SLASH_LAG,
terminate incumbent, immediate burn, force-only, migration, vacant
```

Required results:

- no live normative path burns a seat at the recovery-open instant;
- the old `Seat` dataclass/immediate `_activate` burn survives nowhere in executable behavior;
- any retained 3,600-second value is labeled failover lag, not initial recovery/slash;
- force-only activation neither excuses nor resets an independently elapsed lag duty;
- canonical paths contain no Market, premium, bond, payout, or operator callback;
- no seat is needed to submit, prove, land, commit, recover, roll a round, or migrate;
- migration arm closes/excuses seat economics without moving ETH and abort remains vacant;
- all rejected alternatives and threat tables reflect the amended mechanism; and
- every parameter-table value agrees with the models and economic JSON.

## 11. Independent review checklist

Before commit, the protocol/economic reviewer must independently confirm:

1. bounded scans/storage and native-ETH conservation;
2. no seat authority leaked into consensus or proof ordering;
3. exact threshold fairness and full successor proof runway;
4. single-term/single-duty tranche use and release-race safety;
5. unsynchronized premium-cap safety and forced-ETH treatment;
6. force-recovery, late-cure, reorg, ring-exhaustion, and migration traces;
7. explicit uncalibrated status for every unsupported monetary/timing claim;
8. domain-separated commitment widths/order and mutation tests; and
9. deterministic, visually valid PDFs with clean references.

Any surviving critical/high finding returns the round to red. If correction changes a frozen field,
domain, formula, status discriminant, or economic key, update LaTeX, both models, commitment vectors,
JSON, and tests together before review repeats.

## 12. Commit procedure

```bash
git status --short
git diff --stat
git diff --check
git add \
  docs/superpowers/plans/slotchain-round-01-normative-seat-economic-alignment.md \
  packages/protocol/docs/preconfirmation-v2/tex/main.tex \
  packages/protocol/docs/preconfirmation-v2/slot-chain-spec.pdf \
  packages/protocol/docs/preconfirmation-v2/README.md \
  packages/protocol/docs/preconfirmation-v2/settlement-window-model.py \
  packages/protocol/docs/preconfirmation-v2/seat-market-model.py \
  packages/protocol/docs/preconfirmation-v2/commitment-model.py \
  packages/protocol/docs/preconfirmation-v2/test-seat-market.py \
  packages/protocol/docs/preconfirmation-v2/test-settlement-window.py \
  packages/protocol/docs/preconfirmation-v2/economic-profile.example.json \
  packages/protocol/script/slotchain/check-slot-chain-docs.sh \
  packages/protocol/package.json
git diff --cached --name-only
git diff --cached --check
git commit -m "docs(protocol): integrate perpetual reverse auction design"
```

The staged-name list must exactly equal section 7. Do not amend another round, squash unrelated user
work, or push as part of this micro-plan task.
