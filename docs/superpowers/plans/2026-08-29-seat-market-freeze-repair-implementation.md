# Seat-Market Freeze Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox
> (`- [ ]`) syntax for tracking.

**Goal:** Integrate the approved seat-market freeze repair into executable economic/Settlement
models, machine-readable vectors, the full LaTeX specification, the circulated PDF, and a single
cross-artifact release gate without writing Solidity.

**Architecture:** Keep canonical chain state in `settlement-window-model.py` and all offer, bond,
premium, release, and credit custody in a new `seat-market-model.py`. Join them only through exact
immutable views and explicit integration tests. Treat `tex/main.tex` as the final normative source,
generate the PDF reproducibly, and make one checker fail on any stale model, profile, term, vector,
README count, or PDF.

**Tech Stack:** Python 3.12 standard library (`dataclasses`, `enum`, `hashlib`, `json`, `unittest`,
`copy`, `importlib`), existing pure-Python Keccak helpers, POSIX shell, ripgrep, Tectonic/LaTeX,
Poppler `pdfinfo`/`pdftoppm`, bundled `pypdf`, Git.

---

## 0. Execution rules and file map

Authoritative approved design:

- `docs/superpowers/specs/2026-08-29-seat-market-freeze-repair-design.md`

Files to create:

- `packages/protocol/docs/preconfirmation-v2/economic-profile-model.py` — strict schema, units,
  arithmetic, production blockers, and economic inequalities.
- `packages/protocol/docs/preconfirmation-v2/test-economic-profile.py` — standalone standard-library
  profile tests.
- `packages/protocol/docs/preconfirmation-v2/economic-profile.example.json` — structurally valid,
  deliberately `UNCALIBRATED` example.
- `packages/protocol/docs/preconfirmation-v2/seat-market-model.py` — bounded auction, tranche,
  reserve, exact-credit, release, enforcement, and generation-sync model.
- `packages/protocol/docs/preconfirmation-v2/test-seat-market.py` — standalone Market unit and
  stateful invariant tests.
- `packages/protocol/docs/preconfirmation-v2/test-settlement-window.py` — standalone seat/duty/router
  integration tests over the Settlement model.
- `packages/protocol/docs/preconfirmation-v2/seat-market-vectors.json` — machine-readable exact
  identities and commitments.
- `packages/protocol/docs/preconfirmation-v2/slot-chain-toolchain.json` — source-controlled PDF epoch
  and exact document-tool versions.
- `script/slotchain/check-slot-chain-docs.sh` — one local/CI gate for every model, source, PDF, and
  stale-term check.

Files to modify:

- `packages/protocol/docs/preconfirmation-v2/settlement-window-model.py` — replace immediate-burn seat
  logic with lineup, duty, successor, preview-cap, release-view, and migration-completion state.
- `packages/protocol/docs/preconfirmation-v2/commitment-model.py` — add exact seat domains and verify
  the committed JSON vectors.
- `packages/protocol/docs/preconfirmation-v2/tex/main.tex` — integrate the complete approved repair
  and remove every superseded rule.
- `packages/protocol/docs/preconfirmation-v2/slot-chain-spec.pdf` — reproducible circulation build.
- `packages/protocol/docs/preconfirmation-v2/README.md` — artifact descriptions, exact commands, and
  final assertion counts.

Existing `lookahead-model.py` should remain behaviorally unchanged and must pass after every task.
The untracked historical file
`docs/superpowers/plans/slotchain-round-01-normative-seat-economic-alignment.md` is not part of this
plan and must not be added, edited, deleted, or committed accidentally.

Before each commit:

```bash
git status --short
git diff --check
node_modules/.bin/prettier <changed-markdown-or-json-files> --write
```

Stage only the files named in that task. Use normal repository hooks. If the fallback `pnpm` asks to
delete/reinstall `node_modules`, answer no, stop the commit, and fix the package-manager environment;
do not approve an unrelated destructive reinstall.

Every command in Tasks 1--6 that names only a local Python filename runs from
`packages/protocol/docs/preconfirmation-v2`. Each task starts from the repository root; do not rely
on a previous task's `cd` persisting. Tasks 7--8 state their own working directory explicitly.

## Task 1: Freeze the economic profile schema and arithmetic

**Files:**

- Create: `packages/protocol/docs/preconfirmation-v2/economic-profile-model.py`
- Create: `packages/protocol/docs/preconfirmation-v2/test-economic-profile.py`
- Create: `packages/protocol/docs/preconfirmation-v2/economic-profile.example.json`
- Reference: `docs/superpowers/specs/2026-08-29-seat-market-freeze-repair-design.md:680`

- [ ] **Step 1: Add a failing loader and production-rejection test**

Create `test-economic-profile.py` with a local hyphenated-file loader and the first tests:

```python
from __future__ import annotations

import importlib.util
import json
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parent


def load_module(filename: str, module_name: str):
    spec = importlib.util.spec_from_file_location(module_name, ROOT / filename)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


class EconomicProfileTests(unittest.TestCase):
    def test_example_is_structurally_valid_but_not_production_valid(self):
        model = load_module("economic-profile-model.py", "economic_profile_model")
        profile = json.loads((ROOT / "economic-profile.example.json").read_text())
        self.assertEqual(model.validate_schema(profile), ())
        self.assertIn("status must be CALIBRATED", model.production_blockers(profile))


if __name__ == "__main__":
    unittest.main(verbosity=2)
```

- [ ] **Step 2: Run the test and verify the red state**

Run:

```bash
cd packages/protocol/docs/preconfirmation-v2
python3 test-economic-profile.py
```

Expected: FAIL because `economic-profile-model.py` and the example JSON do not exist.

- [ ] **Step 3: Add the exact renamed schema sections and preserve the complete profile**

The JSON must contain at least these exact renamed sections and keys:

```json
{
  "schema": "taiko.slot-chain.economic-profile.v2",
  "status": "UNCALIBRATED",
  "profileId": null,
  "measurementCommit": null,
  "units": {
    "nativeAmount": "wei",
    "nativeRate": "wei/second",
    "builderAmount": "atomic"
  },
  "assets": {
    "builderLease": {
      "chainId": null,
      "address": null,
      "runtimeHash": null,
      "decimals": null
    },
    "nativeCustody": { "chainId": null }
  },
  "builder": {
    "leasePerWindowAtomic": null,
    "maximumBondAtomic": null,
    "reporterRewardCapAtomic": null
  },
  "seat": {
    "slaBondWei": null,
    "maximumAskWeiPerSecond": null,
    "minimumPrimaryTenureSeconds": null,
    "minimumStandbyTenureSeconds": null,
    "handoverDelaySeconds": null,
    "stageGraceSeconds": null,
    "maximumInclusionSeconds": 120,
    "handoverExecutionBufferSeconds": null,
    "premiumClaimDelaySeconds": null,
    "reorgStabilitySeconds": 1800,
    "recoveryLagSeconds": 1200,
    "slashLagSeconds": 5164,
    "seatRunwaySeconds": null,
    "maximumAvoidedServiceCostWei": null,
    "collusionSafetyMarginWei": null
  },
  "sinks": {
    "builderPenalty": { "asset": "BUILDER_LEASE", "address": null },
    "dataRent": { "asset": "NATIVE_ETH", "address": null },
    "seatPenalty": { "asset": "NATIVE_ETH", "address": null },
    "forcedExpiry": { "asset": "NATIVE_ETH", "address": null }
  }
}
```

