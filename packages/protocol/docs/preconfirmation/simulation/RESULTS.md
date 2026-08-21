# v11 Protocol — Exhaustive State-Machine Model-Checking Results

**Artifact:** [`model_checker.py`](model_checker.py) — a self-contained Python explicit-state
model checker for the [redesign proposal](../redesign-proposal.md) (v11).
**Question asked:** *can the new design reach an invalid state?*
**Answer (within the checked bounds and modelled configurations):** **No.** Across every
explored bound the checker found **zero reachable states or transitions violating any safety
invariant** and **deadlock-freedom** — from every reachable state an exit path to full
finalization always exists — holding even under an **adversarial proving outage that never
lifts** (v9): the proof-free floor is that exit. (Precise scope, round-8 W1: this is
deadlock-freedom, not unconditional livelock-freedom under a fully unfair scheduler — see
[Liveness scope](#liveness--deadlock-freedom-and-its-scope).) Exploration is exhaustive **from a
curated set of initial configurations** (see [How it works](#how-it-works)) — it covers every
adversarial interleaving from those seeds, not every conceivable initial assignment. A mutation
self-test confirms the invariants are not vacuous — each of **fifteen** deliberately-injected
design bugs is caught by the check written to catch it.

> Scope honesty up front: this is *bounded* model checking of an *abstraction*. It exhaustively
> explores every adversarial interleaving up to a finite number of epochs and wall-clock steps,
> over a logical abstraction of the protocol (slot-level timing is abstracted into phases — see
> [Abstraction](#what-is-and-isnt-modelled)). It is strong evidence for the *logical* state
> machine (single-decision epochs, monotone `openEpoch`, cascade-voided commitments, no
> double-debit, bond safety, no-frame, sticky evidence, halt-safety), not a proof about the
> eventual Solidity, and not a substitute for the game-theory and timing analysis in the design
> doc.

> **Revision note (v11 — round 10, anarchy proposal phase).** The owner-directed round-10
> review restored discretionary content to Total Anarchy (design §9), and the model now
> carries the lane it reverted in v8 — this time with **both** sides of the repair:
> (1) a new **`anarchy_propose`** action — any actor may seal an *unowned* `openEpoch` with
> content in **one atomic step** (propose ≡ seal ≡ finality; proof-carrying, so impossible
> during an outage; discretionary, so disabled in recovery-only mode); (2) the **two-sided
> proposal cutoff** (`min(e + W_ANARCHY, first owned epoch after e)`, collapsed in
> recovery-only mode): the unowned epoch's proof-free EMPTY resolution is enabled only
> **at/after** the cutoff, and the proposal only **strictly before** it. Two new
> path-independent edge invariants (`edge_empty_respects_phase`,
> `edge_proposal_respects_phase`) enforce the two sides, and a new state invariant
> (`inv_anarchy_content_sealed`) enforces atomicity (unowned discretionary content never
> exists unsealed — it is born sealed, so the §6.7 cascade can never touch it). **Four new
> mutants** prove the additions have teeth: horn 2 (`anarchy_empty_in_phase` — a proof-free
> empty front-running the phase), the determinacy break (`anarchy_propose_after_close`),
> horn 1 (`nonatomic_anarchy_propose`), and the owned-successor truncation
> (`anarchy_ignores_ownership`, run at `W_ANARCHY = 2` so the truncation term binds) →
> **fifteen** mutants total. **`W_ANARCHY = 0` disables the lane and reproduces the v8/v10
> model bit-for-bit** — verified: the `3 × 4, W = 0` run reproduces the previous revision's
> state count exactly (results table). *Honesty note (round-10 finding r10-11):* the
> round-9 review dispositioned its checker-validity findings (R9-16 / D1–D7) as
> "Closed-in-checker", describing typed seals, an `equivocate` action, ordered forced items,
> and a "v10 revision note" in this file — **none of which was ever committed**; the checker
> this revision extends is the round-8 model plus the v9 outage mode, exactly as the git
> history records. Closing R9-16 for real remains open with the owner (proposal Appendix B,
> r10-11; §13-T.10's CI lint is the guard that would have caught the drift).
>
> **Revision note (round 5).** This version incorporates fixes for four review findings against
> the first checker: (1) `openEpoch` monotonicity is now genuinely checked **across every
> transition** (the first version only checked per-state consistency); (2) the double-debit
> property is now a real transition invariant (`edge_debit_conservation`), not a structural
> no-op; (3) the §6.7 **cancellation cascade is modelled** — cancelling the `openEpoch` voids
> every committed-CONTENT unsealed descendant (previously a stale descendant could seal
> unchanged, a protocol-invalid continuation the model wrongly admitted); (4) **fault maturity
> is materialized at read time (I2)** — a missed (tolled) seal deadline settles its certificate
> deterministically inside the `tick` action and evidence is sticky, so the
> seal-late-then-withdraw bypass the first model admitted is now structurally impossible, and
> the withdrawal gate provably reads the computed matured set. The exit code now also fails on
> liveness halts, not only safety violations.
>
> **Revision note (v7).** The owner-approved self-review simplification round changed the
> *design*; the model tracked it as follows. Three of the five changes required **no model
> change** because the abstraction already had the simpler shape: the model never had a
> seal-window lower bound (v7's deadline-only seal — the design moved *toward* the model), it
> never had a separate `H_force` (fault-paid resolution attaching at the deadline is exactly
> the tick-materialization + seal semantics already checked), and the single-account waterfall
> is invisible at this abstraction level (one `reserve` per tenure). The present-at-`D+κ`
> acceptance rule is slot-level, below the abstraction. The one real addition was the anarchy
> atomic lane (an `anarchy_seal` action).
>
> **Revision note (v8 — regression audit).** The owner then mandated a post-simplification
> regression audit: every finding from all six review rounds was re-checked against the v7
> changes. The four structural simplifications hold every prior closure, but the
> anarchy-content restoration **re-opened round-2 finding 6's empty-front-running horn** (a
> cheap proof-free empty seal beats any ~10–15-minute proof-carrying proposal) and was
> **reverted**: the `anarchy_seal` action is removed and anarchy epochs are forced-only/empty
> again, as in v6. The v8 model reproduced the pre-v7 (round-6) state counts **bit-for-bit**
> at every bound — a determinism check confirming the revert changed exactly one action and
> nothing else.
>
> **Revision note (v9 — round 7).** Round 7 argued the zero-halt result was conditional on an
> assumption the design does not guarantee: that a prover with the data always exists. The
> model now includes an **adversarial proving-outage mode**: the adversary may start/end an
> outage at any time — or never end it — and while it is active **no proof-carrying (CONTENT)
> seal is possible**; only the design's proof-free resolutions (empty seals, void closure,
> disaster cancellation) remain. Liveness is now checked **twice**: the standard exists-path
> pass, and an **outage-robust** pass over the sub-relation that excludes `outage_end` — i.e.
> the goal must be reachable *even if the outage never lifts* (without this second pass the
> outage model would be vacuous: an exists-path analysis can always "un-outage" its way out). A
> ninth mutant (`outage_blocks_empty` — the outage wrongly blocking proof-free seals too) must
> produce permanent halts and does. `CANCEL_LAG` was decoupled from `K` and set to 1 so
> *chains* of cancellations (a permanent outage over an all-forced backlog cancels through one
> epoch per `CANCEL_LAG+1` ticks) fit inside bounded horizons — with `CANCEL_LAG = K = 2` those
> chains overran `MAXCLOCK` and appeared as pure horizon artifacts in the robust pass.
>
> **Revision note (round 8).** A DeepSeek pass on the checker plus an independent adversarial
> self-review tightened the artifact without changing the design: (1) the liveness claim is
> **scoped precisely to deadlock-freedom** — an exit path always exists — because backward
> reachability cannot (and no checker of this model can) rule out livelock under a *fully unfair
> scheduler* that starves the permissionless advancing action; that residual is inherent to any
> permissionless-liveness property and is supplied at the protocol layer by weak fairness (the
> advancing action is open to every honest party). See [Liveness scope](#liveness--deadlock-freedom-and-its-scope).
> (2) A new path-independent edge invariant **`edge_seal_immutable`** checks "no transition may
> change an already-CLOSED epoch" directly, so state deduplication (which omits `closed_hist`
> from the key) can never mask a re-open. (3) Debits **no longer silently floor at zero**, so
> `edge_debit_conservation` now checks *every* debit and `inv_bond_nonneg` surfaces
> under-collateralization directly; `RESERVE0` is sized to the abstract worst case
> (`2·NEPOCHS + 1` — up to two debits per owned epoch: a missed-seal and a later cancel). (4) The
> mutation self-test is robust to incidental violations (`stop_on_inv` early-exits only on the
> *expected* invariant). Two mutants added (`reopen_sealed`, `undersized_reserve`) → **eleven**.
>
> **Revision note (round 6).** A follow-up review pass tightened four more things: (5) seal-duty
> materialization now covers **explicit-empty outcomes too** — any owned, DECIDED `openEpoch`
> (content *or* empty) that survives a tick unsealed settles the owner's SEAL certificate, with
> one carve-out: an epoch that resolved EMPTY through a *missed commit* already carries that
> owner's LIVENESS certificate, and its closure is the recovery lane's job rather than a second
> distinct fault; (6) the cancellation trigger is an explicit, documented abstraction
> (`CANCEL_LAG`, below) rather than silently reusing the lag cap; (7) "exhaustive" is scoped
> honestly to the curated initial configurations; (8) all model parameters are documented here
> alongside the results.

---

## How it works

The protocol is encoded as a state `(per-epoch status + owner + forced-flag + decision record +
commit generation, global openEpoch, wall-clock, mode, per-tenure reserve, settled certificates,
consumed fault-ids, withdrawn tenures, immutable assignment record, cascade generation)`. From a
curated-but-broad set of initial owner/forced configurations (single owner, handover,
multi-handover, anarchy in every position, forced snapshots in every position, all-forced,
none-forced, alternating), the checker does a **breadth-first exploration of every enabled
action**, where the adversary is maximally nondeterministic — at each state it may take any
legal action of any actor:

- **decide** an epoch to CONTENT or EMPTY (commit); **miss_commit** (objective liveness fault,
  certificate settled atomically with the EMPTY resolution);
- **seal** the `openEpoch` (honest or permissionless force-resolve); *withholding* the seal is
  the path where seal is simply not taken — and a tick spent that way settles the owner's
  missed-seal certificate deterministically (I2 read-time materialization). This applies to
  **both decided outcomes** — the proof-carrying content seal *and* the proof-free
  explicit-empty/forced-only seal are the seat's duty — with tolling (only time spent as the
  *openEpoch* counts, so a backlogged descendant is never blamed) and one carve-out (an epoch
  EMPTY through a missed commit already carries that owner's LIVENESS certificate; closing it
  is the recovery lane's job, not a second fault);
- **cancel** a stuck CONTENT epoch past the data-loss horizon (`H_cancel`), which also
  **cascades**: every committed-CONTENT unsealed descendant is voided (§6.7), forced snapshots
  re-queue to the earliest still-SEQ epoch, and the causing tenure is charged an additional
  CANCEL-class certificate; **close_void** later closes a voided epoch as CANCELLED in
  `openEpoch` order;
- **debit** a settled certificate (one-shot per logical fault id);
- **promote** a terminated holder's successor (or drop to anarchy);
- **withdraw** a bond (only through the state-gate, which reads the computed matured set);
- **tick** the wall clock (which drives recovery-only mode via the lag cap `K` and materializes
  matured seal faults);
- **outage_start / outage_end** (v9): toggle the proving outage — while active, CONTENT seals
  are impossible and only proof-free resolutions advance the chain; the adversary may leave the
  outage on forever;
- **anarchy_propose** (v11, design §9): any actor seals an **unowned** `openEpoch` with
  discretionary content in one atomic proof-carrying step (propose ≡ seal ≡ finality),
  strictly before the epoch's **proposal cutoff** (`min(e + W_ANARCHY, first owned epoch
  after e)`, collapsed while recovery-only mode is active); the unowned epoch's proof-free
  EMPTY resolution is conversely enabled only **at/after** the cutoff. The action is
  impossible during an outage (it carries a proof) and in recovery-only mode (it is
  discretionary content, I5); forced-only CONTENT decisions stay enabled in both phase
  regimes (a forced-only seal is the degenerate proposal during the phase and the mandated
  resolution after it — I6 cadence untouched).

Only *legal* (design-permitted) transitions are in the relation; the invariants then verify that
the reachable set contains no bad state and no bad transition. (Injecting illegal transitions
would test the checker, not the design — so illegal moves appear only in the mutation self-test
below.)

**Model parameters** (documented so results are interpretable without reading the script):
`NEPOCHS × MAXCLOCK` per the results table; `NTENURES = 3` tenure identities; `L_LIVE = 1`
(abstract slash unit); `W_ANARCHY = 1` anarchy proposal-phase length in ticks (v11; design
`W_a = S = 4` epochs, scaled down like `K` so both sides of the cutoff are exercised within
tiny bounds; `0` disables the lane and reproduces the v8/v10 model bit-for-bit, and the
truncation-binding runs use `2`); `RESERVE0 = 2·NEPOCHS + 1` per-tenure reserve at admission (round-8 W3:
sized to the abstract worst case — up to two debits per owned epoch, a missed-seal SEAL cert and
a later CANCEL cert — so a correctly-admitted tenure is never driven negative; a run that *does*
go negative is the checker detecting under-collateralization, which `inv_bond_nonneg` reports).
Two design horizons
are deliberately scaled/collapsed for bounded exploration: the lag cap **`K = 2`** (design
value 8; the recovery-exit threshold `K'`, design 4, scales to `lag == 0` here), and
**`CANCEL_LAG = 1`** (decoupled from `K` — round-6 W3) — the disaster cancellation enables at
`lag > CANCEL_LAG` instead of the design's 10-day `H_cancel` wall-clock horizon, so the
disaster lane — including **chains** of cancellations under a permanent proving outage, which
consume `CANCEL_LAG + 1` ticks per epoch — is *reachable* within tiny bounds. This
**over-approximates cancellation availability**: safety-conservative (the cascade is exercised
strictly more, not less), while the real `H_cancel` delay is a timing parameter argued in the
design doc, not checked here. Prover unavailability is modelled explicitly (v9, the outage
mode); *data* unavailability is not a separate concept — a data-loss epoch behaves like a
permanently-unprovable one, and both exit through the same cancellation floor the outage-robust
pass verifies.

After the state graph is built, a backward reachability pass from the "all epochs sealed" terminal
states identifies any reachable state that **cannot** reach full finalization — a deadlock, which
would violate G5 / I3. **Halts fail the exit code exactly like safety violations do.**

### Liveness — deadlock-freedom and its scope

The liveness property the checker establishes is **deadlock-freedom**: from every reachable
state an exit path to a fully-sealed terminal exists — equivalently, there is no reachable
*terminal-avoiding trap* (no SCC from which finalization is unreachable) — in both the standard
relation and the **outage-robust** sub-relation (finalization stays reachable even if a proving
outage never lifts). What the checker does **not** establish, and what no checker of this model
can (round-8 W1), is **livelock-freedom under a fully unfair scheduler**: because every action —
the clock tick, the permissionless advancing seal/cancel, even toggling the outage flag — is
adversary-selectable, the non-terminal subgraph is full of cycles an adversary could loop in
forever simply by *declining* the advancing action. That residual is inherent to *any*
permissionless-liveness property; it is resolved not in the model but at the protocol layer, by
**weak fairness**: the advancing action is open to every honest party, so an always-enabled
permissionless action is eventually taken by someone honest, and deadlock-freedom then upgrades
to finalization. RESULTS.md and the checker's output state the claim in exactly these terms
rather than an unqualified "no permanent halt."

## Invariants checked

State invariants (at every reachable state):

| Invariant | Design source | Meaning |
| --- | --- | --- |
| `single_decision` | I2, §3.1, §5 | an epoch is decided at most once; its status never flips its recorded decision |
| `closed_is_prefix` | I3, §6.1 | seals happen strictly in `openEpoch` order — no closed epoch above an open one |
| `open_monotone` | I3 | `openEpoch` always equals the lowest non-closed epoch |
| `seal_immutable` | Immutability corollary | a SEALED/CANCELLED epoch never changes afterwards |
| `empty_not_forced` | I6 | an epoch never resolves EMPTY while its forced snapshot is non-empty |
| `content_current_gen` | §6.7 | every live CONTENT commitment is of the current lineage generation — a commitment that predates an ancestor's cancellation must have been voided by the cascade, never left sealable |
| `bond_nonneg` | §4, §8 | a slash never drives a reserve below zero |
| `no_frame` | §7.2, §8.3 | a certificate only ever names the acting owner of that epoch |
| `withdraw_gated` | §8.4, I2 | no withdrawn tenure retains an unresolved certificate or unsealed owned epoch |
| `anarchy_content_sealed` | §9, I5 (v11) | unowned **discretionary** content exists only born-sealed (propose ≡ seal is atomic) — it can never sit in the cancellable value-at-risk tail or lock the chain unproven (round-2 finding 6, horn 1) |

Edge invariants (at every transition):

| Invariant | Design source | Meaning |
| --- | --- | --- |
| `edge_open_monotone` | I3 | `openEpoch` never decreases across any transition |
| `edge_evidence_monotone` | I2 | settled certificates and consumed ids never disappear — no action (a late seal included) can erase matured evidence |
| `edge_debit_conservation` | I2, §8 | a reserve decreases only by consuming exactly one fresh logical fault id — no double-debit, no id-less debit, no cross-tenure debit; and (round-8 W3, no zero-floor) it now checks *every* debit, including at exhausted reserve |
| `edge_maturity_materialized` | I2 | a tick spent as a DECIDED (content or explicit-empty), owned `openEpoch` must settle that owner's missed-seal certificate (unless its miss-commit LIVENESS certificate already stands) |
| `edge_seal_immutable` | I3+I7 corollary | **path-independent** (round-8 W2): no single transition may change an already-CLOSED epoch's status — dedup cannot mask a re-open |
| `edge_empty_respects_phase` | §9.1 (v11) | an unowned, non-forced epoch resolves EMPTY only **at/after** its proposal cutoff — a proof-free empty inside the phase is round-2 finding 6's empty-front-running horn (horn 2) |
| `edge_proposal_respects_phase` | §9.1 (v11) | an anarchy proposal (unowned SEQ→SEALED) is valid only for the `openEpoch`, strictly **before** its cutoff, in NORMAL mode, outside an outage — a late proposal would flip a determined outcome; one past an owned successor's start would leave that holder parentless |
| **liveness / deadlock-freedom** | **G5, I3** | **from every reachable state, full finalization is still reachable (standard + outage-robust); scope per [Liveness](#liveness--deadlock-freedom-and-its-scope)** |
| **outage-robust halt-safety** (v9) | **G5, I3, §10.4** | **full finalization is reachable even if an active proving outage never lifts** — checked over the sub-relation excluding `outage_end`, so the proof-free floor (empty seals, void closure, cancellation) carries the whole burden |

## Results

All runs below completed the **full exploration from the curated initial configurations** (no
state-cap truncation) and reported `SAFETY: NONE` and `LIVENESS: NONE` (no halt), with exit
code 0:

| Bound (`NEPOCHS × MAXCLOCK`, `W_ANARCHY`) | Reachable states | Terminal (all-sealed) states | Safety violations | Permanent halts (standard / outage-robust) |
| --- | ---: | ---: | :---: | :---: |
| 3 × 4, `W = 0` (lane off — v10-equivalence check) | 2,339,418 | 1,130,952 | 0 | 0 / 0 |
| 3 × 4, `W = 1` (default) | 2,384,366 | 1,167,068 | 0 | 0 / 0 |
| 3 × 5, `W = 1` | 3,744,298 | 2,143,784 | 0 | 0 / 0 |
| 3 × 5, `W = 2` (ownership truncation binds) | 3,730,066 | 2,144,630 | 0 | 0 / 0 |

The `W = 0` row **exactly reproduces the pre-v11 model's documented `3 × 4` counts**
(2,339,418 / 1,130,952) — the same bit-for-bit determinism check the v8 revert used, here run
in the opposite direction: disabling the lane recovers the previous relation precisely, so
every v11 delta is attributable to the lane alone. (The pre-v11 `3 × 5` result for
comparison: 3,659,594 states / 2,075,820 terminal, 0 / 0.) The v9 outage adversary roughly
quadruples the state space (every configuration is explored with and without an active
outage, at every point), so the `4 × 3` bound exceeds the 4,000,000-state cap; the
outage-free `4 × 3` result stands from the v8 model (2,722,729 states, 0 violations, 0 halts
— bit-for-bit reproducible by removing the two outage actions).

The completed runs span the structurally interesting depth: handovers, multi-tenure
promotion chains, anarchy (now with the proposal lane and both sides of its cutoff),
forced-only epochs, recovery-only mode (lag `> K`), the data-loss cancellation floor,
cascades over committed descendants, forced re-queueing, and matured-fault materialization
under every interleaving of late seals, promotions, and withdrawals.

### Mutation self-test — the invariants have teeth

Run with `python3 model_checker.py --mutate`. Each mutant injects one known design-breaking bug
and the named invariant **must** catch it:

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
| a proof-free empty resolves an unowned epoch inside its proposal phase — round-2 finding 6, horn 2 (v11) | `edge_empty_respects_phase` | **CAUGHT** |
| an anarchy proposal is accepted at/after the cutoff, flipping a determined outcome (v11, r10-1) | `edge_proposal_respects_phase` | **CAUGHT** |
| an anarchy proposal locks decided-but-unsealed content — round-2 finding 6, horn 1 (v11) | `inv_anarchy_content_sealed` | **CAUGHT** |
| the cutoff ignores the owned-successor truncation (v11, r10-3; run at `W_ANARCHY = 2` so the term binds) | `edge_proposal_respects_phase` | **CAUGHT** |
| a proving outage wrongly blocks proof-free seals too | outage-robust halt analysis (v9) | **CAUGHT** (hundreds of thousands of permanent-halt states appear) |

`# mutation self-test: ALL BUGS CAUGHT (invariants have teeth)`

## What this tells us about the design

- **No reachable invalid state or transition** (within the bounds): the v8 state machine never
  double-decides an epoch, never mutates finalized state, never seals out of order, never seals a
  commitment that an ancestor's cancellation voided, never resolves a forced epoch as empty,
  never double-debits a bond, never erases matured evidence, never drives a reserve negative,
  never frames a successor for a predecessor's miss, and never lets a tenure withdraw with
  outstanding — poked *or unpoked* — liability.
- **Halt-safety (G5 / I3) holds structurally — now including proving outages**: in *all* states
  of every run, whatever the adversary does — withhold commits, withhold seals, force anarchy,
  stack forced snapshots, trigger recovery-only mode, cancel a stuck epoch mid-backlog, or
  **switch off proving forever** — a permissionless action always remains that eventually
  finalizes the open epoch, and in the outage case that path uses only proof-free resolutions
  (empty seals, void closure, cancellation with forced re-queue and refunds). This is the
  property the reviews pushed hardest on, and it survives exhaustive attack in the abstraction.
- **The I2 withdrawal-gate claim is now checked, not assumed**: because certificates materialize
  deterministically at maturity and are sticky, the explored relation contains every
  seal-late-then-withdraw ordering — and the gate blocks all of them until the debit lands.
- **The v11 anarchy lane holds under the same attack surface**: with the two-sided cutoff in
  the relation, no interleaving of proposals, empties, forced decisions, outages, mode
  switches, promotions-to-anarchy, and cancellations produces an empty inside a protected
  phase, a proposal past a cutoff or an owned successor's start, unsealed unowned
  discretionary content, or any regression of the prior invariants — and both liveness
  passes still hold, because the post-cutoff proof-free empty is exactly the outage-robust
  exit the v9 pass already relied on. `W_ANARCHY = 0` reproduces the pre-v11 state space
  bit-for-bit (the v8-revert determinism check, re-run for the opposite direction).

## What is and isn't modelled

**Modelled:** the epoch lifecycle and its single-decision finality, the `openEpoch` state machine
and recovery lane, seat handover / promotion / anarchy, objective liveness certificates with
read-time (tolled) maturity materialization and one-shot debiting, the state-gated withdrawal,
forced-snapshot / empty-resolution interaction (I6), recovery-only mode via the global lag cap,
the cancellation floor, the §6.7 cascade (voided descendants, in-order closure, forced
re-queue, causing-tenure charge), and (v11) the anarchy proposal phase — the atomic
propose≡seal action, the two-sided cutoff with its ownership truncation, and its
recovery-only / outage interactions.

**Abstracted away (deliberately):** exact slot counts (`Γc`, `κ`, the 32-slot epoch, the `Γc+κ`
last-look window), continuous bond magnitudes and fee/MEV economics, cryptographic mechanisms
(proof public inputs, precommitted payees, the forced-item nullifier, verdict incarnation), and
`>κ` deep-reorg rewind. These are argued in the design doc's game-theory (§11), parameters (§10),
and structural-blocking (§13-S) sections; several are explicitly flagged there as requiring their
own proofs and adversarial tests at the contract/client layer. The model checker is the *logical
state-machine* leg of that verification story, not the whole of it.

**Known horizon artifacts.** (a) Deciding epoch `e` requires `clock ≥ e`, so runs with
`MAXCLOCK < NEPOCHS−1` leave tail epochs undecidable and report artifact halts — the tool warns
and such bounds should not be used for liveness conclusions. (b) If a cascade fires when no
still-SEQ epoch remains inside the bound, the re-queued forced flags have nowhere to go and stay
recorded on the cancelled/voided epochs; in the real (unbounded) protocol the front of the queue
is always a future epoch. Neither artifact affects the safety results.

**Bounds are finite.** A clean result up to `NEPOCHS=4` does not prove correctness at all
depths. The value of bounded model checking is that the overwhelming majority of state-machine
bugs manifest at very small bounds (2–4 epochs is more than enough to exercise handover, backlog,
recovery, cascade, and cancellation); a bug that first appears only at depth ≥ 5 would be
unusual. Raising the bounds (and the 4,000,000-state cap) is a mechanical follow-up; so is a
compact bit-packed state encoding if deeper exhaustive runs are wanted (a reviewer suggestion
worth taking if and when the depth is needed).

## Reproduce

```bash
cd packages/protocol/docs/preconfirmation/simulation
python3 model_checker.py            # default 3×4 exhaustive run (W_ANARCHY=1)
python3 model_checker.py 3 5        # NEPOCHS=3 MAXCLOCK=5
python3 model_checker.py 3 4 0      # W_ANARCHY=0: anarchy lane off — reproduces the v8/v10 model
python3 model_checker.py 3 5 2      # W_ANARCHY=2: ownership truncation binds
python3 model_checker.py --mutate   # invariant self-test (all bugs must be CAUGHT)
```

No dependencies beyond the Python 3 standard library. Exit code is non-zero on any safety
violation or halt, so the checker is CI-safe; wiring `model_checker.py` (and `--mutate`) into CI
is tracked as design-doc §13-T.10 so a future edit cannot silently invalidate these invariants.
