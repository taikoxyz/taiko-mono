# Round 10 — Owner Directive Review: Discretionary Proposals in Total Anarchy, and the v11 Dispositions

**This document is the in-depth review of proposal v10 through one owner question** (2026-08-21):

> *What if, in the new design, an unowned epoch can still have proposals proposed by any
> address (`msg.sender`), instead of keeping it empty or forced-inclusion-only?*

That question re-opens, deliberately, the one piece of the original brief the redesign has so
far **subtracted**: Total Anarchy as a mode that carries discretionary content, not merely a
censorship-resistant fallback that drains forced items and empties. The v10 design records the
subtraction in three places — §9's v8 note, Appendix A #28, and the §13-T.11 repair sketch —
and this review's job is to (1) reconstruct exactly *why* v10 forbids it, (2) audit every part
of v10 that load-bears against re-admitting it, (3) find what the §13-T.11 repair sketch got
right and what it missed, and (4) derive the mechanism that survives the audit. The resulting
normative change is **draft v11** of [`../redesign-proposal.md`](../redesign-proposal.md) (the
**anarchy proposal phase**, §9); dispositions for every finding below are in that document and
in this one.

**Targets reviewed:** `redesign-proposal.md` v10 (full pass, §0–§13 + appendices),
`simulation/model_checker.py` + `RESULTS.md` **as committed** (which turned out not to be
the revision round 9 claimed — finding r10-11), the v7→v8 restoration-and-revert record
(§9 v8 note, Appendix A #28, RESULTS.md v7/v8 revision notes), and the round-2 finding-6
lineage as recorded in those places.

---

## 1. History: the two horns, and what v10 actually says

Round 2's finding 6 established that FCFS anarchy content, as the brief sketched it, dies on
one of two horns:

- **Horn 1 — unproven content locks state.** If a bare proposal (no proof) can claim an
  unowned epoch, an adversary locks the epoch with content only it can prove (or that no one
  can), and the chain stalls behind it. This violates what became **I7** (only proven
  transitions lock state).
- **Horn 2 — empty front-running.** If the epoch is instead claimable only by a
  *proof-carrying* proposal, the fix for horn 1 creates horn 2: a **proof-free empty seal** is
  valid (and costs one cheap transaction) from the moment the epoch is resolvable, while a
  proof-carrying proposal needs ~10–15 minutes of proving that cannot even *start* before the
  parent outcome is known. Any actor — a griefer, a competing proposer, an L1 builder — can
  resolve the epoch empty before any content proposal can physically exist, torching every
  proposer's proving spend at near-zero cost. Rational proposers never form; the lane is
  content-dead by construction.

v3–v6 resolved the pair *by subtraction* (no discretionary anarchy content — accepted by the
round-2 reviewer as a valid closure). v7 restored the atomicity half (**propose ≡ seal**:
one transaction carrying content + validity proof, sealing on acceptance), which genuinely
closes horn 1 — and the v8 regression audit correctly found that alone it walks straight onto
horn 2, and reverted it. The repair sketch recorded in §13-T.11 names the missing half:

> a deterministic `S`-epoch **empty-wait** (pure empty resolution of an unowned epoch valid
> only after the window in which a proven transition could have landed; forced-only outcomes
> unaffected — I6 already invalidates empty), plus its lag/`K` interaction (`S < K` keeps
> dead-anarchy lag constant at `S`) and the FCFS/builder-ordering analysis.

This review's core result: **the sketch is directionally right and materially incomplete.**
The empty-wait alone — added naively — either reintroduces horn 2 at every content-run
startup, or destroys dead-anarchy cadence, or breaks an owned successor's ability to commit,
depending on which clock the wait runs on. Each failure, and the closing rule, is a numbered
finding below. The good news is that every closing rule is one the design already owns: the
mechanical-cutoff discipline of §6.7's `T_exp` (r9-F2), the fixed-at-vs-materialized-at
discipline of I2/§3.1, and the epoch-relative timing discipline of I1. v11 adds no new *kind*
of mechanism — it reuses three existing ones.

---

## 2. What in v10 load-bears against anarchy content — the invariant audit

Before designing anything, the review swept §0–§13 for every statement that assumes unowned
epochs carry no discretionary content. The constraint each imposes on any re-admission:

| Source | What it demands of an anarchy-content mechanism |
| --- | --- |
| **I1** (content-addressed, inclusion-independent derivation) | A proposal must commit its own content and L1 origin exactly as an EBC does; its derived outcome may not depend on its L1 inclusion block, sender, or timing. The *selection among competing proposals* is the only thing inclusion order may decide (see I7 row). |
| **I2** (liability is computed state) | No one is *obligated* to propose: an unowned epoch has no holder, so there must be **no fault, no bond, no deadline duty** attached to proposing. A proposal is an opportunity; its absence must still resolve the epoch deterministically. |
| **I3** (single open epoch, always advanceable) | Any wait that defers the empty resolution must be **bounded and mechanical**, and the proof-free exit must survive a proving outage (during which proposals are impossible). |
| **I4** (successor-safe parent) | Deferring an unowned epoch's outcome must never leave a *successor holder* sequencing on an undetermined parent past its own commit deadline. This kills the naive wait in mixed (anarchy→owned) regimes — finding r10-3. |
| **I5** (bounded backlog; recovery-only mode) | Anarchy content is discretionary content: recovery-only mode must suppress it, and the wait must keep steady-state lag strictly inside `K`. Conversely, atomic propose≡seal content adds **zero** epochs to the unsealed tail — it is born sealed (finding r10-5). |
| **I6** (forced inclusion censorship-proof) | Every proposal must consume the epoch's forced snapshot as its prefix (the snapshot commitment is already a public input of every seal proof consuming it — §6.5). Empty stays invalid while the snapshot is non-empty. Forced cadence must not degrade (finding r10-4). |
| **I7** (only proven transitions lock; outcomes sender-free) | Atomicity satisfies the first clause. The second clause needs an explicit, scoped statement: for an unowned epoch, *which* proven outcome locks **is** selected by L1 inclusion order among valid proposals — that is the definition of FCFS anarchy, an owner-chosen property, not a leak. Every candidate's own outcome stays sender-free and its reward payee proof-bound. |
| **I8** (precommitted payees) | The proposal's fee/MEV beneficiary (`coinbase`, reward payee) must be a **public input of its proof**, so a copied proposal in the mempool cannot be re-pointed. Already the design's standard rule for seals. |
| **I9** (oracle-free deterrence) | Nothing to deter: no preconfs exist for unowned epochs, so there is no equivocation class, no `L_safety` analog, and no new bond. A "second proposal" is a no-op, not evidence. |
| **Immutability corollary** | A sealed proposal is final; the §6.7 cascade never touches it. |
| **§5.2 availability certificate** | Not needed for proposals: the AC machinery exists because an EBC references blobs *streamed earlier*. An atomic proposal carries its blobs **in its own transaction** — DA is by construction (finding r10-5). |
| **§5.4 `K_empty` / §4 `T_max`** | Tenure counters; vacuous in anarchy. No anarchy activity may reset or feed any tenure counter — and none does, since no tenure exists. |
| **§6.7 `T_exp` / cascade** | The cascade's re-resolution is deterministic (§13-S.2) and must stay so: **cancellation re-resolution admits no proposals.** A proposal-sealed epoch never reaches `T_exp`. |
| **§10.4 four-guarantee split** | Guarantee 3 ("discretionary throughput: anarchy carries none") is the only guarantee v11 upgrades — to *conditional best-effort* — and it must be restated, not silently strengthened. |

No other section constrains the mechanism. Notably, the **acceptance predicate** (§3.1, v10)
already implies why unowned epochs resolve EMPTY-PENDING at their decision: no registered
tenure keys exist, so no acceptable EBC can exist. v11 keeps that decision untouched — the
proposal lane attaches strictly *after* it.

---

## 3. Findings

Severities are against the *naive* re-admission (v7's mechanism plus §13-T.11's sketch read
literally). Status is the v11 disposition.

### r10-1 [CRITICAL] — The empty-wait needs a mirror cutoff, or determinacy dies

The sketch gates *empty* ("valid only after the window") but says nothing about when
**proposals stop being valid**. Without a proposal cutoff, an epoch past its wait with no
proposal is empty-resolvable — but a late proposal could still land and race the empty seal
indefinitely. Consequences: (a) L1 transaction ordering decides content-vs-empty for
arbitrarily old epochs, forever — the exact sender/order dependence I7 exists to exclude,
now unbounded in time; (b) no downstream actor can ever treat an unproposed epoch's outcome
as determined, so a proposer for epoch `N+1` cannot safely start proving against
"`N` resolves empty" — which serializes all of anarchy behind actual on-chain seals and
resurrects the cadence problems of r10-2; (c) the v10 `T_exp` lesson (r9-F2: never leave two
mutually exclusive resolutions simultaneously enabled) is violated verbatim.

**Status: Closed (v11 §9).** The phase is **two-sided and mechanical**, mirroring `T_exp`:
each unowned epoch `N` gets one fixed **proposal cutoff** `T_prop(N)`. Proposals are valid
**strictly before** `T_prop(N)`; the proof-free empty / third-party forced-only resolution is
valid **at and after** it; no L1 block can accept both. At the cutoff the epoch's outcome
becomes *determined* (empty or forced-only, a pure function of L1 state — the same
fixed-at-vs-materialized-at split as §3.1: the resolution *seal* may land later, but nothing
after the cutoff can change which branch it takes). After the cutoff the epoch's semantics
are exactly v10's.

### r10-2 [CRITICAL] — Which clock the wait runs on decides whether anarchy can pace itself

The sketch leaves the wait's start implicit, and the two obvious readings both fail:

- **From "the epoch became sealable"** (i.e., from when it is the `openEpoch` with its
  parent final): waits become **sequential** — in dead anarchy (no proposers), epoch `N+1`'s
  wait cannot start until `N`'s empty seal lands, so the chain resolves one epoch per wait
  (`W_a·E` each) instead of one per `E`. Lag grows by `(W_a−1)·E` per epoch until it crosses
  `K`, recovery-only mode fires, the wait is suspended, the backlog purges, the mode exits,
  and the cycle repeats: a **permanent sawtooth** between anarchy-content and recovery-only
  mode, in the *quiet* case. Unacceptable — v10's dead anarchy is clean (constant small lag).
- **From the epoch's decision instant, without the r10-1 cutoff:** cadence is fixed
  (decisions are `E`-spaced, so waits run concurrently and expire `E`-apart), but the first
  epoch of a content run re-opens **horn 2**: a proposer can only start proving when the
  parent's outcome is determined, and by then the target epoch's wait — which started at its
  own decision, long before — may be about to expire, so a griefer's empty seal at expiry
  torches the in-flight proof. The wait exists and still fails its one job.

**Status: Closed (v11 §9), by combining the decision-anchored clock with the r10-1 cutoff.**
`T_prop(N) = D_N + W_a·E` on the I4-tolled clock, where `D_N` is `N`'s decision-final
instant. Concurrent, `E`-spaced cutoffs give dead anarchy a **constant** lag of
`≈ (1 + (Γc+κ)/E + W_a)` epochs (≈ 5.2 epochs at `W_a = 4`) and full `1/E` cadence. The
startup horn disappears because of the cutoff's *other* face (r10-1): an epoch past its
cutoff is **determined**, so a proposer never targets it — it targets an epoch whose
remaining window still exceeds its proving time `P`, and every older unowned epoch
auto-resolves. The arithmetic closes: a proposal for epoch `M` started at time `t` with
`T_prop(M) ≥ t + P + margin` lands after every older epoch's cutoff has passed (cutoffs are
`E`-spaced), so the proposer can materialize the ancestor empty seals and its own content
seal in one transaction. Anarchy **self-paces**: content epochs land at proof-latency
cadence (~one per `max(E, P)`), skipped epochs auto-empty, and lag never leaves the constant
band — no sawtooth, no recovery-only oscillation. The consensus constraint
`W_a + 2 ≤ K` (v11 §3 table) keeps the band strictly inside the recovery trigger, and
`W_a·E ≥ P + margin` (same row) is what makes the protected window real; `W_a = S` satisfies
both at current values because `S` is already sized to proving latency (§10.1).