First inventory every profile field already normative in `tex/main.tex`, then retain every unrelated
forced-envelope, data-session, reward-class, and builder timing field in the real example. Freeze the
complete permitted-key tree in one `EXPECTED_SCHEMA` constant used by `validate_schema`; after that
inventory is encoded, missing or unknown keys at any level must fail. The snippet above freezes the
renamed fields and unit/sink ownership only; it is not the complete top-level schema and is not
permission to delete other normative profile sections.

- [ ] **Step 4: Add the complete failing schema and arithmetic inventory tests**

Before implementing validation, encode a reviewed `PROFILE_RELATIONS` test table. Every row must
contain a stable name, `main.tex` source heading/anchor, exact JSON operand paths, relation operator,
checked evaluation function, and one-below/equality/one-above cases where the boundary is meaningful.
Inventory every existing normative relation whose operands are profile fields, including at least:

```text
builder bond * (Q_MAX + 1) < 2^256
liability residence < MAX_LIVE_WINDOWS
liability generations >= MAX_REPLACEMENTS_PER_WINDOW * MAX_LIVE_WINDOWS
lookahead/snapshot/finality/seal-margin geometry
G_MAX == DELTA_FINAL_LAG and fits the candidate-window cap
DELTA_TIP >= submit inclusion + CLOCK_SKEW
DELTA_FINAL_LAG >= activation + escape + submit + CLOCK_SKEW
ESCAPE_OFFSET >= depth time + proof time + margin
FORCE_DELAY >= W_SETTLE + T_INCLUDE_MAX
forced item/count/bytes/gas <= candidate and queue bounds
queue and terminal counts < UINT64_MAX
refund capsule word/ERC721/ERC1155 caps
kind-0 validity, kind-1 enqueue, process TTL, and data TTL lower bounds
canonical-history capacity > ceil((T_INCLUDE_MAX + REORG_MARGIN) / L1_SLOT) + 2
EIP-2935 history > arm/evidence/reorg replay horizon
session/live-window/ring capacities >= their bounded residence/GC requirements
```

Add the five new seat inequalities, identity/unit/sink/null checks, reporter reward split, malformed
decimal cases, booleans-as-integers, checked overflow at every multiplication/addition, and an
assertion that the table's source anchors still exist in normative LaTeX. Run the tests now and
demonstrate failure because `validate_schema`, `production_blockers`, checked helpers, and the real
example are not implemented.

- [ ] **Step 5: Implement deterministic validation and all inventoried relations**

In `economic-profile-model.py`, define checked arithmetic and stable blocker sorting:

```python
UINT256_MAX = (1 << 256) - 1


def checked_add_u256(a: int, b: int) -> int:
    result = a + b
    if a < 0 or b < 0 or result > UINT256_MAX:
        raise ValueError("uint256 addition overflow")
    return result


def checked_mul_u256(a: int, b: int) -> int:
    result = a * b
    if a < 0 or b < 0 or result > UINT256_MAX:
        raise ValueError("uint256 multiplication overflow")
    return result


def production_blockers(profile: dict) -> tuple[str, ...]:
    blockers: set[str] = set()
    if profile.get("status") != "CALIBRATED":
        blockers.add("status must be CALIBRATED")
    # Add exact identity, unit, sink, null, and inequality blockers here.
    return tuple(sorted(blockers))
```

`validate_schema` must reject unknown/missing keys, booleans where integers are required, negative
values, malformed decimal strings, duplicate/nested sink sources, and wrong asset/unit bindings.
`production_blockers` must evaluate every frozen `PROFILE_RELATIONS` row, not a hand-selected subset.
The new seat relations include:

```text
premiumClaimDelay >= reorgStability
seatRunway >= minimumPrimaryTenure + handoverExecutionBuffer + slaTail
handoverExecutionBuffer >= handoverDelay + stageGrace + maximumInclusion
slaBond >= maximumAsk * premiumClaimDelay
slaBond >= maximumAsk * minimumPrimaryTenure
           + maximumAvoidedServiceCost + collusionSafetyMargin
```

Implement `reporterReward = min(cap, slash)` with the remainder going only to the builder-token
penalty sink. Re-run the exact red suite until every legacy and new boundary/overflow case passes.

- [ ] **Step 6: Run the profile tests**

Run:

```bash
python3 test-economic-profile.py
```

Expected: every test passes; the example has zero structural errors and at least the deliberate
`UNCALIBRATED` production blocker.

- [ ] **Step 7: Commit Task 1**

```bash
git add packages/protocol/docs/preconfirmation-v2/economic-profile-model.py \
  packages/protocol/docs/preconfirmation-v2/test-economic-profile.py \
  packages/protocol/docs/preconfirmation-v2/economic-profile.example.json
git commit -m "docs(protocol): model slot chain economic profile"
```

## Task 2: Implement the bounded offer book and tranche lifecycle model

**Files:**

- Create: `packages/protocol/docs/preconfirmation-v2/seat-market-model.py`
- Create: `packages/protocol/docs/preconfirmation-v2/test-seat-market.py`
- Reference: `docs/superpowers/specs/2026-08-29-seat-market-freeze-repair-design.md:113`

- [ ] **Step 1: Write failing enum, capacity, and accounting tests**

Use `unittest` and the Task-1 `load_module` pattern. Pin the public discriminants:

```python
self.assertEqual(model.OfferLocation.NONE.value, 0)
self.assertEqual(model.OfferLocation.PENDING.value, 1)
self.assertEqual(model.OfferLocation.STAGED.value, 2)
self.assertEqual(model.TrancheUsage.OFFER.value, 1)
self.assertEqual(model.TrancheUsage.STAGED.value, 2)
self.assertEqual(model.TrancheUsage.INSTALLED.value, 3)
self.assertEqual(model.TrancheUsage.CLOSED_UNINSTALLED.value, 4)
self.assertEqual(model.BondDisposition.NONE.value, 0)
self.assertEqual(model.BondDisposition.OWNER_CREDITED.value, 1)
self.assertEqual(model.BondDisposition.PENALTY_CREDITED.value, 2)
```

Add tests for four pending entries, deterministic five-key order, fifth-entry rejection/displacement,
and the invariant:

```python
assert market.pending_count + market.staged_count <= 4
```

Before any transition implementation, also add red tests for successful and rejected insertion,
displacement, pending-only requote, pending exit/finalization, and exact-credit claim. Include wrong
caller, no-op/upward requote, zero payout, ask one below/equal/one above the immutable maximum, stale
offer ID, wrong target, stale generation, fresh checked `quoteSequence` at its maximum/overflow,
before/equal/after pending refund, repeated terminalization, malicious beneficiary substitution, and
claim replay. Add a malicious bond-credit beneficiary callback that recursively claims the same and
a second credit, plus a reverting beneficiary. Prove effects are recorded before interaction, no
double transfer/accounting decrement occurs, and a reverted transfer atomically restores claimed
state, credit amount, and aggregate accounting. Each rejection must compare the whole state to a
deep-copy snapshot.

- [ ] **Step 2: Run and verify the missing-model failure**

Run:

```bash
python3 test-seat-market.py
```

