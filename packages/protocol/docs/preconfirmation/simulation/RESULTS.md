# Protocol — Exhaustive State-Machine Model-Checking Results

**Artifact:** [`model_checker.py`](model_checker.py) — a self-contained Python explicit-state
model checker for the [redesign proposal](../redesign-proposal.md). The checker models the
**logical state machine** and was upgraded for the round-9 findings (the "v10 upgrade" below);
it tracks the proposal through **v12**.

> **Scope of the v11/v12 additions (r11-N5).** The v11 **default derivation rule** (§6.8), its
> `EBC`/`DEFAULT` mode pin, the **clock-capacity invariant**, the v12 default-anchor
> `max()` rule, and the §6.4 bridge terminal-cancellation handshake are **header-determinism and
> cross-chain properties below this checker's abstraction** (which collapses slot-level timing
> and headers into phases). They are discharged by the **§13-S.18 / §13-S.16 conformance
> vectors and proofs**, not by this state-machine checker. What the checker *does* verify about
> holderless epochs — that an unowned/forced-only/EMPTY epoch always has a constructible
> proof-free exit and never double-decides, seals out of order, or strands forced work — is
> unchanged by v11/v12 and re-confirmed by the runs below (the v12 mode-pin correction is a
> refinement of *which* proof-free seal applies, still modeled as `seal_empty`/forced-only).

