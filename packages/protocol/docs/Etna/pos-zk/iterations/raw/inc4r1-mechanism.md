# Increment 4 round 1 — the narrow forced-inclusion mechanism

**Reviewer:** r6-gov-generations (task-41), independent adversarial reviewer.
**Snapshot:** `169480a56` (branch `etna-pos-zk`). The working tree moved during this review (the reconciliation
implementer's edits landed on `spec/04`, `spec/08`, `spec/10`, `index.html` and the delta after the snapshot);
every quotation below is taken from `git show 169480a56:…` unless it says otherwise.
**Angle:** attack the mechanism — vacuity, stalls, unboundedness, void manufacture, the totality of the
three-mode walk, expiry, `FI_MIN_DRAIN`, and the capped prefix.
**Method:** the specification is authoritative; the delta's and the coordination doc's claims are claims.
Citations: `NN:line` = `spec/NN-*.html` at the snapshot; `coord §n` = `increments/04-coordination.md`.

**Counts: Critical 1 · High 0 · Medium 2 · Low 1.**
**Verdict: the mechanism is well built — the ratified `R` = the window, the unconditional advance, the
dead-mode discharge and the no-gate enforcement all hold under attack — but it is not safe to ship as
written.** A permissionless publication containing **one forceable and one permanently non-forceable
transaction** is neither executed, void nor dead, so it cannot be resolved; because FI-11(2)(4)/PRF-04(vi)
require every position in the fixed window `[c, c + R)` to be resolved, **every proof is invalid while that
record is live and inside the window** — all landings stop chain-wide until the record is dead
(`T_PROVE_DEADLINE` after publication), and the grief is repeatable for one publication per deadline
(R4R1-M-01). Two smaller items: FI-12 still asserts the `paramVersion = 2` preimage commitment the owner
decision declares wrong (R4R1-M-02), and the snapshot gives the per-height settlement pair no storage home
(R4R1-M-03; the in-flight edit fixes it).

---

## Finding R4R1-M-01 — Critical: a record with a mixed forceability profile cannot be resolved, so every proof is invalid until it expires — a permissionless settlement halt

**Severity: Critical.** One-line rationale: FI-13's three modes are not jointly exhaustive — mode (a)
requires **all** of a record's transactions executed, mode (b)'s ground is "over-bound, **or one none of
whose transactions is forceable at any block's pre-state in the batch**", and mode (c) needs the record
dead — so a live record with at least one forceable and at least one never-forceable transaction is
*unresolvable*; FI-11(2)(4) requires **every** position in the fixed window `[c, c + R)` to be resolved and
`R = min(d(A) − c, FI_MAX_PER_BATCH)` is computed (not chosen), so once the frontier reaches that position
every batch's proof is invalid, `land` can never succeed, and settlement stops chain-wide until the record
is dead — reachable by any account with one publication, repeatable at one publication per
`T_PROVE_DEADLINE`, and exactly the halt the increment's no-halt argument (FI-12(5)) claims cannot happen.

**File + rule id.**
- `04:734` (**FI-13(1)**): "A position j is resolved by a batch iff exactly one of: **(a) executed** — the
  record at j is live at A and **all of its transactions** appear in the batch's executed payload …;
  **(b) void** — the record at j is over-bound or non-forceable under (2)–(3); or **(c) dead** — …".
- `04:734` (**FI-13(4)**): "A record above any registered bound, **or one none of whose transactions is
  forceable at any block's pre-state in the batch**, is void"; and FI-13(1)'s last sentence: "A record that
  was forceable somewhere in the batch and was not executed is **(b) or invalid**".
- `04:734` (**FI-13(5)**): "A record that is neither executed, void nor dead cannot be passed:
  FI-11(3)(c) makes the proof invalid."
- `04:732` (**FI-11(2)(4)**): "require that **every position in `[c, c + R)`** is resolved under FI-13's
  three modes, and recompute `c' = c + R`"; `04:738` (**FI-12(2)**): "`R = min(d(A) − c,
  FI_MAX_PER_BATCH)` — the resolved count, the size of the required window"; `05` **PRF-04(vi)** repeats the
  same requirement.
- `04:738` (**FI-12(5)**): "Why this cannot produce a permanent halt" — the claim this finding falsifies
  (the halt is bounded per record but repeatable, and while it lasts it is chain-wide, not confined to the
  forced data).
- **Missing rule:** a resolvability ground that is total. The clean form: mode (a) requires every
  transaction that is forceable at the pre-state where it would be required (simulating the record's own
  preceding transactions) to be executed, and mode (b) covers a transaction that is non-forceable at
  **every** such pre-state; a record is void iff at least one of its transactions can never be executed
  after the record's own preceding transactions, and already-executed transactions of that record count as
  executed, not as a gap. Whatever the owner picks, the rule must guarantee that **every** payable record
  is resolved by exactly one mode.

**Assumptions.** A publisher crafts the payload (publication is permissionless, DA-07); no assumption in the
specification's fault model is violated. The publisher needs one valid transaction of its own (forceable at
the batch's first pre-state) and one transaction of any account whose nonce is far ahead of that account's
current nonce and cannot be reached by any transaction the batch can carry. No key, stake, validator or
producer cooperation is needed.

**Concrete attack trace.**
1. The attacker publishes one record whose decoded payload has two transactions:
   `t1` — the attacker's own next transaction (nonce equal to its current nonce, balance covering
   `gasLimit × maxFeePerGas + value`) → forceable at the batch's first pre-state; and
   `t2` — any signed transaction whose declared nonce is far above its sender's current nonce (e.g.
   `nonce = current + 10^6`), which no batch can make current because that would need a million signed
   transactions of that sender → non-forceable at **every** pre-state in **every** batch. The payload is
   small and within `FI_ITEM_MAX_BYTES` / `FI_MAX_TX_PER_RECORD`, and both gas limits are within
   `FI_RECORD_GAS_MAX`, so the record is not over-bound.
