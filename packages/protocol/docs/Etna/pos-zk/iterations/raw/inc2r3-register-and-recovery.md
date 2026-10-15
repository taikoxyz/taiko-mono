# Increment 2 round 3 — register and recovery: confirmation

**Angle.** The register and the recovery claim after the round-2 repairs: (1) `spec/09`'s
`HEARTBEAT_WINDOW` row versus MEM-13(3)'s launch transition — same formula, same two epochs, same "MUST
NOT be appended before" rule, unit and blocks-to-blocks relation intact, unmeasured tag intact, no new
row; (2) `spec/08`'s MIG-03 announcement — launch duty, pre-T3 acceptance position and the disclosed
one-window delay in the operator's voice; (3) the recovery sentence (an append clears an entry-absence
boundary halt but cannot make a committed roster reachable); (4) no disclosure promising more than the
rules deliver.

**Snapshot.** `bb06395d3`; working tree at the same commit. Read first: the two `inc2r2-*` reports, the
current `spec/03` MEM-13, `spec/02` CONS-13(5)/CONS-14, `spec/09`, `spec/08` MIG-03, `spec/10`, the
index, the course, and the delta.

**Result: no findings. 0 Critical, 0 High, 0 Medium, 0 Low. I found nothing.** Both round-2 Mediums
(INC2R2-UD-01/-02) are closed by the current text, the repairs are real and consistent with each other,
and I could not construct a new defect in the launch transition, the register row, the announcement or
the recovery claim. Three items I examined and dismissed are recorded below with reasons.

---

## Verified: the register row is MEM-13(3), name for name

`spec/09-parameters.html` line 213 (`HEARTBEAT_WINDOW`, unit **L1 blocks**, tag **unmeasured**) now
carries the launch transition verbatim:

- "for exactly the epochs whose clamp resolves to `e_0` — `e_0 + 1` and `e_0 + 2`, the first two filtered
  versions — the ordinary definition is shifted forward by one full heartbeat window, exactly as
  `MEM-13 (3)` defines it: `w*(e) = floor(L1_first(e_0) / HEARTBEAT_WINDOW) + 1` and
  `I*(e) = (floor(L1_first(e_0) / HEARTBEAT_WINDOW) + 1) · HEARTBEAT_WINDOW`, with `L1_first(e_0) = L1_0`,
  and the entries for those two epochs MUST NOT be appended before that shifted instant; from `e_0 + 3`
  the clamp advances and the unshifted definition resumes."

