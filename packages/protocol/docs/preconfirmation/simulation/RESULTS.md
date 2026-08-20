# v9 Protocol — Exhaustive State-Machine Model-Checking Results

**Artifact:** [`model_checker.py`](model_checker.py) — a self-contained Python explicit-state
model checker for the [redesign proposal](../redesign-proposal.md) (v9).
**Question asked:** *can the new design reach an invalid state?*
**Answer (within the checked bounds and modelled configurations):** **No.** Across every
explored bound the checker found **zero reachable states or transitions violating any safety
invariant** and **zero permanent halts** — including under an **adversarial proving outage
that never lifts** (v9): the chain can always still reach full finalization through the
proof-free floor. Exploration is exhaustive **from a curated set of initial configurations**
(see [How it works](#how-it-works)) — it covers every adversarial interleaving from those
seeds, not every conceivable initial assignment. A mutation self-test confirms the invariants
are not vacuous — each of nine deliberately-injected design bugs is caught by the check
written to catch it.

> Scope honesty up front: this is *bounded* model checking of an *abstraction*. It exhaustively
> explores every adversarial interleaving up to a finite number of epochs and wall-clock steps,
> over a logical abstraction of the protocol (slot-level timing is abstracted into phases — see
> [Abstraction](#what-is-and-isnt-modelled)). It is strong evidence for the *logical* state
> machine (single-decision epochs, monotone `openEpoch`, cascade-voided commitments, no
> double-debit, bond safety, no-frame, sticky evidence, halt-safety), not a proof about the
> eventual Solidity, and not a substitute for the game-theory and timing analysis in the design
> doc.

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
  outage on forever.

Only *legal* (design-permitted) transitions are in the relation; the invariants then verify that
the reachable set contains no bad state and no bad transition. (Injecting illegal transitions
would test the checker, not the design — so illegal moves appear only in the mutation self-test
below.)

**Model parameters** (documented so results are interpretable without reading the script):
`NEPOCHS × MAXCLOCK` per the results table; `NTENURES = 3` tenure identities; `L_LIVE = 1`
(abstract slash unit); `RESERVE0 = K + 2` per-tenure reserve at admission. Two design horizons
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
states identifies any reachable state that **cannot** reach full finalization — a permanent halt,
which would violate G5 / I3. **Halts fail the exit code exactly like safety violations do.**

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

Edge invariants (at every transition):

| Invariant | Design source | Meaning |
| --- | --- | --- |
| `edge_open_monotone` | I3 | `openEpoch` never decreases across any transition |
| `edge_evidence_monotone` | I2 | settled certificates and consumed ids never disappear — no action (a late seal included) can erase matured evidence |
| `edge_debit_conservation` | I2, §8 | a reserve decreases only by consuming exactly one fresh logical fault id — no double-debit, no id-less debit, no cross-tenure debit |
| `edge_maturity_materialized` | I2 | a tick spent as a DECIDED (content or explicit-empty), owned `openEpoch` must settle that owner's missed-seal certificate (unless its miss-commit LIVENESS certificate already stands) |
| **liveness / halt-safety** | **G5, I3** | **from every reachable state, full finalization is still reachable** |
| **outage-robust halt-safety** (v9) | **G5, I3, §10.4** | **full finalization is reachable even if an active proving outage never lifts** — checked over the sub-relation excluding `outage_end`, so the proof-free floor (empty seals, void closure, cancellation) carries the whole burden |

## Results

All runs below completed the **full exploration from the curated initial configurations** (no
state-cap truncation) and reported `SAFETY: NONE` and `LIVENESS: NONE` (no halt), with exit
code 0:

| Bound (`NEPOCHS × MAXCLOCK`) | Reachable states | Terminal (all-sealed) states | Safety violations | Permanent halts (standard / outage-robust) |
| --- | ---: | ---: | :---: | :---: |
| 3 × 4 (default) | 2,339,418 | 1,130,952 | 0 | 0 / 0 |
| 3 × 5 | 3,659,594 | 2,075,820 | 0 | 0 / 0 |

The v9 outage adversary roughly quadruples the state space (every configuration is explored
with and without an active outage, at every point), so the `4 × 3` bound now exceeds the
4,000,000-state cap; the outage-free `4 × 3` result stands from the v8 model (2,722,729 states,
0 violations, 0 halts — bit-for-bit reproducible by removing the two outage actions).

The completed runs span the structurally interesting depth: handovers, multi-tenure
promotion chains, anarchy, forced-only epochs, recovery-only mode (lag `> K`), the data-loss
cancellation floor, and — new in this revision — cascades over committed descendants, forced
re-queueing, and matured-fault materialization under every interleaving of late seals,
promotions, and withdrawals.

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

## What is and isn't modelled

**Modelled:** the epoch lifecycle and its single-decision finality, the `openEpoch` state machine
and recovery lane, seat handover / promotion / anarchy, objective liveness certificates with
read-time (tolled) maturity materialization and one-shot debiting, the state-gated withdrawal,
forced-snapshot / empty-resolution interaction (I6), recovery-only mode via the global lag cap,
the cancellation floor, and the §6.7 cascade (voided descendants, in-order closure, forced
re-queue, causing-tenure charge).

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
python3 model_checker.py            # default 3×4 exhaustive run
python3 model_checker.py 3 5        # NEPOCHS=3 MAXCLOCK=5
python3 model_checker.py 4 3        # NEPOCHS=4 MAXCLOCK=3
python3 model_checker.py --mutate   # invariant self-test (all bugs must be CAUGHT)
```

No dependencies beyond the Python 3 standard library. Exit code is non-zero on any safety
violation or halt, so the checker is CI-safe.