### r10-3 [CRITICAL] — A naive wait breaks every owned successor of an anarchy epoch

The sketch never considers the mixed regime. If unowned epoch `N` can stay undetermined
until `D_N + W_a·E` (~4.2 epochs past its boundary), a tenure assigned epoch `F = N+1` (or
`N+2`, …) must sequence, commit, and prove on a parent chain that is **not determined until
long after its own EBC deadline**. I4 breaks; the new holder is unslashable-through-no-fault
or simply cannot serve; the auction — the designed exit from anarchy — becomes the thing the
wait sabotages.

**Status: Closed (v11 §9 + §4).** Two mechanical rules:

1. **Cutoff truncation at the seat boundary:** `T_prop(N) = min(D_N + W_a·E, T_F)`, where
   `F` is the earliest epoch assigned to any tenure per L1 assignment state **at `D_N`**
   (`T_F = +∞` if none). Fixed once, at the decision, from then-current L1 state — never
   retroactively re-evaluated (the §3.1 artifact-set-closure discipline). Epochs whose
   decision falls at/after `T_F` get an empty phase (`T_prop = D_N`) and are v10-identical —
   which is exactly the `Γc+κ` soft-window regime the incoming holder already tolerates for
   its immediate predecessor under v10 (§5.2).
2. **Assignment-side guard:** a seat transition may not assign a first epoch `F` with `T_F`
   below any **already-fixed** cutoff; the transition delay is
   `max(q·E, latest fixed cutoff − now)` — at most `≈ (W_a+1)·E` beyond `q`, and only while
   anarchy phases are actually pending. Ending anarchy by out-bidding the reserve floor
   (G5) therefore costs up to ~`W_a` epochs of extra notice; in exchange, every in-flight
   honest proposal keeps the window it was promised, and the incoming holder starts on a
   fully determined parent chain. The griefing dual — winning the auction to torch
   proposals — is thereby bounded to work already committed inside one window, priced at a
   full reserve-floor bid, and *is* the designed exit working as intended.

