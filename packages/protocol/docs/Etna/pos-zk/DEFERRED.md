# Deferred work register

Mechanisms **excluded from v1** by decision D-16, with what each was for, why it was deferred, what
blocked it, and what would revive it — and, where an increment has since revived one, the revival record. Nothing here is abandoned: each entry is a scoped piece of work
with its findings preserved in `iterations/raw/`. **Three deferred items remain**, counted by mechanism
with its own rule id: the heartbeat rotation (`CONS-16`, §2), the governance stall resolution (§3) and
aggregation (§4). Heartbeat eligibility was revived in part by increment 02 — the eligibility rule is
live, the rotation that consumes it is not — and narrow forced inclusion was revived by increment 04
(§1); both leave the deferred set, and the rotation inside §2 stays named on its own.

## 1. Narrow forced inclusion (D-12) — REVIVED (increment 04, in review)

*Revived by increment 04: the FI-10–FI-14 family is re-derived as a live rule family against the converged
v1 rather than restored from its tombstone, and the general inclusion list stays absent. The increment is
in review and ships only after two consecutive clean review rounds; this section is kept as the revival
record — what was revived, how each blocker recorded here was disposed of, what remains deferred inside the
mechanism, and what a future increment would need.*

**For:** bounding the time a proposer can keep a *published* transaction out of the chain, without a
general inclusion list. **Why it was deferred:** it was non-functional as written — the settled-frontier
bound was waived by an exception with no referent, the per-block clause and the per-batch cap used
`FI_MAX_PER_BATCH` in two different units, and its void predicate could be steered by the producing
environment while its expiry discharge had no proof-side ground.

**What was revived.** A publication record *is* the forced-data record: after its due point
(`l1BlockNumber + FI_INCLUSION_DELAY ≤ A`), every batch that lands must advance the settlement frontier
past the capped FIFO prefix of the due set, and the obligation is enforced **in the proof** (PRF-04(vi)),
never as an admission gate on `land` — L1-04's no-gate property survives. A position is resolved by exactly
one of three modes, under the per-transaction walk of FI-13(1) and its stated precedence:
**executed** — the record is live at `A`, not over-bound and containing no transaction that can never be
executed from the record's own bytes, and walking its transactions in the record's own order, each
transaction either executes or is **discharged** at its turn, where its turn's pre-state is computed in the
batch's own execution, after the record's own preceding transactions and after every transaction the batch
executes before that point, and the discharge holds only if the transaction's declared nonce does not equal
the sender's nonce at that pre-state, or the sender's balance at that pre-state is below
`gasLimit × maxFeePerGas + value` — with at least one transaction executing, so a mixed record is resolved
with its executed transactions recorded as executed and its discharged ones as discharged; **void** — the
record is live at `A` and over a registered bound (this limb is tested before executed, so a live
over-bound record is void even if one of its transactions appears in the executed payload), or live at `A`
and containing a transaction that can never be executed from the record's own bytes (for example a chain id
that does not match FI-13(2)(iii)), so it can neither execute nor be discharged, or live at `A` with every
one of its transactions discharged, so none of them executes; or **dead** (the record's own stored
`l1BlockNumber` plus the registered `T_PROVE_DEADLINE` at or below the anchored view) — tested first and
unconditionally, so a record that is dead at `A` is dead whatever its size, contents or discharge state.
*(FI-13(1)–(5): the ground is per transaction with that batch-wide turn pre-state, applied in the rule's
dead-first and void-limb-first precedence so the three modes partition every position; the record-level form
"no transaction forceable at any pre-state of the batch" is superseded; a record whose remaining
transactions cannot execute is fully discharged rather than left unresolved, so every position resolves in a
bounded number of batches.)*
The advance is unconditional and monotone:
`c' ≥ min(d(A), c + FI_MAX_PER_BATCH)`, `c' ≤ nextSeq(A)`, `c' ≥ c`, and every position in `[c, c')`
must be resolved. `CONS-01(v)` is an **order and non-omission** duty only, with no per-block count and no
per-block gas quota. The register appends, and pruning is deletion only, behind the settlement frontier
through a stored prune cursor; it returns no frontier and is never read by `land`.