Expected: FAIL because `seat-market-model.py` is missing.

- [ ] **Step 3: Implement focused state types**

Create enums and dataclasses without transition behavior first:

```python
class OfferLocation(Enum):
    NONE = 0
    PENDING = 1
    STAGED = 2


class TrancheUsage(Enum):
    OFFER = 1
    STAGED = 2
    INSTALLED = 3
    CLOSED_UNINSTALLED = 4


class BondDisposition(Enum):
    NONE = 0
    OWNER_CREDITED = 1
    PENALTY_CREDITED = 2


@dataclass(frozen=True)
class Clock:
    timestamp: int
    block_number: int


@dataclass
class BondTranche:
    tranche_id: bytes
    operator: str
    bond_amount: int
    creation_sequence: int
    usage: TrancheUsage
    disposition: BondDisposition = BondDisposition.NONE
    installed_term_id: bytes | None = None
    pending_refund_at: int | None = None
    release_requested_at: int | None = None
```

Define separate `Offer`, `Stage`, `ExactCredit`, `PremiumReserve`, `MarketAccounting`,
`TargetAuthorization`, `ExactTargetView`, and `TransitionResult` records. Keep authority data immutable
inside test inputs.

- [ ] **Step 4: Implement exact accounting and invariant checks**

`MarketAccounting.assert_valid(actual_balance)` must check:

```python
accounted = (
    bond_escrow
    + outstanding_owner_credits
    + outstanding_penalty_credits
    + free_premium
    + reserved_premium
    + outstanding_premium_claims
)
assert actual_balance >= accounted
assert reserved_premium == sum(r.reserved_wei for r in live_reserves.values())
```

For every tranche, assert exactly one of escrow, owner credit, or penalty credit according to its
disposition. Surplus ETH creates no claimant.

- [ ] **Step 5: Implement insert, displacement, requote, and pending exit**

Required transition predicates:

- insertion derives `operator = caller`, requires the exact initialized current authorization/cache,
  and escrows one full bond;
- a stale generation cannot rank or displace;
- full-book insertion strictly beats the worst complete order key or rolls back;
- requote requires current exact `PENDING/OFFER`, no exit, same operator/tranche/bond, lower ask or
  same ask plus different nonzero payout, enforces `ask <= immutableMaximumAsk`, allocates a fresh
  checked `quoteSequence`/offer ID without narrowing or wraparound, and resets both maturity clocks;
- pending exit removes the cell immediately, sets `CLOSED_UNINSTALLED`, and leaves the bond escrowed
  until exact equality;
- displacement and generation purge terminalize directly to the deterministic owner credit.

- [ ] **Step 6: Complete the state matrix and replay properties**

Confirm the Step-1 rejection suite is green and extend it with deterministic action permutations and
credit replay properties; do not introduce a new public transition here without first adding its red
case.

Initialize a table-driven edge matrix whose rows are every public event implemented in Task 2 and
whose columns cover every `OfferLocation × TrancheUsage × BondDisposition` combination. Pin its
allowed Section 4.4 edges and require every other currently reachable edge to reject without
mutation. Task 3 extends this same matrix when it adds stage/install/release/enforcement. Even at this
stage, prove that a terminal `CLOSED_UNINSTALLED` tranche never re-enters an offer.

- [ ] **Step 7: Run Task-2 and baseline models**

```bash
python3 test-seat-market.py
python3 lookahead-model.py
python3 commitment-model.py
python3 settlement-window-model.py
```

Expected: new Market tests pass; all three existing model suites still report `ALL ... PASS`.

- [ ] **Step 8: Commit Task 2**

```bash
git add packages/protocol/docs/preconfirmation-v2/seat-market-model.py \
  packages/protocol/docs/preconfirmation-v2/test-seat-market.py
git commit -m "docs(protocol): model perpetual seat offer book"
```

## Task 3: Add staging, premium tails, release, enforcement, and reclamation

**Files:**

- Modify: `packages/protocol/docs/preconfirmation-v2/seat-market-model.py`
- Modify: `packages/protocol/docs/preconfirmation-v2/test-seat-market.py`
- Reference: `docs/superpowers/specs/2026-08-29-seat-market-freeze-repair-design.md:208`

- [ ] **Step 1: Write failing shared-capacity staging tests**

Add the composed trace:

```text
insert A/B/C/D -> stage A -> pending=3/staged=1
insert E -> E must displace one of B/C/D or revert; it cannot fill a fifth waiting slot
expire/invalidate A -> A returns exactly; pending=4/staged=0
```

Also cover empty-roster primary, pre-tenure standby fill, competitive replacement, caller rank
tampering, quote maturity immediately before/equal/after its threshold, immature structural poison,
one-wei-under/equal funding, and `SYNCED` with Market unchanged. Add deterministic timestamp-skip and
sync-order traces where a funded post-tenure interval remains installable, plus monotone sponsorship
fuzzing that proves added funding cannot turn a feasible candidate infeasible or change selection to
a higher ask.

Declare the expected model-only fault-point names in red tests now: after candidate selection,
reserve debit, offer-location change, reserve rekey, tranche-usage change, credit creation, and stage
clear. Each test arms one point and expects full rollback. They fail until Step 3 adds the hooks.

- [ ] **Step 2: Implement fixed-order `stage_best`**

Use one fixed `freePremium` snapshot and a maximum-four scan. The model must distinguish structural
infeasibility from funding:

```python
reserve = checked_mul_u256(offer.ask, profile.seat_runway_seconds)
if structurally_feasible and reserve > free_premium:
    return TransitionResult(ResultCode.UNDERFUNDED)
```

Because cost is rank-independent and asks are sorted, stop at the first structurally feasible
underfunded offer. Never anticipate outgoing-reserve release. Candidate, selected rank, reserve debit,
stage location, and capacity counts change atomically.

- [ ] **Step 3: Implement Market-side deadlines and stage reconciliation primitives**

```python
if replacing_primary:
    handover_at = max(active.minimum_tenure_until, now + handover_delay)
else:
    handover_at = now + handover_delay
stage_expires_at = handover_at + stage_grace
```

For a live primary, require
`stageExpiresAt + maximumInclusionSeconds <= serviceEligibleUntil`. Ordinary/lineup expiry restores
the exact reserved capacity and premium. Migration invalidation returns the reserve and owner-credits
the never-installed bond exactly once.

These are Market-side unit primitives against immutable `ExactTargetView` inputs, not a claim that a
split Market-only call can complete staging or apply. Do not expose a protocol-success path that can
leave only one component changed. Task 4 composes these primitives with Settlement state and proves
the shared revert domain.

Add deterministic model-only fault points after candidate selection, reserve debit, offer-location
change, reserve rekey, tranche-usage change, credit creation, and stage clear. Tests must arm one
fault at a time and prove the Market snapshot and accounting are byte-identical after rollback. Task
4 reuses these same hooks to prove two-component rollback; they are test instrumentation, not a
protocol API or production authorization path.

- [ ] **Step 4: Write failing ordinary-accrual tests, then implement exact accrual**

For `OPEN` started service, pin:

```text
settlementCap = exact Settlement.previewPremiumCap(seatTermId)
claimMaturedThrough = 0 if now < PREMIUM_CLAIM_DELAY
                      else now - PREMIUM_CLAIM_DELAY
accrueTo = max(
    lastAccruedAt,
    min(claimMaturedThrough, settlementCap, premiumFundedUntil))
earnedWei = ask * (accrueTo - lastAccruedAt)
```