**Question asked:** *can the new design reach an invalid state?*
**Answer (within the checked bounds and modelled configurations):** **No.** Across every
explored bound the checker found **zero reachable states or transitions violating any safety
invariant**, and — at every bound at or above the model's artifact-free horizon floor —
**deadlock-freedom**: from every reachable state an exit path to full finalization *with every
forced item consumed or refunded* always exists, even under an **adversarial proving outage
that never lifts** (v9): the proof-free floor plus the modeled forced-refund path is that
exit. Below-floor bounds report a precisely-characterized horizon-artifact class in the
outage-robust pass — documented in [Results](#results), never counted as a pass. (Precise
scope, round-8 W1: this is deadlock-freedom, not unconditional livelock-freedom under a fully
unfair scheduler — see [Liveness scope](#liveness--deadlock-freedom-and-its-scope).) Exploration is exhaustive **from a
curated set of initial configurations** (see [How it works](#how-it-works)) — it covers every
adversarial interleaving from those seeds, not every conceivable initial assignment. A mutation
self-test — now with a per-mutant **validity protocol** (baseline-clean check before every
mutant, r9-B5) — confirms the invariants are not vacuous: each of **seventeen**
deliberately-injected design bugs is caught by the check written to catch it.

> Scope honesty up front: this is *bounded* model checking of an *abstraction*. It exhaustively
> explores every adversarial interleaving up to a finite number of epochs and wall-clock steps,
> over a logical abstraction of the protocol (slot-level timing is abstracted into phases — see
> [Abstraction](#what-is-and-isnt-modelled)). It is strong evidence for the *logical* state
> machine (single-decision epochs with a **deadlined decision phase**, monotone `openEpoch`,
> cascade-voided commitments, ordered forced work with terminal refunds, typed seals, one-shot
> commits with L1-direct equivocation slashing, no double-debit, bond safety, no-frame, sticky
> evidence, halt-safety), not a proof about the eventual Solidity, and not a substitute for the
> game-theory and timing analysis in the design doc.

> **Revision note (v10 — round 9).** Two independent round-9 reviews audited the *checker
> itself* and found validity gaps (consolidated as r9-B5 and r9-D1–D7). This revision closes
> each one:
>
> - **r9-D1/B5 — the decision phase is now deadlined.** `decide`/`miss_commit` were
>   un-deadlined adversary choices — an epoch could linger undecided to the horizon, a relation
>   the protocol does not contain (the design has exactly *one* decision instant, `D+κ`, §3/§3.1).
>   Epoch `e` is now decidable only inside its **decision window** (`e ≤ clock ≤ e+1`; the
>   `D+κ` instant falls ~7 slots into wall-epoch `e+1`, so the tick past `e+1` is the first
>   clock event strictly after the outcome is fixed). The window-closing tick **auto-resolves**
>   any still-undecided epoch — EMPTY, or forced-only CONTENT when its snapshot is non-empty
>   (I6) — settling the owner's LIVENESS certificate atomically. A new edge invariant
>   `edge_decision_deadline` checks all three obligations on every transition; a new mutant
>   `late_decide` re-enables late decides and is caught by exactly it.
> - **r9-D2 — typed seals.** The single `seal` action is split into `seal_content` (the
>   proof-carrying closure of a CONTENT-decided epoch — discretionary *and* forced-only
>   content, per I7/§10.4 guarantee 2; disabled during a proving outage) and `seal_empty` (the
>   proof-free deterministic closure of an EMPTY-decided epoch; outage-immune). New edge
>   invariant `edge_typed_seal`: a proof-free-typed closure never closes a CONTENT-decided
>   epoch (I1). New mutant `empty_seal_steals_content` caught by exactly it.
> - **r9-D4 — EBC one-shot + L1-direct equivocation (§3.1/§5.1/§8).** A decide by an owned
>   seat now consumes that `(tenure, epoch)`'s commit one-shot (`committed[e]`). A new
>   adversary action `equivocate` models a *second distinct accepted* commit artifact, possible
>   only while the acceptance window is open (§3.1 artifact-set closure). Per the one-shot rule
>   the decision **never changes** (verified: `single_decision` covers it); the action
>   atomically settles an **L1-direct SAFETY certificate** (§8 variant (a), zero adjudication
>   latency) and **terminates the tenure** (still-SEQ epochs promote/drop to anarchy exactly as
>   for other terminations). Evidence stickiness is `edge_evidence_monotone` (existing); the
>   atomic certificate+termination is the new `edge_equivocation_settles`. Two new mutants:
>   `equivocation_flips_decision` (caught by `single_decision`) and `equivocation_no_cert`
>   (caught by `edge_equivocation_settles`).
> - **r9-B5 — per-epoch cancellation age (§6.7 `T_exp`).** The global-lag cancellation
>   enablement — which let one epoch's backlog age a *different* epoch into cancellability —
>   is replaced by a per-epoch tolled open-age: `openAge[e]` counts ticks epoch `e` spends
>   decided, unsealed and *effectively open*, and cancellation of the `openEpoch` is enabled
>   only when **that epoch's own** `openAge` exceeds `CANCEL_LAG` — the model of v10 §6.7's
>   mechanical per-epoch expiry `T_exp`. The v10 **no-overlap rule** (r9-F2: "seals valid
>   strictly before `T_exp`, cancellation at/after it") is enforced: the proof-carrying seal is
>   disabled once the epoch's expiry is reached. New edge invariant
>   `edge_no_seal_after_expiry`; new mutant `seal_after_expiry` (the overlap bug) caught by
>   exactly it. (See [Tolling](#model-parameters) for the one documented deviation:
>   "effectively open" rather than strictly "as the openEpoch".)
> - **r9-B5 — forced-work liveness goal + modeled refund.** The liveness goal is no longer
>   "all epochs closed": it now also requires **every forced item to reach a terminal state** —
>   consumed by its epoch's proof-carrying seal, or **refunded** (§6.4: expired snapshots void
>   with fees refundable; §10.4 guarantee 2: the unconditional forced-queue guarantee is
>   *refund*, not execution). The refund is now a modeled transition (taken when a cancellation
>   finds no still-SEQ epoch inside the bound to re-queue into), so the old "flags stranded on
>   cancelled epochs" horizon artifact is *gone* — the goal is honestly reachable and forced
>   work stranded live would surface as a halt.
> - **r9-D3 — ordered forced queue.** The per-epoch forced boolean is replaced by **ordered
>   item identities** (one per originally-forced epoch; id = the epoch the item was originally
>   due in, so ascending id = original queue order). Cascade re-queue preserves original queue
>   order (§6.7/r4b-M8) and consumption in `openEpoch` order respects it. New state invariant
>   `inv_forced_order` (global order, no live item on a closed/voided epoch, terminal-state
>   exclusivity — the consumed-xor-refunded nullifier the §6.4 bridge handshake relies on);
>   new mutant `requeue_reorders` caught by exactly it.
> - **r9-B5 — mutation-harness validity.** `--mutate` now runs a per-mutant protocol: (a) the
>   *unmutated* baseline at the mutant's bound must be fully clean (no violation, no halt, no
>   truncation) or the harness fails with an explicit error; (b) the mutant must produce a
>   counterexample attributed to the *expected* invariant (`stop_on_inv`); (c) the liveness
>   (outage) mutant runs at a bound whose baseline *outage-robust* pass is clean. All mutants
>   run at **2×5** — the smallest fully-clean bound under the v10 model. (The review suggested
>   3×4 for the outage mutant; under v10's per-epoch tolled expiry 3×4's own baseline reports
>   outage-robust horizon artifacts, so 3×4 is an *invalid* mutant bound now — the harness
>   would refuse it. Every mutant's counterexample, including the re-queue reorder and the
>   outage halt, is reachable at 2×5.)
> - **r9-D7 — `RESERVE0` sufficiency is a checked bound.** After exploration the checker
>   computes the **observed maximum cumulative debit per tenure** over all reachable states and
>   asserts `RESERVE0` covers it, printing both numbers and the slack. The formula itself grew
>   with the model: `RESERVE0 = 3·NEPOCHS + 1` (a missed-seal SEAL cert, a CANCEL cert, *and*
>   an equivocation SAFETY cert can now hit the same owned epoch).
> - **r9-D6 — worst-case-depth report.** The backward liveness passes now compute the maximum
>   over reachable states of the *shortest* path (in transitions) to a goal state — for the
>   standard relation and the outage-robust sub-relation — surfacing the "worst-case forced
>   march to finalization" as a printed number (see
>   [Worst-case depth](#worst-case-depth-to-finalization-r9-d6)).
> - **r9-D5 — `S_TICKS` parameter.** The number of tolled ticks an owned, decided,
>   effectively-open epoch may survive unsealed before its missed-seal certificate materializes
>   is now a parameter (default 1 — conservative: the fault matures at the first opportunity, so
>   every late-seal/withdraw ordering exists at the smallest bound; `--sticks 2` supported, with
>   a companion `--cancel-lag` so the expiry can scale with the deadline; a `S_TICKS=2` run is
>   in the results table).
> - **Housekeeping forced by the above (documented honestly):** per-epoch tolled expiry
>   serializes cancellation chains, raising the artifact-free liveness floor to
>   `MAXCLOCK ≥ NEPOCHS·CANCEL_LAG + 3` (the tool warns below it, and truncated exploration
>   is now a **hard failure**, never a silently-reported result). The clean `NEPOCHS=3`
>   bound that floor demands (3×6) did not complete within this session's ~15 GB/~20-min
>   practical limits (>11M states, frontier still growing at stop — and the below-floor 3×5
>   likewise exceeded them), so the **shipped default moved 3×4 → 2×6** — the largest bound
>   that completes cleanly on commodity hardware — with `3 6` one command away on larger
>   hardware; the state cap was raised 4M → 14M. The global lineage
>   generation counter was replaced by an equivalent bounded per-epoch lineage tag
>   (`CUR`/`STALE`) so state identity does not grow with cancellation history.

> Earlier revision notes (rounds 5–8, v7–v9) are unchanged in substance and kept in the
> repository history; their fixes — transition-level `openEpoch` monotonicity, real
> debit-conservation, the §6.7 cascade, read-time (I2) fault materialization, the v7
> simplifications, the v8 anarchy-content revert, the v9 outage mode and outage-robust
> liveness pass, the round-8 deadlock-freedom scoping, path-independent seal immutability,
> no-zero-floor debits, and the `stop_on_inv` mutation harness — are all still present and
> re-verified by this revision's runs.

---

## How it works

The protocol is encoded as a state `(per-epoch status + owner + ordered forced snapshot +
decision record + commit one-shot record + lineage tag + tolled open-age, global openEpoch,
wall-clock, mode, per-tenure reserve, settled certificates, consumed fault-ids, withdrawn
tenures, acting assignment record, proving-outage flag, forced-item terminal sets)`. From a
curated-but-broad set of initial owner/forced configurations (single owner, handover,
multi-handover, anarchy in every position, forced items in every position, all-forced,
none-forced, alternating), the checker does a **breadth-first exploration of every enabled
action**, where the adversary is maximally nondeterministic — at each state it may take any
legal action of any actor:

- **decide** an epoch to CONTENT or EMPTY (the commit) — only inside its **decision window**
  (`e ≤ clock ≤ e+1`, the coarse image of the single `D+κ` decision instant, §3.1); an owned
  decide consumes the `(tenure, epoch)` **commit one-shot**; **miss_commit** (objective
  liveness fault, certificate settled atomically with the EMPTY resolution) — and when a tick
  closes an undecided epoch's window, the epoch **auto-resolves** (EMPTY, or forced-only
  CONTENT under I6) with the owner's LIVENESS certificate settled atomically: the decision
  phase is irreversible *and deadlined* (r9-D1);
- **equivocate** (v10, r9-D4): a second distinct accepted commit artifact by the one-shot's
  consumer, inside the acceptance window — the decision never changes; an L1-direct SAFETY
  certificate settles and the tenure terminates atomically (§8 variant (a));
- **seal_content** the `openEpoch` (proof-carrying — discretionary *and* forced-only content;
  impossible during a proving outage; valid strictly *before* the epoch's expiry) — consumes
  the epoch's forced items; **seal_empty** the `openEpoch` (proof-free, outage-immune closure
  of an EMPTY outcome). *Withholding* a seal is the path where seal is simply not taken — an
  epoch that spends `S_TICKS` tolled, effectively-open ticks decided-and-unsealed settles the
  owner's missed-seal certificate deterministically (I2 read-time materialization), for **both
  decided outcomes**, with one carve-out (an epoch resolved through a missed commit already
  carries that owner's LIVENESS certificate; closing it is the recovery lane's job, not a
  second fault);
- **cancel** a CONTENT `openEpoch` whose own tolled `openAge` has passed its expiry
  (the per-epoch `T_exp`, §6.7 v10; the seal is already disabled at this age — no overlap),
  which also **cascades**: every committed-CONTENT unsealed descendant is voided, live forced
  items of the cancelled/voided epochs **re-queue in original queue order** to the earliest
  still-SEQ epoch — or take the **modeled refund** exit when no such epoch exists in the bound
  (§6.4; r9-B5) — and the causing tenure is charged an additional CANCEL-class certificate;
  **close_void** later closes a voided epoch as CANCELLED in `openEpoch` order;
- **debit** a settled certificate (one-shot per logical fault id);
- **promote** a terminated holder's successor (or drop to anarchy);
- **withdraw** a bond (only through the state-gate, which reads the computed matured set and
  — v10 — also refuses while any of the tenure's committed epochs still has an open
  acceptance window, the model of the ≥2-week floor outlasting every challenge window);
- **tick** the wall clock (drives window auto-resolution, tolled ages, missed-seal
  materialization, and recovery-only mode via the lag cap `K`);
- **outage_start / outage_end** (v9): toggle the proving outage — while active, proof-carrying
  seals are impossible and only proof-free resolutions advance the chain; the adversary may
  leave the outage on forever.

Only *legal* (design-permitted) transitions are in the relation; the invariants then verify that
the reachable set contains no bad state and no bad transition. (Injecting illegal transitions
would test the checker, not the design — so illegal moves appear only in the mutation self-test
below.)

### Model parameters

Documented so results are interpretable without reading the script:

- `NEPOCHS × MAXCLOCK` per the results table; `NTENURES = 3`; `L_LIVE = 1` (abstract slash
  unit).
- **Decision window** (r9-D1): epoch `e` is decidable at clocks `e` and `e+1`. Mapping: the
  design's single decision instant `D+κ = T_e + E + Γc + κ` falls ~7 slots (~22%) into
  wall-epoch `e+1`, so explicit decisions may land at coarse clocks `e` or `e+1` (preserving
  every handover interleaving the un-deadlined model reached), and the tick `e+1 → e+2` is the
  first clock event strictly after the outcome is fixed — it materializes the fixed outcome
  for whatever the adversary left undecided.
- **Forced-item ids** (r9-D3): one item per originally-forced epoch, id = that epoch's index —
  so ascending id is original queue order and the order invariant is "the concatenated live
  queue is ascending". Items end **consumed** (proof-carrying seal) or **refunded** (cancel
  with no re-queue target inside the bound — the modeled §6.4 blob-expiry refund, collapsed
  into the stranding step; its 18-day timing is a design-doc argument, not checked here).
- **`openAge` / tolling**: `openAge[e]` counts ticks epoch `e` is decided, unsealed and
  *effectively open* — every ancestor closed, or VOID/EMPTY (whose closures are I7's
  deterministic, zero-latency proof-free resolutions). Waiting behind a SEQ or CONTENT
  ancestor tolls (I4/§7.1: a descendant is never blamed while a real proving/expiry latency
  blocks it). **Documented deviation from the strict "as the openEpoch" reading:** under the
  strict reading, an adversary who simply declines the free permissionless closure of an
  EMPTY/VOID prefix pauses every descendant clock — the round-8 W1 unfair-scheduler residual,
  which weak fairness resolves at the protocol layer; in a *bounded* model it would
  manufacture outage-robust horizon artifacts at **every** bound. Treating a proof-free-only
  prefix as non-blocking is the bounded-model image of that weak-fairness assumption, applied
  at the finest grain the reviews asked for (per-epoch, tolled).
- **`CANCEL_LAG = 1`** (per-epoch expiry, §6.7 v10): epoch `e` is cancellable once
  `openAge[e] > CANCEL_LAG`, and its proof-carrying seal is **disabled** from that same age —
  the mechanical `T_exp` cutoff (r9-F2), no seal/cancel overlap ever. The design's 10-day
  `H_cancel` is deliberately collapsed to 1 tolled tick so the disaster lane — including
  *chains* of per-epoch expiries under a permanent outage — is reachable in tiny bounds. This
  over-approximates cancellation availability (safety-conservative: the cascade is exercised
  more, not less); the real `H_cancel` magnitude is argued in the design doc, not checked
  here. `--cancel-lag` overrides it (keep `CANCEL_LAG ≥ S_TICKS`, or the tool warns:
  expiry would disable seals before the seal deadline can even mature).
- **`S_TICKS = 1`** (r9-D5): tolled ticks a decided, owned, effectively-open epoch survives
  unsealed before the missed-seal certificate materializes. Default 1 is the conservative
  choice — the fault matures at the first opportunity, so every
  late-seal/seal-then-withdraw ordering exists at the smallest bound. `--sticks 2` delays
  maturation by one tick (a coarse image of the design's `S = 4`-epoch deadline exceeding one
  epoch); the results table includes such a run.
- **`K = 2`** global lag cap (design 8, scaled; recovery-exit `K'` scales to `lag == 0`).
- **`RESERVE0 = 3·NEPOCHS + 1`** per-tenure admission reserve: worst case is now *three*
  debits on one owned epoch — missed-seal SEAL, CANCEL, and (v10) the L1-direct equivocation
  SAFETY cert — across all epochs a tenure can own. The design splits these across the
  recovery tranche and the ETH safety tranche of the single account (§4); one abstract
  reserve stands in for the waterfall, and the observed-max check below reports the real
  slack (r9-D7).
- **Artifact-free liveness floor: `MAXCLOCK ≥ NEPOCHS·CANCEL_LAG + 3`.** Per-epoch tolled
  expiry serializes cancellation chains: each CONTENT epoch of an all-forced backlog can
  delay its successor's tolled clock by up to `CANCEL_LAG` valid-seal ticks, and the last
  epoch (decidable as late as clock `NEPOCHS+1`) still needs `CANCEL_LAG+1` fresh ticks to
  its expiry. Below the floor the outage-robust pass reports **horizon artifacts** (the tool
  warns); at or above it, none remain. This floor is the model-scale image of the design's
  honestly-stated worst case — **one cascade per `H_cancel` horizon** under a permanent
  outage (§6.7, r9-A4).
- **State cap 14,000,000** — hitting it now **fails the run** (exit ≠ 0) with an explicit
  truncation error; exploration is never silently partial.

After the state graph is built, backward reachability from the goal set — **all epochs closed
AND every forced item terminal** (r9-B5) — identifies any reachable state that cannot reach
full finalization (a deadlock, violating G5/I3), in the standard relation and in the
outage-robust sub-relation (excluding `outage_end`). **Halts fail the exit code exactly like
safety violations do.**

### Liveness — deadlock-freedom and its scope

The liveness property the checker establishes is **deadlock-freedom**: from every reachable
state an exit path to a goal state (fully sealed *and* all forced work consumed or refunded)
exists — equivalently, there is no reachable *terminal-avoiding trap* (no SCC from which
finalization is unreachable) — in both the standard relation and the **outage-robust**
sub-relation (finalization stays reachable even if a proving outage never lifts). What the
checker does **not** establish, and what no checker of this model can (round-8 W1), is
**livelock-freedom under a fully unfair scheduler**: because every action — the clock tick, the
permissionless advancing seal/cancel, even toggling the outage flag — is adversary-selectable,
the non-terminal subgraph is full of cycles an adversary could loop in forever simply by
*declining* the advancing action. That residual is inherent to *any* permissionless-liveness
property; it is resolved not in the model but at the protocol layer, by **weak fairness**: the
advancing action is open to every honest party, so an always-enabled permissionless action is
eventually taken by someone honest, and deadlock-freedom then upgrades to finalization. (The
same weak-fairness assumption, applied at the finest per-epoch grain, is why a proof-free-only
prefix does not toll a descendant's expiry clock — see [Model parameters](#model-parameters).)

## Invariants checked

State invariants (at every reachable state):

| Invariant | Design source | Meaning |
| --- | --- | --- |
| `single_decision` | I2, §3.1, §5 | an epoch is decided at most once; its status never flips its recorded decision — including under equivocation (the one-shot: first accepted artifact wins, r9-D4) |
| `closed_is_prefix` | I3, §6.1 | seals happen strictly in `openEpoch` order — no closed epoch above an open one |
| `open_monotone` | I3 | `openEpoch` always equals the lowest non-closed epoch |
| `seal_immutable` | Immutability corollary | a SEALED/CANCELLED epoch never changes afterwards |
| `empty_not_forced` | I6 | an epoch never resolves EMPTY while its forced snapshot is non-empty |
| `forced_order` (v10) | §6.7, r4b-M8, §6.5, r9-D3 | the global live forced queue stays in original submission order; no closed/voided epoch retains a live item; live and terminal are disjoint and consumed-xor-refunded is exclusive (the §6.4 bridge-handshake nullifier) |
| `content_current_gen` | §6.7 | every live CONTENT commitment carries the current lineage tag — a commitment that predates an ancestor's cancellation must have been voided by the cascade, never left sealable |
| `bond_nonneg` | §4, §8 | a slash never drives a reserve below zero |
| `no_frame` | §7.2, §8.3 | a certificate only ever names the acting owner of that epoch |
| `withdraw_gated` | §8.4, I2 | no withdrawn tenure retains an unresolved certificate or unsealed owned epoch |

Edge invariants (at every transition):

| Invariant | Design source | Meaning |
| --- | --- | --- |
| `edge_open_monotone` | I3 | `openEpoch` never decreases across any transition |
| `edge_evidence_monotone` | I2 | settled certificates (SAFETY included), consumed ids, and forced-item terminal states never disappear — no action (a late seal included) can erase matured evidence |
| `edge_debit_conservation` | I2, §8 | a reserve decreases only by consuming exactly one fresh logical fault id — no double-debit, no id-less debit, no cross-tenure debit; checks *every* debit, including at exhausted reserve |
| `edge_maturity_materialized` | I2, r9-D5 | a tick that brings a DECIDED (content or explicit-empty), owned, effectively-open epoch's tolled age to `S_TICKS` must settle that owner's missed-seal certificate (unless its miss-commit LIVENESS certificate already stands) |
| `edge_seal_immutable` | I3+I7 corollary | **path-independent** (round-8 W2): no single transition may change an already-CLOSED epoch's status — dedup cannot mask a re-open |
| `edge_decision_deadline` (v10) | §3.1, I2, r9-D1 | no transition decides an epoch whose window has closed; no undecided epoch survives any transition past its window; the window-closing resolution of an owned epoch settles its owner's LIVENESS certificate atomically |
| `edge_typed_seal` (v10) | I1, I7, r9-D2 | a proof-free (empty-typed) closure never closes a CONTENT-decided epoch; a proof-carrying content seal only consumes a CONTENT decision |
| `edge_no_seal_after_expiry` (v10) | §6.7, r9-F2/B5 | no transition closes an expired CONTENT `openEpoch` as SEALED — seals strictly before `T_exp`, cancellation at/after, never both |
| `edge_equivocation_settles` (v10) | §8, r9-D4 | an equivocation atomically settles an L1-direct SAFETY certificate against the equivocating tenure and terminates it |
| **liveness / deadlock-freedom** | **G5, I3, r9-B5** | **from every reachable state, full finalization — all epochs closed and all forced work terminal — is still reachable (standard + outage-robust); scope per [Liveness](#liveness--deadlock-freedom-and-its-scope)** |
| **outage-robust halt-safety** (v9) | **G5, I3, §10.4** | **the goal is reachable even if an active proving outage never lifts** — checked over the sub-relation excluding `outage_end`, so the proof-free floor (empty seals, void closure, cancellation with re-queue and refund) carries the whole burden |

## Results

All runs in the following table completed the **full exploration from the curated initial
configurations** (no state-cap truncation — truncation is a hard failure now) and reported
`SAFETY: NONE`, `LIVENESS: NONE` (no halt), and a passing `RESERVE0` sufficiency check, with
exit code 0 — re-run at the end of the revision and bit-for-bit reproducible:

| Bound (`NEPOCHS × MAXCLOCK`, params) | Reachable states | Goal (all-closed + forced-terminal) states | Safety violations | Halts (std / outage-robust) | Worst depth (std / robust) | Max debit / RESERVE0 | Wall time |
| --- | ---: | ---: | :---: | :---: | :---: | :---: | ---: |
| 2 × 5 (mutation-suite bound) | 409,954 | 223,282 | 0 | 0 / 0 | 6 / 7 | 5 / 7 | ~28 s |
| **2 × 6 (default)** | 508,276 | 282,130 | 0 | 0 / 0 | 6 / 7 | 5 / 7 | ~35 s |
| 2 × 7, `S_TICKS=2`, `CANCEL_LAG=2` (r9-D5) | 432,782 | 203,348 | 0 | 0 / 0 | 6 / 8 | 5 / 7 | ~29 s |

**Three-epoch coverage, stated honestly: none completed.** The v10 state grew per epoch
(ordered forced items, commit one-shots, tolled ages, equivocation branching), and **no
`NEPOCHS=3` exploration completed within this session's practical limits** (~15 GB RAM,
~20 min per run): the clean bound the artifact-free floor demands (3×6) was stopped past
**11.2M discovered states with the frontier still growing** (an earlier attempt hard-failed
the then-4M state cap), and even the below-floor 3×5 was stopped past **9.6M discovered
states, likewise still growing**. No partial numbers are reported from either — the checker
*fails loudly* at its cap and reports nothing from a truncated exploration, and this
document follows the same rule. `python3 model_checker.py 3 6` (and `3 5`) remain one
command away on larger hardware; until then, the v10 exhaustive evidence is the
`NEPOCHS=2` bounds above, whose relation already contains every v10 mechanism — the
decision window and auto-resolution, the commit one-shot and equivocation
(certificate + atomic termination), typed seals, the per-epoch expiry with the no-overlap
cutoff, the cancellation cascade with order-preserving re-queue into a still-SEQ epoch
*and* the stranded-refund exit, and the outage-robust proof-free march. What two epochs
cannot exhibit (and three can): cascades that void *multiple* descendants at once, re-queue
chains longer than one hop, and three-tenure promotion chains — untested in v10 at
exhaustive depth, a stated gap rather than a footnote.

The `S_TICKS=2` run scales the expiry with the longer deadline (`CANCEL_LAG=2`, keeping the
matured-fault-then-late-seal orderings reachable) at that configuration's own artifact-free
floor (`2·2+3 = 7`); its outage-robust worst depth grows 7 → 8, the visible effect of the
one-tick-later seal-fault maturation — the semantics are exercised, not baked in.

**Horizon artifacts below the floor (documented, not counted as results).** Below
`MAXCLOCK = NEPOCHS·CANCEL_LAG + 3` the outage-robust pass reports halts that are pure
bound artifacts of the per-epoch tolled expiry — e.g. a 2×4 run (312,348 states, exit ≠ 0
by design) reports **2,958 outage-robust-only halts, 0 standard halts, and 0 safety
violations**, every representative being a late-decided forced CONTENT epoch whose own
`CANCEL_LAG+1` expiry ticks no longer fit the horizon under a permanent outage. The tool prints an explicit warning at such bounds and they
are not used for liveness conclusions. This is exactly the review's r9-A4 point made
mechanical: under a permanent proving outage the chain drains at **one expiry cancellation
per epoch per `H_cancel` horizon** — the model's clock must be long enough to contain that
march, and the checker now *shows* the march instead of hiding it behind a global lag.

Runs at 4 epochs are out of reach for the same reason (`NEPOCHS=4`'s floor is
`MAXCLOCK ≥ 7`, far past the cap). Raising the memory/time budget — or the bit-packed state
encoding suggested in an earlier review — is the mechanical follow-up that unlocks clean 3-
and 4-epoch exhaustiveness; the completed 2-epoch bounds already exercise every structural
mechanism (handover, cascade over a committed descendant, re-queue *and* refund, expiry
chains, equivocation), with the multi-descendant/multi-hop variants named above as the gap.

### Worst-case depth to finalization (r9-D6)

The backward passes compute, for every reachable state, the shortest path to a goal state; the
maxima are the **worst-case forced-march to finalization**:

- **Standard relation: 6 transitions; outage-robust: 7** (2×6 default run; identical at 2×5).
- **`S_TICKS=2` (2×7): standard 6, outage-robust 8** — the one-tick-later seal-fault
  maturation visibly stretches the proof-free march: the extra transition is exactly the
  extra tolled tick the longer deadline grants before the expiry exit can fire.

Interpretation: the robust number is the model-scale quantification of the design's admitted
throughput consequence (r9-A4) — under a permanent outage every content epoch in the tail
costs its own expiry wait (ticks) plus its cascade/closure transitions, i.e. **the chain
finalizes at one cascade per `H_cancel` horizon, and nothing in the reachable space does
better when proofs never return**. At design scale that is days per epoch — survivable
(refunds and bridge recalls flow, §10.4's four-guarantee split), but emphatically not normal
service; the number is printed so that consequence stays visible in every future run.

### RESERVE0 sufficiency (r9-D7)

The admission-sizing assumption is now a checked bound: over all reachable states of the 2×6
default run (and every other completed bound) the **observed maximum cumulative debit per
tenure is 5** abstract units, against `RESERVE0 = 3·NEPOCHS+1 = 7` — **slack 2**. The formula
`3·NEPOCHS + 1` therefore over-provisions at model scale — consistent with its worst case
(SEAL + CANCEL + SAFETY on every owned epoch) being cut short by equivocation's atomic
termination, which strips the equivocator of still-SEQ epochs before it can accrue their
faults. A run that ever drove the observed max above `RESERVE0` would fail the exit code (and
`inv_bond_nonneg` would fire on the way).

### Mutation self-test — the invariants have teeth, and the harness proves it

Run with `python3 model_checker.py --mutate`. **Per-mutant validity protocol (r9-B5):** for
each mutant the harness (a) first runs the *unmutated* baseline at that mutant's bound and
requires it fully clean — no violation, no halt, no truncation — failing loudly otherwise
(a catch at an already-dirty bound would be unattributable); (b) then requires the mutant to
produce a counterexample attributed to the *expected* invariant (`stop_on_inv` — incidental
co-firing of other invariants can neither mask nor fake it); (c) the liveness mutant runs at a
bound whose baseline outage-robust pass is clean. All seventeen run at **2×5** (baseline:
409,954 states, 0 violations, 0 halts — printed by the harness itself); the whole suite takes
~60 s:

| Injected bug | Should trip | Result |
| --- | --- | --- |
| re-decide an already-decided epoch (double decision) | `single_decision` | **CAUGHT** |
| resolve EMPTY despite a non-empty forced snapshot | `empty_not_forced` (I6) | **CAUGHT** |
| seal an epoch that is not the `openEpoch` (out-of-order) | `closed_is_prefix` | **CAUGHT** |
| withdraw a bond despite outstanding liability | `withdraw_gated` | **CAUGHT** |
| cancel without cascading (stale descendant stays sealable) | `content_current_gen` (§6.7) | **CAUGHT** |
| re-execute an already-consumed debit | `edge_debit_conservation` | **CAUGHT** |
| a seal erases the epoch's matured certificate | `edge_evidence_monotone` (I2) | **CAUGHT** |
| a missed seal deadline is never materialized | `edge_maturity_materialized` (I2) | **CAUGHT** |
| re-open an already-CLOSED epoch (round-8 W2) | `edge_seal_immutable` | **CAUGHT** |
| admit a tenure under-collateralized for its faults (round-8 W3) | `inv_bond_nonneg` | **CAUGHT** |
| decisions un-deadlined: no window auto-resolution, late decides allowed (r9-D1) | `edge_decision_deadline` (v10) | **CAUGHT** |
| the proof-free empty-typed closure claims a CONTENT epoch (r9-D2) | `edge_typed_seal` (v10) | **CAUGHT** |
| a second accepted EBC silently replaces the decision (r9-D4) | `single_decision` | **CAUGHT** |
| an equivocation settles no SAFETY certificate (r9-D4) | `edge_equivocation_settles` (v10) | **CAUGHT** |
| the seal stays enabled at/after `T_exp` (the §6.7 overlap bug, r9-B5) | `edge_no_seal_after_expiry` (v10) | **CAUGHT** |
| cascade re-queue re-orders the forced queue (r9-D3) | `forced_order` (v10) | **CAUGHT** |
| a proving outage wrongly blocks proof-free seals too | outage-robust halt analysis (v9) | **CAUGHT** (49,136 permanent-halt states) |

`# mutation self-test: ALL BUGS CAUGHT (invariants have teeth)` — with two documented
incidental co-firings (`double_decision` also trips `content_current_gen`; `reopen_sealed`
also trips `edge_open_monotone`), both tolerated and neither able to mask the expected
invariant under the `stop_on_inv` protocol.

## What this tells us about the design

- **No reachable invalid state or transition** (within the bounds): the v10 state machine never
  double-decides an epoch — *and never decides one late*; never lets an equivocation flip a
  decision or escape its L1-direct slash-and-terminate; never closes content through the
  proof-free lane; never seals past an epoch's expiry (no seal/cancel L1-ordering race);
  never mutates finalized state, never seals out of order, never seals a commitment that an
  ancestor's cancellation voided, never resolves a forced epoch as empty, never re-orders or
  strands forced work (every item ends consumed or refunded, exclusively), never double-debits
  a bond, never erases matured evidence, never drives a reserve negative, never frames a
  successor for a predecessor's miss, and never lets a tenure withdraw with outstanding —
  poked *or unpoked*, settled *or still-in-window* — liability.
- **Halt-safety (G5 / I3) holds structurally — including proving outages and forced work**: in
  *all* states of every run at or above the artifact-free floor, whatever the adversary does —
  withhold commits or seals to their deadlines, equivocate, force anarchy, stack forced
  snapshots, trigger recovery-only mode, cancel a stuck epoch mid-backlog, or **switch off
  proving forever** — a permissionless path always remains that finalizes every epoch *and
  retires every forced item* (consumed or refunded). The worst such path is now measured, not
  assumed (the r9-D6 depth), and its cadence matches the design's honest r9-A4 statement.
- **The I2 withdrawal-gate claim is checked, not assumed** — and now extends to equivocation:
  the gate refuses an exit while any committed epoch's acceptance window is still open, the
  model of the ≥2-week floor outlasting every challenge window (§8, r9-B3).
- **Admission sizing is a checked bound** (r9-D7): the observed worst-case per-tenure debit is
  printed against `RESERVE0` every run.

## What is and isn't modelled

**Modelled:** the epoch lifecycle with a deadlined, irreversible single decision per epoch
(window + auto-resolution); the commit one-shot and L1-direct double-EBC equivocation
(certificate + atomic termination); the `openEpoch` state machine and recovery lane; typed
proof-carrying vs proof-free seals; seat handover / promotion / anarchy; objective liveness
certificates with read-time (tolled, `S_TICKS`-parameterized) maturity materialization and
one-shot debiting; the state-gated withdrawal (including the open-acceptance-window refusal);
ordered forced snapshots with order-preserving cascade re-queue, consumption, and terminal
refund (I6, §6.5's nullifier, §6.4's refund); recovery-only mode via the global lag cap; the
per-epoch mechanical expiry `T_exp` with the no-overlap seal cutoff and the §6.7 cascade
(voided descendants, in-order closure, causing-tenure charge); and the adversarial proving
outage with outage-robust liveness.

**Abstracted away (deliberately):** exact slot counts (`Γc`, `κ`, `R`, the 32-slot epoch, the
`Γc+κ` last-look window), the 10-day/18-day `H_cancel`/blob-retention magnitudes (collapsed to
`CANCEL_LAG` ticks; the refund fires at bound-stranding rather than at blob expiry),
continuous bond magnitudes and fee/MEV economics (one abstract reserve stands in for the §4
tranche waterfall; `L_safety`'s ETH denomination and `Λ`-sizing are §8/§11 arguments), the
availability-certificate mechanics of §5.2 (the decision window subsumes them at this
altitude), cryptographic mechanisms (proof public inputs, precommitted payees, signatures on
the second EBC — the model takes §3.1's acceptance predicate as given and models only its
consequences), and `>κ` deep-reorg rewind. These are argued in the design doc's game-theory
(§11), parameters (§10), and structural-blocking (§13-S) sections; several are explicitly
flagged there as requiring their own proofs and adversarial tests at the contract/client
layer. The model checker is the *logical state-machine* leg of that verification story, not
the whole of it.

**Known horizon artifacts.** (a) Deciding epoch `e` requires `clock ≥ e`, so runs with
`MAXCLOCK < NEPOCHS−1` leave tail epochs undecidable — the tool warns. (b) Below the
artifact-free floor `MAXCLOCK = NEPOCHS·CANCEL_LAG + 3`, the outage-robust pass reports
halts that are pure images of the serialized per-epoch expiry march (see
[Results](#results)) — the tool warns, and such bounds are not used for liveness
conclusions. The v9 artifact — forced flags stranded on cancelled epochs when no re-queue
target exists — is **gone**: that path is now the modeled refund and the goal predicate
accounts for it (r9-B5). Neither remaining artifact affects any safety result.

**Bounds are finite — and v10's completed bounds are two epochs.** A clean result at these
bounds does not prove correctness at all depths, and this revision's exhaustive runs stop at
`NEPOCHS=2` (see [Results](#results) for exactly what that covers and what it cannot). The
value of bounded model checking is that the overwhelming majority of state-machine bugs
manifest at very small bounds — every v10 mechanism, including the cascade/re-queue/refund
lanes and equivocation, is exercised at two epochs — but multi-descendant cascades and
longer re-queue/promotion chains first exist at three, so completing `3 6` on larger
hardware (or after a compact bit-packed state encoding, a standing reviewer suggestion) is
the stated next step, not an optional nicety.

## Reproduce

```bash
cd packages/protocol/docs/preconfirmation/simulation
python3 model_checker.py                      # default 2×6 exhaustive run (~35 s)
python3 model_checker.py 3 6                  # clean NEPOCHS=3 bound — needs a large
                                              #   memory/time budget (>11M states; did
                                              #   not complete on a 15 GB / ~20 min
                                              #   budget — fails loudly, never silently)
python3 model_checker.py 2 7 --sticks 2 --cancel-lag 2   # S_TICKS=2 semantics run
python3 model_checker.py --mutate             # validity-protocol mutation self-test
```

No dependencies beyond the Python 3 standard library. Exit code is non-zero on any safety
violation, halt, truncated exploration, failed `RESERVE0` check, or mutation-harness error, so
the checker is CI-safe; wiring `model_checker.py` (and `--mutate`) into CI is tracked as
design-doc §13-T.10 so a future edit cannot silently invalidate these invariants.
