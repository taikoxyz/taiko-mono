# Increment 4 round 1 — register, numbers and disclosures

**Angle.** Attack the register, the numbers and the disclosures: every live FI name registered with a unit,
an owner rule and a tag; `FI_MAX_PER_BATCH` in exactly one unit everywhere; `FI_MIN_DRAIN`'s row matching
the ratified clause; the settlement pair's gap-slot cost and MIG-02's 15/28 arithmetic; no rule committing
`L2_BLOCK_GAS_LIMIT` through a config preimage and the capacity input bound by the anchored view; the
deferral set reading three with the right membership and forced inclusion no longer called deferred; the
ECON-04(6)/ECON-13(4) offence rows tombstoned with no invented penalty, bounty or fee; F-FI-1…F-FI-6 and
the not-a-latency-guarantee headline with its condition wherever the obligation is summarised; and no
disclosure promising more than the rules deliver.

**Snapshot.** `169480a56` (assigned). Mid-review another commit landed — `066ec452d` ("reconcile spec/05
PRF-02(5) with the anchored-view decision; no preimage change") — so every finding below was re-checked at
HEAD and is stated with the ref where it can be seen. The assigned snapshot's working tree was clean at
the start of the round.

**Result: 1 High, 1 Medium, 1 Low.** The register, the units, the settlement-slot arithmetic, the deferral
membership and the falsifier disclosures all hold; the three findings are residual text of the pre-increment
state in three artifacts the increment did not sweep. **The increment is not safe to ship as it stands**:
INC4R1-RD-01 is a live rule clause that asserts the opposite of an owner decision on a config-commitment
surface. All three repairs are text-only.

---

## INC4R1-RD-01 — High — `spec/04`'s FI-12(5)(ii) still claims PARAM-04 commits `L2_BLOCK_GAS_LIMIT` through the historical `paramVersion = 2` preimage, which the owner decision forbids and which the register, PRF-02(5) and the increment's own ratified correction all deny.

**File + rule id.** `spec/04-l1-integration.html`, **FI-12(5)(ii)** (line 738): "no rule registered here
constrains the L2 gas-limit schedule, and **while the per-epoch configuration of PARAM-04 commits
`L2_BLOCK_GAS_LIMIT` through the `paramVersion = 2` preimage of PRF-02(5)**, that commitment only records
the value." The owner decision (`increments/04-coordination.md` §3) is the opposite: "the capacity
relation reads `L2_BLOCK_GAS_LIMIT` from the anchored L1 view; it is **NOT** committed through the config
preimage, and FI-12(5)(ii)'s claim that `PARAM-04` commits it through the `paramVersion = 2` preimage of
`PRF-02(5)` is **WRONG and must not be implemented** … The rule must say so explicitly, and must say that
no preimage changes." The ratified correction in the delta (RC-4) repeats it, and the register row is
already correct: `spec/09` line 195 — "`L2_BLOCK_GAS_LIMIT` … read from the anchored L1 view the proof
already fixes: it is **NOT** committed through any config preimage and no preimage enumeration changes
(04-coordination.md §3)".

**Assumptions.** `PRF-02(5)` owns the config preimage enumeration; `PARAM-04` owns the per-epoch registry
and its field list; the increment may not change a live commitment to serve one arithmetic input; the
guest needs no committed copy of the value because `FI-12(1)` evaluates the capacity condition from the
batch's own headers and the anchored view.

**Attack trace (implementer-facing, no adversary).**
1. An implementer reads FI-12(5)(ii) as the normative clause and concludes that `L2_BLOCK_GAS_LIMIT` is
   already committed per epoch through V2, so the guest may read it from `configHash`; the rule nowhere
   says the value is bound by the anchored view (the sentence the owner required is absent).
2. Implementing that reading means either using V2 — which `spec/05` PRF-02(5) says "remains the preimage
   only for an epoch already entered under it and **MUST NOT be used for a new epoch**" — or adding the
   field to the live enumeration, i.e. changing the config preimage the owner refused to change. Both
   contradict fixed decisions; a third implementer following `spec/09` line 195 instead would produce an
   artifact that disagrees with `spec/04` on what the proof binds.

**Fault-model verdict.** Outside-model documentation contradiction: no rule mis-executes from it in a way
that loses funds or forks history, and no in-model action follows. It is nonetheless a contradiction
between normative text and a fixed owner decision about a live commitment surface.

**Attacker cost.** None (no adversary needed; the defect is a reader/implementer trap).

**Requirement affected.** 04-coordination §3 (owner decision); delta RC-4; `spec/09` line 195;
`spec/05` PRF-02(5) and `spec/04` L1-05 row 23 (the V3 closed list without `L2_BLOCK_GAS_LIMIT`);
FI-12(1)/(4)/(5)(ii); L1-04/L1-05's no-new-preimage property.

**Evidence.** `git show 169480a56:packages/protocol/docs/Etna/pos-zk/spec/04-l1-integration.html` FI-12(5)(ii);
the same text at HEAD (`066ec452d`) — the reconcile commit touched only the delta and `spec/05`;
`increments/04-coordination.md` lines 34–48 and 54–55; `increments/04-forced-inclusion-design.md` lines
366–381 (RC-4: "That is wrong and MUST NOT be implemented … the relation reads it from the anchored view,
so it is bound without any preimage change"); `spec/09-parameters.html` line 195;
`spec/05-proof-statement.html` PRF-02(5) (post-`066ec452d`: "no live config preimage commits it");
`spec/04` L1-05 row 23 (line 155: "The live preimage is PRF-02(5)'s closed version-3 enumeration … it
carries only parameters a live v1 rule reads: … `MAX_BATCH_BLOCKS`, `daModesEnabled`, `paramVersion` and
`D_MAX`" — no `L2_BLOCK_GAS_LIMIT`).

---

## INC4R1-RD-02 — Medium — the T3 initialisation MUST in `spec/08` still initialises `dueHead`, `dueTail` and `dueCount`, three fields the same page says are deleted.

**File + rule id.** `spec/08-migration-upgrades.html`, **MIG-02** (lines 417–422): "at T3 the contract
**MUST** initialise `nextSeq = 0` and **`dueHead = dueTail = dueCount = pruneCursor = 0`** with empty
`publications` and `publicationOrder` maps". Line 281 says the opposite: slot 277 is "the publication
clock, packed — `nextSeq` (uint64) + `pruneCursor` (uint64) = 16 of 32 bytes; **the former `dueHead`,
`dueTail` and `dueCount` fields are deleted**: the settlement frontier is the predecessor checkpoint's
recorded `settledCount` and the due frontier is recomputed, not stored (FI-10(5), FI-12(2))". The three
names appear nowhere else in the live specification, are not in the change list, and have no slot.

**Assumptions.** MIG-02's change table is the authoritative storage shape; a normative initialisation may
only name state the change list declares; the increment deletes the stored due frontier deliberately
(the due frontier is recomputed, so storing it would restore a second source of truth).

**Attack trace (implementer-facing).** An implementer following the MUST looks for three nonexistent
storage fields; the cheapest way to "comply" is to add them back — restoring the stored due-frontier state
the increment removed and invalidating the 15/28 slot arithmetic and the audit — while an implementer who
notices the contradiction cannot tell which clause is normative. The clause is also the audit's checklist
for T3 initialisation, so a stale entry there propagates into the deployment script.

**Fault-model verdict.** Not applicable (normative text naming deleted state; no in-model action).

**Attacker cost.** None.

**Requirement affected.** MIG-02's slot budget and storage-shape note (08:266–281, 300–320, 337–344,
379–387); D-18's "the deadline is derived, never stored" and the deleted due-frontier design; FI-10(5),
FI-12(2).

**Evidence.** `spec/08-migration-upgrades.html` line 419 vs line 281; the change-list rows 275–277
(lines 279–281) and the arithmetic at lines 300–320, 337–344, 379–387; `DECISIONS.md` D-18 lines
640–654; `spec/04` L1-07/Checkpoint (lines 243–249).

---

## INC4R1-RD-03 — Low — `CONVERGENCE.md`'s increment note still lists narrow forced inclusion among the three deferred mechanisms and says it has no implementation.

**File + rule id.** `CONVERGENCE.md` lines 43–58 (the increment note, which presents itself as the
current reading: "the four-mechanism sentence above is the converged-state record, **not the current
one**"). Line 46–47: "accordingly **three mechanisms remain deferred** — **narrow forced inclusion**, the
governance stall resolution and aggregation". Lines 56–58: "Increments 3, 4 and 5 remain queued: …
**forced inclusion has a design delta but no implementation**, and the governance stall resolution is
last." After increment 4 the membership is the heartbeat rotation (`CONS-16`), the governance stall
resolution and aggregation — `DEFERRED.md` lines 5–9, `spec/index.html` lines 42, 92, 118, 355–356, 367,
528, 584 and 593, and `spec/10-assurance.html` lines 31 and 418–419 all state it — and the FI-10–FI-14
implementation is live in review (`PLAN.md` lines 29–36, `spec/10` line 420).

**Assumptions.** `DEFERRED.md`, the index and `spec/10` are the authoritative deferral lists
(04-coordination §1 names exactly those three artifacts), so this is a legacy summary, not a competing
list. Mitigating context, recorded: increment 2's `CONVERGENCE.md` note was added when that increment
*shipped* (commit `5acd58edf`) and no increment-4 ship record exists yet, so the file may intentionally
lag; the two sentences are current-state claims that are presently false either way.

**Attack trace.** A reader checking "what is still not built" takes narrow forced inclusion as deferred
and unimplemented, and misses that FI-10–FI-14 are live normative rules under review — the same
four-mechanism reading increment 2 had to correct.

**Fault-model verdict.** Not applicable (historical-note staleness).

**Attacker cost.** None.

**Requirement affected.** 04-coordination §1 (the deferral count and membership); DEFERRED.md §1's revival
record; the index's and spec/10's deferral lists (all correct — only CONVERGENCE.md disagrees).

**Evidence.** `CONVERGENCE.md` lines 43–58; `DEFERRED.md` lines 5–9; `spec/index.html` lines 42, 355–356,
593; `spec/10-assurance.html` lines 31, 418–419; `PLAN.md` lines 29–36.

---

## Verified and holds

1. **Every live FI name is registered with unit, owner rule and tag; no row invented.**
   `spec/09` lines 189–199: `FI_MAX_PER_BATCH` (**positions per batch**; "never per block"), `FI_MIN_DRAIN`
   (positions per accepted batch), `FI_PREFIX_CAP` (withdrawn spelling, MUST NOT be used), `FI_ITEM_MAX_BYTES`
   (bytes), `FI_INCLUSION_DELAY` (L1 blocks), `FI_RECORD_GAS_MAX` (gas), `L2_BLOCK_GAS_LIMIT` (gas per L2
   block), the **FI capacity relation** (gas per batch), `FI_MAX_TX_PER_RECORD` (transactions per record),
   `FI_ANCHOR_MAX_AGE` (L1 blocks) and the **FI registered relations** row — each with its owner clause
   (FI-10…FI-13, PRF/DA ids) and tag (`unmeasured`, "unmeasured relation (Open: F-FI-1)", "revived by
   increment 04"). The change-order note (line 96) lists the revived set and keeps only the withdrawn
   `FI_PREFIX_CAP` spelling as a name tombstone; the measurement row (line 266) is reinstated with the
   F-FI-1 schedule check. `FI_MIN_DRAIN` is the one new name and it is registered (line 190). The index
   rows 455–460, 552–553 carry the same units, owners and tags.
2. **`FI_MAX_PER_BATCH` is in exactly one unit in all four places.** Obligation and frontier bound
   (FI-11(3)(a), positions), cap (FI-12(1), positions per batch), capacity relation (FI-12(4), gas per
   batch with the count in positions), the per-block clause (CONS-01(v), `spec/02` line 72/522/557: order
   and non-omission only, "no per-block count and no per-block gas quota"). The register (09:189), the
   index (457–458, 553), `spec/10` (420), the delta's unit table (lines 488–501) and D-18 (630–632) all
   state the single unit; no live page still reads the count per block.
3. **`FI_MIN_DRAIN`'s row matches the ratified clause.** 09:190 derives it from the clause ("the clause
   requires `R ≥ 1` whenever the outstanding obligation at A is non-empty, and because the capacity
   condition gives `cap(batch) = FI_MAX_PER_BATCH ≥ FI_MIN_DRAIN`, that is `R ≥ min(W, FI_MIN_DRAIN) ≥ 1`
   whenever a live record is outstanding"), gives `1 ≤ FI_MIN_DRAIN ≤ FI_MAX_PER_BATCH`, and never claims
   the floor drives the advance — it makes `R = 0` unreachable, which is what `R6-D12-04` asked. The rule
   (FI-11(2)(3)) and index 458 match, and FI-12(2) carries the ratified `R = min(d(A) − c, FI_MAX_PER_BATCH)`
   / `W` = live-in-window split with the RC-1 note; the delta carries the same correction.
4. **The settlement pair costs no extra gap slot and MIG-02's arithmetic balances.** The pair is carried
   in the L1-07 checkpoint record (`spec/04` lines 243–244, 249): `l1BlockNumber` + `lastAcceptedBatchTime`
   + `settledCount` + `anchoredL1Block` = four `uint64` = exactly the 32-byte word, so no extra slot and no
   per-height mapping; `forcedSettlementAt(uint64)` is a read-only view over the record (04:318–320). 08
   lines 266–281 (15 declaration slots: 258–269 = 12 + 275–277 = 3), 300–320 and 337–344 (43 sourced gap
   slots 258–300 − 15 = 28 free: 270–274 = 5 + 278–300 = 23), 379–387 and 901 repeat it; the record hash's
   listed inputs are explicitly unchanged ("the record hash's listed inputs above are unchanged",
   04:249) and no rule needs the hash to cover the pair, because the contract reads it from storage and
   binds it through `forcedBoundary`.
5. **No rule commits `L2_BLOCK_GAS_LIMIT` through a preimage — except the FI-12(5)(ii) sentence in
   INC4R1-RD-01.** 09:195 (anchored view, not committed, no enumeration changes); `spec/05` PRF-02(5)
   (post-`066ec452d`: "no live config preimage commits it … no preimage enumeration changes"); delta RC-4;
   `spec/04` L1-05 row 23's V3 closed list and its "versions 1 and 2 remain the preimage only for an epoch
   already entered under them". Every other mention of the name is a relation term or a measurement input.
6. **The deferral set reads three with the right membership, and forced inclusion is not called
   deferred.** `DEFERRED.md` 5–9 (rotation/stall/aggregation; forced inclusion "leaves the set");
   index 42, 92, 118, 355–356, 367, 528, 584, 593; `spec/10` 31 and 418–419; `spec/06` 23/48; `spec/08`
   37/797; `PLAN.md` 29–36; `FI-PLANNED-01` now covers only the general list (index 455), and
   `FI-REMOVED-01` stays the general-list tombstone. Only `CONVERGENCE.md` is stale (INC4R1-RD-03).
7. **The offence rows stay tombstoned and nothing new is priced.** ECON-04(6) (`spec/07` 520, 539, 553,
   558: "the obligation is live and creates no offence") and ECON-13(4) (1106–1114) are D-16 tombstones;
   the reporter bounty's clause (5) says the narrow breach "is not an offence, no evidence object exists
   for it and no bounty is payable for it" (672–675); FI-10(1) states the family "adds no register, no
   queue, no escrow, no bond and no fee" (04:730), and the enforcement is the rejected proof (04:732,
   D-18). No fee, escrow, bond, refund or reporter reward was invented.
8. **F-FI-1…F-FI-6 and the headline appear wherever the obligation is summarised.** `spec/10` 35, 260
   ("This is not a latency guarantee … exclusion per unit of a censor's L1 spending … conditional on
   `F-FI-5` and `F-FI-2`"), 286, 353 (all six, each with what it means), 420; index 397, 526, 584;
   `spec/01` 530, 543, 571; `spec/02` 522; `spec/04` 731, 738; `DEFERRED.md` 55–66; `learn/01` 168,
   225, 253; `learn/02` 260; `learn/08` 124; `learn/09` 38, 49, 71; `learn/11` 40, 162–186, 239–241, 285;
   `learn/index` 82; `learn/glossary` 115, 130; `learn/limitations` 54, 191–200, 279–291, 340–341;
   `DECISIONS.md` D-18 665–677. The register's relation row and measurement row carry F-FI-1 as Open.
9. **No disclosure promises more than the rules deliver.** The guarantee is stated as exclusion per unit
   of the censor's L1 spending, conditional on an honest or rational producer and on L1 including the
   publication; F-FI-2 ships **open and unfixed** with no per-publisher bound, because a condition on
   `publish()` would change DA-07(1); F-FI-4 states expiry is a discharge, not inclusion; F-FI-6 keeps the
   deliberate-delay residual; `C_PUBLISH` is unmeasured and the publication-reward question stays Open;
   and no FI state is read by the withdrawal root, its attestation, the k-family check, the veto or exit
   eligibility (04:732 FI-11(1), 07:1103, 01:530/543, index 397/526).
10. **The three interface questions are where the coordination left them.** `forcedSettlementAt(uint64)`
    exists as a view (04:318–320); no `pruneCursor` view is promised anywhere and none is required by a
    rule (the cursor is advanced only by `prunePublications`, 04:322–328, 08:338); the single
    `ForcedViewStale` covers the three freshness conditions in its own comment (04:425), and
    `04-coordination.md` §4d records all three as decisions for the review round rather than as rule
    obligations. Noted, not filed: a client cannot read `pruneCursor` or distinguish which freshness
    condition failed from the error name alone — an observability choice, not a rule defect.

## Considered and dismissed (not findings)

1. **The "R ≥ min(W, FI_MIN_DRAIN) ≥ 1 whenever a live record is outstanding" gloss.** It is the owner's
   ratified wording (04-coordination §4b) and it is repeated verbatim in the delta, 09:190, index 458 and
   FI-11(2)(3), so it matches the ratification as instructed. The operative clause — `R ≥ 1` whenever the
   outstanding obligation is non-empty — is correct in every case, because `R = min(d(A) − c, cap)` with
   `d(A) > c` and `cap ≥ 1`. The shorthand can read as a stronger statement in one corner (the only live
   records sit beyond the required window, so `W = 0`); the bound that matters is unaffected. Recorded,
   not re-litigated.
2. **The single `ForcedViewStale` error.** Keeping one error for three conditions is the implementer's
   recorded choice, the comment enumerates the conditions, and the remedy (use an older, final view) is
   the same for all three. No rule depends on the distinction.
3. **`CONVERGENCE.md`'s timing convention.** The note may be updated only when an increment ships
   (increment 2's note arrived with its ship record); that convention explains the staleness but does not
   make the two current-state sentences true, which is why it is filed as a Low with the fix options.

## Ship decision

**Not clean: 1 High, 1 Medium, 1 Low.** The register, the one-unit discipline, the `FI_MIN_DRAIN` row, the
settlement-slot arithmetic, the deferral membership, the offence tombstones and the F-FI disclosures all
hold, but INC4R1-RD-01 is a live rule clause asserting the config commitment the owner forbade, with the
register and PRF-02(5) already saying the opposite — an implementer trap on a live commitment surface.
**Fix INC4R1-RD-01 and INC4R1-RD-02 (both text-only) before the increment ships**; INC4R1-RD-03 can ride
with them or wait for the ship record.