First add red before/equality/after tests for claim delay, Settlement cap, and funding cap; repeat
accrual; checked multiplication; immutable payout; a canonically promoted standby whose first
economic call lazily authenticates `STARTED`; and a false unstarted sentinel that must not suppress
earned value. Then implement the monotone `lastAccruedAt` update and atomically move `earnedWei` from
the exact reserve into the immutable payout pull credit before withdrawal. A zero delta is
idempotent and no caller may supply the cap or payout.

- [ ] **Step 5: Write failing premium partition tests**

Pin the healthy-close formula for before/equality/after delay and random checked inputs:

```python
m = max(a, min(c, max(0, now - claim_delay)))
matured = ask * (m - a)
tail = ask * (c - m)
unearned = ask * (funded_until - c)
assert matured + tail + unearned == pre_close_reserve
```

Test zero ask, no reserve, unstarted standby, lazily started promoted service, repeated close,
reconcile before/equal/after, and forced-ETH surplus.

- [ ] **Step 6: Implement reserve lifecycle and exact pull credits**

Add `ABSENT`, `UNSTARTED`, `OPEN`, and `CLOSED_TAIL`. Healthy close credits only `matured`, returns only
`unearned`, and retains `tail` until `cap + delay`. Canonical/asynchronous close leaves bytes unchanged
until exact authenticated reconciliation. Claims use checks-effects-interactions and reentrancy guard
state in the model.

- [ ] **Step 7: Write failing installed release/breach race tests**

Cover:

- permissionless request/finalize crediting only immutable operator;
- request timestamp cannot reset;
- reserve must be absent before owner terminalization;
- later breach overrides a request but not an already terminal credit;
- penalty waits for both receipt stability and reserve maturity;
- exact owner/penalty credit exclusivity;
- claim refusal does not block Market's monotone history-safety predicate.

Pin the exact timing equations and test one second before, at equality, and one second after each
independent maximum component:

```text
dispositionStableAt =
    0                                      if no disposition timestamp
    dispositionAt + REORG_STABILITY       otherwise

evidenceSafeAt =
    0                                      if never installed
    lastLiabilityAt + EVIDENCE_DELAY + REORG_STABILITY otherwise

finalizeReleaseAt = max(
    releaseRequestedAt + RELEASE_CHALLENGE,
    dispositionStableAt,
    evidenceSafeAt)

reserveMatureAt =
    0                                      if absent or truly unstarted
    settlementCap + PREMIUM_CLAIM_DELAY   otherwise

ownerTerminalAt = max(finalizeReleaseAt, reserveMatureAt)
penaltyTerminalAt = max(
    breachReceipt.recordedAt + REORG_STABILITY,
    reserveMatureAt)
```

Test unresolved and breached duties, an earlier release request followed by a stable breach,
zero-sentinel branches, checked-overflow rejection, and a beneficiary that never claims.

For premium pull credits, add the same callback adversaries as the Task-2 bond-credit tests: recursive
self/second-credit claim and a reverting payout. Prove checks-effects-interactions, reentrancy guard
coverage across both credit classes, no double reserve/accounting decrement, and full transaction
rollback on failed transfer.

- [ ] **Step 8: Implement release safety and the Market reclamation predicate**

`request_release` must require historical `INSTALLED`, exact closed refundable Settlement term, and
nonterminal bond. `finalize_release` and `enforce_breach` reread exact target views immediately before
terminalization. `is_duty_history_safe` requires exact retained binding, terminal disposition, no
live offer/stage/roster occupancy, no reserve, every release/evidence/reorg/premium horizon enforced,
and a terminal tranche that can never bind another offer, term, or duty. It requires the immutable
closed term to remain. Add monotonicity and attempted-rebinding tests after both owner and penalty
terminalization.

Extend the Task-2 event/state matrix to every Section 4.4 row now implemented, including stage,
ordinary/lineup expiry, migration cancellation, install, release request/finalization, and breach.
Every event × location × usage × disposition combination not listed by the normative table must
reject with a byte-identical state snapshot. Prove explicitly that an `INSTALLED` tranche never
re-enters an offer and a never-installed tranche never reaches installed release or enforcement.

- [ ] **Step 9: Run Task-3 tests and stateful fuzz loops**

```bash
python3 test-seat-market.py
```

Expected: every named transition and at least 1,000 deterministic pseudo-random action sequences
preserve accounting, capacity, one-credit, and no-mutation invariants.

- [ ] **Step 10: Commit Task 3**

```bash
git add packages/protocol/docs/preconfirmation-v2/seat-market-model.py \
  packages/protocol/docs/preconfirmation-v2/test-seat-market.py
git commit -m "docs(protocol): model seat premium and bond lifecycle"
```

## Task 4: Replace immediate burn with the canonical seat/duty model

**Files:**

- Modify: `packages/protocol/docs/preconfirmation-v2/settlement-window-model.py`
- Create: `packages/protocol/docs/preconfirmation-v2/test-settlement-window.py`
- Reference: `docs/superpowers/specs/2026-08-29-seat-market-freeze-repair-design.md:493`

- [ ] **Step 1: Write a red source and behavior gate**

The new test runner must initially fail while the old direct seat-penalty implementation remains,
but it must protect the unrelated core recovery deadline:

```python
source = (ROOT / "settlement-window-model.py").read_text()
self.assertNotIn("burned_local", source)
self.assertNotIn("terminated: bool", source)
self.assertNotIn("self.active_seat.terminated = True", source)
self.assertIn("G_MAX = DELTA_FINAL_LAG", source)
```

`DELTA_FINAL_LAG` remains the core objective recovery/finality bound and may remain in recovery,
evidence-retention, parameter, and liveness calculations. What disappears is its direct authority to
terminate a seat or burn a bond inside canonical Settlement logic.

Add behavior tests for exact recovery/failover/slash equality, four-term lineup, single-duty tranche,
successor selection, ring-full vacancy, and canonical paths with a Market double that raises on every
call.

- [ ] **Step 2: Run and verify the old-model failure**

```bash
python3 test-settlement-window.py
```

Expected: FAIL on the superseded immediate-burn symbols or behavior.

- [ ] **Step 3: Introduce focused canonical seat records**

Replace the old `Seat` record with immutable/history-preserving records equivalent to:

```python
@dataclass(frozen=True)
class SeatTerm:
    term_id: bytes
    tranche_id: bytes
    offer_id: bytes
    operator: str
    payout: str
    ask: int
    installed_at: int


@dataclass
class SeatService:
    responsibility_start: int
    minimum_tenure_until: int
    premium_funded_until: int
    service_eligible_until: int
    closed_at: int | None = None


@dataclass
class Duty:
    duty_id: bytes
    term_id: bytes
    recovery_at: int
    failover_at: int
    slash_at: int
    satisfied_at: int | None = None
    status: DutyStatus = DutyStatus.OPEN
```

Use a four-cell lineup and fixed sequence-tagged duty ring. No canonical method accepts a Market
object or function.

- [ ] **Step 4: Implement common service start and funded handover interval**

Direct and promoted starts both compute:

```text
minimumTenureUntil = start + minimumPrimaryTenure
premiumFundedUntil = start + seatRunway
serviceEligibleUntil = fundedUntil - slaTail
```

Tenure gates only competitive replacement and voluntary exit. Failover, funding expiry, ring-full
vacancy, and migration override it. Promotion reuses the existing term/tranche identity and creates no
Market delta.

- [ ] **Step 5: Implement objective duties and `preview_premium_cap`**

The bounded view must derive the earliest surviving cap even before sync materializes it:

```text
healthy/migration closedAt
latched satisfiedAt
attached or objectively implied failoverAt
serviceEligibleUntil without a duty
ring-full objective recoveryAt
```

Add explicit omitted-sync tests: advance beyond recovery/failover/funding expiry, call preview and
Market accrual, and prove the omission cannot increase withdrawable premium.

- [ ] **Step 6: Add the composed Market/Settlement transaction harness**

Write red integration tests that clone both components before every noncanonical cross-component
call. Model `Settlement.stage_best(market, ...)`, `Settlement.apply_stage(market, ...)`, ordinary
stage expiry, and asynchronous lineup-invalidation reconciliation as one EVM-style revert domain:

- `SYNCED` permits only the exact leading Settlement delta and makes zero Market calls;
- successful stage atomically selects/debits/moves the Market offer and records the exact Settlement
  stage;
- successful apply atomically consumes/rekeys the Market stage, closes only the outgoing primary,
  and updates the exact lineup;
- ordinary permissionless expiry clears the exact Settlement stage and restores the exact Market
  offer/reserve in one transaction;
- canonical lineup invalidation writes only the Settlement tombstone, while later Market
  reconciliation authenticates that exact tombstone before restoring the offer/reserve; and
- stale lineup, target, generation, health, maturity, funded headroom, tombstone, or stage identity
  rolls both component clones back byte-for-byte.

Inject failure after each intermediate write in candidate selection, reserve debit, location change,
stage recording, outgoing close, reserve rekey, term install, and stage clear. No split-brain state
may survive. Keep these entry points explicitly noncanonical; canonical commit/recovery/failover code
still never receives or calls a Market object.

- [ ] **Step 7: Implement installed voluntary exit**

Add red before/equality/after tests and then model one-shot exit request plus permissionless removal:

```text
primaryExitAt = max(exitRequestedAt + EXIT_DELAY, minimumTenureUntil)
standbyExitAt = max(exitRequestedAt + EXIT_DELAY, minimumStandbyTenureUntil)
```

Competitive primary tenure applies only to primary voluntary exit/replacement. Reject exit of a
selected successor, prevent request-time reset, and leave tranche bond, reserve, and all existing
duty liability unchanged until exact roster removal. Funding expiry may close service before the
requested exit. Later sponsorship may extend funding but must never move the immutable exit deadline
later. Removal must preserve unaffected rank IDs/order and use the same two-component rollback
harness when Market reserve reconciliation is required.

- [ ] **Step 8: Write the composed reclamation trace, then implement the local cache**

First add a red four-operator trace: all duties become satisfied/excused, every operator refuses to
request release, finalize, claim, or reclaim, and unrelated callers must still drive permissionless
release request/finalization and reuse every duty cell. Include wrong three-way binding, premature
Market-safety false, replay, and terminal-credit-but-unclaimed cases.

Then implement `reclaim_duty_cell` as a noncanonical call that accepts only the exact immutable Market
safety result for the three-way binding. Canonical code reuses only the local monotone flag. A full
ring closes optional seat economics to vacancy and never reverts proof/commit/recovery.

- [ ] **Step 9: Run new and legacy Settlement tests**

```bash
python3 test-settlement-window.py
python3 settlement-window-model.py
```

Expected: new seat/duty tests pass and the complete legacy non-seat property suite still prints
`ALL PROPERTIES PASS` with its updated count.

- [ ] **Step 10: Commit Task 4**

```bash
git add packages/protocol/docs/preconfirmation-v2/settlement-window-model.py \
  packages/protocol/docs/preconfirmation-v2/test-settlement-window.py
git commit -m "docs(protocol): model seat duties and fail-open recovery"
```

## Task 5: Model the global/local migration handshake and generation synchronization

**Files:**

- Modify: `packages/protocol/docs/preconfirmation-v2/settlement-window-model.py`
- Modify: `packages/protocol/docs/preconfirmation-v2/test-settlement-window.py`
- Modify: `packages/protocol/docs/preconfirmation-v2/seat-market-model.py`
- Modify: `packages/protocol/docs/preconfirmation-v2/test-seat-market.py`
- Reference: `docs/superpowers/specs/2026-08-29-seat-market-freeze-repair-design.md:588`

- [ ] **Step 1: Write failing arm/abort completion tests**

Test exact router tuple binding and the full transaction rollback for wrong caller, generation,
old/target version, manifest, phase, magic, length, and trailing returndata. Include:

```text
manager writes ARMED
local leading sync commits a mature best
local seat arm still completes
manager receives exact SEAT_ARMED_MAGIC tuple
```

and abort where internal sync changes mode before exact `SEAT_ABORTED_MAGIC`.

Add arm traces one second before, exactly at, and one second after every strict slash boundary. After
the leading sync, every already-objective slash must create and retain the exact breach disposition/
receipt before any remaining duty is marked satisfied or `EXCUSED_MIGRATION`. Equality follows the
normative strict comparison. A post-boundary breached duty must never be converted into an owner-
refundable migration excuse.

- [ ] **Step 2: Implement router/manager model records**

```python
class RouterPhase(Enum):
    ACTIVE = 1
    ARMED = 2
    READY = 3


@dataclass(frozen=True)
class RouterWord:
    generation: int
    active_version: int
    target_version: int
    target_manifest_hash: bytes
    phase: RouterPhase
```

The manager writes the proposed global word, calls the manager-only Settlement completion callback,
validates fixed-length bound magic, and commits only if the whole call returns. Use one cloned global
state in tests so any callback failure restores router and Settlement bytes.

- [ ] **Step 3: Implement local arm/abort completion semantics**

The callback runs one bounded leading sync internally. Generic `SYNCED` is never returned to the
manager; after any sync delta it recomputes local state and continues. Arm increments seat generation
once, materializes every already-objective strict slash/breach first, then closes/excuses only the
remaining lineups and duties, records the exact tombstone, and leaves Market untouched. Abort retains
that generation and never resurrects consumed state.

- [ ] **Step 4: Write failing Market generation-sync fault tests**

Cover equal/lower/higher generation, ACTIVE versus ARMED, revert/OOG/short/long/wrong magic, wrong
chain ID, Settlement protocol version, Settlement address, runtime hash, and configuration hash,
staged untouched, and maximum-four pending purge. Every fault must preserve a complete Market
deep-copy snapshot. Insert/requote/pending-refund call counts to Settlement must remain zero. Add an
append-only authorization-registry trace with two old targets and one current target: old insertion,
requote, and staging must be disabled, while exact credit claim, breach enforcement, installed
release, and duty-history safety/reclamation must still succeed against each tranche's immutable
historical target.

Add rotation fault points after exact migration-stage cancellation, owner-credit creation, each
individual pending purge, old-target disablement, new-target enablement, generation-cache reset, and
current-target pointer update. Reuse the Market model's deterministic fault mechanism and require
complete Market/authorization/accounting deep-copy equality after every injected failure.

