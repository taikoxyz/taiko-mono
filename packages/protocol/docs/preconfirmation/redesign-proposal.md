# Taiko Based Preconfirmation Redesign — Perpetual Auction with Commit → Publish → Seal Epochs

> **Deliverable 2 of the preconfirmation redesign effort. Draft v3, 2026-08-20** — revised after
> two adversarial review rounds
> ([round 1](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5353544928),
> [round 2](https://github.com/taikoxyz/taiko-mono/pull/22034#issuecomment-5353904484); dispositions in
> [Appendix B](#appendix-b--review-dispositions)). This is a *design* document: mechanisms,
> invariants, incentives, parameters — no implementation details. Factual baseline:
> [`status-quo.md`](status-quo.md); resolved owner decisions: its §6.
>
> Prior art — the URC-based post-whitelist design
> ([reference](reference/post-whitelist-design.md)), the post-Shasta slashing design
> ([reference](reference/post-shasta-preconf-slashing.md)), and PR
> [#22019](https://github.com/taikoxyz/taiko-mono/pull/22019) — is consciously **not** followed;
> #22019 is implementation reference only, per the redesign brief.

---

## 0. Core invariants (normative)

Everything else in this document serves these. An implementation that violates any of them is
wrong regardless of what other sections say.

- **I1 — Total, bounded derivation.** The derivation function maps *any* committed + published
  byte string to a valid, bounded-cost L2 block sequence: malformed content degrades
  deterministically to default/empty blocks (as Shasta derivation already does today), and
  content exceeding the per-epoch zk-gas cap degrades deterministically at the cap. Therefore
  **every committed epoch has exactly one canonical outcome and that outcome is always
  provable by anyone holding the data.** "Unprovable content" cannot exist on-chain.
- **I2 — No fault requires the accused.** Every liveness-family fault is an objective,
  mechanically-decidable L1 fact; recording it **atomically locks the liability** (§8).
- **I3 — Single open epoch, always advanceable.** One canonical `openEpoch`; only a valid
  seal advances it; at every moment, at least one permissionless action exists that can
  eventually advance it (proven-content seal, empty seal, forced-only seal, or — as the
  disaster floor — expiry cancellation). Unproven material never blocks any of these.
- **I4 — Successor-safe parent.** Epoch N's outcome (content-with-DA or empty) becomes
  irreversible within a small bounded time after N's boundary (`Γb + κ`), and every deadline of
  every later actor measures from the moment its prerequisite became irreversible — never from
  wall-clock while blocked (automatic tolling).
- **I5 — Bounded global backlog.** If `openEpoch` lags the wall clock by more than `K` epochs,
  the protocol enters recovery-only mode (no new discretionary content) until the lag clears.
  Collateral, retention, and prover sizing are dimensioned against `K`, not against per-tenure
  arithmetic.
- **I6 — Forced inclusions are censorship-proof against the seat.** Once an epoch's forced
  snapshot is non-empty, the epoch's minimum valid outcome is the deterministic forced-only
  epoch, constructible and provable by anyone from L1 data alone; "empty" is invalid.
- **I7 — Only proven transitions lock state.** In every mode — normal, recovery, anarchy —
  canonical state changes only through proof-carrying seals (content, forced-only) or the
  deterministic proof-free resolutions (empty seal where valid; expiry cancellation), which are
  pure functions of on-chain state. Sender identity never affects what the outcome *is*.

---

## 1. Motivation and goals

The current system secures preconfirmations by trusting a whitelist; the designed URC/validator
replacement is blocked on URC maturity and validator adoption (status quo §1, §3.6). This
redesign removes both dependencies:

- **[G1]** Anyone can become the preconfer — rights are sold in a perpetual on-chain auction.
- **[G2]** Slashing from day one, on objective faults (I2).
- **[G3]** Non-validators can reliably act on L1 — every mandatory action has a multi-slot
  inclusion budget; the proof-carrying seal has a multi-epoch window.
- **[G4]** The pipeline collapses — sealed epochs finalize immediately; no separate prover
  market, no contestation, fast withdrawals.
- **[G5]** Halt-safe degradation with a permissionless endgame (I3), Phase A explicitly
  DAO-recoverable (§10.3).

Out of scope for the v1 implementation (owner decisions): per-transaction fair-exchange
enforcement (§12; *epoch-level* release **is** enforced — §5); multi-seat; based-validator
alignment.

---

## 2. Roles, tenures, and identities

Roles as before: **seat holder** (auction winner; sole sequencer; per-epoch duties), **standby
bidders** (bonded, auto-promoted), **observers** (permissionless evidence; rewarded),
**users**, **treasury/DAO**, **L2 nodes**.

**Tenures.** Each continuous holding period is a **tenure**: immutable id binding holder
address, registered proposer + commitment keys (rotations append, never overwrite; history
retained for the tenure's whole obligation tail), assigned epochs, and the collateral reserved
for it. Every artifact binds `(chain id, tenure id, epoch, acting role)`.

**Fault identity** (round-2 finding 9): the stable logical id of a fault is
`H(originChainId, tenureId, epoch, faultClass, position)` — independent of fork, mode,
relayer, or recoverer. Mutable routing (fork/domain, mode, envelope version) lives in a
separately domain-separated verdict envelope. A persistent consumed-set on the executing
contract keys on the logical id, so the same logical fault can never double-debit nor be
stranded by a transport change.

---

## 3. Time structure

L1 beacon epochs: `E = 384 s`, epoch `N` = `[T_N, T_N + E)`.

```text
sequencing [T_N ──────────────── T_N+E)      preconfs stream over P2P; publication may stream too
commit     by T_N + E + Γc                   EBC: one-shot content commitment (small tx)
publish    holder-only until T_N + E + Γb_h; open fill until T_N + E + Γb   (blobs, streamable)
irreversible at (last outcome artifact) + κ  observed → provisional → irreversible
seal       [T_N + d·E, T_N + (d+s)·E)        one proof-carrying seal finalizes the epoch
```

| Param | Meaning | Initial | Notes |
| --- | --- | --- | --- |
| `d`, `s` | seal deferral / window span (epochs) | 2, 2 | proof latency §10.1; `32·s` seal slots |
| `q` | auction transition delay (epochs) | 2 | current + next assignments final |
| `Γc` | EBC deadline after boundary | 8 slots | small tx |
| `Γb_h` / `Γb` | holder-exclusive / final publication deadline | 12 / 24 slots | streamable during the epoch; §5.2 |
| `κ` | reorg grace | 3 slots | §3.1 |
| `K` | global lag cap (epochs) | 8 | recovery-only mode beyond it (I5) |
| `K_empty` | max consecutive discretionary empty epochs | 16 (~1.7 h) | then tenure terminates without slash (§5.4) |
| `H_cancel` | published-unsealed cancellation horizon | 14 days | < blob retention; disaster floor (§6.7) |

Derived constraints: `d + s ≤ ~14` (mainnet derivation bounds; Hoodi raised);
`forcedInclusionDelay` and snapshot rules per §6.5; retention ≥ `H_cancel`; collateral horizon
includes `κ` and bridge/challenge time; withdrawal gating per §8.4.

### 3.1 Observed / provisional / irreversible (round-2 finding 7)

Deadline-relevant artifacts (EBC, publication slices, seals) are judged on the L1 chain
observed at the deadline **plus `κ` slots of grace**; within the grace, an artifact reorged
out may be resubmitted **only byte-identical** — resubmission can shift *when* an outcome
became irreversible, never *what* it is (the EBC is one-shot, slices are hash-bound to it, the
seal is deterministic given them). Epoch N's outcome is **irreversible** `κ` slots after its
deciding artifact (or deadline lapse); all successor deadlines measure from that moment (I4).
Deadlines do **not** wait for Ethereum finality — a finality stall does not stall the protocol;
a reorg deeper than `κ` that flips an epoch outcome is an exceptional event handled by the
recovery machinery (openEpoch rewinds with the L1 reorg since all records are L1 state), and
`κ` plus this exceptional path are included in the collateral/retention horizons.

---

## 4. The perpetual auction (L1)

- **Bid** = (TAIKO bond, ETH fee rate per epoch, prepaid ETH). Highest rate wins; ~10% minimum
  increment; governance reserve floor when vacant; fees debit per held epoch to the treasury
  (owner decision).
- **Transitions delayed `q` epochs**; current + next epoch assignments immutable — with one
  provisional edge (round-2 finding 7): an incoming assignment whose *parent* epoch outcome is
  not yet irreversible activates only when it becomes so (in practice `≤ Γb + κ` into the
  epoch; deadlines shift accordingly per I4).
- **Funding rule**: prepaid ETH ≥ `(q + 2)·feeRate + perEpochEscrows·(d + s)`, where
  per-epoch escrows fund publication fill and recovery/observer compensation in ETH (§8.5).
  Falling below is an automatic quit notice at the last funded epoch.
- **Reservation**: a tenure reserves `K·L_slash +` the safety reserve (I5 — global cap, not
  per-tenure arithmetic), checked against a conservative **ETH-value floor** for TAIKO
  (governance haircut; breach ⇒ top-up demand, short cure, then termination).
- **Termination**: on any recorded fault certificate (§8.2), on bond-below-reservation, or on
  exceeding `K_empty` consecutive discretionary empty epochs (no slash in that last case — the
  seat is a service; §5.4). No new epochs assigned beyond the already-final current + next; a
  downed holder's remaining epochs resolve empty at their boundaries. Highest standby promoted;
  none ⇒ Total Anarchy (§9). Fees pause during recovery-only mode (no service sold).

Lifecycle as v2 (Vacant → Assigned → Active → Draining/Terminating → Departed; Vacant →
Anarchy), with Departed gated by §8.4.

---

## 5. The per-epoch pipeline: commit → publish → seal

Purpose (unchanged from v2, timing hardened in v3): **epoch N's content is locked and
network-executable within slots — not epochs — of its boundary**; only the *proof* is deferred.

### 5.1 Commit — the epoch-boundary commitment (EBC)

One-shot per (tenure, epoch), due by `T_N + E + Γc` (8 slots): commits the complete ordered
content, the publication slice list, and the EOP tip. May be posted any time from the holder's
EOP onward. **Missing EBC ⇒ epoch is EMPTY-PENDING** (deterministic empty outcome — or
forced-only outcome if the snapshot is non-empty, per I6) **and a Missed-commit certificate is
recorded** (§8.2). An intentionally idle epoch requires an *explicit empty EBC* — valid,
unslashed, but counted against `K_empty` and invalid when the forced snapshot is non-empty
(I6). Silence is never ambiguous; content revealed after the EBC that differs from it is
invalid, and any conflict with previously signed P2P material is equivocation evidence.

### 5.2 Publish — streamed DA with escrow-funded fill (round-2 findings 3, 10)

Publication is **streamable during the epoch**: the holder may post blob slices as it
sequences; the EBC binds the final slice list. Remaining slices are **holder-exclusive until
`Γb_h`** (12 slots past the boundary), then **open**: anyone may post a byte-matching slice
until `Γb` (24 slots), claiming that epoch's **publication escrow** (prepaid ETH, §4) —
funding is the holder's own escrow, not a fault-contingent slash and not the treasury, so
timely third-party fill has a coherent payer, sybil bounty-farming buys nothing (the holder
funds it either way), and front-running an honest holder merely spends the escrow the holder
would have spent (sender identity never affects the outcome — I7).

**Missing publication at `Γb` ⇒ the epoch flips EMPTY-PENDING** (its committed content is
void) **and a Missed-publication certificate is recorded.** The v2 "missing-data notice" is
**deleted** — with `Γb` at 24 slots there is nothing for it to accelerate.

**Successor exposure** is now bounded to `Γb + κ ≈ 27 slots (~5.4 min)`: the successor
sequences its first slots provisionally on the P2P tip (which, against an honest predecessor,
it already has), and its own commit/publication deadlines measure from the parent's
irreversibility moment (I4). The alternative that makes the parent final strictly *before* the
successor's boundary — ending sequencing `Γpre` before `T_N+E` — buys absolute cleanliness at
a ~12% duty-cycle tax every epoch; v3 keeps the post-boundary schedule and flags the choice
for round 3 (§13.1).

### 5.3 Sequencing and preconfirmations (off-chain)

As v2: real-time envelopes + signed commitments over the existing P2P stack (binding tenure
id, epoch, block number + intra-epoch index, hashes, seal deadline, EOP), gossip validated
against the tenure registry, end-of-sequencing handover flow retained, `handoverSkipSlots`
retired. A preconf is credible iff signature, assignment, and intact reservation check out on
L1.

### 5.4 Explicit-empty epochs are bounded (round-2 finding 2)

An incumbent may run quiet epochs, but: (a) empty is **invalid whenever the forced snapshot is
non-empty** — the minimum outcome is then the forced-only epoch, constructible by anyone from
L1 data (I6), so forced inclusions (including bridged messages and observer evidence forced
past a censoring sequencer) land within bounded time regardless of the seat's behavior; (b)
each empty epoch still pays the auction fee; and (c) more than `K_empty` consecutive
discretionary empties terminates the tenure — not a slash (no promise was broken) but a
removal, because the seat exists to provide service. The anti-stall economics claim is
restated precisely: *silent* stalling costs `L_slash` per missed obligation plus termination;
*declared* idling costs the fee stream, bounded tenure, and zero user harm beyond what the
auction can re-price.

### 5.5 Seal — proof-carrying finalization

Within `W_N = [T_N + d·E, T_N + (d+s)·E)` (clock running only while admissible — I4), the
holder posts the seal: the validity proof of the epoch's canonical outcome (per I1, unique and
always provable from published data). Acceptance = finality; checkpoint saved. Proofs are
fully precomputable (§6.6); the seal itself is one small, retryable transaction.

---

## 6. The epoch state machine

### 6.1 Single open epoch (I3)

`openEpoch` = oldest unsealed epoch. Commits/publications happen at each epoch's own boundary
schedule regardless of `openEpoch`; **seals apply only to `openEpoch`**; only a valid seal
advances it; sealing an epoch before its sequencing period ends is invalid.

### 6.2 Lifecycle

```text
SEQUENCING ──┬─ no EBC by Γc ───────────────────────────► EMPTY-PENDING ─┐
 [T_N,T_N+E) ├─ explicit-empty EBC (snapshot empty) ─────► EMPTY-PENDING ├─► SEALED
             └─ content EBC ─► COMMITTED ─┬─ data by Γb ─► PUBLISHED ────┘
                                          └─ no data by Γb ─► EMPTY-PENDING
```

- **EMPTY-PENDING**: sealable by anyone, immediately (from `T_N + E`) and forever — the empty
  seal (or forced-only seal when the snapshot is non-empty) is deterministic, proof-free or
  proof-cheap, and a pure function of on-chain state (I7).
- **PUBLISHED**: sealable by the holder in `W_N`; thereafter in the permissionless recovery
  lane (§6.3); after `H_cancel`, cancellable (§6.7).

### 6.3 Recovery lane

Past its window (or from `T_N+E` if EMPTY-PENDING), sealing `openEpoch` is **permissionless
with no deadline** in every mode. By I1, any data-holder can seal a PUBLISHED epoch; by I6/I7,
anyone at all can seal empty/forced-only epochs. Occupation griefing (winning the
one-proposal-per-block race) buys delay at per-block cost against a lane with no deadline.

### 6.4 Empty and forced-only seals

The **empty seal** carries no blocks (valid only when the forced snapshot is empty). The
**forced-only seal** derives exactly the snapshot's blocks plus the anchor heartbeat — data
entirely on L1, proof required but cheap and open to anyone. Long empty runs therefore pause
anchor updates (L1→L2 messaging) only until someone forces a message through — which itself
makes the next epoch forced-only. Accepted degradation; noted for bridge-liveness review
(§13).

### 6.5 Forced-inclusion snapshots

Fixed per epoch before `T_N`; consumed exactly by that epoch's outcome, whenever sealed or
recovered; deterministic coinbase (original tenure or protocol address, never the tx sender).
Empty-resolved epochs pass their snapshot forward — **bounded** by I6 (a non-empty snapshot
forbids empty resolution, so a snapshot travels at most one epoch before it must be included
via forced-only). Snapshot items whose blobs have expired during an extreme outage are voided
(precedent: the post-incident `init3` voiding), counted in §13.

### 6.6 Epoch-native execution identity (derivation v3 = v2 + totality)

As v2: L2 block identity is `(epoch, intra-epoch index)`; no L1-inclusion-time inputs
(`proposalId`, sender, packing) anywhere in L2 headers or execution; all inputs snapshotted
before sequencing. v3 adds I1 explicitly: the mapping from (EBC, published bytes, parent
state, snapshot) to the block sequence is **total** (degrade-to-default, cap-at-zk-gas), so
outcome existence and provability are unconditional. Proofs are precomputable by holder and
successor alike, unaffected by anyone's L1-side behavior.

### 6.7 Expiry cancellation — the disaster floor (round-2 findings 1, 8)

If a PUBLISHED epoch remains unsealed for `H_cancel` (14 days — reachable only through a
sustained failure that recovery-only mode §7.2 has already flagged), anyone may **cancel** it:
its outcome is re-resolved as empty/forced-only (per I6, from surviving L1 data), and every
*later committed* epoch whose EBC chained to the cancelled content is cancelled in the same
deterministic cascade (their outcomes re-resolve likewise). Cancellation is a pure function of
on-chain state (I7), exists so that finite DA can never contradict I3, and is expected never
to fire outside disasters; its cascade semantics are a named review target (§13).

---

## 7. Backlog, tolling, and global bounds

### 7.1 Automatic descendant tolling (I4; round-2 finding 4)

Every deadline whose action is inadmissible (seal while `openEpoch` is older; commit while the
parent outcome is not irreversible) is tolled for exactly the inadmissibility duration —
mechanically computable from L1 records, applying to *every* affected actor, not only the one
doing recovery. An honest later holder can never be in breach because of an older epoch it
does not control.

### 7.2 Global lag cap and recovery-only mode (I5; round-2 finding 4)

If `openEpoch` lags the wall-clock epoch by more than `K = 8`, the protocol enters
**recovery-only mode**: new epochs resolve EMPTY-PENDING at their boundaries (no new
discretionary content, no fees charged), sequencing suspends, and all effort funnels into the
recovery lane, until the lag falls below `K' = 4`. This bounds the global backlog — and hence
retention, prover burst, and collateral horizons — by a constant, independent of how many
sybil tenures stack their `current + next` obligations. Repeated fault-and-promote cycles thus
converge to recovery-only mode instead of an unbounded queue.

### 7.3 Recovery compensation (round-2 economics)

Recovery work is compensated in **ETH at fixed, cost-covering rates** from the faulted
tenure's seized prepaid ETH and escrows: per-epoch content recovery ≈ proving + gas cost with
a small margin; empty/forced-only recovery a small fixed amount. The TAIKO slash itself is
**predominantly burned** (≥ 80%), with a small capped observer share. Consequence: the best
feasible self-recovery strategy reclaims only its own out-of-pocket ETH costs — the burn is
unavoidable, which is the deterrence metric; and recoverers' ETH-denominated costs are covered
regardless of TAIKO price shocks.

### 7.4 Retention

Everyone's retention duty runs to `H_cancel`; after `Γb`, L1 blobs are the retention for
committed epochs (P2P-only exposure ≈ `Γb`). Per-epoch zk-gas cap bounds each recovery unit's
proof bill (with I1's degrade-at-cap making the cap self-enforcing).

---

## 8. Faults, collateral, and adjudication

Owner decision honored with one round-2 refinement: the bond ledger and **all mechanically
decidable liveness facts execute natively on L1 at record time**; L2 (with proofs) remains
the adjudication layer for everything that requires L2 state — content faults — and for
reward distribution. (Round 1 offered this split as an option; round 2's finding 5 showed the
prove-L1-facts-back-to-L1 round trip creates a withdrawal race with no compensating benefit.)

### 8.1 Fault classes

| Fault | Decided | Effect at record time |
| --- | --- | --- |
| **Missed commit / publication / seal** (per §5; seal lateness judged on the tolled clock) | L1-mechanical (assignment + absence at deadline + κ) | Certificate recorded **and `L_slash` locked/debited atomically** (I2); tenure terminates |
| **Equivocation** (conflicting signed statements per (tenure, epoch, position) — commitments, EBC, EOP — or a signed statement vs. content the same tenure sealed) | L2, by observers, with proofs (signatures + L2 state + anchored L1 records where needed) | Verdict bridged; full remaining tenure reservation |

Anyone may poke the L1 recording functions; recording is permissionless and unauthenticated
(the facts are in contract state). Explicit-empty epochs are not faults (§5.4).

### 8.2 Certificates and evidence

L1 keeps per (tenure, epoch): assignment, EBC/publication/seal presence + times + acting
proposer + mode, and fault certificates. L2 adjudication reads L1 records via anchored state
roots when content faults need timing context. Fault consumption keys on the stable logical
id (§2). Verdict transport (bridge/signal service) queues across forks and emergency mode.

### 8.3 No framing

Safety faults require the accused's own signatures or its own sealed content; liveness
certificates name the tenure that held the duty. Recovery-mode seals are recorded as such and
can never read as the recoverer's own content or the original holder's timeliness.

### 8.4 Withdrawal gating (round-2 finding 5)

Collateral (bond remainder + prepaid ETH) releases only when: the tenure has **zero unresolved
fault certificates** (settled high-watermark), no unsealed epochs it was assigned, no open
escrows, no in-flight verdicts, and no active emergency/recovery-only mode — then a floor
delay (≥ 2 weeks). Since liveness liabilities are debited at record time (8.1), the gate's
job is ordering, not trust.

### 8.5 Funding summary

Prepaid ETH funds: epoch fees (treasury), publication escrows (§5.2), recovery/observer
compensation (§7.3). TAIKO reservation funds: the burn-dominant slashes. The ETH-value floor
(§4) keeps the reservation meaningful under price shocks.

---

## 9. Total Anarchy mode

No assigned holder ⇒ no preconfs, bonds, fees, or slashing. **The state machine and I-set do
not change** (round-2 finding 6): every anarchy epoch resolves EMPTY-PENDING at its boundary
(nobody can commit content for it — commitment rights belong to tenures), so from `T_M + E`
it is sealed permissionlessly as empty or forced-only per I6/I7. Consequences: in anarchy the
chain carries forced inclusions and heartbeats but no discretionary content — anyone wanting
more must win the auction (`q` delay). This deliberately resolves the reviewer's trilemma by
**removing anarchy content proposals entirely**: no unproven material exists to block empty
(I7), no empty seal can censor forced content (I6), and builder ordering decides nothing but
who pays the gas. It also collapses v2's anarchy-mode derivation special cases. The recovery
lane (for pre-anarchy backlog) remains fully open, and recovery escrows remain claimable.

Trade-off stated plainly: v2's anarchy could carry discretionary content; v3's cannot. Given
Phase A gating and the auction's `q`-epoch refill, the shorter, safer anarchy is preferred;
flagged for round 3 (§13.4).

---

## 10. Bootstrap, parameters, emergency brake

### 10.1 Proving latency

Content locked at `T_N+E+Γc`, published by `+Γb`; the seal is due `(d+s−1)·E` after the
boundary (~19 min) — precomputable throughout (§6.6). Sizing target: the recovery burst under
I5 (`K` epochs, zk-gas-capped each), not the steady state.

### 10.2 Economic parameters

| Parameter | Initial posture | Constraint |
| --- | --- | --- |
| `L_slash` | modest | `≥` fixed recovery compensation for one epoch (§7.3); ceiling per censorship corridor (§11.5) |
| Safety reserve | small at launch | ≥ κ·(aggregate outstanding-epoch MEV up to `K`), ETH-floor valued; governance-tracked |
| Reservation | `K·L_slash +` safety reserve | §4 |
| Burn share | ≥ 80% of every slash | deterrence = unavoidable burn (§7.3) |
| Observer share | ~5%, capped | |
| Publication escrow / recovery rates | fixed ETH amounts, cost-covering | §5.2, §7.3 |
| Fee floor / increment | governance-set | anti-squat / anti-flip |
| Withdrawal floor delay | ≥ 2 weeks | on top of §8.4 gating |

### 10.3 Phases

Unchanged: **A** — allowlisted `bid()`; endgame DAO-recoverable (stated plainly); small
bonds; `PreconfWhitelist` rotation retired. **B** — allowlist removed (G5 complete), gated on
§11.7 simulations. **C** — tuning and extensions. Cutover is a fork-level change.

### 10.4 Emergency brake

For systemic *proving* outages only (recovery-only mode I5 already handles backlog
objectively): seals suspend, nothing finalizes unproven, commits/publications continue up to
a backlog cap, liveness certificates arising from the outage are forgiven for its duration.
Hardened as v2: objective precondition (openEpoch age), bounded duration + auto-expiry,
withdrawal freeze for duration + challenge horizon, queued-verdict replay before any release.

---

## 11. Game-theory analysis (v3)

Notation: `F` fee/epoch, `L = L_slash`, `R` epoch revenue, `C_cen(k)` censorship cost over
`k` slots.

- **11.1 Squat-and-stall.** Silent: first missed commit ⇒ certificate + atomic `L` debit +
  termination; every further held epoch adds a certificate. Declared-idle: fees + `K_empty`
  termination + zero user harm beyond re-auction latency; forced content still flows (I6).
  Both re-priced claims now have mechanical backing.
- **11.2 Equivocation MEV.** Reservation aggregates up-to-`K` exposure at ETH-floor value;
  burn-dominance makes laundering pointless; draining tenures keep full reservation through
  the gate (§8.4).
- **11.3 Withholding.** Content locks at EBC; DA final at `Γb + κ` (~5.4 min); successor
  provisional exposure bounded and auto-tolled; late reveals invalid; the v2 notice and its
  timing hole are gone. Residual: the ~5-min provisional window (§13.1).
- **11.4 Successor/standby adversaries.** No framing (§8.3), no revenue theft (deterministic
  coinbase), no withheld-parent limbo (§5.2), recovery pays cost-only (§7.3) — promotion value
  is the only prize, priced against `C_cen` below.
- **11.5 L1 censorship.** Seal = one small retryable tx across residual window slots, judged
  on tolled clocks with `κ` grace and resubmission; a censored seal costs the chain delay
  only (recovery lane). Corridor: `0.5·L +` promotion value `≪ C_cen(residual)`, recomputed
  with proof-tail latency; FOCIL strengthens it.
- **11.6 Poison content.** Dead by I1 (total derivation): garbage publishes derive to default
  blocks, over-cap content degrades at the cap; every published epoch is provable by any
  data-holder; disaster floor §6.7 covers data loss. (Round-2 critical finding.)
- **11.7 Simulation plan (gates Phase B).** v2's scenarios plus: `Γb + κ` provisional-window
  abuse, `K`/`K_empty` boundary gaming (idle-toggle just under `K_empty`; lag oscillation
  around `K`), certificate-record censorship (poke permissionlessness under builder
  censorship), forced-only seal races, cancellation-cascade correctness, and TAIKO price-shock
  paths against ETH-denominated compensation.

---

## 12. Explicitly out of scope (v1 implementation)

Per-transaction fair exchange (epoch-level release is enforced; per-tx latency is not); user
restitution; multi-seat; based-validator alignment; automated bond scaling (rule +
measurement specified; execution manual).

---

## 13. Open issues for round 3

1. **Provisional successor window**: keep the `Γb + κ ≈ 5.4 min` provisional start (v3), or
   shave sequencing by `Γpre` for an absolutely-final parent at the boundary at ~12%
   duty-cycle cost? Quantify real-world blob-inclusion reliability for `Γb = 24`.
2. **`K` / `K_empty` / `H_cancel` calibration** and gaming at the thresholds.
3. **Cancellation cascade** (§6.7): full determinism proof, interaction with in-flight
   verdicts and bridged messages, and voided-snapshot UX (refunds?).
4. **Anarchy without discretionary content** (§9): acceptable, or does some proven-content
   lane belong in anarchy despite the trilemma?
5. **Bridge liveness during long empty runs** (§6.4): is forced-only heartbeat cadence
   sufficient for L1→L2 messaging SLAs?
6. **Deep-reorg exceptional path** (§3.1): specify openEpoch rewind semantics precisely.
7. **Certificate poke incentives**: who pays gas to record faults promptly when nobody
   benefits directly (small poke bounty from the debited `L`?).
8. **ETH-floor governance** capture and cadence.
9. **Phase-A → B objective criteria.**
10. **Client migration sequencing** against one fork cutover.

---

## Appendix A — Divergence from the brief (owner to confirm)

1–5 as v2 (window `s = 2`; termination on first fault; recovery escrows claimable in anarchy —
now via the recovery lane; "same proposals" enforced structurally via the EBC; proof gate
replaced by Phase-A allowlist). New in v3: **6.** commit/publish deadlines tightened to slots
after the boundary (streamed publication), the missing-data notice removed; **7.** anarchy
carries no discretionary content (forced-only + empty), making it a bridge to the next tenure
rather than a parallel proposing mode; **8.** liveness faults execute natively on L1 at record
time — L2-with-proofs adjudicates content faults and distributions (refines the "all slashing
on L2" decision along the line round 1 explicitly offered).

## Appendix B — Review dispositions

**Round 1** (7/7 blockers accepted): see v2 changelog — commit→publish→seal pipeline;
objective faults; single openEpoch + recovery lane; L1 record spine; epoch-native identity;
forced snapshots; `d+s+q` dimensioning (superseded in v3 by the global `K` bound).

**Round 2** (1 critical, 7 high, 2 medium — all accepted, two with explicit design-choice
notes):

| # | Finding | v3 response |
| --- | --- | --- |
| 1 (crit) | PUBLISHED poison halts openEpoch | **I1 total derivation** made explicit (degrade-to-default + cap-at-zk-gas ⇒ every published epoch provable); §6.7 expiry cancellation as the data-loss floor. Note: totality already exists in Shasta derivation; v2's failure was not stating it as an invariant |
| 2 | Explicit-empty censorship | **I6** forced-only minimum when snapshot non-empty (permissionlessly constructible from L1 data); `K_empty` termination; fees continue (§5.4) |
| 3 | Late DA consumes successor epoch | `Γb` cut from 1 epoch to 24 slots with streamed + escrow-funded fill; notice deleted; successor exposure `Γb + κ ≈ 5.4 min`, auto-tolled (§5.2; residual choice §13.1) |
| 4 | Per-tenure ≠ global bound | **I4** universal descendant tolling + **I5** global lag cap `K` with recovery-only mode; reservation re-based on `K` (§7.1–7.2) |
| 5 | Missed certificate doesn't lock collateral | Liveness faults execute natively on L1: certificate records **atomically debit** `L`; withdrawal gate adds zero-unresolved-certificates; L2 adjudicates only what L1 cannot decide (§8) |
| 6 | Anarchy trilemma | Anarchy carries no discretionary content: EMPTY-PENDING + forced-only under I6/I7 — no unproven material can exist to block or censor (§9; trade-off flagged §13.4) |
| 7 | Grace vs Γc parent fixing | Observed/provisional/irreversible states; byte-identical-only resubmission (one-shot EBC ⇒ outcomes monotone); no finality-wait; deep-reorg exceptional path; horizons include κ (§3.1) |
| 8 | Unbounded recovery vs finite retention | `H_cancel` cancellation before blob-retention expiry + recovery-only mode makes the horizon finite; retention duty runs to `H_cancel` (§6.7, §7.4) |
| 9 (med) | Fault-identity inconsistency | Stable logical id `H(originChainId, tenureId, epoch, faultClass, position)` + separate versioned envelope + consumed-set (§2) |
| 10 (med) | Publication reimbursement funding | Holder-funded per-epoch publication escrow with holder-exclusive subdeadline then open fill; sender identity never affects the outcome (§5.2) |
| econ | Sybil self-recovery reclaims ~55% | Compensation switched to fixed ETH cost-covering rates from seized prepaid ETH; TAIKO slash ≥ 80% burned — deterrence measured as unavoidable burn (§7.3) |