2. Once the record is due (`FI_INCLUSION_DELAY` after publication) the frontier advances toward its
   position at `R` positions per accepted batch; when the position enters `[c, c + R)`, every proof must
   resolve it.
3. Mode (a) fails: `t2` cannot be executed, so "all of its transactions appear in the batch's executed
   payload" is false. Mode (b) fails under FI-13(4): `t1` **is** forceable at the batch's first pre-state,
   so the record is not "one none of whose transactions is forceable". Mode (c) fails while the record is
   live. FI-13(5) then makes **the proof invalid** — for every batch, since the requirement is on the
   window and the window is computed, not chosen.
4. Result: no `land(data, proof)` can succeed until the record is dead at every admissible view — the
   record is dead at `A` iff `A ≥ record.l1BlockNumber + T_PROVE_DEADLINE`, and the attacker waits only
   for the L1 clock (the record is not re-published, so no state changes). Until then, settlement is frozen
   chain-wide: no checkpoint advances, the L2 halts when the unsettled-depth cap binds (HALT-03), and no
   new withdrawal root can form (L1-13 requires an accepted checkpoint), so value above the last accepted
   checkpoint cannot leave — the D-16 disclosed class, here *caused* by a permissionless publication.
5. Repeatability: one fresh poison record per `T_PROVE_DEADLINE` keeps settlement frozen indefinitely at
   the cost of one publication per period; the attacker can also publish while the deadline of the previous
   poison is expiring.