**Disposition of the four blockers recorded here.**
1. *The frontier-advance rule.* Closed: FI-11(3)(a) states the lower bound **unconditionally**; the
   preserved "unless the window is shorter" exception is deleted, not narrowed, and the two-sided bound
   plus the `[c, c')` resolution walk leaves no reading under which `c' = c` passes. The drain relation
   `1 ≤ FI_MIN_DRAIN ≤ FI_MAX_PER_BATCH` independently forbids `R = 0`.
2. *The unit mismatch.* Closed: one unit of account — register positions per batch — used by the
   obligation, the cap, the capacity relation and the frontier bound; the per-block requirement keeps only
   FIFO order and non-omission.
3. *The steerable void predicate.* Closed: the includability test loses the base fee and the block gas
   limit entirely; forceability is a function of the record's immutable bytes, the registered constants and
   two facts a block producer cannot move — the sender's nonce and balance, checked against the
   transaction's own declared maximum charge. *(FI-13(2)(v): the forceability term is the sender's balance,
   not a "free balance".)*
4. *Expiry with no proof-side ground, and the prune that contradicted it.* Closed: dead-at-`A` is a third
   resolution mode computed from the record's own stored `l1BlockNumber` and `T_PROVE_DEADLINE`, needing
   no bytes, blobs, execution or L1 call; the mutable status flag is not restored; and
   `pruneExpiredPublications(uint32) returns (uint64)` is replaced by a deletion-only
   `prunePublications(uint32)` that must stay strictly behind the settlement frontier.

**What remains deferred inside the mechanism.** The **per-publisher live-record bound** — the candidate
remedy for F-FI-2 — is **not adopted**: it is a condition on `publish()`, which D-12 does not authorise
and which would change DA-07(1)'s "any account MUST be able to publish". F-FI-2 therefore stays an
**open, unfixed falsifier**, and the guarantee is stated with its condition wherever it is summarised: it
holds only while the arrival rate of livable records stays within the drain the obligation can force. The
disclosed residue travels with the revived rules rather than as deferred work: **F-FI-1** (the capacity
relation constrains a value, and no registered rule maintains the L2 gas-limit schedule premise),
**F-FI-3** (a transaction discharged at its turn may become executable later only through the sender's own
further signed transactions; re-publication is the remedy), **F-FI-4** (a record
can age out to dead rather than be included), **F-FI-5** (the guarantee is conditional on a non-censoring
L1 and on at least one honest or rational producer) and **F-FI-6** (a certified range deliberately delayed
past the anchor-age envelope is permanently unacceptable; the registered relations close the in-envelope
case, the residual stays disclosed). *(FI-13(3)/(5): F-FI-3 is stated per transaction, and the record-level
"a voided record may become forceable later" form is superseded.)*

**What a future increment would need.** Two things, neither of which this increment may do:
(i) a decision on the per-publisher live-record bound, or another publish-time bound, as an explicit change
to DA-07(1), with its economic bypass — a censor with many funded addresses — reviewed as the residual it
is; and (ii) Phase B's measurements, because every `FI_*` value, the capacity relation and the schedule
premise remain unmeasured placeholders. The measurement line is publication gas, `forcedBoundary`
recomputation gas, the per-batch capacity under a target batch size, the register's bounded-binary-search
cost, and the L2 gas-limit schedule check. F-FI-1 would close only with a registered rule that constrains
the L2 gas-limit schedule constructively, or with a consensus-enforced per-block floor on header gas
limits; neither exists.

**Preserved:** `FI-10`-`FI-14` text in git history at `7917ba264`; the findings disposed of above
(`R6-D12-01`, `R6-D12-02`, `R6-D12-03`, `R6-D12-04`, `R6-D12-05`, `R6-DPE-01` and the rounds
5–6 findings named in `increments/04-forced-inclusion-design.md`); falsifiers F-FI-1–F-FI-6. The design
delta and its owner decisions are the increment's authority.

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

