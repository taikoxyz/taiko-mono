# Deferred work register

Mechanisms **excluded from v1** by decision D-16, with what each was for, why it was deferred, what
blocked it, and what would revive it. Nothing here is abandoned: each entry is a scoped piece of work
with its findings preserved in `iterations/raw/`. **Three mechanisms remain deferred**; heartbeat
eligibility was revived in part by increment 02 — the eligibility rule is live, the rotation that
consumes it is not (§2).

## 1. Narrow forced inclusion (D-12)

**For:** bounding the time a proposer can keep a published transaction out of the chain.
**Why deferred:** two independent round-6 reviewers found it **non-functional as written** - the
settled-frontier bound is waived by an exception with no referent, so under the only non-vacuous
reading the frontier never advances and the obligation is dead for the life of the deployment. A
separate finding shows `CONS-01(v)` is per-block at `FI_MAX_PER_BATCH` while the cap is per-batch,
which permits a configuration where no block can carry the prefix.
**Blocked by:** the frontier-advance rule, the unit mismatch, a steerable void predicate, and an
expiry discharge with no proof-side ground (`R6-D12-01`, carried unrepaired from round 5).
**Revive criteria:** one unit of account for the obligation; a mandatory frontier advance with no
waiver; a void predicate computed from the record's immutable bytes and registered constants only;
expiry as an objective proof-side discharge ground.
**Preserved:** `FI-10`-`FI-14` text in git history at `7917ba264` and the findings in
`iterations/raw/round5t-*.md` and `round6-d12-d14-repairs.md`.

## 2. Heartbeat eligibility (D-14) — REVIVED IN PART (increment 02)

*Revived by increment 02: L1 heartbeat eligibility is a live rule; the rotation that consumes it stays
deferred and tombstoned.*