MEM-13(3) states the same two formulas, the same two epochs, the same prohibition, the same resumption at
`e_0 + 3`, and adds the coverage argument (an attestation in the window containing `L1_0` records
`I*(e) − HEARTBEAT_WINDOW` for the shifted epochs; the unshifted instant for `e_0 + 3` is
`floor((L1_0 + EPOCH_LEN_L1)/W)·W ≤ S` because `EPOCH_LEN_L1 < W`, so the launch record covers it) and the
normative enforcement in MEM-09(1) ("a call that would append before the shifted instant MUST revert
rather than append", `spec/03` line 475). The launch shift is *derived* from `L1_0`, `e_0` and
`EPOCH_LEN_L1` — rows that already exist (`L1_0` = "L1 block number", `EPOCH_LEN_L1` = "L1 blocks",
lines 105–106) — so **no new row or parameter was invented**; the round-3 diff touches the
`HEARTBEAT_WINDOW` row only (one sentence) inside `spec/09`. The row's earlier content is intact: the
half-open interval `[w·W, (w+1)·W)`, `hbWindowOf(n) = floor(n/W)`, the blocks-to-blocks relation
`HEARTBEAT_WINDOW ≥ EPOCH_LEN_L1 + ceil(T_L1_include(p)/L1_BLOCK_INTERVAL) + margin`, the change semantics
with "cannot permanently empty the roster", and the `unmeasured` tag.

The round-2 guard is likewise in place where the roster is defined: MEM-09(1)'s filter is "the active
bonded set filtered by the predicate `lastHeartbeatSeq(v) > 0` and
`lastHeartbeatAt(v) ≥ I*(e) − HEARTBEAT_WINDOW` (an entry with no accepted heartbeat is ineligible
regardless of the arithmetic …)" (`spec/03` line 475), matching MEM-13(3) and the D-17 and
`DEFERRED.md` addenda.

## Verified: the MIG-03 announcement is in the operator's voice and complete

`spec/08-migration-upgrades.html` line 504 now states, in the voice of the duty the announcement must
carry:

- **the derived instant and the cadence**: "keep signing one heartbeat per `HEARTBEAT_WINDOW` L1 blocks,
  because an entry whose last accepted heartbeat is more than one window behind the instant a set version
  is evaluated at is not selected into that version. The instant is derived from the L1 block at which the
  epoch's coverable start falls … not from the version's commit point, so pace attestations to the cadence,
  not to a commit point: when inside its window a heartbeat is sent cannot change who is selected";
- **the launch duty**: "Every entry that is to be selectable for the first filtered set version MUST have
  an accepted heartbeat naming the heartbeat window containing `L1_0` before the first `commitSet()` that
  appends a filtered version, because the launch transition opens the appends for `e_0 + 1` and `e_0 + 2`
  only after that window closes; … an entry with no accepted heartbeat in that window is not selected for
  the first two post-activation versions (`CONS-14 (1)`)";
- **the pre-T3 acceptance position**: "The heartbeat acceptance path is not disabled before T3: the
  activation entry is exempt from the eligibility predicate as a deliberate policy choice, not because its
  records are unset (`CONS-14 (1)`), so pre-activation acceptance is neither required nor relied upon";
- **the disclosed one-window delay**, at line 141: "the launch transition holds the appends for `e_0 + 1`
  and `e_0 + 2` until the shifted instant of `MEM-13 (3)`, so the first two filtered appends are delayed
  by up to one `HEARTBEAT_WINDOW`; if the L2 reaches the first boundary before the entry for epoch 1 is
  appended and Ethereum-final, the missing-entry halt of `CONS-13 (5)` applies and clears on the
  permissionless lowest-missing append (`MEM-09 (1)`)".

## Verified: the recovery sentence is exact

The two halves are stated, in the rules that own them:

- **the append clears an entry-absence halt**: `spec/02` CONS-13(5) — "a missing-entry boundary halt is
  not permanent and needs no protocol update: the absent entry stays appendable by any caller under
  `MEM-09 (1)`'s permissionless lowest-missing rule, and the halt ends when that append is made, the entry
  is Ethereum-final and the restart rules of `HALT-02` let the chain resume — conditional on an active
  entry being eligible (`MEM-13 (3)`) and on no block of the affected epoch having been produced"; the
  same in `spec/03` lines 481/487, `spec/10` line 323 and the course;
- **a committed roster is not made reachable**: MEM-13(3) — "a signature for a later window MUST NOT
  retroactively make an entry eligible for a version whose `R_k` is already committed, and no rule may
  re-open, amend or re-derive a committed `R_k`"; MEM-13(5) — "A version already committed is unchanged,
  so a chain stalled inside an epoch whose committed roster cannot form quorum does not resume by this
  rule alone: it resumes when that cohort returns to vote and re-attests, or through a later protocol
  update"; `spec/08` line 809 ("heartbeat eligibility is live but restores no committed roster"),
  `spec/06` line 475, `spec/10` lines 321–322, 349, the index and `learn/08` lines 133–140, 460–461;
- **the reason is stated without conflating the instant with the records**: MEM-09(1) evaluates the
  predicate "once inside this call, from L1 state at `N(k)`", against the fixed `I*(e)` — so a late append
  "can only add entries that have since attested and can never remove an entry that was eligible"
  (MEM-13(3)) — while the *instant* is "single and well-defined for every epoch, and no account chooses
  it". No page says the records are read as of `I*(e)`; every page says the predicate is read at the
  fixed instant, which is the correct form.

## Verified: no disclosure promises more than the rules deliver

- The launch claims are conditional: coverage is asserted only for "an entry that attests at least once
  in the window containing `L1_0`"; the launch duty is a duty on the entry's owner; and the delay is
  bounded and its fallback (the `CONS-13 (5)` halt, cleared by the permissionless append) is named
  (`spec/08` line 141).
- The guard closes the low-height admission explicitly ("a never-attested entry cannot enter a roster on a
  low-height L1, exactly as (2b) requires") rather than leaving the arithmetic to admit `0 ≥ I*(e) − W`.
- The change-timing Open is sized as a contiguous run with the pending-change ordering influence named,
  and stays an Open with its falsifier and closing options (`spec/03` line 545, `spec/10` line 354, the
  index line 428, both addenda) — not a guarantee.
- The register's earlier "cannot empty the roster" is now qualified "cannot **permanently** empty the
  roster" with the reason stated (round-2 wording note carried).

## Considered and dismissed (not findings)

1. **The index's MEM-13 summary and parameter map do not restate the two-epoch launch shift.** They give
   the steady-state rule and cite MEM-13(3); the shift is a two-epoch transient whose duty is stated in
   `spec/08`'s announcement (the artifact an operator reads at migration), in CONS-14(1)/(3) and in
   MEM-13(3). The summary is not wrong for the steady state and does not overstate; a reader who needs
   launch behavior is pointed at the owning rule. Worth one clause if the index is ever revised, but not a
   defect.
2. **MEM-09(1)'s generic append deadline versus the launch bar.** The deadline sentence ("no later than one
   `EPOCH_LEN_L1` after it becomes coverable") is stated without a launch carve-out, while the launch gate
   can hold the `e_0 + 1` append until `S`, which can fall after that deadline. CONS-14(3) governs the
   launch explicitly ("MUST be committed as early as the launch-transition opening of MEM-13(3) permits …
   the launch-transition shift can open those appends after the L1-side start of an epoch they govern, and
   a missing entry at the first boundary then clears under the permissionless lowest-missing append"), and
   no conforming implementation has a second behavior available — the early append MUST revert. A wording
   tension with a stated consequence, not a rule defect.
3. **The course does not carry the launch shift.** `learn/*` contains no `launch`, `L1_0` or
   `shifted` mention; its description is the steady-state rule, which is *stricter* than the launch rule
   for the two clamped epochs (it asks for an attestation per window, which satisfies both). An operator
   following the course is not misled into an ineligible state; the migration announcement carries the
   launch duty. Noted only.

## Ship decision

**No Critical, no High — and no finding at any severity: the increment is clean and this is the second
consecutive clean round.** The launch transition is stated identically in MEM-13(3), MEM-09(1),
CONS-14(1)/(3), the `HEARTBEAT_WINDOW` register row and the MIG-03 announcement; the register invented no
row and kept its unit, relation and `unmeasured` tag; the recovery claim is exact in both halves; and no
disclosure overstates the mechanism. **Safe to ship.**