### r10-4 [HIGH] — No rule can distinguish forced-only sealers from content proposers, so don't try

An attractive-looking refinement — "let forced-only seals land during the wait, but delay
*empty* only" (to keep bridge cadence) or its dual "make forced-only wait too, so it cannot
race content proposals" — is **vacuous both ways**: a proposal is the forced prefix plus an
arbitrary discretionary suffix, so a "forced-only seal" is exactly a proposal whose suffix
is empty, and any predicate on the suffix ("real" content vs stuffing) is trivially
satisfiable with one self-dealing transaction — the same undecidability that demoted
`K_empty` to a nuisance bound (§5.4, r9-A3). The only mechanical line that exists is the one
the design already draws: **proof-carrying vs proof-free.**

**Status: Closed-by-scoping (v11 §9, §11.8).** During the phase, *every* proof-carrying
proposal is valid — including the empty-suffix one — and they race on equal, cost-symmetric
terms (each burns real proving); at/after the cutoff, the v10 resolutions apply. Two honest
consequences are stated rather than engineered away: (a) **forced cadence does not degrade**
— a forced-fee-collecting proposal is valid from the first instant a v10 forced-only
recovery would have been, so items flow at the same `decision + P` cadence whenever anyone
wants the §6.5 fees, and the cutoff path is the same nobody-acted fallback as v10's; (b) a
determined racer can suppress *discretionary* anarchy content by winning the FCFS race every
epoch — partially reimbursed by forced fees when the snapshot is non-empty — which is a
**priced service-level residual, not a guarantee break**: the inclusion floor was and
remains the forced queue (I6), the censor must win every race against arbitrarily
fee-bumpable competitors, and the durable fix is the auction (any party that values open
sequencing more than the racer bids the reserve floor — G5). Recorded as §13-T.14's
quantification item alongside the corridor economics of §11.5.

