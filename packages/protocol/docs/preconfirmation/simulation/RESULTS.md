# Protocol — Exhaustive State-Machine Model-Checking Results

**Artifact:** [`model_checker.py`](model_checker.py) — a self-contained Python explicit-state
model checker for the [redesign proposal](../redesign-proposal.md). The checker models the
**logical state machine**. It was upgraded for the round-9 findings (the "v10 upgrade" below),
extended with the round-10 **anarchy proposal phase** (design §9; the "v11 anarchy" note below),
and — in this revision — extended again with the **round-12 Codex fidelity fixes** (the
"v14 round-12" note below): the availability-certificate CONTENT/EMPTY resolution branch (§5.2 /
§6.8 F2), the per-tenure equivocation-challenge withdrawal horizon (§8 / r11-N2), and the
machine-checked no-false-successor-slash tolling property (§7.1 / I4). It tracks the proposal
through **v15**. The v15 round-13 fixes are design/spec-level (L1-authoritative bridge `msgHash`
+ `NEW`-guard §6.4; the single-valued `T_exp_eff = min(T_exp, blob_slot+retention)` §6.7; the
equivocation-challenge horizon tolling during attested outages §8/§10.4) and lie at or below
this checker's abstraction — they change no reachable state in the modelled state machine. One
**tracked checker-fidelity follow-up** (non-gating, §13-T.10): the `safety_settle_late` action
carries no `s.outage` guard and the withdrawal-freeze is unmodelled, so `inv_withdraw_gated` is
exercised only outage-free; the v15 §8/§10.4 challenge-horizon toll (which prevents the
outage-escape) is normative in the proposal but not yet mirrored here. No safety result depends
on it.

> **Scope of the v11/v12/v14 additions (r11-N5; updated v14 round-12).** The round-10 **anarchy
> proposal phase** (§9) *is* in the checker (the `anarchy_propose` action, the two-sided
> `W_ANARCHY` cutoff, and its three invariants — see the v11 revision note). **As of v14 round-12,
> the §5.2 / §6.8-F2 CONTENT-vs-EMPTY resolution branch and its `EBC`/`DEFAULT` mode consequence
> ARE now in the checker too** (the `UNRESOLVED` state, `ac_certify` → CONTENT/EBC, `ac_timeout` →
> EMPTY-or-forced-only/DEFAULT, and `edge_content_via_ac` — see the v14 revision note). What
> remains below the abstraction is the AC's **cryptographic mechanics** — the SSZ generalized-index
> Merkle proof, the EIP-4788 beacon-root binding, the KZG-commitment opening in the seal circuit,
> and the `R`-slot timing — the state machine takes §3.1's acceptance predicate as given and models
> only the CONTENT-vs-EMPTY resolution it produces and the mode that resolution pins. The remaining
> v11/v12 additions are still below the abstraction: the v11 **default derivation rule**'s header
> construction (the greedy block partition, the `t_i` timestamps, the **clock-capacity invariant**,
> the v12 default-anchor `max()` rule) and the §6.4 bridge terminal-cancellation handshake are
> **header-determinism and cross-chain properties** discharged by the **§13-S.18 / §13-S.16
> conformance vectors and proofs**, not by this state-machine checker (which collapses slot-level
> timing and headers into phases). What the checker verifies about holderless and withheld-data
> epochs — that an unowned/forced-only/EMPTY/DEFAULT epoch always has a constructible proof-free
> exit and never double-decides, seals out of order, materializes discretionary content without an
> AC, or strands forced work — is re-confirmed by the runs below.

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
mutant, r9-B5) — confirms the invariants are not vacuous: each of **twenty-four**
deliberately-injected design bugs (seventeen from the v10 checker-validity upgrade, four from
the v11 anarchy proposal phase, three from the v14 round-12 Codex fidelity fixes) is caught by
the check written to catch it.