**What was revived.** `MEM-13` is live as the rule it was re-derived to be: a set version's roster is
the active entries that posted a heartbeat inside the heartbeat window containing that version's commit
point, and an entry that did not is excluded from the root, the total and the count — never decayed,
slashed or removed — and is restored by re-attesting at a later commit point. The heartbeat is an ECDSA
signature checked on L1 with `ecrecover`; anyone may carry it and a relayer may batch. The payload
binds a versioned domain tag, the chain id, the entry, a window index, a strictly increasing sequence
number, and a recent L1 block (its number and its hash); acceptance requires the named window to be
current and unrecorded and the anchor block to be at most `HEARTBEAT_ANCHOR_AGE` L1 blocks old. The
domain tag is `"ETNA_HEARTBEAT_V2"`, bumped because the preimage gains the anchor pair. No rule
removes weight (D-14's property); the boundary, the exit, D-8/D-9 and D-11 are not reopened.

**Reviewed addendum (increment 2 second review, INC2R2-UD-02) — the evaluation instant is derived, and the window is an L1 block-height grid.** The paragraph above is preserved as the historical record; its wording "the heartbeat window containing that version's commit point" and "restored by re-attesting at a later commit point" is **withdrawn** (the pre-repair `t_root(e)` predicate). The shipped rule is `MEM-13(3)`: entry `v` is eligible for the version committed for epoch `e` if and only if `lastHeartbeatSeq(v) > 0` **and** `lastHeartbeatAt(v) ≥ I*(e) − HEARTBEAT_WINDOW` — an entry with no accepted heartbeat is ineligible regardless of the arithmetic, because `lastHeartbeatAt(v) = 0` would satisfy the inequality whenever `I*(e) ≤ HEARTBEAT_WINDOW` — where with `C(e) = max(e − LOOKAHEAD_EPOCHS, e_0)` and `L1_first(C(e)) = L1_0 + (C(e) − e_0) · EPOCH_LEN_L1`, the evaluation instant is `I*(e) = floor(L1_first(C(e)) / HEARTBEAT_WINDOW) · HEARTBEAT_WINDOW`, computed inside `commitSet()` from the activation record — so the commit block, its timestamp and its position select nothing. The grid is an interval of **L1 block numbers**: window `w` is `[w · HEARTBEAT_WINDOW, (w+1) · HEARTBEAT_WINDOW)`, acceptance requires the named window to be the including block's window, and `lastHeartbeatAt(v)` is that window's start block, never a carrier timestamp. Re-attestation restores eligibility for every version whose evaluation window is the window the new heartbeat names or the one immediately after it — including an append that is still pending, because `I*(e)` does not move (`MEM-13(4)`). This addendum also records the two limits §2 did not carry: the **change-timing Open of `MEM-13(6)`** — a change to `HEARTBEAT_WINDOW` landing after the first boundary of the new grid strictly following an active entry's record `A` can exclude that entry from a **contiguous run** of versions, not one version: every version evaluated before the entry re-attests whose evaluation instant falls in `(A + W', A + W_old]` (about `(W_old − W') / EPOCH_LEN_L1` of them when a backlog is drained in a single block) excludes it, and the Open names the sole remaining caller influence on `I*(e)`: while a change is pending, an append caller's ordering relative to it selects whether the version is evaluated under the old or the new value (bounded to the pending change and of F8's ordering class); with its falsifier and closing options stated there and carried in `spec/10-assurance.html` — and the **wall-clock-variability cost** — the duty is one attestation per `HEARTBEAT_WINDOW` L1 blocks, not per fixed duration, so the cadence expressed in seconds is variable and `unmeasured` (`MEM-13(7)(g)`). F7, F8 and F9 above are unaffected. *(INC2R2-UD-02: the withdrawn commit-point wording is corrected by reviewed addendum, and the new Open and the height-grid cost are carried here. R2-DI-01/R2-DI-02: the predicate above carries the non-zero-sequence guard, and the change-timing residual is the contiguous run with the pending-change ordering influence named.)*

**Further recorded correction (increment 02, third review round, R3-LT-01) — the launch transition shifts the instant two windows, and the guard is load-bearing.** The addendum above states the steady-state instant `I*(e) = floor(L1_first(C(e)) / HEARTBEAT_WINDOW) · HEARTBEAT_WINDOW` and does not carry the launch transition. For exactly the two epochs whose clamp resolves to `e_0` — `e = e_0 + 1` and `e = e_0 + 2`, the first two filtered versions — the instant is shifted forward by two full heartbeat windows: `w*(e) = floor(L1_0 / HEARTBEAT_WINDOW) + 2` and `I*(e) = (floor(L1_0 / HEARTBEAT_WINDOW) + 2) · HEARTBEAT_WINDOW`. The second window is what the guarantee needs: the predicate's one-window slack admits the counting window `[(floor(L1_0 / HEARTBEAT_WINDOW) + 1) · HEARTBEAT_WINDOW, (floor(L1_0 / HEARTBEAT_WINDOW) + 2) · HEARTBEAT_WINDOW)`, which starts at or after `L1_0` and keeps the full length `HEARTBEAT_WINDOW` whichever block of its window `L1_0` falls in, so a prepared entry cannot win a one-block race and fix the first two filtered rosters; the entries for those two epochs MUST NOT be appended before that counting window closes — the gate applies to every appender alike and names no entry or caller — and from `e_0 + 3` the unshifted definition resumes, a lower later threshold admitting, never excluding. The added cost is recorded too: the first two filtered appends are gated by up to two heartbeat windows rather than one, and the missing-entry halt of `CONS-13(5)` gains up to one full window, so its total is up to two windows in L1 blocks and is unbounded in wall clock, because the register bounds `HEARTBEAT_WINDOW` only from below (`PARAM-01`). The predicate's sequence conjunct is not decoration at low heights: `lastHeartbeatSeq(v) > 0` is required alongside `lastHeartbeatAt(v) ≥ I*(e) − HEARTBEAT_WINDOW`, and an entry with no accepted heartbeat is ineligible regardless of the arithmetic, because its record `0` would otherwise satisfy an unguarded threshold on a low-height L1 (`MEM-13(3)`; R2-DI-01). *(R3-LT-01: this further correction records the two-window shift, the full counting window after `L1_0`, the gate, the guard and the added delay and halt window; the paragraphs above are preserved and not rewritten.)*

**What increment 02 changed, against the two blockers recorded here.** (a) *The per-window payload
needed a fresh review.* The payload is restated as the normative surface, every recorded replay vector
is mapped to the check that rejects it, and the increment ships only after its own review round is
clean — the fresh review is that round's, not this record's. (b) *The pre-signing residual was
disclosed but open.* It is now bounded, not closed, by the `HEARTBEAT_ANCHOR_AGE` freshness term, and
the residual is the named falsifier **F9**. **F8** is carried and sharpened: an adversary able to
censor, delay past the window, or price out honest L1 heartbeats excludes honest validators from future
set versions at no slashable cost and can raise its own share of those versions; it remains Open. The
declared non-fix is stated wherever the mechanism is summarised: a declaration of presence is not proof
of participation, so a cohort that keeps heartbeating keeps its weight.

**What remains deferred in it: the rotation.** `CONS-16` stays deferred and tombstoned. Its
precondition is sharpened rather than resolved: the closing height `h_close(e)` is an L2 fact, L1
state holds neither the L2 tip nor the highest produced height, and the completion record's value would
be an unverifiable claim by the completer — a false one re-judges a produced height, makes its
certificate unverifiable against the boundary record and strands value above the accepted checkpoint.
The preserved rule's falsifier **F7** is carried and sharpened accordingly. What would close the gate:
an L1-verifiable referent for `h_close` — a stored last-finalized marker written by a rule L1 can
verify (noted as not constructible in v1, because a proof can attest that a height *is* finalized but
cannot prove that no higher height is), or a composite transition carrying the head batch with the same
"highest" absence problem, or the governed stall resolution (D-15), whose revival would reopen a v1
decision.

**What a future revival would need.** Close the `h_close` gate as above, then the rotation's own
review round; its conditional budget is the boundary-record amendment storage and the pending-rotation
record, and its completion rule would add the `REC-01(a)` qualification for heights no validator
produced. Until then `CONS-16` MUST NOT be implemented, and v1 keeps the disclosed consequence that a
quorum-loss halt inside an epoch is cleared only by the cohort returning or by a future protocol update.

**Preserved:** `MEM-13` and `CONS-16` text at `7917ba264`; findings `R5T-C-2`, `R6-D12-06` and
`R5T-H-1`; falsifiers F7, F8, F9.

## 3. Governance stall resolution (D-15)

**For:** clearing a settlement stall without a permissionless recovery.
**Why deferred:** it did not survive its first review. A Critical showed that nothing consumes the
queued entry on execution, so any account can re-execute it and churn the generation - a
permissionless, gas-priced settlement-denial loop (`G-1`). Two reviewers independently showed the
timelock cannot be the exit window the rule claims (`G-2`, and round-5 `F1`/`F2`), and the
generation binding makes the first epoch-opening batch after a resolution unprovable (`G-3`).
**Blocked by:** an entry state machine with an `executed` state; a resolved exit contradiction; a
generation rule for the anchor certificate.
**Revive criteria:** fix the three Criticals and re-review the whole path.
**Preserved:** `GOV-04` text at `7917ba264`; `round6-gov-generations.md`.

## 4. Aggregation (D-13)

**For:** one proof object per batch whose soundness is n-of-m over independent backends.
**Why deferred:** it was never reviewed on its own terms, and it moves the trust to an aggregation
program while adding a proving cost that S1 has not measured.
**Revive criteria:** S1's aggregation-cost line, then a review of the family-bitmap enforcement.
**Preserved:** `PRF-15`, `L1-14`, `L1-13` text at `7917ba264`; `round6-data-proof-economics.md`.

## Cross-cutting items that outlive all three

- **The round-5/6 findings not specific to a deferred mechanism** are listed in
  `iterations/raw/round5t-*.md` and `round6-*.md`; the round-8 pass is in
  `iterations/raw/round8-*.md`. The exit contradiction is **repaired** (`MEM-15`(2a)/(2b) +
  `L1-13`(5)/`L1-11`): the exit's funding and witness dependencies are stated with their falsifier.
  What remains is disclosed rather than repaired — the unenforced proving split (`R8-EBA F3`, now a
  disclosed policy target of `ECON-02`(5)(e), not an on-chain bound) and the witness half of the exit
  assumption and falsifier (`R8-EBA F4`, a retention assumption no rule of the exit enforces). The
  un-relaxed-D5 wording had one surviving site, the blob-quantisation row of `09-parameters.html`,
  and it is re-based on D-11 in round 8; no other row argues from the superseded one-transaction
  form. *This closes review round 8 finding R8-EBA F7: the note lists the current residuals instead
  of calling repaired defects load-bearing.*
- **Phase B measurements** remain as planned: nothing in this register can be revived honestly
  without them. The revived heartbeat reinstates its own measurement line — per-signature `ecrecover`
  and anchor-check cost, batch fit in one L1 block, relayer cost, and the L1 inclusion quantile at that
  gas profile — and `HEARTBEAT_WINDOW`/`HEARTBEAT_ANCHOR_AGE` stay unmeasured until it runs.
- **The learning site** must be re-synced on **any** specification change, not only when a deferred
  mechanism returns, because it teaches the design as it stands; it was out of sync with the v1 exit
  until round 8 (`R8-EBA F2`). *This closes review round 8 finding R8-EBA F7: the sync trigger is any
  change to a live rule, not only the return of a deferred mechanism.* Increment 02 re-synced the course
  for the revived heartbeat (lessons 4, 7, 8, 10, the glossary, the index and the limitations page) and
  deliberately does not teach the deferred rotation.