### r10-5 [HIGH] — Atomic proposals must be self-contained: no AC, no publication window, no retention duty

v7's restoration inherited the owned pipeline's shape (commit referencing streamed blobs).
Wrong shape for anarchy: a proposer racing FCFS cannot pre-stream slices and then hope its
commitment wins — that both wastes every loser's blob fees *and* drags the §5.2 availability
machinery (AC windows, `R`-timeouts, fill rewards) into a lane with no holder to fault.

**Status: Closed (v11 §9).** An anarchy proposal is **one transaction**: its blob slices ride
the proposal transaction itself; the contract binds them via the transaction's own blob
versioned hashes; the proof opens exactly those commitments and proves the derivation
(forced prefix first — I6 — then the discretionary suffix) with the payee as a public input
(I8). Acceptance = seal = finality in the same atomic step. Consequences, all
simplifications relative to the owned pipeline: no AC, no `R` window, no publication fault,
no fill reward, no retention duty toward `H_cancel` (the epoch is born sealed and can never
be cancelled), no equivocation surface (nothing was promised before landing — there are no
anarchy preconfs), and **zero addition to the value-at-risk unsealed tail** that I5/§6.7
bound. An invalid proposal (bad proof, wrong snapshot, stale anchor) is an inert revert that
consumes nothing — the §3.1 acceptance-predicate discipline applied to a permissionless
artifact.