**Further recorded correction (increment 02, third review round, R3-LT-01) — the launch transition shifts the instant two windows, and the guard is load-bearing.** The addendum above states the steady-state instant `I*(e) = floor(L1_first(C(e)) / HEARTBEAT_WINDOW) · HEARTBEAT_WINDOW` and does not carry the launch transition. For exactly the two epochs whose clamp resolves to `e_0` — `e = e_0 + 1` and `e = e_0 + 2`, the first two filtered versions — the instant is shifted forward by two full heartbeat windows: `w*(e) = floor(L1_0 / HEARTBEAT_WINDOW) + 2` and `I*(e) = (floor(L1_0 / HEARTBEAT_WINDOW) + 2) · HEARTBEAT_WINDOW`. The second window is what the guarantee needs: the predicate's one-window slack admits the counting window `[(floor(L1_0 / HEARTBEAT_WINDOW) + 1) · HEARTBEAT_WINDOW, (floor(L1_0 / HEARTBEAT_WINDOW) + 2) · HEARTBEAT_WINDOW)`, which starts at or after `L1_0` and keeps the full length `HEARTBEAT_WINDOW` whichever block of its window `L1_0` falls in, so a prepared entry cannot win a one-block race and fix the first two filtered rosters; the entries for those two epochs MUST NOT be appended before that counting window closes — the gate applies to every appender alike and names no entry or caller — and from `e_0 + 3` the unshifted definition resumes, a lower later threshold admitting, never excluding. The added cost is recorded too: the first two filtered appends are gated by up to two heartbeat windows rather than one, and the missing-entry halt of `CONS-13(5)` gains up to one full window, so its total is up to two windows in L1 blocks and is unbounded in wall clock, because the register bounds `HEARTBEAT_WINDOW` only from below (`PARAM-01`). The predicate's sequence conjunct is not decoration at low heights: `lastHeartbeatSeq(v) > 0` is required alongside `lastHeartbeatAt(v) ≥ I*(e) − HEARTBEAT_WINDOW`, and an entry with no accepted heartbeat is ineligible regardless of the arithmetic, because its record `0` would otherwise satisfy an unguarded threshold on a low-height L1 (`MEM-13(3)`; R2-DI-01). *(R3-LT-01: this further correction records the two-window shift, the full counting window after `L1_0`, the gate, the guard and the added delay and halt window; the paragraphs above are preserved and not rewritten.)* The relative statement above is also an inevitability, and its size is absolute: the gate opens at `(floor(L1_0 / HEARTBEAT_WINDOW) + 2) · HEARTBEAT_WINDOW` while the first L1-side epoch boundary is `L1_0 + EPOCH_LEN_L1`, and with `EPOCH_LEN_L1 < HEARTBEAT_WINDOW` their difference `2 · HEARTBEAT_WINDOW − (L1_0 mod HEARTBEAT_WINDOW) − EPOCH_LEN_L1` is at least `HEARTBEAT_WINDOW + 1 − EPOCH_LEN_L1 > 0`, so the append for `e_0 + 1` can never be made before that epoch is entered — the halt is guaranteed whenever the L2 keeps pace — and it runs between `HEARTBEAT_WINDOW − EPOCH_LEN_L1 + 1` and `2 · HEARTBEAT_WINDOW − EPOCH_LEN_L1` blocks before the append, plus Ethereum finality. The gate can also pass the second boundary `L1_0 + 2 · EPOCH_LEN_L1` whenever `2 · (HEARTBEAT_WINDOW − EPOCH_LEN_L1) > (L1_0 mod HEARTBEAT_WINDOW)`, and the finality lag can make the entry for `e_0 + 2` late in most alignments, so the launch may need two recovery cycles rather than one. *(R4-LT-01: appended to this record — the halt is guaranteed, and its block range and possible second cycle are stated beside the kept relative "one full window" bound.)*

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

The deferred set is three: the heartbeat rotation (`CONS-16`, §2), the governance stall resolution (§3)
and aggregation (§4). The items below outlive all three.

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
  deliberately does not teach the deferred rotation. Increment 04 re-synced it for the revived narrow forced
  inclusion — lesson 9's censorship half, the new lesson 11, lessons 1, 2, 5, 6 and 8, the glossary, the
  index and the limitations page — and deliberately does not teach the general inclusion list.