- [ ] **Step 5: Implement `sync_seat_generation` and rotation**

Use the exact authorized target derived from Market state. A higher ACTIVE generation purges pending
offers to owner credits and writes the cache last. Stage cancellation belongs only to the exact
migration tombstone path. Rotation validates old FROZEN/new ACTIVE and exact release-manager route,
performs stage cancellation and old purge, then changes installation target atomically.

Store target authorization in an append-only mapping keyed by the exact target authorization ID,
with separate `currentInstallationTarget` and `insertionEnabled` state. Never rewrite a historical
tranche to the current target. Release, enforcement, claim, and reclamation derive and authenticate
the target from the immutable tranche/term binding and remain executable after any number of
rotations. Rotation may disable new economic activity on an old target but cannot delete the exact
authorization or historical-operation route.

- [ ] **Step 6: Run migration and complete model regressions**

```bash
python3 test-seat-market.py
python3 test-settlement-window.py
python3 settlement-window-model.py
python3 lookahead-model.py
```

Expected: all pass; snapshot tests prove arm/abort leave every Market byte, bucket, and ETH balance
unchanged, and multi-rotation tests prove historical operations remain permanent while old target
insertion/staging remains impossible.

- [ ] **Step 7: Commit Task 5**

```bash
git add packages/protocol/docs/preconfirmation-v2/settlement-window-model.py \
  packages/protocol/docs/preconfirmation-v2/test-settlement-window.py \
  packages/protocol/docs/preconfirmation-v2/seat-market-model.py \
  packages/protocol/docs/preconfirmation-v2/test-seat-market.py
git commit -m "docs(protocol): model atomic seat migration handshake"
```

## Task 6: Freeze exact identities and machine-readable vectors

**Files:**

- Modify: `packages/protocol/docs/preconfirmation-v2/seat-market-model.py`
- Modify: `packages/protocol/docs/preconfirmation-v2/settlement-window-model.py`
- Modify: `packages/protocol/docs/preconfirmation-v2/commitment-model.py`
- Create: `packages/protocol/docs/preconfirmation-v2/seat-market-vectors.json`
- Modify: `packages/protocol/docs/preconfirmation-v2/test-seat-market.py`
- Modify: `packages/protocol/docs/preconfirmation-v2/test-settlement-window.py`
- Reference: `docs/superpowers/specs/2026-08-29-seat-market-freeze-repair-design.md:154`

- [ ] **Step 1: Add failing golden-vector assertions**

Pin domains for at least:

```text
TAIKO_SEAT_TARGET_AUTHORIZATION_V1
TAIKO_SEAT_TRANCHE_V1
TAIKO_SEAT_OFFER_V1
TAIKO_SEAT_STAGE_V1
TAIKO_SEAT_TERM_V1
TAIKO_SEAT_LINEUP_V1
TAIKO_SEAT_DUTY_V1
TAIKO_SEAT_BREACH_V1
TAIKO_SEAT_BOND_CREDIT_V1
```

Test that chain ID, Market, Settlement version/address/runtime/config, generation, tranche, quote
sequence, and OWNER/PENALTY kind substitutions all change the expected identity.

- [ ] **Step 2: Run and verify missing-vector failure**

```bash
python3 commitment-model.py
python3 test-seat-market.py
```

Expected: FAIL because the JSON vectors/domains are not yet present.

- [ ] **Step 3: Reuse one fixed-width identity codec in the model and vectors**

Keep `seat-market-model.py` as the single implementation of the already-frozen identity domains and
fixed-width field encodings. Reuse its exact functions from `settlement-window-model.py` and
`commitment-model.py`; do not create another codec that can diverge from either state machine.
Continue using the existing Ethereum Keccak and width-check helpers. Do not introduce
`hashlib.sha3_256`, dynamic ABI encoding, implicit address padding, or silent narrowing. Expose one
deterministic mapping of vector name to lowercase `0x` hash, and assert that every Market and
Settlement state-machine identity equals the vector mapping for the same inputs.

- [ ] **Step 4: Generate and then pin `seat-market-vectors.json`**

The file must include input fields and expected outputs, not only hashes. Generate once from the
reviewed model, review the diff, then make the model load the committed JSON and assert exact equality
on every subsequent run.

- [ ] **Step 5: Run vector substitution and stability tests**

```bash
python3 commitment-model.py
python3 test-seat-market.py
python3 test-settlement-window.py
```

Expected: all vectors pass and the output prints the exact new total count.

- [ ] **Step 6: Commit Task 6**

```bash
git add packages/protocol/docs/preconfirmation-v2/commitment-model.py \
  packages/protocol/docs/preconfirmation-v2/seat-market-model.py \
  packages/protocol/docs/preconfirmation-v2/settlement-window-model.py \
  packages/protocol/docs/preconfirmation-v2/seat-market-vectors.json \
  packages/protocol/docs/preconfirmation-v2/test-seat-market.py \
  packages/protocol/docs/preconfirmation-v2/test-settlement-window.py
git commit -m "docs(protocol): freeze seat market commitment vectors"
```

## Task 7: Integrate the repair into the full LaTeX specification

**Files:**

- Modify: `packages/protocol/docs/preconfirmation-v2/tex/main.tex`
- Create: `packages/protocol/docs/preconfirmation-v2/slot-chain-toolchain.json`
- Reference: `docs/superpowers/specs/2026-08-29-seat-market-freeze-repair-design.md`
- Reference: `docs/superpowers/specs/2026-08-29-perpetual-aggregator-seat-market.md`

- [ ] **Step 1: Record the red stale-term inventory**

Run:

```bash
rg -n 'Terminate and burn penalty bond|seat termination/burn|migration.coordinator|activationRunway|promotionRunway|REFUND_CREDIT' \
  packages/protocol/docs/preconfirmation-v2/tex/main.tex
```

Expected: matches proving the current LaTeX is stale. Save the relevant line numbers in the task
notes; do not mechanically replace terms without rewriting their surrounding transition rules.

- [ ] **Step 2: Replace the seat architecture and auction sections**

Add exact normative definitions for:

- four installed ranks and shared `pendingCount + stagedCount <= 4` capacity;
- full offer order, current-generation insertion, pending-only requote, delayed pending exit;
- nonzero requote payout, immutable maximum ask, checked fresh quote sequence/offer ID, and maturity
  reset;
- unified primary tenure/runway and all checked inequalities;
- rank-specific handover deadlines for replacement versus vacancy/standby insertion;
- maximum-four Market scan, gross reserve, `SYNCED`, apply, expiry, and tombstones; and
- exact IDs/encodings matching the committed vectors.

- [ ] **Step 3: Replace immediate seat burn with duty/failover/reclamation**

Keep the objective `DELTA_FINAL_LAG` recovery/finality condition, but remove its direct canonical
seat-termination/bond-burn side effect. Document duty creation, recovery, failover, strict slash,
successor selection, single-duty tranche, ring-full economic vacancy, objective `previewPremiumCap`,
permissionless release/enforcement, and monotone history safety exactly as modeled.

- [ ] **Step 4: Add orthogonal lifecycle and premium accounting tables**