### r10-6 [MEDIUM] — Anchor eligibility and timestamps must stay epoch-relative, not landing-relative

A proposal proven days after its epoch's window must not get to anchor "fresh" L1 state into
an old epoch (bridge-ingestion coherence, timestamp monotonicity), and its validity must not
depend on its own landing time (I1).

**Status: Closed (v11 §9).** A proposal for epoch `N` commits an anchor from **exactly the
eligibility window an owned EBC for `N` would have had** (§6.6: ≥ `D_anchor` deep measured
against `N`'s own schedule, inside the freshness ceiling relative to `T_N`, advancing past
the previous non-empty epoch's anchor), and its L2 timestamps keep the committed
`[T_N, T_N+E)` bounds. By landing time the committed anchor is only *deeper* — strictly
safer — and the stale-timestamp consequence (anarchy content executes with timestamps up to
the constant lag band behind wall clock, ~30 min worst case) is stated in §9 rather than
hidden. Sustained-anarchy bridge ingestion advances with each content epoch's anchor —
strictly better than v10's forced-only-cadence-only ingestion.

### r10-7 [MEDIUM] — Mode interactions: recovery-only, proving outage, cancellation

Three interactions the sketch never mentions, each resolved by an existing rule:

- **Recovery-only mode (I5):** anarchy proposals are discretionary content, so while the
  mode is active they are invalid and cutoffs collapse (`T_prop = now`): the backlog drains
  at proof-free speed, exactly as v10. Mode entry/exit is already deterministic from L1
  state, so the collapsed cutoff stays mechanical. Because the r10-2 lag band sits strictly
  inside `K`, anarchy alone never triggers the mode; after an exogenous trigger (outage
  backlog), the `K'` exit and the band re-establish without oscillation.
- **Proving outage:** proposals are proof-carrying, hence impossible during an outage — and
  nothing waits for them: cutoffs keep running (there is no holder to protect, so §10.4's
  attested-outage tolling does **not** extend `T_prop`), the proof-free empty resolution
  fires at each cutoff, and the checker's outage-robust deadlock-freedom is preserved (§5
  below). An attested outage that tolls a *decision* (per §10.4) tolls `D_N` and hence
  `T_prop` with it — inherited, not special-cased.
- **Cancellation cascade (§6.7):** re-resolution stays deterministic and proposal-free;
  a proposal-sealed epoch is sealed state and untouchable. No change to §13-S.2.

### r10-8 [MEDIUM] — Seat-value cannibalization: why the auction still clears