> Scope honesty up front: this is *bounded* model checking of an *abstraction*. It exhaustively
> explores every adversarial interleaving up to a finite number of epochs and wall-clock steps,
> over a logical abstraction of the protocol (slot-level timing is abstracted into phases — see
> [Abstraction](#what-is-and-isnt-modelled)). It is strong evidence for the *logical* state
> machine (single-decision epochs with a **deadlined decision phase** and an **availability-
> certificate CONTENT/EMPTY resolution branch**, monotone `openEpoch`, cascade-voided
> commitments, ordered forced work with terminal refunds, typed seals, one-shot commits with
> L1-direct equivocation slashing **and a per-tenure equivocation-challenge withdrawal horizon**,
> no double-debit, bond safety, no-frame, **no false-successor-slash**, sticky evidence,
> halt-safety), not a proof about the eventual Solidity, and not a substitute for the
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
>
> **Revision note (v11 — round 10, anarchy proposal phase).** The owner-directed round-10
> review restored discretionary content to Total Anarchy (design §9), and — **ported onto the
> v10 checker above** — the model now carries the lane it reverted in v8, this time with
> **both** sides of the repair: (1) a new **`anarchy_propose`** action — any actor may seal an
> *unowned* `openEpoch` with content in **one atomic step** (propose ≡ seal ≡ finality; born
> SEALED, adapted to v10's typed seals so it consumes the forced snapshot into `fconsumed`
> exactly like `seal_content`; proof-carrying, so impossible during an outage; discretionary, so
> disabled in recovery-only mode); (2) the **two-sided proposal cutoff**
> (`min(e + W_ANARCHY, first owned epoch after e)`, collapsed in recovery-only mode): the
> unowned epoch's proof-free EMPTY resolution is enabled only **at/after** the cutoff, and the
> proposal only **strictly before** it. Two new path-independent edge invariants
> (`edge_empty_respects_phase`, `edge_proposal_respects_phase`) enforce the two sides, and a new
> state invariant (`inv_anarchy_content_sealed`) enforces atomicity (unowned discretionary
> content never exists unsealed — it is born sealed, so the §6.7 cascade can never touch it).
> **Four new mutants** prove the additions have teeth: horn 2 (`anarchy_empty_in_phase` — a
> proof-free empty front-running the phase), the determinacy break
> (`anarchy_propose_after_close`), horn 1 (`nonatomic_anarchy_propose`), and the owned-successor
> truncation (`anarchy_ignores_ownership`, run at `W_ANARCHY = 2` so the truncation term binds)
> → **twenty-one** mutants total (at the v11/v12 merge; the v14 round-12 note below adds three
> more → **twenty-four**). The composition with the r9-D1 decision deadline is
> consistent for `W_ANARCHY ≤ 2`: the cutoff never exceeds `e+2` (the window-closing tick's
> auto-resolution clock), so a window-close EMPTY auto-resolve always lands at/after the cutoff
> and proposals only ever fire at clock `e` or `e+1` (inside the decision window). **`W_ANARCHY
> = 0` disables the lane cleanly** — at the v11/v12 merge the `2 × 6, W = 0` run reproduced the
> pre-anarchy v10 state count (508,276) bit-for-bit; the v14 additions changed the base state
> shape, so the current lane-off number is refreshed in the v14 note and results table (the
> invariant property is *lane-off*, not a frozen constant).
> *Honesty note (round-10 finding r10-11, updated at this merge):* the round-9 review
> dispositioned its checker-validity findings (R9-16 / D1–D7) as "Closed-in-checker" —
> describing typed seals, an `equivocate` action, and ordered forced items — and on the owner's
> branch those were **described but not yet committed**. **As of this merge they are genuinely
> present**: the anarchy phase was ported onto the *committed* v10 checker (typed seals,
> `equivocate`, ordered forced items, and all of D1–D7), so R9-16 / D1–D7 is now really
> closed-in-checker, not just in prose. §13-T.10's CI lint remains the guard that keeps the
> checker and its prose from drifting apart again.

> **Revision note (v14 — round 12 / Codex fidelity).** A Codex review of the *committed*
> `model_checker.py` raised three P1 fidelity findings — places where the checker's abstraction
> diverged from the v14 design. This revision closes each with a new mutant proving the new
> invariant has teeth (**21 → 24 mutants**), plus four small DeepSeek hardening items:
>
> - **r12-1 — the availability-certificate CONTENT/EMPTY resolution branch is now modeled
>   (§5.2, §6.8-F2).** A discretionary content-bearing EBC no longer materializes CONTENT at
>   `decide`. It enters a new **`UNRESOLVED`** state — the EBC is accepted (the commit one-shot is
>   consumed) but availability is pending its **AC** in the `R` window — resolved by one of two new
>   actions: **`ac_certify`** → CONTENT (**EBC** mode; the AC landed), or **`ac_timeout`** → EMPTY,
>   or **forced-only CONTENT** when the snapshot is non-empty (**DEFAULT** mode; AC censorship /
>   data withheld). The window-closing tick auto-times-out any still-`UNRESOLVED` epoch, so it is
>   always resolvable. This makes the checker explore the **accepted-EBC / no-AC branch** and
>   validates **F2's commit-then-withhold**: a withheld-data epoch with a non-empty forced snapshot
>   materializes **forced-only / DEFAULT** — sealable in `seal_content`-forced form, *not* stuck —
>   and the holder carries a publication **LIVENESS** certificate (§5.2). A new edge invariant
>   **`edge_content_via_ac`** enforces that EBC-mode (non-forced, discretionary) CONTENT is
>   reachable *only* via `ac_certify`; the **`content_without_ac`** mutant materializes it directly
>   and is caught by exactly it. Kept at the state-machine altitude: only the CONTENT-vs-EMPTY
>   resolution branch and its `EBC`/`DEFAULT` mode consequence are modeled — the AC's SSZ /
>   EIP-4788 / KZG / slot-timing mechanics stay below the abstraction (scope box reconciled).
> - **r11-N2 — the withdrawal gate is on the equivocation-challenge horizon, not the acceptance
>   window (§8).** The v10 gate refused withdrawal only while a committed epoch's D+κ acceptance
>   window was open. v14 gates on a single **per-tenure equivocation-challenge horizon**
>   (`CHALLENGE_HORIZON` ticks after the tenure's last assigned epoch's finality, the model of the
>   `≥ Λ + margin` window the ≥2-week floor covers), elapsed **with no settled safety certificate**
>   — because opening a preconf-vs-record accusation is cheap and each preconf is a fresh fault id,
>   so a "no verdict currently open" gate is re-openable (r11-N2 over-accusation). A new adversary
>   action **`safety_settle_late`** models a watchtower settling a **preconf-vs-record SAFETY
>   certificate** (§8 variant (b), L2-evidence) at any tick *within* the horizon — after the
>   acceptance window, which the horizon strictly contains. The **`withdraw_before_horizon`**
>   mutant exits before the horizon elapses; `safety_settle_late` then settles against the
>   ex-holder and **`inv_withdraw_gated`** catches the withdrawn tenure carrying an unresolved
>   (and, being withdrawn, un-debitable) safety cert — the exact "withdraw then a safety cert
>   settles against it" property.
> - **r12-3 — strict tolling evaluated and rejected; the false-successor-slash property is
>   machine-checked in its correctly-scoped form (§7.1 / I4).** Codex asked whether descendants
>   should toll until a decided EMPTY/VOID ancestor *closes* (strict), not merely until it is
>   decided (effectively-open). We **implemented strict tolling and measured it**: it manufactures
>   the round-8 **W1 outage-robust artifact at *every* finite bound** — an adversary declines the
>   *free* permissionless close of an EMPTY/VOID prefix until clock `MAXCLOCK−1`, and the
>   descendant, unable to pre-age under strict tolling, then lacks its `CANCEL_LAG+1` fresh expiry
>   ticks (2×5 went from clean to **13,336 outage-robust halts**, all of this delayed-free-close
>   class — the residual weak fairness resolves at the protocol layer, not in a bounded model). So
>   **effectively-open tolling is retained**, and the property Codex worries about is machine-checked
>   in its *correctly-scoped* form by a new state invariant **`inv_no_seal_fault_behind_blocking`**:
>   a missed-**SEAL** certificate never matures behind a **genuine** (non-proof-free-closeable
>   SEQ / CONTENT / UNRESOLVED) lower epoch — only behind a proof-free EMPTY/VOID prefix the
>   descendant could itself clear in the same L1 block and *then* seal — so no descendant is ever
>   slashed for a seal it genuinely could not have performed. The **`loose_tolling`** mutant matures
>   a SEAL behind an unclosed CONTENT (a genuine latency the descendant cannot clear) and is caught
>   by exactly it. (A descendant behind a *proof-free-closeable* prefix is not falsely slashed: it
>   could clear the prefix and seal in one block, so its deadline legitimately runs, per I4's "toll
>   until the prerequisite *outcome* is irreversible" — the effectively-open reading.)
> - **DeepSeek hardening (four items).** (W#1) `W_ANARCHY > 2` is now a **hard error** at startup
>   (nonzero exit) — the proposal-cutoff/decision-deadline composition is only consistent for
>   `W_ANARCHY ≤ 2`, and the CLI previously accepted any int. (W#5) **state-space hygiene**: the
>   dead per-epoch fields (`openAge`, `committed`, `cgen`, `decided_as`) are now cleared
>   consistently on **all** closure/void paths (`cancel`, `close_void`, and the seal paths) — this
>   both merges behaviourally-identical states (the 2×5 baseline dropped from ~1.33M to ~1.17M) and
>   removes an `equivocate`-on-a-just-closed-epoch surface. (suggestion) `CANCEL_LAG < S_TICKS` is
>   now a **hard error**, not a printed warning. (doc) version strings updated v10/v11 → **v14**.
> - **`RESERVE0` sizing is now exercised to its designed worst case.** Before v14 the observed max
>   per-tenure debit was 5 against `RESERVE0 = 3·NEPOCHS+1 = 7` (slack 2), because equivocation's
>   atomic termination stripped a tenure of its still-SEQ epochs before it could accrue their
>   faults. The `safety_settle_late` lane settles the third (SAFETY) debit **without** that
>   termination, so a single tenure can now reach **6 = 3·NEPOCHS** at the default bound — exactly
>   the formula's designed worst case (SEAL/LIVENESS + CANCEL + SAFETY on every owned epoch),
>   leaving **slack 1**. The check still passes and now validates the sizing *tightly* rather than
>   over-provisioning.

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

- **decide** an epoch — only inside its **decision window** (`e ≤ clock ≤ e+1`, the coarse image
  of the single `D+κ` decision instant, §3.1); an owned decide consumes the `(tenure, epoch)`
  **commit one-shot**. A discretionary content-bearing EBC does **not** materialize CONTENT
  here (v14, r12-1) — it enters **`UNRESOLVED`** pending its availability certificate; an
  explicit-empty EBC → EMPTY, and a forced-only decision → forced-only CONTENT (DEFAULT) directly
  (no AC needed, I6). **miss_commit** (objective liveness fault, certificate settled atomically
  with the EMPTY resolution) — and when a tick closes an undecided *or* still-`UNRESOLVED` epoch's
  window, the epoch **auto-resolves** (EMPTY, or forced-only CONTENT under I6) with the owner's
  LIVENESS certificate settled atomically: the decision phase is irreversible *and deadlined*
  (r9-D1);
- **ac_certify / ac_timeout** (v14, r12-1, §5.2 / §6.8-F2): resolve an `UNRESOLVED` epoch inside
  its `R` window (subsumed into the coarse decision window). `ac_certify` → CONTENT (**EBC** mode;
  the availability certificate landed — proof-free-ish, so *not* blocked by a proving outage);
  `ac_timeout` → EMPTY, or **forced-only CONTENT** when the snapshot is non-empty (**DEFAULT**
  mode; AC censorship / data withheld — "absence never needs proving", outage-immune) with the
  holder's publication **LIVENESS** certificate settled atomically. This is the accepted-EBC /
  no-AC branch and F2's commit-then-withhold case;
- **equivocate** (v10, r9-D4): a second distinct accepted commit artifact by the one-shot's
  consumer, inside the acceptance window — the decision never changes; an L1-direct SAFETY
  certificate settles and the tenure terminates atomically (§8 variant (a), double-EBC);
- **safety_settle_late** (v14, r11-N2, §8 variant (b)): a watchtower settles a **preconf-vs-record
  SAFETY certificate** against a tenure for a held (materialized) epoch, at any tick **within** that
  tenure's equivocation-challenge horizon (evidence-based, so it can arrive *after* the acceptance
  window the horizon strictly contains) — the late-settlement path a premature withdrawal must not
  outrun;
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
  — v14, r11-N2 — refuses until the tenure's **equivocation-challenge horizon** has elapsed
  (`CHALLENGE_HORIZON` ticks after its last assigned epoch's finality, `≥ Λ + margin`) with no
  settled safety cert — a fixed per-tenure horizon that strictly contains, and outlasts, every
  acceptance/verdict window, so a griefer cannot re-open accusations to freeze an honest exit and
  a premature exit cannot outrun a late `safety_settle_late`);
- **tick** the wall clock (drives window auto-resolution, tolled ages, missed-seal
  materialization, and recovery-only mode via the lag cap `K`);
- **outage_start / outage_end** (v9): toggle the proving outage — while active, proof-carrying
  seals are impossible and only proof-free resolutions advance the chain; the adversary may
  leave the outage on forever;
- **anarchy_propose** (v11, design §9): any actor seals an **unowned** `openEpoch` with
  discretionary content in one atomic proof-carrying step (propose ≡ seal ≡ finality; born
  SEALED, consuming the forced snapshot exactly as `seal_content` does), strictly before the
  epoch's **proposal cutoff** (`min(e + W_ANARCHY, first owned epoch after e)`, collapsed while
  recovery-only mode is active); the unowned epoch's proof-free EMPTY resolution is conversely
  enabled only **at/after** the cutoff. The action is impossible during an outage (it carries a
  proof) and in recovery-only mode (it is discretionary content, I5); forced-only CONTENT
  decisions stay enabled in both phase regimes (a forced-only seal is the degenerate proposal
  during the phase and the mandated resolution after it — I6 cadence untouched).

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
- **`openAge` / tolling** (effectively-open; the machine-checked false-slash property, v14
  r12-3): `openAge[e]` counts ticks epoch `e` is decided, unsealed and *effectively open* —
  every ancestor closed, or VOID/EMPTY (whose closures are I7's deterministic, zero-latency
  proof-free resolutions, clearable by anyone — the descendant included — in the same L1 block).
  Waiting behind a SEQ / CONTENT / **UNRESOLVED** (v14) ancestor tolls (I4/§7.1: a descendant is
  never blamed while a *genuine*, non-proof-free-closeable latency blocks it). **Strict tolling
  was evaluated and rejected (v14 r12-3, Codex line ~414).** Codex asked whether descendants
  should toll until a decided EMPTY/VOID ancestor *closes* (strict), not merely until it is
  decided. Implemented and measured, strict tolling manufactures the round-8 W1 outage-robust
  artifact at **every** finite bound — an adversary declines the *free* permissionless close of an
  EMPTY/VOID prefix until clock `MAXCLOCK−1`, and the descendant, unable to pre-age, then lacks
  its `CANCEL_LAG+1` fresh expiry ticks (**2×5 went from clean to 13,336 outage-robust halts**).
  That residual is exactly the unfair-scheduler livelock weak fairness resolves at the protocol
  layer, not in a bounded model, so effectively-open is retained. The false-successor-slash Codex
  fears is instead **machine-checked** in its correctly-scoped form by
  `inv_no_seal_fault_behind_blocking`: a missed-**SEAL** cert never matures behind a genuine
  (SEQ/CONTENT/UNRESOLVED) block — only behind a proof-free prefix the descendant could itself
  clear and *then* seal — so no descendant is ever slashed for a seal it genuinely could not have
  performed. `loose_tolling` (treat a CONTENT ancestor as non-blocking) trips it.
- **`CHALLENGE_HORIZON = 2`** (v14 per-tenure equivocation-challenge horizon, r11-N2 / §8): the
  withdrawal gate refuses until this many ticks after a tenure's last assigned epoch's finality
  (`~ e_last+1`), i.e. until `clock ≥ e_last + 1 + CHALLENGE_HORIZON`. It is the model of the
  `≥ Λ + margin` window the ≥2-week floor covers; the design magnitude is collapsed to 2 ticks so
  the late-settlement lane is reachable in tiny bounds. Because `2 > 1` the horizon **strictly
  contains** every epoch's `D+κ` acceptance window (`clock ≤ e+1`) — the N2 point that the
  challenge horizon outlasts every acceptance/verdict window — and `safety_settle_late` can settle
  a preconf-vs-record SAFETY cert at any tick inside it. **No new state field** was needed: the
  AC branch reuses the `UNRESOLVED` status value and existing lineage/one-shot fields, and the
  horizon is computed from `assigned` and `clock`.
- **`CANCEL_LAG = 1`** (per-epoch expiry, §6.7 v10): epoch `e` is cancellable once
  `openAge[e] > CANCEL_LAG`, and its proof-carrying seal is **disabled** from that same age —
  the mechanical `T_exp` cutoff (r9-F2), no seal/cancel overlap ever. The design's 10-day
  `H_cancel` is deliberately collapsed to 1 tolled tick so the disaster lane — including
  *chains* of per-epoch expiries under a permanent outage — is reachable in tiny bounds. This
  over-approximates cancellation availability (safety-conservative: the cascade is exercised
  more, not less); the real `H_cancel` magnitude is argued in the design doc, not checked
  here. `--cancel-lag` overrides it; **`CANCEL_LAG < S_TICKS` is now a hard error** (v14
  DeepSeek): expiry would disable seals before the seal deadline can even mature, making the
  missed-seal/late-seal orderings unreachable, so such a config exits nonzero rather than
  silently running.
- **`S_TICKS = 1`** (r9-D5): tolled ticks a decided, owned, effectively-open epoch survives
  unsealed before the missed-seal certificate materializes. Default 1 is the conservative
  choice — the fault matures at the first opportunity, so every
  late-seal/seal-then-withdraw ordering exists at the smallest bound. `--sticks 2` delays
  maturation by one tick (a coarse image of the design's `S = 4`-epoch deadline exceeding one
  epoch); the results table includes such a run.
- **`K = 2`** global lag cap (design 8, scaled; recovery-exit `K'` scales to `lag == 0`).
- **`W_ANARCHY = 1`** (v11 anarchy proposal-phase length, design §9): the unowned-epoch
  proposal cutoff is `min(e + W_ANARCHY, first owned epoch after e)`, collapsed to the current
  clock in recovery-only mode. Design `W_a = S = 4` epochs, scaled down like `K`/`CANCEL_LAG`
  so both sides of the two-sided cutoff are exercised in tiny bounds; the composition with the
  r9-D1 decision deadline stays consistent for `W_ANARCHY ≤ 2` (the cutoff never exceeds the
  window-closing tick's auto-resolution clock, `e+2`) — and **`W_ANARCHY > 2` is now a hard
  error** (v14 DeepSeek W#1), exiting nonzero rather than silently exploring an inconsistent
  relation where a legal window-close EMPTY false-trips `edge_empty_respects_phase`. **`W_ANARCHY
  = 0` disables the lane cleanly** (`anarchy_propose` is never enabled and EMPTY is never
  phase-gated; the lane-off delta from `W = 1` is attributable to the lane alone, goal count
  identical — results table); the truncation-binding mutant runs use `W_ANARCHY = 2`. Settable
  via `--w-anarchy N`, a 3rd positional arg, or the `W_ANARCHY` environment variable.
- **`RESERVE0 = 3·NEPOCHS + 1`** per-tenure admission reserve: worst case is *three* debits on
  one owned epoch — a missed-seal SEAL (or a publication/missed-commit LIVENESS in its place),
  a CANCEL, and a SAFETY cert (v10 L1-direct equivocation, **or v14 late preconf-vs-record
  settlement**) — across all epochs a tenure can own. The design splits these across the recovery
  tranche and the ETH safety tranche of the single account (§4); one abstract reserve stands in
  for the waterfall, and the observed-max check below reports the real slack (r9-D7). v14 note:
  because `safety_settle_late` settles the SAFETY debit *without* equivocation's atomic
  termination, the observed max now reaches the formula's designed worst case `3·NEPOCHS` (6 at
  the default bound) — slack 1, sizing validated tightly.
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
| `forced_order` (v10) | §6.7, r4b-M8, §6.5, r9-D3 | the global live forced queue stays in original submission order; no closed/voided epoch retains a live item; live and terminal are disjoint and consumed-xor-refunded is exclusive (the §6.5 seal-vs-refund exclusion nullifier) |
| `content_current_gen` | §6.7 | every live CONTENT commitment carries the current lineage tag — a commitment that predates an ancestor's cancellation must have been voided by the cascade, never left sealable |
| `bond_nonneg` | §4, §8 | a slash never drives a reserve below zero |
| `no_frame` | §7.2, §8.3 | a certificate only ever names the acting owner of that epoch |
| `withdraw_gated` | §8.4, I2, §8 r11-N2 | no withdrawn tenure retains an unresolved certificate or unsealed owned epoch — the gate the checker proves *sufficient*: because the exit waits for the equivocation-challenge horizon to elapse, a late `safety_settle_late` cert can never land on an already-withdrawn tenure (v14 r11-N2) |
| `anarchy_content_sealed` | §9, I5 (v11) | unowned **discretionary** content exists only born-sealed (propose ≡ seal is atomic) — it can never sit in the cancellable value-at-risk tail or lock the chain unproven (round-2 finding 6, horn 1) |
| `no_seal_fault_behind_blocking` (v14) | §7.1, I4, r12-3 | a missed-**SEAL** certificate never matures while a lower **genuinely-blocking** (SEQ/CONTENT/UNRESOLVED) epoch is unclosed — only behind a proof-free-closeable EMPTY/VOID prefix the descendant could itself clear — so no descendant is ever slashed for a seal it could not have performed (the false-successor-slash property, Codex line ~414, machine-checked) |

Edge invariants (at every transition):

| Invariant | Design source | Meaning |
| --- | --- | --- |
| `edge_open_monotone` | I3 | `openEpoch` never decreases across any transition |
| `edge_evidence_monotone` | I2 | settled certificates (SAFETY included), consumed ids, and forced-item terminal states never disappear — no action (a late seal included) can erase matured evidence |
| `edge_debit_conservation` | I2, §8 | a reserve decreases only by consuming exactly one fresh logical fault id — no double-debit, no id-less debit, no cross-tenure debit; checks *every* debit, including at exhausted reserve |
| `edge_maturity_materialized` | I2, r9-D5 | a tick that brings a DECIDED (content or explicit-empty), owned, effectively-open epoch's tolled age to `S_TICKS` must settle that owner's missed-seal certificate (unless its miss-commit LIVENESS certificate already stands) |
| `edge_seal_immutable` | I3+I7 corollary | **path-independent** (round-8 W2): no single transition may change an already-CLOSED epoch's status — dedup cannot mask a re-open |
| `edge_decision_deadline` (v10, v14) | §3.1, I2, r9-D1 | no transition decides/resolves an epoch whose window has closed; no SEQ-**or-UNRESOLVED** epoch (v14: the AC R-window shares the deadline) survives any transition past its window; the window-closing resolution of an owned epoch settles its owner's LIVENESS certificate atomically |
| `edge_content_via_ac` (v14) | §5.2, §6.8-F2, r12-1 | an epoch newly reaching CONTENT with an **empty forced snapshot** (discretionary / EBC-mode content) must do so via `ac_certify` — a discretionary content outcome materializes only when an availability certificate is accepted; forced-only DEFAULT CONTENT (non-empty snapshot, no AC) is exempt |
| `edge_typed_seal` (v10) | I1, I7, r9-D2 | a proof-free (empty-typed) closure never closes a CONTENT-decided epoch; a proof-carrying content seal only consumes a CONTENT decision |
| `edge_no_seal_after_expiry` (v10) | §6.7, r9-F2/B5 | no transition closes an expired CONTENT `openEpoch` as SEALED — seals strictly before `T_exp`, cancellation at/after, never both |
| `edge_equivocation_settles` (v10) | §8, r9-D4 | an equivocation atomically settles an L1-direct SAFETY certificate against the equivocating tenure and terminates it |
| `edge_empty_respects_phase` (v11) | §9.1 | an unowned, non-forced epoch resolves EMPTY only **at/after** its proposal cutoff — a proof-free empty inside the phase is round-2 finding 6's empty-front-running horn (horn 2) |
| `edge_proposal_respects_phase` (v11) | §9.1 | an anarchy proposal (unowned SEQ→SEALED) is valid only for the `openEpoch`, strictly **before** its cutoff, in NORMAL mode, outside an outage — a late proposal would flip a determined outcome; one past an owned successor's start would leave that holder parentless |
| **liveness / deadlock-freedom** | **G5, I3, r9-B5** | **from every reachable state, full finalization — all epochs closed and all forced work terminal — is still reachable (standard + outage-robust); scope per [Liveness](#liveness--deadlock-freedom-and-its-scope)** |
| **outage-robust halt-safety** (v9) | **G5, I3, §10.4** | **the goal is reachable even if an active proving outage never lifts** — checked over the sub-relation excluding `outage_end`, so the proof-free floor (empty seals, void closure, cancellation with re-queue and refund) carries the whole burden |

## Results

All runs in the following table completed the **full exploration from the curated initial
configurations** (no state-cap truncation — truncation is a hard failure now) and reported
`SAFETY: NONE`, `LIVENESS: NONE` (no halt), and a passing `RESERVE0` sufficiency check, with
exit code 0 — re-run at the end of the revision and bit-for-bit reproducible:

| Bound (`NEPOCHS × MAXCLOCK`, params) | Reachable states | Goal (all-closed + forced-terminal) states | Safety violations | Halts (std / outage-robust) | Worst depth (std / robust) | Max debit / RESERVE0 | Wall time |
| --- | ---: | ---: | :---: | :---: | :---: | :---: | ---: |
| 2 × 5, `W = 1` (mutation-suite bound) | 1,165,932 | 488,496 | 0 | 0 / 0 | 6 / 7 | 6 / 7 | ~65 s |
| **2 × 6, `W = 1` (default)** | 1,408,548 | 615,968 | 0 | 0 / 0 | 6 / 7 | 6 / 7 | ~2 min |
| 2 × 6, `W = 0` (anarchy lane off — lane-off check) | 1,411,772 | 615,968 | 0 | 0 / 0 | 6 / 7 | 6 / 7 | ~2 min |
| 2 × 7, `S_TICKS=2`, `CANCEL_LAG=2`, `W = 1` (r9-D5) | 1,224,824 | 402,776 | 0 | 0 / 0 | 6 / 8 | 5 / 7 | ~1 min 45 s |

All four numbers are from real runs at the end of this v14 revision (exit 0). The state totals
grew ~2.8× from v13 — the AC branch adds the `UNRESOLVED` intermediate and its two resolutions,
and `safety_settle_late` reaches SAFETY certs the acceptance-window-gated `equivocate` could not
— all comfortably under the 14M cap.

The **`W = 0` row is the lane-off check** (the invariant property is *anarchy-lane-off*, not a
frozen constant, per the task): with `W_ANARCHY = 0` the cutoff collapses to `e`, so
`anarchy_propose` is never enabled and EMPTY is never phase-gated — the lane is cleanly disabled.
Turning the lane **on** (`W = 1`) *lowers* the total slightly (1,411,772 → 1,408,548) rather than
raising it, because the two-sided cutoff **gates out** the early proof-free EMPTY intermediates of
an unowned, non-forced epoch inside its phase, while the born-sealed `anarchy_propose` mostly
lands on **already-reachable** terminals — the **goal count is identical (615,968)** in both,
since the set of fully-final configurations is unchanged; only the intermediate exploration
differs, so the whole `W`-delta is attributable to the lane alone. (At the v11/v12 merge the
lane-off `2 × 6` count was 508,276, reproducing the then-current pre-anarchy base bit-for-bit; the
v14 AC / horizon / hygiene changes reshaped the base state space, so the lane-off number is
refreshed here — what is preserved is the *property*, not the constant.)

The `S_TICKS=2` row shows the max debit is 5 (not 6) under that configuration and the outage-robust
worst depth grows 7 → 8 (the one-tick-later seal-fault maturation), at its own artifact-free floor
(`2·2+3 = 7`).

**Three-epoch coverage, stated honestly: none completed — and v14 pushed it further out of
reach.** The state grows per epoch (ordered forced items, commit one-shots, tolled ages,
equivocation branching, the anarchy phase, and now the AC `UNRESOLVED` branch and late-safety
lane), and the v14 additions multiplied the `NEPOCHS=2` totals ~2.8×, so the per-state footprint
that already kept `NEPOCHS=3` out of reach at v10/v11 (the clean-floor bound 3×6 was stopped past
**11.2M discovered states with the frontier still growing**, and the below-floor 3×5 past 9.6M —
both under the then-current model, both un-completable within ~15 GB / ~20 min) is now larger
still: a v14 `3×6` would exceed the **14M state cap** and **fail loudly** long before completing.
No partial numbers are reported from a truncated exploration — the checker *fails loudly* at the
cap and reports nothing, and this document follows the same rule. `python3 model_checker.py 3 6`
remains one command away on larger hardware (or after a bit-packed state encoding); until then,
the exhaustive evidence is the `NEPOCHS=2` bounds
above, whose relation already contains every v10, v11 *and* v14 mechanism — the decision window and
auto-resolution, the commit one-shot and equivocation (certificate + atomic termination), typed
seals, the per-epoch expiry with the no-overlap cutoff, the cancellation cascade with
order-preserving re-queue into a still-SEQ epoch *and* the stranded-refund exit, the
outage-robust proof-free march, the anarchy proposal phase with both sides of its two-sided cutoff,
**and the v14 additions — the AC `UNRESOLVED` → `ac_certify`/`ac_timeout` resolution branch
(including F2's commit-then-withhold → forced-only/DEFAULT), the equivocation-challenge withdrawal
horizon with late `safety_settle_late` settlement, and the machine-checked no-false-slash tolling
property** (exercised from the anarchy-in-every-position, full-anarchy, and forced-in-every-position
initial configurations). What two epochs cannot exhibit (and three can): cascades that void
*multiple* descendants at once, re-queue chains longer than one hop, and three-tenure promotion
chains — untested at exhaustive depth, a stated gap rather than a footnote.

**Horizon artifacts below the floor (documented, not counted as results).** Below
`MAXCLOCK = NEPOCHS·CANCEL_LAG + 3` the outage-robust pass reports halts that are pure
bound artifacts of the per-epoch tolled expiry — e.g. a 2×4 run (`W = 1`; 923,316 states,
exit ≠ 0 by design) reports **15,976 outage-robust-only halts, 0 standard halts, and 0 safety
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

The admission-sizing assumption is a checked bound: over all reachable states of the 2×6
default run the **observed maximum cumulative debit per tenure is 6** abstract units, against
`RESERVE0 = 3·NEPOCHS+1 = 7` — **slack 1**. This is a v14 change (was 5 / slack 2): the new
`safety_settle_late` lane settles the third (SAFETY) debit on an owned epoch **without**
equivocation's atomic termination — which previously stripped the equivocator of its still-SEQ
epochs before it could accrue their faults and so capped the observed max at 5. The observed
worst case now reaches the formula's *designed* worst case `3·NEPOCHS` (SEAL/LIVENESS + CANCEL +
SAFETY on every owned epoch), so `3·NEPOCHS + 1` is validated as a **tight** bound (slack 1 =
the margin term) rather than an over-provision. (The `S_TICKS=2` run observes 5 / slack 2 — a
different configuration reaches a different max; both pass.) A run that ever drove the observed
max above `RESERVE0` would fail the exit code (and `inv_bond_nonneg` would fire on the way).

### Mutation self-test — the invariants have teeth, and the harness proves it

Run with `python3 model_checker.py --mutate`. **Per-mutant validity protocol (r9-B5):** for
each mutant the harness (a) first runs the *unmutated* baseline at that mutant's bound and
requires it fully clean — no violation, no halt, no truncation — failing loudly otherwise
(a catch at an already-dirty bound would be unattributable); (b) then requires the mutant to
produce a counterexample attributed to the *expected* invariant (`stop_on_inv` — incidental
co-firing of other invariants can neither mask nor fake it); (c) the liveness mutant runs at a
bound whose baseline outage-robust pass is clean. All **twenty-four** run at **2×5** — the
twenty-three non-truncation mutants at the default `W_ANARCHY = 1` (baseline: 1,165,932 states,
0 violations, 0 halts) and `anarchy_ignores_ownership` at `W_ANARCHY = 2` (baseline: 1,161,644
states, 0 violations, 0 halts) so its owned-successor truncation term binds; both baselines are
printed by the harness itself. The whole suite takes about 5 minutes:

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
| a proof-free empty resolves an unowned epoch inside its proposal phase — round-2 finding 6, horn 2 (v11) | `edge_empty_respects_phase` | **CAUGHT** |
| an anarchy proposal is accepted at/after the cutoff, flipping a determined outcome (v11, r10-1) | `edge_proposal_respects_phase` | **CAUGHT** |
| an anarchy proposal locks decided-but-unsealed content — round-2 finding 6, horn 1 (v11) | `inv_anarchy_content_sealed` | **CAUGHT** |
| the cutoff ignores the owned-successor truncation (v11, r10-3; run at `W_ANARCHY = 2` so the term binds) | `edge_proposal_respects_phase` | **CAUGHT** |
| a discretionary content decision materializes CONTENT with no availability certificate (v14, r12-1) | `edge_content_via_ac` (§5.2/F2) | **CAUGHT** |
| withdraw before the equivocation-challenge horizon elapses, then a late safety cert settles against the ex-holder (v14, r11-N2) | `inv_withdraw_gated` (§8) | **CAUGHT** |
| a descendant's missed-SEAL cert matures behind an unclosed CONTENT ancestor it could not clear (v14, r12-3) | `inv_no_seal_fault_behind_blocking` (§7.1/I4) | **CAUGHT** |
| a proving outage wrongly blocks proof-free seals too | outage-robust halt analysis (v9) | **CAUGHT** (203,738 permanent-halt states) |

`# mutation self-test: ALL BUGS CAUGHT (invariants have teeth)` — with documented incidental
co-firings, all tolerated and none able to mask the expected invariant under the `stop_on_inv`
protocol: `double_decision` also trips `content_current_gen` **and** `edge_content_via_ac`
(the flip EMPTY→CONTENT on a non-forced epoch is a content materialization with no AC);
`reopen_sealed` also trips `edge_open_monotone` **and** `edge_content_via_ac` (re-opening a
closed non-forced epoch to CONTENT); and `nonatomic_anarchy_propose` also trips
`edge_content_via_ac` (unowned non-forced SEQ→CONTENT). These three incidental
`edge_content_via_ac` co-firings are a sign the new invariant has *broad* teeth — it fires on
every illegal direct CONTENT materialization, not only the one `content_without_ac` injects.

## What this tells us about the design

- **No reachable invalid state or transition** (within the bounds): the v14 state machine never
  double-decides an epoch — *and never decides one late*; never materializes discretionary
  content without an availability certificate, never leaves an `UNRESOLVED` epoch stuck; never
  lets an equivocation flip a decision or escape its L1-direct slash-and-terminate; never closes
  content through the
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
- **The I2 withdrawal-gate claim is checked, not assumed** — and, v14 (r11-N2), is now gated on
  the **equivocation-challenge horizon** rather than the acceptance window: the gate refuses an
  exit until the fixed per-tenure horizon (`≥ Λ + margin`) has elapsed, and the checker proves
  that gate *sufficient* against the new `safety_settle_late` lane — a late preconf-vs-record
  safety certificate can never settle against an already-withdrawn tenure over any legal run, so
  no honest exit is frozen by re-opened accusations and no premature exit outruns a late verdict.
- **The AC CONTENT/EMPTY resolution branch is now explored** (v14, r12-1): the checker walks the
  accepted-EBC/no-AC branch and confirms F2's commit-then-withhold has a clean exit — a
  withheld-data epoch with a non-empty forced snapshot materializes forced-only/DEFAULT, seals in
  `seal_content`-forced form, and is never stuck; and EBC-mode content is unreachable without an
  availability certificate.
- **No descendant is falsely slashed** (v14, r12-3): the false-successor-slash property Codex
  raised is machine-checked — a missed-seal certificate never matures behind a genuinely-blocking
  lower epoch, only behind a proof-free prefix the descendant could itself clear.
- **Admission sizing is a checked bound** (r9-D7), now exercised to its designed worst case
  `3·NEPOCHS` (v14): the observed worst-case per-tenure debit is printed against `RESERVE0` every
  run.
- **The v11 anarchy lane holds under the same attack surface**: with the two-sided cutoff in
  the relation, no interleaving of proposals, empties, forced decisions, outages, mode switches,
  promotions-to-anarchy, and cancellations produces an empty inside a protected phase, a
  proposal past a cutoff or an owned successor's start, unsealed unowned discretionary content,
  or any regression of the prior invariants — and both liveness passes still hold, because
  the post-cutoff proof-free empty is exactly the outage-robust exit the v9 pass already relied
  on. `W_ANARCHY = 0` cleanly disables the lane (the lane-off delta is attributable to the lane
  alone; goal count identical).

## What is and isn't modelled

**Modelled:** the epoch lifecycle with a deadlined, irreversible single decision per epoch
(window + auto-resolution); (v14) the **availability-certificate CONTENT/EMPTY resolution
branch** — the `UNRESOLVED` decision-pending state and its `ac_certify` (→ CONTENT, EBC mode) /
`ac_timeout` (→ EMPTY or forced-only, DEFAULT mode) resolutions, including F2's commit-then-
withhold; the commit one-shot and L1-direct double-EBC equivocation (certificate + atomic
termination) **and (v14) the late preconf-vs-record `safety_settle_late` lane**; the `openEpoch`
state machine and recovery lane; typed proof-carrying vs proof-free seals; seat handover /
promotion / anarchy; objective liveness certificates with read-time (tolled, `S_TICKS`-
parameterized) maturity materialization and one-shot debiting **and the machine-checked
no-false-successor-slash tolling property (v14)**; the state-gated withdrawal (v14: gated on the
**equivocation-challenge horizon**, `≥ Λ + margin`, not the acceptance window); ordered forced
snapshots with order-preserving cascade re-queue, consumption, and terminal refund (I6, §6.5's
nullifier, §6.4's refund); recovery-only mode via the global lag cap; the per-epoch mechanical
expiry `T_exp` with the no-overlap seal cutoff and the §6.7 cascade (voided descendants, in-order
closure, causing-tenure charge); the adversarial proving outage with outage-robust liveness; and
(v11) the **anarchy proposal phase** — the atomic propose ≡ seal action (born sealed, adapted to
v10's typed seals), the two-sided `W_ANARCHY` cutoff with its ownership truncation, and its
recovery-only / outage interactions.

**Abstracted away (deliberately):** exact slot counts (`Γc`, `κ`, `R`, the 32-slot epoch, the
`Γc+κ` last-look window, `CHALLENGE_HORIZON`'s `Λ`-derived magnitude), the 10-day/18-day
`H_cancel`/blob-retention magnitudes (collapsed to `CANCEL_LAG` ticks; the refund fires at
bound-stranding rather than at blob expiry — the design's disaster exit is cancel-on-blob-expiry,
whose timing is a design-doc argument, not checked here), continuous bond magnitudes and fee/MEV
economics (one abstract reserve stands in for the §4 tranche waterfall; `L_safety`'s ETH
denomination and `Λ`-sizing are §8/§11 arguments), the **cryptographic mechanics of the §5.2
availability certificate** — the SSZ generalized-index Merkle proof, the EIP-4788 beacon-root
binding, the KZG-commitment opening in the seal circuit, and the `R`-slot timing (v14: the
**CONTENT-vs-EMPTY resolution branch the AC produces IS now modeled** — `UNRESOLVED` /
`ac_certify` / `ac_timeout` — only its cryptographic realization stays below the abstraction);
other cryptographic mechanisms (proof public inputs, precommitted payees, signatures on
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

**Bounds are finite — and the completed bounds are two epochs.** A clean result at these
bounds does not prove correctness at all depths, and this revision's exhaustive runs stop at
`NEPOCHS=2` (see [Results](#results) for exactly what that covers and what it cannot). The
value of bounded model checking is that the overwhelming majority of state-machine bugs
manifest at very small bounds — every v10, v11 *and* v14 mechanism, including the cascade/re-queue/
refund lanes, equivocation, the anarchy proposal phase with both sides of its cutoff, the AC
`UNRESOLVED` resolution branch, the challenge-horizon withdrawal gate with late safety
settlement, and the no-false-slash tolling check, is
exercised at two epochs — but multi-descendant cascades and
longer re-queue/promotion chains first exist at three, so completing `3 6` on larger
hardware (or after a compact bit-packed state encoding, a standing reviewer suggestion) is
the stated next step, not an optional nicety.

## Reproduce

```bash
cd packages/protocol/docs/preconfirmation/simulation
python3 model_checker.py                      # default 2×6 exhaustive run (W_ANARCHY=1, ~2 min)
python3 model_checker.py 3 6                  # clean NEPOCHS=3 bound — needs a large
                                              #   memory/time budget (did not complete on a
                                              #   15 GB / ~20 min budget — fails loudly at
                                              #   the 14M cap, never silently)
W_ANARCHY=0 python3 model_checker.py          # anarchy lane off (lane-off check)
python3 model_checker.py 2 6 0                #   (same, via 3rd positional arg)
python3 model_checker.py 2 6 2                # W_ANARCHY=2: ownership truncation binds (W>2 errors)
python3 model_checker.py 2 7 --sticks 2 --cancel-lag 2   # S_TICKS=2 semantics run
python3 model_checker.py --mutate             # validity-protocol mutation self-test (24 mutants)
```

No dependencies beyond the Python 3 standard library. Exit code is non-zero on any safety
violation, halt, truncated exploration, failed `RESERVE0` check, or mutation-harness error, so
the checker is CI-safe; wiring `model_checker.py` (and `--mutate`) into CI is tracked as
design-doc §13-T.10 so a future edit cannot silently invalidate these invariants.