Include the complete OfferLocation/TrancheUsage/BondDisposition transition table, exact-credit
identity, Market bucket conservation, reserve lifecycle, healthy matured/tail/unearned partition,
canonical delayed reconciliation, owner/penalty terminal times, and claim-independent reclamation.
Specify the exact ordinary-accrual `claimMaturedThrough`, `accrueTo`, `lastAccruedAt`, Settlement cap,
funding cap, checked earned-value transfer, lazy promoted start, and immutable payout rules. Specify
installed exit with exact `primaryExitAt`, independent `MIN_STANDBY_TENURE_SECONDS`, selected-
successor rejection via `selectedSuccessorTermId`, one-shot immutable `exitRequestedAt`, unchanged
bond/duty liability until removal, earlier funding expiry, and sponsorship that cannot postpone exit.

- [ ] **Step 5: Integrate migration with the existing global chapter**

Update the `ActiveSettlementRouter`/`ProtocolVersionManager` section rather than adding a competing
seat-only coordinator. Specify manager-only completion callbacks, exact tuple magic, internal sync
continuation, atomic rollback, retained generation on abort, no seat resurrection, target rotation,
and permanent historical claim paths.

- [ ] **Step 6: Replace the parameter and economic-profile sections**

Use asset-safe units, one top-level sink source, renamed builder atomic fields, common tenure/runway,
claim-delay/reorg, tail-grief, and collusive-promotion inequalities. Mark the example and production
numbers uncalibrated. Do not claim deployment readiness.

Create `slot-chain-toolchain.json` with a stable schema, fixed `sourceDateEpoch: 1787966400`, exact
Tectonic `0.17.0`, Python major/minor `3.12`, `pypdf` `6.10.0`, Poppler `26.05.0`, bundle URL
`https://relay.fullyjustified.net/default_bundle_v33.tar`, and resolved bundle content SHA-256
`6ffe055852f8faf66c0acbe1a7fb27f87b869a90bad1204f3bf4d9683f597c7c`. The epoch is an artifact-build
constant, not a commit timestamp; ordinary LaTeX repair commits must not change it. Changing any
locked value requires an explicit toolchain-policy review and a full PDF rebuild.

- [ ] **Step 7: Compile LaTeX and reject reference errors**

Run from the repository root. Read the source-controlled epoch and bundle URL, require the locally
resolved URL cache pointer to equal the locked content SHA-256, and compile cached-only. If the exact
bundle is absent, stop and provision that reviewed bundle; never silently resolve a newer default.

```bash
slotchain_source_epoch=$(python3 -c \
  'import json; print(json.load(open("packages/protocol/docs/preconfirmation-v2/slot-chain-toolchain.json"))["sourceDateEpoch"])')
slotchain_bundle_url=$(python3 -c \
  'import json; print(json.load(open("packages/protocol/docs/preconfirmation-v2/slot-chain-toolchain.json"))["tectonicBundleUrl"])')
slotchain_bundle_hash=$(python3 -c \
  'import json; print(json.load(open("packages/protocol/docs/preconfirmation-v2/slot-chain-toolchain.json"))["tectonicBundleSha256"])')
slotchain_bundle_root=$(tectonic -X show user-cache-dir 2>/dev/null | tail -1)
slotchain_bundle_pointer=$(rg --files "$slotchain_bundle_root/hashes" | \
  rg '/.*default_bundle_v33\.tar$')
test -f "$slotchain_bundle_pointer"
test "$(tr -d '\n' < "$slotchain_bundle_pointer")" = "$slotchain_bundle_hash"
SOURCE_DATE_EPOCH="$slotchain_source_epoch" tectonic \
  --bundle "$slotchain_bundle_url" --only-cached --keep-logs \
  packages/protocol/docs/preconfirmation-v2/tex/main.tex
if rg -ni 'undefined references|undefined citations|Emergency stop|error:' \
  packages/protocol/docs/preconfirmation-v2/tex/main.log; then
  echo "fresh LaTeX log contains a fatal/reference diagnostic" >&2
  exit 1
fi
```

Expected: Tectonic exits zero and the conditional finds nothing. Inspect all new overfull-box
warnings; fix any affecting tables, algorithms, or margins instead of suppressing them globally.

- [ ] **Step 8: Verify superseded and required terms in source**

Forbidden search must return no matches in normative LaTeX:

```bash
if rg -n 'Terminate and burn penalty bond|seat termination/burn|migration.coordinator|activationRunway|promotionRunway|REFUND_CREDIT' \
  packages/protocol/docs/preconfirmation-v2/tex/main.tex; then
  echo "normative LaTeX still contains a superseded seat rule" >&2
  exit 1
fi
```

Required searches must find every concept independently. One alternation is forbidden because one
surviving anchor could mask all missing anchors:

```bash
for slotchain_anchor in \
  DELTA_FINAL_LAG SEAT_RUNWAY HANDOVER_EXECUTION_BUFFER CLOSED_TAIL \
  OWNER_CREDITED PENALTY_CREDITED previewPremiumCap SEAT_ARMED_MAGIC \
  isDutyHistorySafe claimMaturedThrough accrueTo lastAccruedAt primaryExitAt \
  MIN_STANDBY_TENURE_SECONDS selectedSuccessorTermId exitRequestedAt; do
  if ! rg -n --fixed-strings "$slotchain_anchor" \
    packages/protocol/docs/preconfirmation-v2/tex/main.tex >/dev/null; then
    echo "missing normative LaTeX anchor: $slotchain_anchor" >&2
    exit 1
  fi
done
```

- [ ] **Step 9: Commit Task 7**

Only `main.tex` is tracked from the build directory; the toolchain lock lives one directory above:

```bash
git add packages/protocol/docs/preconfirmation-v2/tex/main.tex \
  packages/protocol/docs/preconfirmation-v2/slot-chain-toolchain.json
git commit -m "docs(protocol): integrate perpetual seat market specification"
```

## Task 8: Add the cross-artifact checker, rebuild the PDF, and update README

**Files:**

- Create: `script/slotchain/check-slot-chain-docs.sh`
- Modify: `packages/protocol/docs/preconfirmation-v2/README.md`
- Modify: `packages/protocol/docs/preconfirmation-v2/slot-chain-spec.pdf`
- Review: `packages/protocol/docs/preconfirmation-v2/slot-chain-toolchain.json`
- Test: every artifact created or modified by Tasks 1–7

- [ ] **Step 1: Write the checker with a deliberate red PDF comparison**

Create the parent directory, write the script, and preserve its executable bit:

```bash
mkdir -p script/slotchain
chmod +x script/slotchain/check-slot-chain-docs.sh
```

The script must use `set -eu`, resolve the repository root from its own path, allocate two
task-specific temporary directories with `mktemp -d`, and trap cleanup. It must run:

```text
test-economic-profile.py
test-seat-market.py
test-settlement-window.py
settlement-window-model.py
lookahead-model.py
commitment-model.py
```