If anyone can sequence unowned epochs for free (no seat fee, no bond), does the seat still
sell — or does v11 quietly convert the perpetual auction into a suggestion? Reviewed as an
economics question: the seat buys (a) **preconfirmation power** — sub-second promises backed
by `L_safety`, the product users actually feel, structurally impossible in anarchy (nothing
exists to slash — no bond, no registered keys, no promise before landing); (b)
**exclusivity** — no FCFS race, no torched proofs, no speculative-ancestor risk; (c)
**latency and cadence** — real-time sequencing and a `K+S`-deep pipeline vs
proof-latency-stale, one-per-`max(E,P)` contested slots; (d) **fine-grained MEV** — anarchy
content is frozen ~`P` before landing, so its extraction is coarse. A rational actor for
whom sequencing Taiko is worth anything above the reserve floor strictly prefers the seat;
sustained "shadow service" is dominated by bidding. Anarchy proposing pays no admission
tithe or per-epoch protocol fee because it consumes no protocol guarantee — it *is* the
degraded service. Stated in §11.8; the empirical check (does the auction clear promptly out
of anarchy once real demand exists) joins the §13-T.7 graduation metrics.

### r10-9 [LOW] — FCFS selection is an explicit I7 scope statement, not a silent exception

L1 builders/proposers become the de-facto selectors of anarchy content (whoever's proposal
lands first wins) — which is *based sequencing* in its purest form and the brief's stated
intent, but v10's I7 ("who sends a transaction never affects what the outcome is") reads as
forbidding it.

**Status: Closed (v11 §0-I7).** I7 gains one scoped sentence: for an unowned epoch strictly
inside its proposal phase, *which* proven outcome locks is selected **first-accepted-wins**
— L1 inclusion order is the selection rule, by definition of the anarchy lane — while every
candidate proposal's own derived outcome and reward payee remain sender-free and
proof-bound, and every *resolution* (empty, forced-only, cancellation) remains a
deterministic pure function of on-chain state. The relaxation is bounded to the phase: at
`T_prop` the epoch re-enters the fully order-free regime.

### r10-10 [LOW] — Deployment: the whole lane must be switchable off

Phase A ships allowlisted and conservative; a new permissionless lane should not be a
day-one consensus risk.

**Status: Closed (v11 §9, §13).** `W_a` is a governance parameter with a consensus floor of
`0`; **`W_a = 0` makes every phase empty and v11 byte-identical to v10** (proposals are
never valid; all resolutions fire at the decision, as today). The owner can ship Phase A
with the lane dark and light it by parameter change; the artifact spec (§13-S.18) is
Phase-B-blocking, not Phase-A-blocking, unless the owner elects `W_a > 0` at launch.

### r10-11 [HIGH, artifact-consistency] — Round 9's "Closed-in-checker" disposition describes a checker that was never committed