6. The benign variant is the same hole without malice: a legitimate multi-sender record in which one
   sender's transaction becomes non-forceable (its nonce consumed, its balance insufficient) while another
   sender's remains forceable is unresolvable by the same argument — and F-FI-3's disclosure ("a record
   voided in this batch may become forceable later; the remedy is re-publication") mis-describes it, because
   the record is **not** voided; no batch can pass it.

*The other reading is also broken.* If "non-forceable" in FI-13(1)(b) is read per transaction ("any
transaction non-forceable ⇒ the record is void"), the poison halt disappears but a producer can then void a
record by including or ordering the sender's own competing transactions (a replacement or a later-nonce
transaction from the mempool), so FI-13(3)'s "no producer … can make a due record void by choosing block
contents" and "a record that is genuinely non-forceable stays void in every batch" become false, and the
onus shifts to F-FI-3's narrow disclosure. The rule as written supports the FI-13(4) reading, and that
reading halts the chain.

**Fault-model verdict.** Inside (any account; no assumption failure, no producer, validator or DAO
cooperation, no cryptographic break). **Attacker cost.** One L1 publication (plus one valid L2 transaction's
gas and one signed far-nonce transaction, both free to craft); ~one publication per `T_PROVE_DEADLINE` to
sustain the halt.
**Requirement affected.** FI-12(5)'s "why this cannot produce a permanent halt"; FI-11's no-halt argument;
**D-12** (the fixed decision that narrow forced inclusion must not halt the chain); the increment's
convergence claim; F-FI-3's accuracy.
**Evidence.** `04:734` (FI-13(1)/(4)/(5)), `04:732` (FI-11(2)(4)), `04:738` (FI-12(2),(5));
`05` PRF-04(vi); delta `FI-13(4)`, `FI-12(5)`, `F-FI-3`.

---

## Finding R4R1-M-02 — Medium: FI-12 still asserts the `paramVersion = 2` preimage commitment that the owner decision declares wrong

**Severity: Medium.** One-line rationale: the live FI-12(5)(ii) tells the implementer that
`L2_BLOCK_GAS_LIMIT` "is committed through the `paramVersion = 2` preimage of PRF-02(5)", while the owner
decision this round must verify says that claim is **WRONG and must not be implemented** — V2 is historical,
the live preimage is V3 whose field list does not include the value, the capacity input is read from the
anchored L1 view, and no preimage enumeration changes — and the register row already states the corrected
reading, so the rule now contradicts both the decision and the register.
**File + rule id.** `04:734` (FI-12(5)(ii)): "… no rule registered here constrains the L2 gas-limit
schedule, **and while the per-epoch configuration of PARAM-04 commits `L2_BLOCK_GAS_LIMIT` through the
`paramVersion = 2` preimage of PRF-02(5)**, that commitment only records the value." Against it:
`coord §3` ("FI-12(5)(ii)'s claim … is WRONG and must not be implemented … the live preimage is V3, whose
field list does not include `L2_BLOCK_GAS_LIMIT` … the value is bound by that view … no preimage changes"),
and `09:195` ("Live input again by increment 04, **read from the anchored L1 view the proof already fixes:
it is NOT committed through any config preimage and no preimage enumeration changes** (04-coordination.md
§3)"). The sentence is still present in the working tree after the snapshot (04:738 there).
**Missing rule / correction:** replace the sentence with the anchored-view reading, exactly as 09:195 has
it, and state that the capacity relation's input is the value the proof's anchored view binds.
**Assumptions.** None. **Attack trace.** Not an attack: an implementer following the rule could add the
field to a live preimage (changing a commitment), validate against the historical V2 list, or reject batches
whose config does not carry it — each of which contradicts PRF-02(5)/PARAM-04 and the owner ratification.
**Fault-model verdict.** Inside (rule-versus-decision contradiction; no adversary).
**Attacker cost.** None. **Requirement affected.** The owner decision `coord §3`; PRF-02(5)'s V3 field list;
09:195; PRF-04(viii)'s configHash binding. **Evidence.** snapshot `04` FI-12(5)(ii); `coord §3`; `09:195`;
delta `FI-12(5)(ii)`.

---

## Finding R4R1-M-03 — Medium: in the snapshot the per-height settlement pair has no storage home, so the frozen mechanism is not implementable as written

**Severity: Medium.** One-line rationale: FI-11(2)(2) and L1-03(6) require `(settledCount, anchoredL1Block)`
to be "the predecessor checkpoint's own recorded `settledCount` (written atomically by that height's
accepting `land`)", and L1-08 exposes `forcedSettlementAt(uint64) returns (uint64, uint64)` — but the
snapshot's L1-07 checkpoint struct has eight fields and neither value, and MIG-02's frozen declaration
list carries no mapping or slot for them: the rule reads state no slot owns (the round-5 F6/F8 class).
**File + rule id.** `04:730` (FI-10(5)), `04:81` (L1-03(6)), `04:318-320` (L1-08 view); the snapshot's
`04:231-240` (L1-07 struct: height, blockHash, stateRoot, epoch, setRoot, dataCommitment, l1BlockNumber,
lastAcceptedBatchTime); `08` MIG-02 ("15 declaration slots, 258–269 and 275–277"; "28 gap slots remain").
**Status and fix (verified against the in-flight edit).** The working tree's uncommitted reconciliation edit
adds the two `uint64` fields to the L1-07 record, completing the packed word
(`l1BlockNumber + lastAcceptedBatchTime + settledCount + anchoredL1Block = 4 × 8 = 32 bytes`), adds **no**
per-height mapping, and leaves MIG-02 at 15 declarations / 28 gap slots — the arithmetic balances, and it
implements `coord §2`. If that edit lands, this finding is closed; it is reported because the review target
is the snapshot and because the frozen L1-08 view would otherwise be unimplementable.
**Assumptions.** None. **Attack trace.** None (specification completeness).
**Fault-model verdict.** Inside (no adversary). **Attacker cost.** None.
**Requirement affected.** L1-03(6), L1-07, L1-08, MIG-02, `coord §2`. **Evidence.** snapshot `04` lines
231–240, 318–320, 730, 81; `08` MIG-02; the working-tree diff to `04` (adds the pair to the struct).

---

## Finding R4R1-L-01 — Low: `FI_MIN_DRAIN` is decorative for the advance, and the register row attributes to it work the capacity condition already does

**Severity: Low.** One-line rationale: the advance is `R = min(d(A) − c, FI_MAX_PER_BATCH)` (FI-12(2)) and
the capacity condition forces `cap(batch) = FI_MAX_PER_BATCH ≥ 1` whenever anything is outstanding
(FI-12(1)), so `R ≥ 1` already follows without the floor; `FI_MIN_DRAIN`'s only registered role is the
relation `1 ≤ FI_MIN_DRAIN ≤ FI_MAX_PER_BATCH`, and the register row's causal phrasing ("the registered
floor **that makes `R = 0` unreachable**") credits the floor with what `cap ≥ 1` delivers.
**File + rule id.** `04:738` (FI-12(1),(2),(5)(iii): "`R = min(d(A) − c, FI_MAX_PER_BATCH)` … at least
`min(d(A) − c, FI_MIN_DRAIN) ≥ 1`"); `04:732` (FI-11(2)(3): "`R ≥ 1` whenever the outstanding obligation
at `A` is non-empty"); `09:190` (the row quoted above). **Missing rule / correction:** either make the
floor operative (require the batch to resolve **at least** `min(backlog, FI_MIN_DRAIN)` positions — the
clause already requires the whole window, which is ≥ that) or reword the row to say the floor is a bound on
the registered cap, not the driver of the advance. Neither direction weakens the obligation.
**Assumptions.** None. **Attack trace.** None; the floor cannot be exploited (it neither raises nor lowers
`R`). **Fault-model verdict.** Inside (register precision). **Attacker cost.** None.
**Requirement affected.** FI-11(2)(3), FI-12, 09:190; the owner's `coord §4b` ratification ("the register row
must be reworded to match the clause"). **Evidence.** `04:732`, `04:738`; `09:190`; `coord §4b`.

---

## The angle's questions, answered

**Can the obligation be made vacuous, stalled or unbounded — by a producer, a publisher or a user?**
- *Vacuous* only when nothing is published (`d(A) = c`), which is inherent; the relation
  `FI_INCLUSION_DELAY + L1_FINALITY_DEPTH < T_PROVE_DEADLINE` (FI-10(6), `09:199`) guarantees a window in
  which a record is due while still live, so a publication always becomes forceable, never inert. ✓
- *Stalled by a producer:* the anchor can postpone the due point by at most `FI_ANCHOR_MAX_AGE` blocks
  (FI-11(6): `block.number − FI_ANCHOR_MAX_AGE ≤ A`, an admission condition whose collision with L1-04 is
  resolved by the two registered relations, FI-11(7)), the view may not regress, and the window `R` is
  computed by the guest, so a producer cannot shrink what it must resolve. The producer's only stall is
  *not landing at all* (A-DA-2), which is the disclosed pipeline assumption. The residual (a certified
  range landed past both bounds) is F-FI-6, disclosed. ✓
- *Stalled by a publisher:* the capped FIFO prefix cannot be shrunk (the capacity condition forces
  `cap = FI_MAX_PER_BATCH`) and the batch must resolve exactly `R` (the guest rejects otherwise), so a
  backlog only delays later records (F-FI-2, arrival > drain), which FI-REMOVED-01 states exactly: "arrivals
  must stay within the drain the obligation can force — F-FI-2 is open … conditional on a non-censoring L1
  and on at least one honest or rational batch producer (F-FI-5). It is an upper bound on exclusion per unit
  of a censor's L1 spending, **not a latency guarantee**" (`04:727`). ✓ disclosed.
- *Stalled by a user:* the poison record — R4R1-M-01. ✗

**Is the frontier advance really unconditional and monotone in every case?** Yes, algebraically:
`c' = c + R` with `R = min(d(A) − c, FI_MAX_PER_BATCH)` gives `c' = min(d(A), c + FI_MAX_PER_BATCH) ≥
min(d(A), c + FI_MAX_PER_BATCH)` — the advance condition with equality, so the deleted waiver is genuinely
gone. Cases: *window full of dead records* — dead positions count in `R` and are resolved by mode (c) with
no gas (the owner-ratified form is what makes this work; the delta's `min(W, cap)` would have been
unsatisfiable) ✓; *empty register* — `R = 0` and the `R ≥ 1` check is conditioned on a non-empty obligation
(FI-11(2)(3)), so no deadlock ✓; *a batch that resolves nothing* — only when `d(A) = c` ✓; *skipped epoch* —
the backlog grows and is drained at `≥ 1` per accepted batch ✓; *reorg* — the register, the settlement
records and the frontier ride the reorged L1 state, and a reorged `land` undoes its checkpoint and its
settlement record (FI-14(2) at `04:738`, L1-12) ✓ (subject to R4R1-M-03 in the snapshot).
**Monotonicity**: `c' ≥ c` is required, `d(A)` is monotone in `A`, the view cannot regress
(`ForcedViewRegression`) and the contract rejects `settledAfter > nextSeq(A)` ✓.

**Can a producer manufacture a void ground, or make a record appear forceable when it is not?** The two
producer-movable terms (base fee, block gas limit/remaining gas) are deleted from FI-13(2), and the remaining
inputs are the record's immutable bytes, registered constants, and the sender's nonce and free balance at
the pre-state — none of which a block producer sets. The producer can order the *user's own* signed
transactions (which is F-FI-3's disclosed residual), and the reverse direction — requiring execution of a
transaction that cannot execute — is exactly R4R1-M-01's hole. ✓ with M-01.

**Is the three-mode walk total?** **No** — that is R4R1-M-01. The *other* totality properties hold: each
position in `[c, c')` is checked against exactly one mode (no double count; `c' = c + R` advances once per
position), a hole makes the proof invalid (`ForcedRecordMissing`, FI-11(2)(5)), and no hole can arise while
the prune is deletion-only behind a cursor `≤` the settled frontier (`04:440`, `04:325-326`), which never
touches `[c, nextSeq)` ✓.

**Can expiry be gamed to discharge a record the censor should have included; can the deadline be
manipulated?** No: `dead` is "`record.l1BlockNumber + T_PROVE_DEADLINE ≤ A`" (FI-10(2)/(7)) with the
deadline derived, never stored or mutated, and `A` an anchored L1 view the guest re-derives and the
contract requires to be Ethereum-final and within the age bound — a producer cannot claim an `A` beyond the
real L1 head, so a live record cannot be declared dead early, and it cannot be re-clocked (the record is
immutable; re-publication is a new position with a fresh clock) ✓. Expiry as a *proof-side* ground is the
R6-D12-01 repair and needs no bytes, no call and no mutable status ✓.

**Is `FI_MIN_DRAIN`'s floor real rather than decorative?** Decorative for the advance (R4R1-L-01): the
operative floor is `R ≥ 1`, which follows from `cap ≥ 1`; the parameter remains a registered bound on
`FI_MAX_PER_BATCH` only.

**Can the capped FIFO prefix be used to stall the frontier without censoring?** No: a batch's cap cannot be
shrunk (FI-12(1) forces `batchGasCapacity ≥ FI_MAX_PER_BATCH × itemGasBound` whenever anything is
outstanding, and a smaller batch is invalid under `ForcedCapacityInsufficient`), the guest requires exactly
`R` positions resolved, and dead/void positions cost no gas, so the prefix always drains at `≥ 1` per
accepted batch. The only no-censorship stall is not landing, plus the bounded anchor-age postponement. ✓

**The three interface questions left open (`coord §4d`).** (a) `forcedSettlementAt(uint64)` **is** in the
snapshot's L1-08 (`04:318-320`) and returns the pair; the rule should say what it returns for an unknown
height (revert vs zeros) — a one-line completeness note, not a finding. (b) `pruneCursor` has **no** view
(only the comment at `04:325`); recommend adding one for observability, since no rule reads it and FI-14(3)
already constrains it — disclosure, not enforcement. (c) One `ForcedViewStale` for the three freshness
rejections (not-final, regressed, older than the age bound) is sufficient for correctness — all three are
proof-side rejections and L1-04's no-gate argument is unaffected; distinct error variants are a diagnosis
aid the implementer may add without a rule change.

**Also checked and holding.** The obligation is enforced only in the proof (FI-11(1)): `land` gains no
rejection that depends on the register, and the one capacity condition is part of proof validity ✓; `L1-04`'s
no-gate property survives, with the `FI_ANCHOR_MAX_AGE` freshness gate bounded by the two registered
relations so no in-envelope batch is rejectable (FI-11(7)) ✓; **no new slashable offence** — ECON-04's
forced-inclusion rows stay tombstoned and "the rejected proof is the whole enforcement" (`04:732`) ✓; **no
FI state is read by the exit** — FI-REMOVED-01 states that no obligation attaches to a withdrawal root, its
attestation, the k-family check, the veto or exit eligibility, and I found no FI read in L1-13, MSG-03 or
MSG-04 ✓; the deferral count reads **three** in DEFERRED.md with the membership the coordination decision
adopted (rotation, stall resolution, aggregation) and the index/10 rows state forced inclusion is live (the
full bidirectional sweep is the artifact-consistency reviewer's charged item) ✓; F-FI-2's condition is
stated where the guarantee is summarised, with the "not a latency guarantee" phrasing (`04:727`, Fi-REMOVED-01)
✓.

## Summary for the lead

| Severity | Count | Findings |
|----------|-------|----------|
| Critical | 1 | R4R1-M-01 (a mixed-forceability record is unresolvable → every proof invalid → a permissionless, repeatable, chain-wide settlement halt until expiry) |
| High | 0 | — |
| Medium | 2 | R4R1-M-02 (FI-12 still asserts the V2 preimage commitment the owner decision declares wrong) · R4R1-M-03 (the snapshot gives the per-height settlement pair no storage home; the in-flight edit fixes it) |
| Low | 1 | R4R1-L-01 (FI_MIN_DRAIN is decorative and the register row overstates it) |

**Strongest attack: R4R1-M-01.** Publish one record with two transactions — one forceable at the batch's
first pre-state, one whose nonce is unreachable — and the record is neither executed (not all transactions
can execute), nor void (FI-13(4) voids only a record **none** of whose transactions is forceable), nor dead
(while live). FI-11(2)(4)/PRF-04(vi) require every position in the computed window `[c, c+R)` to be
resolved, so no proof can be valid once the frontier reaches the position, and `land` is dead until the L1
clock passes the record's deadline. One publication freezes settlement; one per `T_PROVE_DEADLINE` keeps it
frozen. The fix is to make the resolution ground total (per-transaction resolvability or a "void" ground
that covers a record no batch can fully execute), and to re-state F-FI-3's consequence in the same words.

**Is the increment safe to ship?** **Not as written.** R4R1-M-01 must be fixed before it ships (it is a
chain-wide, permissionless halt in a v1 with no recovery path); R4R1-M-02 is one sentence and R4R1-M-03 is
already addressed by the in-flight edit; R4R1-L-01 is a wording/no-op item. With M-01 fixed, everything else
in the mechanism survived this round's attack: the ratified `R` = the window, the unconditional and
monotone advance, the dead-mode discharge, the producer-independent void predicate, the proof-only
enforcement, the exit non-interaction and the F-FI-2 disclosure.