Then it must validate required design anchors in the repair spec and required/forbidden terms in
LaTeX. Do not apply the forbidden-term scan to the historical repair spec itself: Section 11 names
the superseded terms that normative LaTeX must delete. Read `SOURCE_DATE_EPOCH` and allowed tool
versions from `slot-chain-toolchain.json`; build Tectonic with `--keep-logs` twice in independent
temporary directories; reject reference/citation/error diagnostics in both fresh logs; require the
two PDFs to be byte-identical; compare one generated PDF to the committed circulation PDF; extract
every page with `pypdf`; reject empty pages; and confirm required/forbidden PDF text. It must derive
tools portably from `SLOTCHAIN_TECTONIC`, `SLOTCHAIN_PYTHON`, `SLOTCHAIN_PDFINFO`, and
`SLOTCHAIN_PDFTOPPM` environment overrides or `PATH`, never a user-specific absolute path. Missing or
version-mismatched tools must fail with an explicit diagnostic before any comparison. Resolve the
exact URL's cached Tectonic bundle pointer, require its content to equal the locked bundle SHA-256,
and pass the locked URL with `--bundle --only-cached` on both builds; a missing bundle is a provisioning
failure, never permission to fetch an unreviewed default. Parse the exact model totals and
machine-check the corresponding README rows/status instead of trusting copied counts. Support one
explicit `--install-pdf` mode that performs every source/model/tool/log and
two-build reproducibility check, skips only the stale committed-PDF comparison, and then copies the
verified generated PDF into the circulation path. No other mode may write repository files.

The checker must test every required LaTeX/PDF anchor in an explicit loop or separate assertion;
never use one regex alternation whose success can be satisfied by only one surviving term. Required
economic lifecycle anchors include `claimMaturedThrough`, `accrueTo`, `lastAccruedAt`,
`primaryExitAt`, `MIN_STANDBY_TENURE_SECONDS`, `selectedSuccessorTermId`, and `exitRequestedAt`.

- [ ] **Step 2: Run the checker and verify stale-PDF failure**

```bash
script/slotchain/check-slot-chain-docs.sh
```

Expected: all model/source checks pass, then the checker reports only the deliberately stale README
counts/status and the committed PDF's stale semantics or byte mismatch. Diagnose and fix any other
failure before continuing.

- [ ] **Step 3: Update README from actual outputs**

Do not guess assertion counts. Copy the exact totals printed by the passing scripts. Document every
new file, the one-command checker, how the reproducible build epoch is derived, the exact Tectonic,
Python, `pypdf`, and Poppler versions used for the committed artifact, and the distinction between
implementation-ready design and production-deployable release.

- [ ] **Step 4: Rebuild and install the circulation PDF reproducibly**

```bash
script/slotchain/check-slot-chain-docs.sh --install-pdf
```

The checker removes only its own freshly allocated temporary directories. Do not copy `main.aux`,
`main.log`, `main.out`, or `main.toc` into Git.

- [ ] **Step 5: Extract and inspect PDF semantics**

Use the portable Python override contract (set `SLOTCHAIN_PYTHON` to the bundled workspace Python on
hosts whose default Python lacks the locked `pypdf`):

```bash
slotchain_python=${SLOTCHAIN_PYTHON:-python3}
"$slotchain_python" - <<'PY'
from pathlib import Path
from pypdf import PdfReader

path = Path("packages/protocol/docs/preconfirmation-v2/slot-chain-spec.pdf")
reader = PdfReader(path)
pages = [(page.extract_text() or "") for page in reader.pages]
assert pages and all(text.strip() for text in pages)
text = "\n".join(pages)
for forbidden in ("Terminate and burn penalty bond", "seat termination/burn", "REFUND_CREDIT"):
    assert forbidden not in text, forbidden
for required in (
    "DELTA_FINAL_LAG",
    "SEAT_RUNWAY",
    "CLOSED_TAIL",
    "previewPremiumCap",
    "SEAT_ARMED_MAGIC",
    "isDutyHistorySafe",
    "claimMaturedThrough",
    "accrueTo",
    "lastAccruedAt",
    "primaryExitAt",
    "MIN_STANDBY_TENURE_SECONDS",
    "selectedSuccessorTermId",
    "exitRequestedAt",
):
    assert required in text, required
print(f"PDF semantic check: {len(pages)} non-empty pages")
PY
```

- [ ] **Step 6: Render and visually inspect critical PDF pages**

Find page numbers containing auction, premium reserve, migration, release/reclamation, and parameter
headings with `pypdf`. Render those pages at 160 DPI using the bundled `pdftoppm`, then inspect each
PNG with the local image viewer. Verify no clipped tables, black boxes, overlapping algorithms,
orphan headings, broken cross-references, or unreadable fonts.

Command template:

```bash
slotchain_pdftoppm=${SLOTCHAIN_PDFTOPPM:-pdftoppm}
"$slotchain_pdftoppm" \
  -png -r 160 -f <page> -l <page> \
  packages/protocol/docs/preconfirmation-v2/slot-chain-spec.pdf <output-prefix>
```

If visual QA finds a defect, fix `main.tex`, rebuild, and repeat before proceeding.

- [ ] **Step 7: Run the complete checker twice**

```bash
script/slotchain/check-slot-chain-docs.sh
script/slotchain/check-slot-chain-docs.sh
```

Expected: both runs pass and produce identical committed-PDF comparison results, proving the build is
reproducible in the pinned environment.

- [ ] **Step 8: Commit Task 8**

```bash
git add script/slotchain/check-slot-chain-docs.sh \
  packages/protocol/docs/preconfirmation-v2/README.md \
  packages/protocol/docs/preconfirmation-v2/slot-chain-spec.pdf
git commit -m "docs(protocol): gate and publish repaired slot chain spec"
```

## Task 9: Final design-only freeze audit

**Files:**

- Review: every file listed in Task 0
- Do not modify contracts under `packages/protocol/contracts/`

- [ ] **Step 1: Freeze the exact snapshot**

Record branch, HEAD, status, and SHA-256 for the repair spec, LaTeX, PDF, every model/test, profile,
vector file, `slot-chain-toolchain.json`, README, and checker. Confirm the historical untracked
Round-1 plan was not committed.

- [ ] **Step 2: Run the complete local gate**

```bash
script/slotchain/check-slot-chain-docs.sh
git diff --check
git status --short
```

Expected: checker and diff check pass; status contains no implementation artifact change and only any
explicitly preserved unrelated user file.

- [ ] **Step 3: Dispatch three independent read-only reviews**

Give fresh reviewers only the frozen paths and hashes, not prior reasoning:

1. auction/economic-liveness/permissionlessness;
2. premium/bond/release/reclamation conservation;
3. canonical duty/migration/implementation feasibility and full LaTeX/PDF consistency.

Require concrete traces and critical/high findings only.

- [ ] **Step 4: Repair any validated critical/high finding in one commit per review round**

For every validated blocker: first add a failing model/checker regression, demonstrate the failure,
make the smallest normative/model change, rerun the complete gate, regenerate/inspect PDF if LaTeX
changed, and commit that round separately. Re-run the full three-view audit. Stop after three repair
rounds and report to the user if approval is still impossible.

- [ ] **Step 5: Issue the freeze verdict**

The only acceptable positive verdict is:

```text
IMPLEMENTATION-READY DESIGN FREEZE APPROVED
```

It requires zero critical/high finding, a passing reproducible checker, and exact artifact hashes.
State separately that production deployment remains blocked on calibrated measurements, proof/gas
evidence, manifest/verifier artifacts, independent implementation reproduction, formal verification,
operations readiness, and external audit.

Do not begin Solidity in this plan. Solidity implementation receives its own subsequent plan only
after this freeze verdict.