Found while preparing the verification extension, and reported here because the round-10
review is the pass that tripped over it. `round9-consolidated-review.md` R9-16 (and the
proposal's Appendix B r9-B5/D1–D7 row) dispositions the seven checker-validity findings as
**Closed-in-checker**, describing typed seals, a decision deadline with auto-EMPTY, an
L1-direct `equivocate` action, ordered forced-item identities, per-epoch tolled `openAge`,
a baseline-validated mutation harness, exit-depth reports, and a "v10 revision note" in
`RESULTS.md`. **None of that exists in the committed artifacts**: `simulation/` was last
touched by the round-8 commit, `model_checker.py` still self-describes as the v9 model, and
`RESULTS.md` has no v10 revision note. Under the header's normative-precedence rule this is
a documentation bug to surface, not to paper over.

**Status: Flagged, scoped out, tracked.** This PR does not attempt the R9-16 rebuild (it is
round-9's own work item and misrepresenting it as done again would compound the bug); the
v11 checker extension (§5) is built on the checker **as committed** (round-8 shape + v9
outage mode), `RESULTS.md`'s v11 revision note states the discrepancy plainly, and closing
R9-16 for real is re-opened for the owner alongside §13-T.10's CI wiring — which is also
the mechanism that would have caught this drift (a consistency lint would have failed on
"v10 revision note" pointing at nothing). One stale-reference bug of the same class was
found and fixed in passing: §9's v8 note and Appendix A #28 both cited "§13-T.9" for the
anarchy repair path, which the v10 renumbering had moved to §13-T.11.

---

## 4. The v11 mechanism in one page (normative text in §9)

For an **unowned** epoch `N`:

1. Its `D+κ` decision is unchanged from v10: no acceptable EBC can exist (no registered
   keys), so the epoch resolves EMPTY-PENDING at `D_N`.
2. One fixed **proposal cutoff** is set at that instant:
   `T_prop(N) = min(D_N + W_a·E, T_F)` on the I4-tolled clock (`F` = earliest assigned
   epoch per L1 state at `D_N`; recovery-only mode collapses the cutoff while active).
3. **Strictly before `T_prop(N)`**, when `N` is the `openEpoch` with ancestors determined:
   any address may submit an **anarchy proposal** — one atomic transaction carrying the
   epoch's full content (forced-snapshot prefix mandatory, discretionary suffix free), its
   blob data (bound by the transaction's own blob versioned hashes), a committed anchor from
   `N`'s own §6.6 eligibility window, and a validity proof with the beneficiary as a public
   input. **Acceptance is sealing is finality.** First accepted wins; later or invalid
   submissions are inert no-ops. Ancestor resolutions whose cutoffs have passed may be
   materialized in the same transaction.
4. **At and after `T_prop(N)`**, proposals are invalid and the epoch is exactly a v10
   unowned epoch: proof-free empty seal (snapshot empty) or permissionless forced-only seal
   (snapshot non-empty), then `T_exp`/cancellation as the disaster floor.
5. No preconfs, no bond, no duty, no fault, no equivocation class exist in the lane.
   `W_a = 0` disables it entirely (v10-identical); `W_a = S` is the recommended initial
   value; `P + margin ≤ W_a·E` and `W_a + 2 ≤ K` are consensus constraints.

## 5. Verification

The model checker gains the lane (see `simulation/RESULTS.md`, v11 revision note): an
`anarchy_propose` action (atomic SEQ→SEALED, unowned `openEpoch` only, phase-gated,
disabled in recovery-only mode and during outages), the phase-gated unowned empty
resolution, and the ownership truncation; two path-independent edge invariants
(`edge_empty_respects_phase`, `edge_proposal_respects_phase`) enforce the two-sided cutoff,
and a state invariant (`inv_anarchy_content_sealed`) enforces atomicity (unowned
discretionary content never exists unsealed). Four new mutants prove the checks have
teeth: re-enabling empty inside the phase (**horn 2**), allowing proposals past the cutoff
(r10-1's determinacy break), making the proposal non-atomic (**horn 1**), and dropping the
owned-successor truncation (r10-3) are each caught by the invariant written for them. All
prior safety invariants, both liveness passes (standard and outage-robust
deadlock-freedom), and all prior mutants continue to hold/fire. A `W_ANARCHY = 0` run
reproduces the pre-v11 state space bit-for-bit — the same determinism check the v8 revert
used, run in the opposite direction.

## 6. Residuals carried forward

- **§13-T.14** — `W_a` calibration (against measured proving latency and the `K` band);
  quantification of the FCFS censor-race economics (r10-4) with the §11.5 corridor data;
  the optional **multi-epoch batch proposal** (one proof sealing `j` consecutive unowned
  epochs, restoring full-cadence anarchy throughput when `j·E ≥ P`) — an extension, not
  needed for soundness.
- **§13-S.18 [Phase B]** — the anarchy-proposal artifact spec: transaction format,
  blob-hash binding, proof public inputs (snapshot commitment, anchor, payee, parent
  lineage), bundled ancestor-resolution semantics, and the assignment-side cutoff guard in
  the transition machinery.
- **Accepted properties, stated:** FCFS selection concentrates to fast provers/builders
  (same texture as §11.3's recovery-race, no censorship lever — I6/G5); anarchy content
  timestamps lag wall clock by the constant band; discretionary anarchy throughput is
  best-effort, never guaranteed (§10.4 guarantee 3 stays conditional).
