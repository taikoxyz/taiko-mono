# Increment 05 — Governance stall resolution (D-15): design delta

**Status: IMPLEMENTED, IN REVIEW.** The design delta has been applied to the specification, register,
index, course and decision files by increment 05's implementation pass; the owner decisions that
answered §10 are recorded as D-19 in [`DECISIONS.md`](../DECISIONS.md), whose text §11 reproduces
verbatim *(R5R1-G-02: the earlier "appended verbatim" label described a paraphrase; §11 now carries
D-19's exact text)*. This document remains what the
increment's adversarial review round is built from, and the review round is the authority that closes the
three blockers named in [DEFERRED.md](../DEFERRED.md) §3. It has NOT shipped: an increment ships only when
two consecutive rounds come back with no Critical and no High, and its ship record follows, exactly as
`increments/02-ship-record.md` and `increments/04-ship-record.md` did.

**Scope.** This increment revives the **timelocked, resume-only governance stall resolution of D-15**
(`GOV-04`, with its analysis family `REC-02`/`REC-03`/`REC-04`) as a live, rule-bound action: a single
queued governance entry, a stored timelock, a permissionless execution that **consumes the entry**, and a
signed generation increment. The action **resumes settlement on the same chain**: it leaves the checkpoint
and everything at or below it untouched; it invalidates a superseded certificate **only as a batch's head
evidence** — a superseded certificate cannot serve as the head certificate of an extending batch, which is
exactly what the enforced checks say, since the head certificate, its contributing votes and the head header
must carry the current generation; the range above the latest L1-accepted checkpoint remains **valid history
that can be extended under the new generation**, and nothing in the rule invalidates or forbids a block on
account of the generation in its own header; and the class above the checkpoint is unprotected for a
different and narrower reason than erasure — the user's signals are not carried into the settlement the
resumed chain produces, so they must be resubmitted, with no compensation. *R5R2-C-01: the "full-range
discard" and "unlandable" forms this scope first carried are corrected here and MUST NOT be restored.*

It adds **no permissionless recovery, no bond, no
reward, no invoker, no certificate bundle, no retirement record, no history-editing power and no new
entry point on the exit or inclusion paths**. It does **not** revive `CONS-16` (the rotation) or `D-13`
(aggregation), and it does not reopen a v1 decision.

**The three blockers, as recorded.** DEFERRED.md §3 records the mechanism as deferred because it "did
not survive its first review": **G-1** (Critical — nothing consumes the queued entry, so any account can
re-execute it and churn the signed generation: a permissionless, gas-priced settlement-denial loop),
**G-2** (High — the timelock cannot be the exit window the rule claims, with round-5 `F1`/`F2`) and
**G-3** (High — the generation binding makes the first epoch-opening batch after a resolution
unprovable). Round 6 also raised three Mediums and one Low (**G-4**–**G-7**). This delta disposes of all
seven: the three blockers by design, the four smaller findings by a design change, a text change already
made in a later round, or an explicit change-list item. Nothing here claims the review has happened.

**Bases.**

- **Preserved rule text at `7917ba264`**: `GOV-04` (`spec/08-migration-upgrades.html`, the rule block
  beginning "GOV-04 — stall resolution"), `GOV-03(e)`, the `MIG-02` slot-268 packing note,
  `REC-01`–`REC-04` (`spec/06-recovery-exceptions.html`), `HALT-01`–`HALT-04`, the `cert_hash` and
  header-generation clauses of `CONS-10(6)`–`(7)`, `CONS-05`/`CONS-08`/`CONS-12`, `PRF-02(4)`,
  `PRF-04(i)`, `PRF-05(ii)`, and the `T_STALL_GOV`/`T_GOV_RESUME`/`govResume*` register rows. The
  revival is a **re-derivation against the current converged draft, not a revert of the tombstone**: the
  preserved text is the starting point and is corrected where round 6 showed it defective.
- **Current-draft anchors this delta was written against** (line numbers are approximate; the draft is
  at HEAD, not at `7917ba264`): `spec/08-migration-upgrades.html` GOV-03 ~L761, GOV-04 tombstone ~L782,
  MIG-02 slot-268 note ~L250; `spec/06-recovery-exceptions.html` REC-01 ~L42, HALT-01 ~L100, HALT-02
  ~L148, HALT-04 ~L235, REC-02 ~L401, REC-03 ~L423, REC-04 ~L444; `spec/02-consensus.html` CONS-02
  ~L84–100, CONS-04 ~L145–160, CONS-05 ~L177–188, CONS-08 ~L242–243, CONS-09 ~L261–269, CONS-10(6)
  ~L344, CONS-10(7) ~L360, CONS-11 ~L365–369, CONS-12 ~L393–394, CONS-15(2) ~L494, CONS-16 ~L505;
  `spec/05-proof-statement.html` PRF-02(4) ~L194, PRF-04(i) ~L244–250, PRF-05(ii) ~L279–283, PRF-13;
  `spec/04-l1-integration.html` L1-05 row 31 ~L207, L1-06 ~L216, L1-07 ~L231, L1-13 ~L460–500, MSG-03
  ~L812, FI-14 ~L742; `spec/03-membership-staking.html` MEM-15 ~L344–352; `spec/09-parameters.html`
  withdrawal notice ~L97, `lastAcceptedBatchTime` ~L182, `T_STALL_GOV` ~L183, `T_GOV_RESUME` ~L184,
  `govResume*` ~L185, measurement rows ~L260–261; `spec/10-assurance.html` LIVE-01 ~L163, LIM-01 ~L325+;
  `spec/01-system-model.html` the "no recovery path of any kind" sentences (~L164, 220, 225, 327, 346,
  350, 553–560, 587–589, 607, 624); `spec/07-economics-slashing.html` ECON-02(5)(f) ~L289, ECON-02(6)
  ~L692, withdrawn rows ~L1193/1218–1231; `spec/index.html` ~L42, ~L116–119, ~L356, ~L481–483,
  ~L512–514, ~L554.
- **Findings disposed of here**: `G-1` (Critical), `G-2`, `G-3` (High), `G-4`, `G-5`, `G-6` (Medium),
  `G-7` (Low) from `iterations/raw/round6-gov-generations.md`; round-5 liveness `F1`/`F2` as G-2 names
  them; the preserved `GOV-04` failure-mode list; the withdrawn-recovery vectors `R5T-D2-01`,
  `R5T-D2-02`, `R5T-D2-04`, `R5T-D2-06`, `R5T-D2-07` (moot — no bundle, no bond, no invoker, nothing
  verified on L1 beyond the record).
- **Decisions**: D-15 (the replacement this increment revives), D-16 (the deferral this increment
  answers; its three named blockers are the three sections below), D-14/D-17 (untouched), D-12/D-18
  (forced inclusion, which must survive a resolution), D-8/D-9 (funding and destinations, untouched).
- **Ships since**: `CONVERGENCE.md` (v1 converged; boundary, exit, constant generation),
  `increments/02-ship-record.md` (`MEM-13` live), `increments/04-ship-record.md` (`FI-10`–`FI-14` live).

---

## 0. What this increment decides

| # | Decision | Where |
|---|---|---|
| 1 | **Execution consumes the entry.** `govResumeState` is `none` / `queued` / `executed`; a successful `execute()` sets `executed` in the same transaction that increments the generation; every later `execute()` call reverts; no other path increments the generation. There is no permissionless re-execution of one entry. | GOV-04(b)–(d), §3 |
| 2 | **A void entry never blocks the mechanism.** A live `queued` entry blocks a second queue; an `executed` entry does not; a **void** entry (checkpoint advanced) may be cancelled by any account **or replaced by the next queue**. The mirror reading that a stored `queued` value blocks every later entry is closed. | GOV-04(e), §3 |
| 3 | **The window is stored in the entry.** `govResumeExecutableAt = govResumeQueuedAt + T_GOV_RESUME` is recorded at queue time and is part of the entry: no upgrade, initialiser or parameter change may move, shorten or recompute it. | GOV-04(g), §3 |
| 4 | **The exit claim is scoped and true.** `T_GOV_RESUME` is stated as the **notice window** for the resolution and as the **exit window of `MEM-15` for signals already messaged at or below the last accepted checkpoint**, with a registered relation over root-attestation latency, `WITHDRAWAL_DELAY`, `T_VETO` and a margin — conditional on `MEM-15(2b)`'s proving dependencies. It is **not** claimed for value above the checkpoint, and the delta says plainly that nothing protects that value. | GOV-04(f), §4 |
| 5 | **Execution removes no claim at or below the checkpoint.** The execution writes exactly two pieces of state — the generation and the entry state — and no checkpoint, height, state root, set, retirement record or resume record; the checkpoint record is untouched and `MEM-15`'s path from it remains available before, during and after execution. | GOV-04(c)/(f), §4 |
| 6 | **A certificate is judged under the generation of the history it certifies.** The **head certificate** of a batch extending the checkpoint must carry the current generation (unchanged); a **historical certificate at or below the checkpoint**, including the anchor certificate, must carry the generation of the block it certifies, pinned by that block's hash as the L1 checkpoint record commits it, and **must not be compared with the current generation**. | CONS-05(2), CONS-08(1), PRF-04(i), PRF-05(ii)(a), §5 |
| 7 | **The first post-resolution epoch-opening batch is provable.** `B_anchor` is the restored checkpoint block, whose header carries the pre-resolution generation; the anchor certificate is judged under that value and the head certificate under the new one, so the two checks read two different objects and neither is unsatisfiable. | §5 |
| 8 | **Nothing shipped is disturbed.** The boundary (`REC-01`) is untouched; `MEM-13` is generation-independent and reads no resolution state; the forced-inclusion register and frontier are untouched by a resolution and the obligation is neither reset, re-clocked nor made unprovable; `MEM-15`'s exit is never gated, delayed or accelerated by a resolution. | §6 |
| 9 | **The parameters get an enforcement point and a named discretion.** The registered relations are **constructor-time assertions**; a change to either value is a rules change published under `GOV-02`; the false "chooses no configuration value" claim is withdrawn and the discretion is named. | GOV-04(g), §7 |
| 10 | **No new power, no new money, no new offence, no new trust assumption.** Resume-only effect, no calldata that names anything, no bond/reward/treasury transfer, no weight reduction, no new slashable offence; the residual is governance liveness/opportunism, already named `A-GOV-2`/F2. | §8 |

---

## 1. What blocked the mechanism, and what this delta does about each blocker

### (a) G-1 — the unconsumed entry (Critical)

**The defect as reviewed.** The preserved `GOV-04` defines `govResumeState` as `none/queued`
(`08:279`, `09:177` at the round-6 snapshot), states no `executed` value, and gives exactly one
clearing rule — cancellation — which is available only for a **void** entry (the checkpoint advanced).
Execution "leaves the checkpoint record itself untouched", so after a successful execution the state is
still `queued`, `govResumeQueuedHeight` still equals `lastLandedHeight`, the one-sided timelock predicate
is still true, and the entry is still executable by any account, repeatedly, with **no fresh trigger
evaluation**. Each call increments `recoveryGeneration`; the acceptance rule admits only the current
generation; a proof takes the D6 envelope to produce; so no batch can land while the attacker pays gas.
The mirror reading — that a stored `queued` value is "pending" — is worse: after one execution no later
queue is possible, and `CONS-16`'s mutual exclusion also reads the stored value.

**Resolution — a three-state machine whose transition is the increment.**

1. `govResumeState ∈ {none, queued, executed}`. The `executed` value is what makes "this entry was
   consumed" a stored fact rather than an inference from the counter.
2. `execute()` MUST revert unless the state is exactly `queued`, and MUST revert if the entry is void or
   the stored deadline has not passed. On success it MUST, **in one transaction**: increment
   `recoveryGeneration` by exactly one, set `govResumeState := executed`, and emit the event. It writes
   nothing else: `resumeHeight = lastLandedHeight + 1` is derived; no checkpoint, height, root, set or
   resume record is written.
3. The generation is incremented **only** in that transition. No initialiser, upgrade, governance call,
   cancellation, queue, client or execution path may increment it in any other state or a second time.
4. A **void** entry may be cancelled by any account, and the next queue MUST be allowed to replace it,
   so an uncancelled void entry never blocks the mechanism. An `executed` entry is not pending, so the
   next queue is allowed under the trigger and starts a fresh entry with a fresh stored deadline.

The effect on the attack: the first execution is unchanged; the second call reverts for **every**
caller, block and calldata. Generation churn now costs **one DAO queue transaction plus one full
`T_GOV_RESUME` per increment**, not one L1 transaction per block; and only governance can pay it. The
governance-driven residue is stated as **F-GOV-3** (§7) rather than denied.

### (b) G-2 — the timelock as an exit window (High)

**The defect as reviewed.** `GOV-04(d)` claimed `T_GOV_RESUME` "MUST be long enough that **every user**
can exit via `MEM-15`", repeated in `REC-02`, `HALT-04`, `LIM-01`'s `A-GOV-2` row and the index. Round 6
showed the claim is unsatisfiable for the class above the checkpoint: value there has **no L1-provable
claim** (`MEM-15(4)`) and cannot create one, so no window protects it, and the resolution does not erase it —
it resumes settlement on the same chain, leaving that value's signals outside the settlement the resumed
chain produces (*R5R2-C-01*);
and at the round-6 snapshot a root at or above the user's height required a **newly settled epoch
boundary**, while settlement advancing **voids the entry** — the two branches were complementary, so the
window could not be the thing that creates the exit.

**What has changed since round 6 (recorded, not assumed).** Round 7's repair widened root formation:
`L1-13(1)` now states that "any already-accepted checkpoint, and in particular the latest one, is
attestable", and `L1-13(3)` states that "the latest L1-accepted checkpoint MUST be attestable by this
path at any time while the chain is halted", with the delay measured on the L1 clock from the root's own
record and the `k−1` proofs funded under `L1-13(5)`. `MEM-15(2a)`/`(2b)` and `L1-13(1)` name this as the
repair of round-5 `F2` and of the exit contradiction (`F1`). **The availability half of G-2 is therefore
already repaired in the current draft** and this increment depends on it rather than re-opening it. What
remains is the **claim**, which is still false, and the **scope**, which was never stated.

**Resolution — one true sentence, one scoped window, and an explicit non-protection.**

- The window is stated for exactly the class that has a claim: a user whose L2→L1 signal is included in
  the L2 state **at or below the last accepted checkpoint at queue time**. For that class the window is
  real and its length is a **function of named terms**: the worst-case time to produce and record the
  `k` attestations of the checkpoint's withdrawal root (producing the `k−1` additional proofs is funded
  proving work, `L1-13(5)`), plus `WITHDRAWAL_DELAY` measured from the root's own record, plus an
  unexpired `T_VETO`, plus a margin — all on the L1 clock, none of which requires settlement progress.
  The relation is registered and unmeasured (Phase B) and is a constructor-time assertion.
- The window is **not** claimed for value above the checkpoint. Such value is unprotected by rule for a
  narrower reason than erasure: the execution does not carry its signals into the settlement the resumed
  chain produces, so the remedy is resubmission, with no protocol compensation (ECON-11), and the range
  itself remains valid history that a later batch may extend under the new generation. The holder's notice
  is the queued entry and the trigger window. *(R5R2-C-01: "discarded by rule" is corrected to "unprotected
  because the resumed settlement does not carry its signals".)* The sentence "the timelock gives every user the exit window of
  `MEM-15`" is **withdrawn** wherever it appears.
- The delta also states the stronger property the window claim does not need: **the execution removes no
  claim at or below the checkpoint**, because it rewrites nothing there (`REC-01`), so the root from the
  restored checkpoint remains attestable and the exit remains available even for a user who does not act
  inside the window. The window is therefore honestly described as a **notice-and-opportunity window**,
  not as the thing that makes that class safe.

### (c) G-3 — the anchor certificate's generation (High)

**The defect as reviewed.** `PRF-05(ii)(a)` verifies `B_anchor`'s certificate "under the same
signature, distinct-signer and quorum checks as `PRF-04(i)`–(iii)", and `PRF-04(i)` requires **every
contributing vote's generation to equal the journal's `recoveryGeneration`** — the post-increment value.
`B_anchor` is the restored checkpoint block and its certificate was necessarily signed under the
superseded generation, so on the reference reading the check fails, `epoch_anchor` cannot be recomputed,
and the first post-resolution epoch-opening batch is unprovable. The charitable reading (take the
generation from the witness certificate) drops the equality the round-4 fix exists to enforce and makes
the one value that decides whether the resumed chain can cross a boundary witness-supplied.

**Resolution — two cases, both pinned.**

1. The generation is a property of the **history a certificate certifies**: every header carries the
   generation in force when it was produced (inside the block hash); every vote and every certificate
   carry the generation of the block they are about.
2. **Head case (unchanged).** A certificate presented as the finality evidence of a batch extending the
   current checkpoint MUST carry the current generation, every contributing vote MUST carry it, and the
   head header MUST carry it. This is the anti-relanding rule, in its enforced form: a certificate of a
   block above the checkpoint produced under the superseded generation cannot be a batch's **head**
   certificate — and the rule is **head-only**: the block is not invalidated by the generation in its own
   header and may be carried as an ancestor of a batch whose head is produced and certified under the new
   generation *(R5R2-C-01)*.
3. **Historical case (new).** A certificate for a block **at or below the last accepted checkpoint** MUST
   carry the generation of that block's own header, and every contributing vote MUST carry the same
   value; it MUST NOT be compared with the current generation. This is not witness-supplied: the block's
   header bytes are pinned to L1 because the checkpoint record commits its hash, and the journal's
   `prevBlockHash` is that committed hash (`L1-05` row 4, `L1-07`), so the generation is read from bytes
   L1 already fixes.
4. **Anchor case (explicit).** When a batch opens an epoch, `B_anchor` is the block whose hash equals
   `prevBlockHash`; the guest MUST verify its certificate under the historical case and MUST recompute
   `cert_hash` into the header's `epoch_anchor`. A block of the range above the checkpoint that carries the
   superseded generation can be neither the head (its certificate cannot be the batch's head certificate)
   nor the anchor (`B_anchor` is pinned by L1 to the restored checkpoint block, which the resolution
   leaves untouched); as an ancestor it remains valid history, and a batch may carry it under a head
   produced and certified under the new generation *(R5R2-C-01)*.
5. **Why the first post-resolution epoch-opening batch is provable** is derived in §5: the anchor
   certificate is judged under `B_anchor`'s own generation (the pre-resolution value), while the batch's
   head certificate, head header and votes are judged under the new value. The two checks read two
   different objects, so no single value has to satisfy both. The rule is invariant under repeated
   resolutions because `B_anchor`'s header never changes.

### (d) G-4 — the trigger and the window are governance-set immutables (Medium)

Recorded defect: `T_STALL_GOV` and `T_GOV_RESUME` change only by upgrade; only an **already-queued**
entry's remaining term is protected; the only constraints on new values are derivation obligations with
no enforcement point; and `REC-02`'s *Resume-only* row claimed governance "chooses … **no configuration
value**". **Resolution:** (i) the entry stores its own deadline (`govResumeExecutableAt`), so the
already-queued protection is a stored fact rather than a recomputation from a mutable parameter;
(ii) the registered relations become **constructor-time assertions** — an implementation that does not
satisfy them MUST refuse to initialise — and a change to either value is a rules change that `GOV-02`
requires to be published as one; (iii) the *Resume-only* claim is corrected to "chooses nothing **at
execution**", and the discretion over future entries is named in `REC-02`, `REC-03`'s falsifiers,
`A-GOV-2` and `LIM-01`. The residual (an upgrade may move future values to their conforming minima) is
disclosed as **F-GOV-4** rather than hidden.

### (e) G-5 — the certificate tuple (Medium) — already closed, kept

The current draft's `CONS-05` carries `recovery_generation` in the certificate tuple and records that
this closes review round 9 finding `R9-CC-01`. This increment keeps the tuple and adds the validity
scoping of `CONS-05(2)`; no change to the field list.

### (f) G-6 — the halt sentence is not generation-scoped (Medium) — closed by a change-list item

`CONS-05`'s sentence "A node that instead holds a conflicting lock at `H` (`CONS-04`) or a conflicting
finalized block at `H` has evidence that the assumptions failed; it halts (`CONS-15`) and MUST NOT
silently adopt the other branch" still reads unqualified in the current draft (it is split across
~L187–188), while `CONS-04(2)`, `CONS-11` and `CONS-15(2)` are generation-scoped. With the resolution
live, an honest node will hold old-generation certificates for heights above the restored checkpoint;
the sentence must read "a conflicting **finalized block at `H` under the current generation**", and a
certificate whose signed generation is superseded is not a finalized block for this purpose. Change-list
item, §9 item 3.

### (g) G-7 — `PRF-02(4)` and the withdrawn recovery-restart form (Low) — already re-based, kept

The current `PRF-02(4)` states that the recovery-restart form `REC-04(3)` is a tombstone and that the
anchor fields are read from L1 and judged against the ordinary certificate in every batch. The Low is
closed in the current text; this increment restates the anchor inputs it depends on (the anchor
certificate's generation is pinned by `prevBlockHash`, not by a new journal input, so `PRF-02`'s field
list is unchanged).

---

## 2. Revived rules — exact text

> Normative text below. It replaces the tombstones in `spec/08-migration-upgrades.html` (`GOV-04`),
> `spec/06-recovery-exceptions.html` (`REC-02`–`REC-04`) and the register/index rows listed in §9, and it
> is written as the rules will read in the specification, with identifiers the register and index must
> match. It is **not** a transcription of the preserved text: every clause whose preserved form round 6
> broke is corrected. Values are never invented; every parameter, relation and term is expressed as a
> registered relation or as unmeasured.

### GOV-04 — stall resolution: a timelocked, resume-only governance action whose entry is consumed exactly once

**(a) Trigger, read from L1 state alone.** *(preserved, unchanged.)* An entry may be queued only while
`block.timestamp - lastAcceptedBatchTime >= T_STALL_GOV`, where `lastAcceptedBatchTime` is the L1
timestamp stored in the current checkpoint record (`L1-07`). No invoker claim, evidence object,
certificate or bundle enters the predicate, and only the acceptance of an extending batch — which
advances `lastAcceptedBatchTime` — can clear it. A queue attempt while the predicate is false MUST
revert.

**(b) The entry, and the state machine.** `govResumeState` takes exactly three values:
`none`, `queued`, `executed`. An **entry** is the tuple
`(govResumeQueuedAt:u64, govResumeQueuedHeight:u64, govResumeExecutableAt:u64, govResumeState:u8)`.

- Queueing is a DAO transaction through the authority of `GOV-01` and is the only runtime governance
  entry point this protocol has. It MUST be allowed only while (i) the trigger of (a) holds, and (ii) the
  state is `none`, is `executed`, or is `queued` **and the entry is void** under (e).
- Queueing records `govResumeQueuedAt = block.timestamp`,
  `govResumeQueuedHeight = lastLandedHeight`, `govResumeExecutableAt = block.timestamp + T_GOV_RESUME`
  and `govResumeState = queued`. It names no height, state root, checkpoint, range, subset, beneficiary,
  generation or any other value, and no other value may be attached to it.
- A second queue attempt while a **live** entry is `queued` MUST revert.
- Replacing a void entry under (e) is a new entry with fresh fields; it is not a revival of the void one.

**(c) Execution consumes the entry, and the effect is resume-only.** `execute()` is permissionless and
takes no arguments that influence the outcome. It MUST revert unless the state is exactly `queued`; it
MUST revert before `govResumeExecutableAt` with the error `TimelockNotElapsed`; it MUST revert if the
entry is void under (e). On success it
MUST, in one transaction:

1. increment `recoveryGeneration` by exactly one;
2. set `govResumeState := executed`; and
3. emit the resolution event, carrying at least the restored height and the new generation.

It writes nothing else. `resumeHeight = lastLandedHeight + 1` is derived from the current L1-accepted
checkpoint, never chosen and never stored; the checkpoint record itself is left untouched; nothing at or
below the checkpoint is read, written, re-judged or discarded. **The generation is incremented nowhere
else**: no other function, initialiser, upgrade, governance call, cancellation or client path may
increment it, and no path may increment it while the state is not `queued` or increment it a second
time for one entry. A completed stall resolution is the only sanctioned action on history above the
latest L1-accepted checkpoint: it resumes settlement on the same chain, it may not touch history at or below
the checkpoint (`REC-01`, `L1-06`), and it invalidates a superseded certificate only as a batch's head
evidence, so the range above the checkpoint remains valid history that can be extended under the new
generation *(R5R2-C-01)*.

**(d) The states, and what a caller can and cannot do.** The table is the rule; prose below it is the
same obligation restated.

| State | `queue()` — DAO only | `execute()` — any account | `cancel()` — any account | Generation |
|---|---|---|---|---|
| `none` | allowed iff the trigger holds | reverts `NoQueuedEntry` | reverts `NothingToCancel` | unchanged |
| `queued`, live (`lastLandedHeight = govResumeQueuedHeight`) | reverts `EntryPending` | reverts `TimelockNotElapsed` before the stored deadline; allowed iff `block.timestamp >= govResumeExecutableAt`; consumes the entry, sets `executed` | reverts `EntryNotVoid` | **+1 exactly once**, only on a successful `execute()` |
| `queued`, void (`lastLandedHeight > govResumeQueuedHeight`) | allowed iff the trigger holds; **replaces** the void entry | reverts `EntryVoid` | allowed; sets `none` | unchanged |
| `executed` | allowed iff the trigger holds; starts a **fresh** entry with fresh fields and a fresh stored deadline | **reverts `EntryAlreadyExecuted` for every caller, in every block, with every calldata** | reverts `NothingToCancel` | unchanged |

- In `executed`, no call, no caller, no repetition, no upgrade initialiser and no governance call may
  execute the entry again or increment the generation. The state is terminal for that entry.
- No account may cancel a **live** `queued` entry: the only cancellation is of a void entry, and it
  costs only gas and transfers no value.
- A void entry left in place does not block anything: the next queue replaces it, so the mechanism never
  depends on a canceller showing up.
- An `executed` entry does not block the rotation exclusion of a future `CONS-16` revival beyond the
  period its own entry is live; only a **live `queued`** entry is "pending" for every rule that reads
  the state.

**(e) Void on progress, with permissionless cancellation and queue-over-void.** If the checkpoint
advances at any time before execution — `lastLandedHeight > govResumeQueuedHeight` — the entry is
**void**: execution MUST revert, and any account may cancel it, which sets `none` and clears the entry.
A void entry cannot be revived and a cancelled entry's fields are not reusable; a new entry requires a
fresh trigger and a fresh stored deadline. **A new queue while the trigger holds MUST be permitted to
replace a void entry**, because a void entry is not pending. No account may cancel an entry whose trigger
still holds and whose checkpoint has not advanced.

**(f) Timelock: the notice window, and what it is not.** A queued entry becomes executable no earlier
than its stored `govResumeExecutableAt`.

- **The window the rule can guarantee.** For a user whose L2→L1 signal is included in the L2 state **at
  or below the last accepted checkpoint at queue time**, the window is a real exit window: execution
  leaves the checkpoint record untouched, nothing at or below it is rewritten (`REC-01`), and the exit of
  `MEM-15` from that checkpoint — including the withdrawal root of `L1-13`, which `L1-13(1)`/`(3)` make
  attestable for **any already-accepted checkpoint, in particular the latest one**, with no new L2 block
  and no settlement progress, its delay measured on the L1 clock from the root's own record — remains
  available before, during and after execution. The required length is the registered relation
  `T_GOV_RESUME >= W_root + WITHDRAWAL_DELAY + T_VETO + MARGIN`, where `W_root` is the worst-case time to
  produce and record the checkpoint's `k` attestations; every term is **unmeasured** and `MARGIN` is a
  stated, unmeasured margin. The relation is a constructor-time assertion under (g) and is conditional on
  the funded proving market and retained inputs of `MEM-15(2b)`.
- **What the window is not.** It is **not** an exit window for value above the last accepted checkpoint.
  Such value has no L1-provable claim and cannot create one (`MEM-15(4)`), and the execution discards it.
  No value of `T_GOV_RESUME` changes that, because the claim does not exist on L1 and no rule may
  manufacture one. What a holder above the checkpoint has is the boundary's prior statement that the
  range was provisional (`REC-01`), the notice the queued entry gives, and the remedy of resubmitting
  their transactions after the resolution; protocol penalties compensate nothing (`ECON-11`).
- **Execution removes no claim at or below the checkpoint.** A user who does not complete the exit inside
  the window can still complete it afterwards from the same checkpoint: the root remains attestable and
  the delay keeps running. The window is therefore a notice-and-opportunity window; what protects that
  class's value is the boundary, not the window.
- The sentence "the timelock gives **every** user the exit window of `MEM-15`" is **withdrawn** wherever
  it appears. The correct sentence is: "the timelock is the notice window of the resolution and the exit
  window of `MEM-15` for value already messaged at or below the last accepted checkpoint, under
  `MEM-15(2b)`'s proving dependencies; no user above the checkpoint has a claim for a window to protect."

**(g) The window is bound to the entry, and the relations are enforced where a value is set.**
`govResumeExecutableAt` is recorded at queue time and is part of the entry: no upgrade, initialiser,
parameter change, governance call or client path may move it, shorten it, extend it or recompute it, and
a change to `T_GOV_RESUME` applies only to entries queued after it (`GOV-03(e)`). An implementation MUST
refuse to initialise unless the registered relations hold —
`T_STALL_GOV > T_PROOF_ENVELOPE + T_SETTLE_PIPELINE` (strictly larger than the D6 envelope, so a normal
slow proof or one prover failure cannot make the trigger true) and
`T_GOV_RESUME >= W_root + WITHDRAWAL_DELAY + T_VETO + MARGIN` (the relation of (f), whose terms are
unmeasured). A change to either value is a **rules change** and MUST be published as one under `GOV-02`;
it is not a silent parameter move, and the *Resume-only* description MUST NOT claim that governance
chooses no configuration value.

**(h) The generation is a signed field, not a retirement record.** *(preserved, with the two-case rule
of §5.)* `recoveryGeneration` is a field of the signed vote and block-header bytes, so validators sign
the generation they are certifying under; the action of (c) increments it; validators sign the new
generation; a batch extending the checkpoint MUST carry the current generation in its head certificate,
in every contributing vote and in the head header — no other header's generation is compared with the
current generation, and a header produced under an earlier generation is not invalid for it
(`CONS-10(7)`) *(R5R2-C-01)*; a certificate at or below the checkpoint MUST carry the
generation of the block it certifies and MUST NOT be compared with the current generation. No height is
retired, no retirement record exists, and no `max(lastLandedHeight + 1, resumeHeight)` form survives.

**(i) Disclosed assumptions.** *(preserved, sharpened.)* Clearing a settlement stall depends on
governance liveness with no protocol bound: the trigger fixes when an entry may be queued, not that it
will be. A captured or coerced governance can also act opportunistically within this rule, waiting for a
genuine stall and having an unfavourable provisional range's in-flight certificates superseded, so its
signals are not carried into the settlement the resumed chain produces and must be resubmitted
*(R5R2-C-01)*; and a **live** governance can queue
a fresh entry as soon as one has executed (the trigger still holds, because execution does not advance
the checkpoint), so generations can be churned at up to one per stored window. Each churn costs a DAO
transaction and a full window; none of it is permissionless. The assumption is named `A-GOV-2` and is
recorded in `LIM-01`.

**(j) Upgrade survival.** *(extends `GOV-03(e)`.)* A queued entry MUST survive an upgrade unchanged: the
upgrade may not cancel it, execute it early, alter the checkpoint it resumes from, move its stored
deadline, or replace it with any other action. An **executed** entry MUST survive an upgrade unchanged:
no upgrade may set its state back to `queued` or `none`, re-open it, or make it executable again, and no
upgrade may reset, lower or skip `recoveryGeneration`. The generation and the entry state are L1 state
that carries with the L1 reorganisation (`L1-12`, `SYS-02`): an execution reorganised out never took
effect, so the entry returns to `queued` with its stored deadline and the generation returns to its
previous value; an acceptance reorganised out un-voids a live entry in the same way.

### CONS-05(2) — which generation a certificate must carry

*(New clause; `CONS-05`'s tuple, quorum and signature predicate are unchanged.)*

**(a) Head certificate.** A certificate presented as the finality evidence of a batch extending the
current checkpoint is valid only if its `recovery_generation` equals the generation the Inbox holds at
acceptance, every contributing vote's generation equals it, and the head header's generation equals it
(`CONS-01(vii)`, `CONS-10(7)`, `PRF-04(i)`), in addition to the epoch, set-root and quorum conditions
`CONS-05` already states.

**(b) Historical certificate.** A certificate for a block at or below the last accepted checkpoint is
valid only if its `recovery_generation` equals the generation carried by that block's **own header**, and
every contributing vote's generation equals the same value. It MUST NOT be compared with the generation
the Inbox holds. The relation `certificate generation <= current generation` holds and MUST be checked;
it is a consequence of `recoveryGeneration` being monotone (`GOV-04(c)`, `GOV-03(e)`) and of the block
having been produced before the checkpoint was accepted. The value is not witness-supplied: the block's
header bytes are pinned to L1 by the checkpoint record's `blockHash` (`prevBlockHash`, `L1-05` row 4,
`L1-07`), so the generation is read from bytes L1 already commits to.

**(c) Halt sentence (closes G-6).** `CONS-05`'s sentence on a conflicting lock or a conflicting
finalized block MUST be scoped: "A node that instead holds a conflicting lock at `H` (`CONS-04`) or a
conflicting **finalized block at `H` under the current generation** has evidence that the assumptions
failed; it halts (`CONS-15`) and MUST NOT silently adopt the other branch." A certificate whose signed
generation is superseded is not a finalized block for this purpose, exactly as `CONS-04(2)` and
`CONS-15(2)` already state.

### CONS-08(1), CONS-10(7), CONS-12 — the constant-generation assumption is retired

- **`CONS-08(1)`**: "the generation MUST equal the generation the Inbox holds" is scoped to the
  certificate's own height: current generation for a block above the last accepted checkpoint, the
  block's own header generation for a block at or below it (`CONS-05(2)`).
- **`CONS-10(7)`**: unchanged as a **production** rule — every new header MUST carry the current
  generation for the height being built, and no new block may be produced at or below the checkpoint —
  with one added sentence: a **historical** header's generation field is read as part of that header's
  bytes and is judged under `CONS-05(2)(b)`; the guest does not compare it with the current generation.
- **`CONS-12`**: the paragraph "The invariant is unconditional in v1" is retired with the revival. The
  operative form is the generation-scoped invariant: **at most one block per height per generation
  receives a valid certificate, a certificate whose signed generation has been superseded is void at the
  acceptance rule, and heights above the last accepted checkpoint may be re-produced under a new
  generation.** At or below the last accepted checkpoint no path may change the history at all. Every
  rule that the draft keeps as "dormant"/"historical" under the constant-generation reading becomes live
  in exactly the form it already carries: `CONS-04(2)` (a lock formed under a superseded generation is
  void at every height above the restored checkpoint and is not a halt condition; R5R2-C-01: the range is superseded, not erased), `CONS-11` (a pair whose signed
  generations differ is not a conflict), `CONS-15(2)` (the halt trigger is a certificate conflicting
  with the lock under the current generation), and `CONS-02`'s signing-store scoping (a resolution's
  scoping change disregards superseded-generation entries for **new signing** and never erases the
  record of what was signed; the store MUST NOT be cleared — `R9-CC-02` anticipates exactly this
  revival).

### PRF-04(i) / PRF-05(ii)(a) — the anchor certificate's generation

- **`PRF-04(i)`** keeps the head rule: every contributing vote's generation MUST equal the journal's
  `recoveryGeneration` and the head header's generation.
- **`PRF-05(ii)(a)`** is amended to read: the certificate MUST be a valid epoch-`(e−1)` commit
  certificate for `B_anchor` under the L1-pinned `anchorSetRoot` and `anchorSetTotalVotingPower`, under
  the same signature, distinct-signer and quorum checks as `PRF-04(i)`–(iii) **except that the
  generation equality is the historical case of `CONS-05(2)(b)`**: every contributing vote's generation
  and the certificate's own generation MUST equal the generation carried by `B_anchor`'s own header,
  and MUST NOT be compared with the journal's `recoveryGeneration`; `cert_hash` MUST recompute into the
  header's `epoch_anchor` (`CONS-10(6)`); and the guest MUST reject the block if either check fails.
- `B_anchor` itself is pinned as it already is: its header hash MUST equal `prevBlockHash` (`L1-05`
  row 4, `L1-07`), and the first header of the batch MUST carry `parent_hash = prevBlockHash`
  (`PRF-04(v)`).

### FI-14 — forced inclusion is not touched by a resolution

*(New clause; replaces the "no recovery path in v1" sentences of `FI-14(2)` and the four preserved
"across an executed stall resolution" clauses that increment 04 deleted for lack of a mechanism.)*

An executed stall resolution MUST NOT read, write, clear, re-order, re-clock or suppress any publication
record, the settlement frontier, the prune cursor, `forcedBoundary`, or any `FI_*` state; it MUST NOT
resolve, discharge or void any register position; it MUST NOT change any record's due point or deadline
(the deadline is derived from the record's own `l1BlockNumber` and `T_PROVE_DEADLINE`, both L1 facts, and
is unaffected by an L2 discard); and it MUST NOT make a proof of any range unprovable. The first batch
accepted after a resolution MUST satisfy the inclusion obligation exactly as any other batch, with the
frontier `c` and the due frontier computed from the register at its own anchored view. This holds
structurally: the resolution writes only the generation and the entry state, and the register and
frontier are L1 state the resolution never reads.

### MEM-15 — the exit is never gated by a resolution

*(New sentence in `MEM-15(5)`; `MEM-15(1)`–(4) are unchanged.)*

A stall resolution MUST NOT gate, delay, accelerate or condition a withdrawal root's formation,
`attestWithdrawalRoot`, the `k`-family verification, the veto, or a user's eligibility to withdraw; the
withdrawal path MUST NOT read `govResumeState`, `govResumeQueuedAt`, `govResumeQueuedHeight`,
`govResumeExecutableAt` or `recoveryGeneration`. Because execution leaves the checkpoint record
untouched, a root for the restored checkpoint remains attestable after execution (`L1-13(3)`), so the
resolution cannot strand a signal at or below it even for a user who acts after the window closes.

### CONS-16 — mutual exclusion, re-derived for a future revival (not revived here)

`CONS-16` stays deferred by D-16 and `MUST NOT` be implemented. When it is ever revived, its exclusion
clause MUST read "while a stall-resolution entry is **live `queued`**": an `executed`, cancelled or void
entry MUST NOT block the rotation. This increment records the re-derivation so the revived rotation does
not read the withdrawn `none/queued` model.

---

## 3. The entry state machine

### 3.1 Objects

- `govResumeState : u8 ∈ {none=0, queued=1, executed=2}`.
- `govResumeQueuedAt : u64` — the queueing transaction's `block.timestamp`.
- `govResumeQueuedHeight : u64` — `lastLandedHeight` at queue time; the void test reads it.
- `govResumeExecutableAt : u64` — `govResumeQueuedAt + T_GOV_RESUME`, recorded at queue time; the
  timelock test reads it and nothing recomputes it.
- `recoveryGeneration : u64` — the one global counter; incremented only by a successful `execute()`.

**Storage consequence, stated for the migration audit (no value is chosen here).** The preserved
`MIG-02` packing note records slot 268 as holding `recoveryGeneration` + `govResumeQueuedAt` +
`govResumeQueuedHeight` + `govResumeState` + `paramVersion` = 27 of 32 bytes. The entry now carries one
additional `u64` (`govResumeExecutableAt`), so the packing MUST be re-derived: it cannot be assumed to
fit the same 32-byte word, and it MUST NOT be carved out of a deprecated slot. The migration audit owns
the layout; this delta only records that the field exists and why.

### 3.2 Transition table

| From | Event | Check | To | Writes |
|---|---|---|---|---|
| `none` | `queue()` | trigger holds | `queued` | the four entry fields |
| `executed` | `queue()` | trigger holds | `queued` | the four entry fields (a fresh entry) |
| `queued` (void) | `queue()` | trigger holds | `queued` | the four entry fields (replaces the void entry) |
| `queued` (live) | `queue()` | — | reverts `EntryPending` | none |
| `queued` | `cancel()` | void | `none` | clears the entry fields |
| `queued` (live) | `cancel()` | — | reverts `EntryNotVoid` | none |
| `executed` | `cancel()` | — | reverts `NothingToCancel` | none |
| `none` | `execute()` | — | reverts `NoQueuedEntry` | none |
| `executed` | `execute()` | — | reverts `EntryAlreadyExecuted` | none |
| `queued` (void) | `execute()` | — | reverts `EntryVoid` | none |
| `queued` (live) | `execute()` | `block.timestamp < govResumeExecutableAt` | reverts `TimelockNotElapsed` | none |
| `queued` (live) | `execute()` | all checks pass | `executed` | `recoveryGeneration += 1`, state `executed`, event |

No other transition exists. There is no `queue()` from a live `queued` state, no `execute()` from
`executed`, no `cancel()` of a live entry, and no path that writes the generation outside the last row.

*(F2 (boundary-and-shipped) / R5R1-G-03(a) / R5R1-NR-04: correction — the grouped table above previously folded `none` and `executed` together under
`NoQueuedEntry`; that was stale delta bookkeeping, not a rule. The artifact was already correct: the
implemented state table of [`spec/08`](../spec/08-migration-upgrades.html) and §2(d)'s four-error table
both give `none` → `NoQueuedEntry` and `executed` → `EntryAlreadyExecuted` for every caller, in every
block, with every calldata, and the two rows above now agree with both.)*

*(R5R1-G-03(b): the pre-deadline revert is named `TimelockNotElapsed` in §2(c) and the §2(d) table,
and the applied rule names it in `spec/08`'s `GOV-04`(c)/(d); the name is no longer delta-only and the
delta and the rule agree on one name.)*

### 3.3 Invariants

1. **SM-1 (single-writer).** `recoveryGeneration` is incremented in exactly one code path: the
   successful `execute()` transition from live `queued` to `executed`, in the same transaction that
   writes `executed`.
2. **SM-2 (one execution per entry).** For a given entry instance (the four stored fields as a tuple),
   at most one successful `execute()` exists in any L1 state.
3. **SM-3 (terminal executed).** In `executed`, every `execute()` reverts for every caller in every
   block, with every calldata; `cancel()` reverts; the state can only be left by a `queue()` that
   creates a **fresh** entry with a fresh stored deadline. No upgrade may violate SM-3 (`GOV-04(j)`).
4. **SM-4 (stored deadline).** The timelock test reads `govResumeExecutableAt` only; no rule, upgrade or
   client recomputes it from `T_GOV_RESUME` after queueing.
5. **SM-5 (void is replaceable).** A void entry blocks nothing: it may be cancelled by any account or
   replaced by the next valid queue.
6. **SM-6 (reorg consistency).** All five objects carry with L1 state (`L1-12`, `SYS-02`): an execution
   reorged out returns the state to `queued` and the generation to its prior value, and an acceptance
   reorged out un-voids a live entry; no partial state exists and no increment is duplicated or lost.
7. **SM-7 (trigger monotonicity).** The trigger of `GOV-04(a)` can become false only by a batch
   acceptance, which voids the entry under `GOV-04(e)`; therefore no live entry can be executed at a
   moment when the trigger that justified it no longer holds. Execution MAY re-check the trigger and
   MUST NOT be required to reconstruct anything beyond the stored fields.

### 3.4 Why the permissionless loop is dead

The attack of G-1 needs `execute()` to be callable twice on one entry. SM-1–SM-3 remove every route: the
first call sets `executed`, the second reverts before any state write, the generation has no other
writer, and the only way back to `queued` is a DAO transaction that also replaces the deadline. The
cheapest repetition available to any account is therefore zero.

---

## 4. The exit window, stated exactly (G-2)

### 4.1 The three classes of value

| Class | Where the claim lives | What the resolution does | What protects it |
|---|---|---|---|
| **A. Messaged signal, `h <= H`** (`h` = signal height, `H` = last accepted checkpoint at queue time) | L2 state at or below `H`; releasable through a withdrawal root at any height `>= h` (`MSG-03`, `L1-13(2)`) | Nothing: `H`'s record is untouched, the root for `H` stays attestable, the delay keeps running | The boundary (`REC-01`) and the exit path; the window `[queue, govResumeExecutableAt]` is a real opportunity to complete it, and missing the window costs nothing |
| **B. Unmessaged L2 balance at or below `H`** | None on L1 (a withdrawal must be started by an L2 transaction) | Nothing at or below `H`; the balance is untouched | Nothing changes for it; it was never covered by `MEM-15(1)`'s guarantee and it is not discarded |
| **C. Value or signal above `H`** | Provisional only; no L1-provable claim (`MEM-15(4)`) | Discarded in full | **Nothing.** No window can protect it, because no claim exists on L1 to protect |

The inherited guarantee of class A is `L1-13(3)`'s: any already-accepted checkpoint, and in particular
the latest one, is attestable with no new L2 block and no settlement progress, and the delay runs on the
L1 clock from the root's own record. The delta depends on that repair (round 7) and does not re-open it.

### 4.2 The registered relation, and its condition

`T_GOV_RESUME >= W_root + WITHDRAWAL_DELAY + T_VETO + MARGIN`, where `W_root` is the worst-case time to
produce and record the `k` attestations of the last accepted checkpoint's withdrawal root (the `k−1`
additional proofs are funded proving work under `L1-13(5)`, and `k` is fixed by the S1 measurement),
`WITHDRAWAL_DELAY` is measured from the root's own record, `T_VETO` is the maximum veto extension, and
`MARGIN` is a stated, unmeasured margin. The relation is a **constructor-time assertion**: an
implementation that does not satisfy it MUST refuse to initialise. Every term is unmeasured; Phase B
measures them. The relation is **conditional** on `MEM-15(2b)`'s two dependencies — a funded proving
market and retained inputs — and this condition is stated wherever the window is summarised. Every
term is registered in [`spec/09`](../spec/09-parameters.html)'s parameter table: `W_root` and `MARGIN`
each have their own row there, with `REC-02` as owner and an unmeasured tag, alongside
`WITHDRAWAL_DELAY` and `T_VETO` *(F1: the relation is read from those rows, so a reader who looks up a
term finds a row of its own rather than an inline definition inside another row)*.

### 4.3 What a user still above the checkpoint has, stated plainly

They have the boundary's prior disclosure that a confirmation above the latest accepted checkpoint is
provisional (`REC-01`, `STATUS-04`/`STATUS-06`), the notice that the queued entry and the trigger window
give, and the remedy of resubmitting their transactions after the resolution — with no protocol
compensation (`ECON-11`) and no guarantee of inclusion. That is the whole of it. Any artifact that says
otherwise — that the timelock lets "every user" exit, or that a holder above the checkpoint can be made
whole by waiting — falsifies this delta.

---

## 5. The generation rule: why the first post-resolution epoch-opening batch is provable (G-3)

### 5.1 The rule, in one paragraph

A certificate carries the generation of the history it certifies. A batch that **extends the current
checkpoint** is new history: its head header, its votes and its head certificate MUST carry the current
generation `g_now`, and only such a certificate can be its finality evidence. The constraint is on the
head certificate, its contributing votes and the head header; no other header's generation is compared
with `g_now`, and a header produced under an earlier generation is not thereby invalid (`CONS-10(7)`)
*(R5R2-C-01)*. A block **at or below the
last accepted checkpoint** is settled history: a certificate for it MUST carry the generation in that
block's own header, and MUST NOT be compared with `g_now`. The anchor certificate of an epoch-opening
batch is judged by the second rule, because `B_anchor` is the predecessor block at `prevHeight =
lastLandedHeight` and that height is at or below the checkpoint by construction.

### 5.2 The post-resolution shape, derived

Let the last accepted checkpoint be at height `H` with generation `g`, and let a resolution execute
(entry consumed, `g_now = g+1`).

1. `H` is unchanged: execution writes no checkpoint. `B_anchor` for any batch starting at `H + 1` is the
   block at `H`, whose header carries `g` — it was produced under `g` and is immutable.
2. If `H + 1` is not the first height of its epoch, the batch carries no anchor duty; its head
   certificate, head header and votes carry `g+1`, satisfy `CONS-05(2)(a)` and `PRF-04(i)`, and land.
3. If `H + 1` **is** the first height of its epoch (the restart height is routinely an epoch boundary),
   the batch must carry `epoch_anchor`. The guest:
   - pins `B_anchor` by `hash(B_anchor) = prevBlockHash` (L1-07's checkpoint record, `L1-05` row 4);
   - reads `B_anchor.header.recovery_generation = g` from those pinned bytes;
   - verifies the epoch-`(e−1)` certificate under `CONS-05(2)(b)`: certificate generation = `g`, every
     contributing vote's generation = `g`, signatures/quorum against the L1-pinned `anchorSetRoot` and
     `anchorSetTotalVotingPower` — **no comparison with `g+1`**;
   - recomputes `cert_hash` into `epoch_anchor` (`CONS-10(6)`), which itself commits the generation;
   - verifies the batch's own head certificate, head header and votes under `CONS-05(2)(a)` with `g+1`.
   The two checks read two different objects (the historical anchor vs. the current batch), so both are
   satisfiable in the same proof.
4. **What the generation rule rejects, exactly.** *R5R2-C-01: the earlier form of this step said a
   discarded block "would have to be the head of a batch extending the checkpoint"; the enforced effect is
   narrower — a superseded certificate cannot be head evidence, and the range stays landable as ancestors.*
   A certificate that carries the superseded generation cannot be the **head certificate** of a batch
   extending the checkpoint (`CONS-05(2)(a)`: the head certificate, every contributing vote and the head
   header must carry the current generation). It does **not** follow that the range above `H` is discarded
   or unlandable: a block above `H` is not invalidated by the generation in its own header
   (`CONS-10(7)`), so a batch may carry it as an **ancestor** and settle it with a head produced and
   certified under `g+1`. The superseded range remains valid history that the resumed chain extends; what
   it loses is the ability to supply the head evidence, and the signals in it are not carried into the
   settlement the resumed chain produces, so they must be resubmitted. It cannot be masqueraded as the
   anchor, because the anchor is pinned by L1 to the block at `H`, which the resolution leaves untouched.
5. **Robustness to repetition and to reorgs.** A second resolution changes `g_now` but not the bytes of
   `B_anchor`'s header, so the anchor case is judged under the same `g` however many resolutions run;
   no "previous generation" value or per-checkpoint generation record is needed. An L1 reorg carries the
   generation and the entry state with it (SM-6).

### 5.3 What is deliberately not required

No new journal input, no `L1-05` row and no checkpoint-record field: the anchor header's hash is already
committed by `prevBlockHash`, and `cert_hash`/`epoch_anchor` already commit the certificate's generation.
The alternative — storing the generation in the checkpoint record — is not needed and would change
`L1-07`'s encoding; this delta does not require it and does not forbid a future increment from adding it
with its own migration accounting.

---

## 6. Interaction with what has shipped since D-15

### 6.1 v1's checkpoint boundary (`REC-01`)

Unchanged and load-bearing. The resolution reads the checkpoint, writes none, and leaves the range above
it valid history rather than erasing it: nothing at or below the checkpoint is read, written, re-judged or
delayed, a superseded certificate cannot be a batch's head evidence, and the range above the checkpoint
can be extended under the new generation *(R5R2-C-01)*. The resolution is the
**only** sanctioned action on the range above the checkpoint (`REC-01(d)`, `GOV-03(e)`); an upgrade still may not
perform it.

### 6.2 Increment 2's constant-generation assumption (`MEM-13` / `CONS-12`)

- **`MEM-13` reads no generation.** Its predicate is a function of L1 block heights, the heartbeat
  records, the activation record and registered windows; it reads no settlement state, no checkpoint
  height and no entry state. The resolution changes nothing in roster selection: the resumed heights sit
  at the same heights, `epoch_of(height)` is a pure function of height (`CONS-13`), and a committed set
  version is immutable (`CONS-08`). Increment 02's rules are generation-independent; this increment
  states that rather than changing them. **Falsifier:** an implementation that re-evaluates a committed
  version's roster after a resolution, or that lets the generation enter the eligibility predicate,
  falsifies this.
- **`CONS-12`'s unconditional paragraph is retired** (see §2). The generation-scoped invariant becomes
  operative, and the rules the draft kept as "dormant" (`CONS-04(2)`, `CONS-11`, `CONS-15(2)`,
  `CONS-02`'s store scoping) become live in exactly the form they already carry. The signing store MUST
  NOT be cleared by a resolution; a resolution's scoping change only disregards superseded-generation
  entries for new signing.
- **`CONS-16` stays deferred** (D-16/D-17 untouched). The revival of the generation does not supply its
  `h_close` referent, and this increment does not revive it.

### 6.3 Increment 4's forced-inclusion obligation (`FI-10`–`FI-14`)

The obligation must not be reset, re-clocked, stalled or made unprovable by a resolution. The rule is
§2's `FI-14` clause, and it holds structurally: the register, the settlement frontier, the prune cursor
and `forcedBoundary` are L1 state a resolution never reads or writes; deadlines are L1-block-derived and
unaffected by a generation change; and the first post-resolution batch is judged against the register at its
own anchored view exactly as any other batch. A position that was resolved by a batch whose range is
later superseded is **not** un-resolved in the register — the register holds no per-height resolution —
so the new range must resolve the same prefix, and the walk applies unchanged. Conversely, the `FI_*`
obligation gates no resolution state: the trigger and the entry read only the checkpoint clock and the
checkpoint height.

### 6.4 The exit (`MEM-15`)

Unchanged and never gated (§2's `MEM-15` clause, §4). The resolution removes no claim at or below the
checkpoint; the root from the restored checkpoint remains attestable after execution; the exit's two
dependencies (`MEM-15(2b)`) are the same before, during and after a resolution. The one thing this
increment changes about the exit is the **claim** attached to the timelock: it is scoped to class A and
conditional on those dependencies.

### 6.5 Everything else

No change to: `MSG-01`–`MSG-04`, `DA-01`–`DA-10`, `L1-01`–`L1-13`, `PRF-01`–`PRF-14`, `ECON-02`'s
funding shares and destinations (D-8/D-9), `ECON-11`, the consensus core (`CONS-01`–`CONS-16` other than
the scoping above), membership rules, the migration boundary, or the recovery-free statements' scope
(this increment is the sanctioned exception, and every "no recovery path of any kind" sentence in the
draft must be re-based to name it — §9).

---

## 7. Falsifiers, honest costs, and what this increment does not fix

### 7.1 Falsifiers

| ID | Statement | Status | What would close it |
|---|---|---|---|
| **F-GOV-1** | Clearing a stall depends on governance liveness with no protocol bound: if governance never queues, or queues and never has the entry executed, the stall persists and the chain stays halted. A captured or coerced governance can also wait for a genuine stall and have an unfavourable provisional range's in-flight certificates superseded, so its signals are not carried into the settlement the resumed chain produces and must be resubmitted (R5R2-C-01). | **Open** (carried; the same class as `A-GOV-2`/F2) | Nothing in-protocol; a bound would require a different trust model. This is the price D-15 chose over a permissionless recovery. |
| **F-GOV-2** | The window relation of `GOV-04(f)` is unmeasured and conditional: `W_root` (the worst-case time to produce and record the checkpoint's `k` attestations), `WITHDRAWAL_DELAY`, `T_VETO` and `MARGIN` are Phase-B measurements, and an unfunded proving market or unretained inputs (`MEM-15(2b)`) can make the window unattainable for class A. | **Open** (unmeasured; inherited condition) | Phase B's exit-time measurement against the recorded value, and a funded proving market with retained inputs. Note that the window is not load-bearing for class A's value: missing it costs nothing, because execution removes no claim at or below the checkpoint. |
| **F-GOV-3** | Governance-driven churn: after an execution the trigger still holds (the checkpoint did not advance), so a live governance can queue a fresh entry and increment the generation again once per stored window, voiding the in-flight certificates and proofs of the then-current provisional range each time. Only governance can pay it, and each increment costs a DAO transaction plus a full window. | **Disclosed** (the residue of closing G-1 by consumption; same actor class as F2) | A "progress-earned" queue rule — e.g. no new entry until the checkpoint advances past the previous execution's restore point — would remove the pure churn, but it **deadlocks** the case this mechanism exists for: a certified-but-unprovable range above a stationary checkpoint needs the next generation to be discarded, and L1 cannot decide whether such a range exists (the `h_close` referent class that gates `CONS-16`, F7). The candidate is recorded and **not adopted**; §10.1 returns it to the owner. |
| **F-GOV-4** | Future-entry parameter discretion: one published rules change may move `T_STALL_GOV` and `T_GOV_RESUME` to their conforming minima for entries queued afterwards. The queue entry's own deadline is now stored and protected, and the relations are constructor-asserted, but the choice of future values is governance policy. | **Disclosed** (named; `GOV-02` requires the change to be published as a rules change) | A registered floor stronger than the stated relations, or an explicit owner decision that the discretion is acceptable. The relation's minimum is the D6 envelope plus the window relation; both terms are unmeasured. |
| **F-GOV-5** | The anchor-generation rule depends on the deployment pinning `B_anchor`: if `prevBlockHash` were not the anchor header's hash, or a client compared the anchor certificate against the current generation, the first post-resolution epoch-opening batch would be unprovable or the anchor equality would be witness-supplied. | **Open** (implementation-verified) | The acceptance tests of §9 item 16: (i) the first post-resolution epoch-opening batch verifies; (ii) a certificate whose generation differs from `B_anchor`'s header generation is rejected; (iii) a client that compares the anchor against the current generation fails the conformance vector. |
| **F-GOV-6** | A resolution could be implemented so that it re-clocks a publication record, lowers the settlement frontier, gates a withdrawal root, or delays the exit — the non-interaction clauses of §2 would be violated. | **Open** (implementation-verified) | The conformance vectors of §9 item 16: a resolution executes between two accepted batches and the register, frontier, `forcedBoundary`, root attestation, veto and exit eligibility are byte-identical except for the generation and the entry state. |

### 7.2 Honest costs

1. **One DAO transaction per entry** (queueing) plus the executing transaction's gas, paid by whoever
   executes; no reward, no bond, no refund, no treasury transfer.
2. **One additional stored field** (`govResumeExecutableAt`) and the slot-268 re-derivation (§3.1);
   the migration audit owns the layout and MUST NOT carve it from a deprecated slot.
3. **One generation increment per execution**, with the consequences already stated (in-flight proofs
   of the then-current provisional range are rejected at acceptance and its certificates cannot serve as a
   batch's head evidence, while the range remains valid history that must be extended under the new
   generation; transactions above the checkpoint must be resubmitted). *(R5R2-C-01: the range is not
   erased.)*
4. **No new entry point anywhere else**: the resolution adds no function to the exit path, the inclusion
   path, the staking path or the proof path.

### 7.3 What this increment does NOT fix

1. An unavailable quorum: the resolution changes no set, manufactures no quorum and cannot clear a
   quorum-loss halt.
2. Unavailable data: it cannot make data available or force an unpublished or L1-censored publication.
3. An economics stall: it changes no fee, reward or subsidy and must never be presented as the remedy
   for an unfunded landing market (`ECON-02`).
4. Class C value above the checkpoint: no window, no compensation, no protection (by design).
5. Governance liveness and governance-driven churn (F-GOV-1, F-GOV-3).
6. Any measurement: every new or reinstated value, relation and term is unmeasured.

---

## 8. What the mechanism does NOT do

- It does **not** give any account a recovery entry point: queueing is a DAO transaction; execution is
  permissionless only over an entry that already exists and is live and past its stored deadline.
- It does **not** let any caller choose anything: `execute()` takes no outcome-affecting argument, and
  the entry names no height, state, checkpoint, range, subset, set, beneficiary or generation.
- It does **not** rewrite, re-judge or delay history at or below the last accepted checkpoint.
- It does **not** create a bond, a reward, an escrow, a fee, a treasury transfer or a slashable offence.
- It does **not** reduce, discount or remove any validator's weight, and it does not rotate a set.
- It does **not** gate, delay or accelerate the exit, the withdrawal root, the veto, forced inclusion,
  settlement, staking exits or `land`.
- It does **not** retire a height, store a resume point, keep a record of any block, or erase the range
  above the checkpoint; it invalidates a superseded certificate only as a batch's head evidence
  *(R5R2-C-01)*.
- It does **not** bound the number of resolutions by protocol rule; the pacing is the DAO transaction
  plus the stored window (F-GOV-3, disclosed).
- It does **not** revive `CONS-16` or aggregation, and it does not supply the `h_close` referent.
- It does **not** promise that a resolution will ever be queued, executed or needed.

---

## 9. What this increment changes outside the revived rules (listed, not made)

Every item below is a required change for the increment to be consistent; **items 1–15 have been made**
by the implementation pass and **item 16 remains the review round's test obligation**. Line anchors are
approximate and refer to the draft the delta was written against.

1. **`spec/08-migration-upgrades.html`**
   - `GOV-04` tombstone (~L782): replaced by §2's rule text, with the three-state machine, the stored
     deadline, the exit-window scope, the constructor assertions and the upgrade-survival clause.
   - `GOV-03(e)` (~L761): extended — a queued **and an executed** entry survive an upgrade; no upgrade
     may reset the generation, re-open an executed entry or move a stored deadline; the "upgrade cannot
     clear a stall" sentence is re-based, because the rule now specifies the action.
   - `MIG-02` (~L224, slot-268 note ~L250): re-derive the slot-268 packing and the declaration count for
     the added `govResumeExecutableAt`; do not reuse a deprecated slot.
2. **`spec/06-recovery-exceptions.html`**
   - `REC-02` tombstone (~L401): revived as the entry/effect/timelock table in the corrected form —
     state machine, scoped exit window, stored deadline, named parameter discretion.
   - `REC-03` tombstone (~L423): revived analysis with the corrected falsifiers `(a)`–`(h)`, replacing
     falsifier `(c)` ("a measured worst-case exit time exceeds `T_GOV_RESUME`") with the **structural**
     window relation and the F-GOV falsifier set; residual (6) (repetition) is re-based on F-GOV-3.
   - `REC-04` tombstone (~L444): revived as the ordinary-linkage clause, with the anchor generation
     read under `CONS-05(2)(b)`; the recovery anchor stays withdrawn.
   - `REC-01` (~L42): unchanged; its "only the stall-resolution path may replace above the checkpoint"
     sentence becomes live again.
   - `HALT-01` (~L100), `HALT-02` (~L148), `HALT-04` (~L235): re-base the "no recovery path of any
     kind / no exception" sentences so the one named exception is the revived `GOV-04`, with its
     trigger, timelock, consumed entry and resume-only effect.
3. **`spec/02-consensus.html`**
   - `CONS-05` (~L177–180): add the two-case validity clause `CONS-05(2)`; scope the halt sentence
     (~L187–188) with "under the current generation" (closes G-6).
   - `CONS-08(1)` (~L242–243): scope the generation equality by height.
   - `CONS-09(1)`/`(2)` (~L261–269): "v1 has no restart after a resolution" sentences re-based; the
     ordinary anchor duty applies with `B_anchor` the restored checkpoint block.
   - `CONS-10(6)` (~L344): unchanged; `CONS-10(7)` (~L360): add the historical-header sentence.
   - `CONS-12` (~L393–394): retire "the invariant is unconditional in v1"; state the generation-scoped
     invariant and the re-production of heights above the checkpoint.
   - `CONS-04` (~L145–160), `CONS-11` (~L365–369), `CONS-15(2)` (~L494): the "dormant in v1" scoping
     becomes live; remove the "no generation is superseded in v1" assertions.
   - `CONS-01(vii)` (~L73) and the `ECON-04` reference in `CONS-01`'s offence scope (~L76): keep the
     generation check as a validity condition; **no new slashable offence** is created (a superseded-
     generation proposal is invalid, and the rejected proposal is the whole enforcement).
   - `CONS-16` (~L505): tombstone unchanged; add the live-`queued`-only exclusion note for a future
     revival.
4. **`spec/05-proof-statement.html`**
   - `PRF-04(i)` (~L244–250): keep the head rule; split out the historical rule and cross-reference
     `CONS-05(2)`.
   - `PRF-05(ii)(a)` (~L279–283): the anchor certificate is judged under `B_anchor`'s own header
     generation; `cert_hash` must recompute into `epoch_anchor`; the current generation is not compared.
   - `PRF-02(4)` (~L194): state that the anchor certificate's generation is pinned by `prevBlockHash`
     (no new journal input, no new `L1-05` row).
5. **`spec/04-l1-integration.html`**
   - `L1-05` row 31 (~L207): restate as a live, signed, L1-derived value with the two-case rule; row 33
     (`resumeHeight`) stays withdrawn (`resumeHeight` is derived, not stored).
   - `L1-06` (~L216): re-base "no height is permanently retired" to "no height is retired, and the only
     action on the range above the checkpoint is the executed `GOV-04` action, which resumes settlement on
     the same chain and never erases the range (R5R2-C-01)"; keep monotonicity and no-gate.
   - `FI-14` (~L742): replace the "no recovery path / no generation increment" sentences with §2's
     non-interaction clause and delete the "no resolution exists" justification.
   - `L1-13` (~L460–500) and `MSG-03` (~L812–830): unchanged; add the sentence that a resolution gates
     nothing on the exit path (`MEM-15(5)` clause).
   - `FI-REMOVED-01` (~L730): unchanged.
6. **`spec/03-membership-staking.html`**
   - `MEM-15` (~L344–352): add the resolution non-interaction sentence; re-base the "(3)" and "(5)"
     sentences that say "no v1 rule discards a branch".
   - `MEM-13`: **no change**; record in the rule's notes that its predicate is generation-independent.
7. **`spec/09-parameters.html`**
   - Un-withdraw and restate `T_STALL_GOV` (~L183), `T_GOV_RESUME` (~L184) and the `govResume*` rows
     (~L185), adding `govResumeExecutableAt`; state the constructor-assertion obligation and the
     window relation `T_GOV_RESUME >= W_root + WITHDRAWAL_DELAY + T_VETO + MARGIN`, all terms unmeasured.
   - Restate the withdrawal notice (~L97) and the measurement rows (~L260–261): the exit-time
     measurement and the trigger derivation are owed again.
   - `lastAcceptedBatchTime` (~L182): restate as the trigger's left-hand quantity.
8. **`spec/10-assurance.html`** — `LIVE-01` (~L163) and `LIM-01` (~L325+): re-base the liveness rows
   ("no recovery path of any kind", "clearing the stall requires a future protocol update"), state
   `F-GOV-1`–`F-GOV-6` with the Open/disclosed split, and re-scope `A-GOV-2`'s exit sentence to class A
   with `MEM-15(2b)`'s dependencies. **(R5R2-C-01)** The rows that state the action's effect MUST say
   resume, not erasure: the checkpoint and everything at or below it untouched; a superseded certificate
   invalid only as a batch's head evidence; the range above the checkpoint valid history extendable under
   the new generation; and the class above the checkpoint unprotected because its signals are not carried
   into the resumed settlement, not because a range was discarded.
9. **`spec/01-system-model.html`** — re-base every "no recovery path of any kind" / "no stall-resolution
   entry point" sentence (approximately ~L164, 220, 225, 327, 346, 350, 553–560, 587–589, 607, 624) so
   that the one named runtime governance action is the revived `GOV-04`, with its trigger, stored
   timelock, consumed entry and resume-only effect.
10. **`spec/07-economics-slashing.html`** — `ECON-02(5)(f)` (~L289) and `ECON-02(6)` (~L692): keep "no
    bond, no completion reward, no treasury transfer, no recovery-completion record"; remove "not
    implemented / no recovery path of any kind"; the withdrawn-parameter rows (~L1193, 1218–1231) stay
    withdrawn except that the stall-resolution names leave the MUST-NOT-USE set where §9 item 7 revives
    them. `ECON-11` unchanged.
11. **`spec/index.html`** — the deferred-set counts (~L42, ~L356) go from three mechanisms to two (the
    `CONS-16` rotation and aggregation); the rule-index rows `REC-02`/`REC-03`/`REC-04` (~L481–483),
    `GOV-01`–`GOV-04` (~L512–514) and the parameter map are re-based; the ~L116–119 decision summary
    records the revival.
12. **`DEFERRED.md`** — §3 becomes a revival record (what was revived, the three blocker dispositions,
    what remains, what a future increment would need: the churn decision and Phase B); the cross-cutting
    "three mechanisms remain deferred" is re-counted to two.
13. **`DECISIONS.md`** — a new append-only entry (the next free number) recording the revival, the three
    blocker dispositions, the state machine, the exit scope and the anchor generation rule. D-15 and
    D-16 stay as written.
14. **`learn/`** — re-sync every page that teaches the absence or the claim: `01-what-is-etna.html`,
    `02-life-of-a-transaction.html`, `05-the-proof.html`, `06-data-and-proof-together.html`,
    `07-timing.html`, `08-when-things-go-wrong.html`, `09-censorship-and-the-bridge.html`,
    `glossary.html`, `limitations.html`, `index.html`. The lessons MUST NOT teach that the timelock lets
    every user exit, and MUST state the class above the checkpoint is unprotected.
15. **`PLAN.md`** — Phase 2 item 4 (increment 5, last) records that the delta is written and the review
    round is owed.
16. **Test obligations for the review round** (not file edits): (i) a second `execute()` on an executed
    entry reverts for every caller; (ii) `queue()` replaces a void entry and reverts on a live one;
    (iii) a change to `T_GOV_RESUME` does not move an existing entry's stored deadline; (iv) the first
    post-resolution epoch-opening batch is provable, and an anchor certificate whose generation differs
    from `B_anchor`'s header generation is rejected; (v) a resolution leaves the register, frontier,
    `forcedBoundary`, root attestation, veto and exit eligibility unchanged; (vi) an L1 reorg of the
    executing transaction restores the entry to `queued` and the generation to its previous value; (vii) a
    batch whose intermediate headers carry the pre-resolution generation and whose head is produced and
    certified under the new generation verifies and lands — the head-only scope of the generation rule,
    which a client MUST NOT reject on account of an ancestor's header generation (R5R2-C-01).

---

## 10. What this increment could not decide (for the review round and the owner)

### 10.1 The churn decision (F-GOV-3)

The increment closes the permissionless loop by consumption. Whether a **governance-driven** repetition
should also be blocked by a "progress-earned" queue rule is the one open design call. The candidate —
no new entry until `lastLandedHeight` advances past the previous execution's restore point — removes pure
churn but deadlocks the certified-but-unprovable case, and L1 cannot decide whether a certified range
exists above a stationary checkpoint (the `h_close` class that gates `CONS-16`, falsifier F7). The
increment therefore **adopts consumption only**, carries F-GOV-3 as disclosed, and returns the candidate
to the owner. A decision either way must be recorded; silence is not a disposition.

### 10.2 The migration layout

`govResumeExecutableAt` cannot be assumed to fit slot 268's preserved 27-of-32-byte packing. Whether to
repack or to consume a new slot is the migration audit's call; the constraint this increment fixes is
that the field exists, that the deadline is stored (SM-4), and that no deprecated slot may be reused.

### 10.3 The offence question

A proposal or vote under a superseded generation is **invalid** but is not made a new slashable offence
here, consistent with increment 04's owner decision 6 (the rejected proof is the whole enforcement). If
the review wants a signing offence, it is a new decision with its own funding and evidence analysis; this
delta does not create one.

### 10.4 Smaller open calls

1. Whether the trigger's conforming floor is the D6 envelope alone or a stronger registered floor; a
   value question, unmeasured.
2. Whether the window relation should carry an additional term for the user's own L1 submission and
   observation latency; the delta states `MARGIN` to hold it and leaves its contents to Phase B.
3. Whether `govResumeState` needs a distinct `cancelled` value for observability; the delta keeps three
   states and records cancellation by event, because a cancelled entry is behaviourally `none` and the
   history is on the log.
4. Whether a future increment should store the generation in the checkpoint record, which would make the
   anchor relation a stored equality instead of a hash-pinned one. Not required here; §5.3.

---

## Appendix A — Clause-by-clause difference from the preserved text (`7917ba264`)

| Clause | Preserved | Revived | Why |
|---|---|---|---|
| GOV-04(a) trigger | predicate over L1 state; queue reverts while false | kept verbatim in substance | it was not the defect |
| GOV-04(b) entry | `govResumeState = queued`; one pending; three fields | three-state machine; **stored deadline** added; queueing allowed into `none`/`executed`/a **void** entry; only a live entry blocks | G-1 and its mirror reading |
| GOV-04(c) effect | permissionless execute; sets `resumeHeight`; increments generation; entry not consumed | **execute consumes**: requires `queued`, sets `executed`, increments exactly once, writes nothing else | G-1 Critical |
| GOV-04(f) timelock | "MUST be long enough that every user can exit" | notice window; **class-A exit window** with a registered relation; class C stated unprotected; stored deadline; no "every user" | G-2, round-5 F1/F2 |
| GOV-04(e) void-on-progress | execution reverts; any account cancels | kept, plus **queue-over-void** | the mirror reading that a void entry blocks the mechanism |
| GOV-04(h) generation | signed field; old certificates void at acceptance | kept, plus the two-case rule (`CONS-05(2)`) and the anchor case; the rule constrains the head certificate, the contributing votes and the head header only, so the range stays landable as ancestors (R5R2-C-01) | G-3 |
| GOV-04(i) disclosure | governance liveness; opportunistic use | kept, plus repetition paced by a fresh DAO transaction and a full window (F-GOV-3) | G-1's residue stated honestly |
| GOV-03(e) upgrade survival | queued entry, remaining term, generation survive | executed entry survives too; stored deadline cannot move; no re-opening | G-1, G-4 |
| CONS-05 validity | generation equals the Inbox's (at acceptance) | two cases: current generation for extending batches; the block's own header generation at or below the checkpoint | G-3 |
| CONS-05 halt sentence | conflicting finalized block at `H`, unqualified | "under the current generation" | G-6 |
| CONS-08(1) | generation equals the Inbox's | scoped by height | G-3 |
| CONS-10(7) | header generation equals the Inbox's for the height being built | kept as a production rule; historical headers judged under `CONS-05(2)(b)` | G-3 |
| CONS-12 | "the invariant is unconditional in v1" | generation-scoped invariant operative; heights above the checkpoint re-producible under a new generation | the revival |
| PRF-04(i) | every vote's generation equals the journal's | kept for the head; historical/anchor case separated | G-3 |
| PRF-05(ii)(a) | anchor certificate under "same checks as PRF-04(i)" | anchor certificate under its own header generation; `cert_hash`/`epoch_anchor` recomputation required | G-3 |
| REC-02/03/04 | tombstones by D-16 | revived in the corrected form; `resumeHeight` stays derived and unstored | D-15/D-16 |
| FI-14(2) | "no recovery path … no generation increment" | non-interaction clause: the register, frontier and deadlines are untouched by a resolution | increment 04's obligation must survive |
| MEM-15(5) | exit unaffected by the absent recovery floor | exit explicitly not gated by a resolution; root at the restored checkpoint stays attestable | shipped exit |
| 09 rows | `T_STALL_GOV`/`T_GOV_RESUME`/`govResume*` withdrawn, MUST NOT use | revived, plus `govResumeExecutableAt`, constructor assertions and the window relation | D-16's register entry |
| HALT-04, GOV-01/02, index, LIM-01 | "no recovery path of any kind / no exception" | the one named exception is the revived `GOV-04`; everything else unchanged | consistency |

*Label correction only: the `GOV-04` clause letters in this table use the **applied** numbering of `spec/08` — timelock (f), generation (h), disclosure (i). The preserved text lettered the same clauses (d), (f) and (g). This aligns labels, not rule text: the generation clause is (h) in the applied rule and in §2, and the difference is not a rule question.*

## Appendix B — Every previously-found attack vector against the check that now rejects it

| # | Vector (finding) | Now rejected by |
|---|---|---|
| 1 | Re-execution of the unconsumed entry by any account, each call incrementing the generation — the permissionless, gas-priced settlement-denial loop (**G-1, Critical**) | §3: `execute()` MUST revert unless the state is `queued`; success atomically increments once and sets `executed`; SM-1 (single-writer) and SM-3 (terminal `executed`) leave no second route; SM-2 makes one entry one execution |
| 2 | The mirror reading: a stored `queued` value is "pending", so after one execution every later queue reverts and the mechanism is unusable (**G-1, mirror**) | §2 GOV-04(b)/(d)/(e): `executed` is not pending; a **void** entry may be cancelled or replaced by the next queue; only a live `queued` entry blocks |
| 3 | A stale queued entry executed to supersede the generation over a range the trigger never justified (preserved GOV-04 failure mode) | SM-7 and §2(e): the trigger can become false only by the acceptance that voids the entry; execution requires a live, non-void, past-deadline entry |
| 4 | The timelock shortened after queueing so the exit window disappears (preserved) | §2(g): the deadline is stored in the entry and no upgrade or parameter change may move it; `GOV-03(e)` carries it |
| 5 | The timelock claimed as the exit window for users it cannot protect (**G-2, High**, round-5 F1/F2) | §4: the window is scoped to class A, its length is the registered relation, the class-C non-protection is stated, and the "every user" sentence is withdrawn; the availability half rests on the post-round-6 `L1-13(1)`/`(3)` widening, which is cited rather than re-derived |
| 6 | The first post-resolution epoch-opening batch unprovable because the anchor certificate is judged under the new generation (**G-3, High**) | §5 and `CONS-05(2)(b)`, `PRF-05(ii)(a)`: the anchor certificate is judged under `B_anchor`'s own header generation, the head under the current one; `cert_hash` must recompute into `epoch_anchor` |
| 7 | The charitable reading: the anchor's generation taken from the witness certificate, dropping the equality (**G-3**) | §5: the anchor header's bytes are pinned by `prevBlockHash` (`L1-05` row 4, `L1-07`) and the certificate's generation must equal the header's; the value is not witness-supplied |
| 8 | A superseded certificate presented as the head certificate of an extending batch | `CONS-05(2)(a)`: a head certificate, every contributing vote and the head header must carry the current generation; a certificate of the range above the checkpoint carries the superseded one and cannot be head evidence. The range itself remains valid history and may be carried as ancestors under a head produced under the new generation (R5R2-C-01). It cannot be the anchor either: `B_anchor` is pinned by L1 to the restored checkpoint block, which the resolution leaves untouched |
| 9 | An upgrade moves `T_STALL_GOV`/`T_GOV_RESUME` to their minima for future entries while claiming no discretion (**G-4, Medium**) | §2(g): stored deadline for existing entries; constructor-time assertions of the relations; a change is a published rules change; the "chooses no configuration value" claim is withdrawn and the discretion named (F-GOV-4) |
| 10 | The certificate tuple omits the generation its validity predicate reads (**G-5, Medium**) | Already closed by `R9-CC-01` in the current draft: the tuple carries `recovery_generation`; this increment keeps it |
| 11 | A node holding an old-generation "finalized" block halts and refuses to adopt the restored chain (**G-6, Medium**) | Change list §9 item 3: the halt sentence is scoped to "under the current generation", as `CONS-04(2)`/`CONS-15(2)` already are |
| 12 | `PRF-02(4)` describes the withdrawn recovery-restart form as live (**G-7, Low**) | Already re-based in the current draft; this increment states the anchor inputs it uses without adding a journal field |
| 13 | Governance picks which provisional transactions survive (preserved failure mode) | §2(b)/(c): the entry names nothing, `resumeHeight` is derived, and the action selects nothing — it resumes the same chain and invalidates a superseded certificate only as a batch's head evidence, so no subset is chosen and the whole class above the checkpoint is unprotected (R5R2-C-01) |
| 14 | An upgrade is used as a substitute for the resolution | §2(j): `GOV-03(e)` extended; the executed entry and the generation survive, and no upgrade may perform the resume |
| 15 | A resolution clears, voids, re-clocks or suppresses forced-inclusion records, or makes a range unprovable | §2 FI-14 clause: no `FI_*` state is read or written; deadlines are L1-block-derived; the next batch is judged against the register at its own anchored view |
| 16 | A resolution gates, delays or accelerates the exit | §2 MEM-15 clause and §6.4: the withdrawal path reads no resolution state; the root from the restored checkpoint remains attestable after execution |
| 17 | `CONS-16`'s rotation is blocked forever by an entry that executed (or that was left void) | §2 CONS-16 note (for a future revival): only a **live `queued`** entry excludes the rotation; a void entry is replaceable, an executed entry is not pending. `CONS-16` stays deferred regardless |
| 18 | An L1 reorg duplicates or loses a generation increment | SM-6: the state carries with L1 state; an execution reorged out never took effect and the entry returns to `queued` with its stored deadline |
| 19 | Repetition by governance churns generations at up to one per window (**round-6 residual (6)**) | **Not rejected** — disclosed as F-GOV-3, with the candidate remedy recorded and not adopted (§10.1) |
| 20 | An unavailable quorum, unavailable data, an economics stall, or class-C value above the checkpoint | **Not rejected** — stated as what the mechanism does not do (§7.3, §8); `ECON-11` states the absence of compensation |
| 21 | The withdrawn recovery's own defects return (`R5T-D2-01` under-sized bundle, `R5T-D2-02` bond actor mismatch, `R5T-D2-04` L1 cannot verify Ed25519, `R5T-D2-06` interface/bond custody, `R5T-D2-07`) | Moot: the revived action accepts no bundle, verifies nothing on L1 beyond its own record, has no bond, no invoker and no completion transition, and pays nobody |
| 22 | A void/cancelled entry is revived to execute later | §2(e): the fields are cleared and a new entry needs a fresh trigger and a fresh stored deadline; the generation is untouched by cancellation |

---

*End of increment 05. The review round owns the fresh adversarial pass and nothing here claims it has
happened; the change list's items 1–15 have been applied and item 16 is the review round's test
obligation.*

## 11. Owner decisions (binding; D-19 reproduced in full)

*R5R1-G-02: the previous §11 claimed to reproduce the owner decisions "verbatim" while carrying an
abridged paraphrase. Measured before this correction, the reviewer's way (whitespace stripped): §11 was
1,636 non-space characters against D-19's 8,992, and neither text contained the other; with markdown
emphasis markers also stripped, 1,613 against 8,760. The block below is D-19's text exactly as
`DECISIONS.md` carries it — measured the same way, 8,992 non-space characters (8,760
emphasis-stripped) containing D-19 character-for-character. All commentary in this section stays outside the
quoted block.*

**The decision of record is D-19 in [`DECISIONS.md`](../DECISIONS.md). Everything between the markers
below is that entry's text as `DECISIONS.md` carries it — its heading line indented four spaces so that
it does not become a sibling section heading of this delta, an indentation that is whitespace only and
is the sole difference — reproduced verbatim and binding on this increment. If this block and
`DECISIONS.md` ever differ, `DECISIONS.md` governs and this block is stale. No commentary appears
inside the markers.**

<!-- BEGIN QUOTED D-19 - verbatim from DECISIONS.md; no commentary inside -->
    ## D-19 — Governance stall resolution revived, consumption-only: a consumed entry, a stored deadline, a scoped window and a two-case generation rule

*Increment 05. Append-only: D-15 and D-16 stay as written; this entry records what changed. The design
delta and the four owner decisions below are the increment's authority.*

**Decision (design owner, 2026-10-07):** increment 05 revives the **timelocked, resume-only governance
stall resolution of D-15** (`GOV-04`, with `REC-02`–`REC-04`) as a live, rule-bound action, re-derived
against the converged v1 rather than restored from its tombstone. It is **in review**: it ships only after
its own review rounds are clean, and the bar is the one v1 and increments 02 and 04 met — **two consecutive
rounds with no Critical and no High**. Only the names this increment needs leave their tombstones —
`GOV-04`, `REC-02`, `REC-03`, `REC-04`, `T_STALL_GOV`, `T_GOV_RESUME` and the `govResume*` /
`govResumeExecutableAt` registrations — and every other tombstone stays exactly as D-16 left it. The
increment adds no permissionless recovery, no bond, no reward, no invoker, no certificate bundle, no
retirement record and no new entry point on the exit, inclusion, staking or proof paths; `CONS-16` (the
rotation) and aggregation (D-13) are not revived, and no v1 decision is reopened.

**The state machine, and consumption is the increment.** `govResumeState ∈ {none, queued, executed}`.
Queueing is a DAO transaction through the authority of `GOV-01` and is the only runtime governance entry
point the protocol has; it is allowed only while the trigger holds, and it records
`govResumeQueuedAt = block.timestamp`, `govResumeQueuedHeight = lastLandedHeight` and
`govResumeExecutableAt = block.timestamp + T_GOV_RESUME`. A live `queued` entry blocks a second queue; a
void entry (the checkpoint advanced) may be cancelled by any account **or replaced by the next queue**; an
`executed` entry is terminal for that entry and blocks nothing. `execute()` is permissionless, takes no
argument that influences the outcome, MUST revert unless the state is exactly `queued` and past the stored
deadline, and MUST revert if the entry is void. On success it MUST, in one transaction, increment
`recoveryGeneration` by exactly one and set the state to `executed`. It writes nothing else:
`resumeHeight = lastLandedHeight + 1` is derived and never stored, the checkpoint record is untouched, and
only history strictly above the latest L1-accepted checkpoint is discarded. The generation is incremented
**nowhere else** — no initialiser, upgrade, governance call, cancellation or client path — and no entry can
be executed twice. The invariants are SM-1 (single writer), SM-2 (one execution per entry), SM-3 (terminal
`executed`), SM-4 (the deadline is read from the entry, never recomputed), SM-5 (void is replaceable),
SM-6 (all five objects carry with L1 state across a reorg) and SM-7 (the trigger can become false only by
the acceptance that voids the entry). The trigger itself is read from L1 state alone:
`block.timestamp - lastAcceptedBatchTime >= T_STALL_GOV`.

**The withdrawn claim, and what the window actually is.** The preserved `GOV-04(d)` claim that
`T_GOV_RESUME` "MUST be long enough that **every user** can exit via `MEM-15`" is **withdrawn**
wherever it appeared (`GOV-04`, `REC-02`, `HALT-04`, the `A-GOV-2` row, the index, the course).
The correct statement is scoped to three classes. **Class A** — a signal already included in L2 state at
or below the last accepted checkpoint at queue time — has a real exit window, because execution leaves the
checkpoint record untouched and the withdrawal root of an already-accepted checkpoint, in particular the
latest, stays attestable with no new L2 block and no settlement progress (`L1-13(1)`/`(3)`). Its length
is the registered, **unmeasured** relation
`T_GOV_RESUME >= W_root + WITHDRAWAL_DELAY + T_VETO + MARGIN`, where `W_root` is the worst-case time to
produce and record the checkpoint's `k` attestations, and it is conditional on `MEM-15`(2b)'s funded
proving market and retained inputs. **Class B** — an unmessaged L2 balance at or below the checkpoint — is
untouched and was never covered by `MEM-15`(1). **Class C** — value or signals above the checkpoint —
has no L1-provable claim (`MEM-15`(4)), is discarded by rule and is **not protected by any window**; its
holders have the prior provisional disclosure, the notice the queued entry gives, and resubmission, with
no protocol compensation (`ECON-11`). The stronger property the claim does not need is stated too:
execution removes no claim at or below the checkpoint, so the window is a **notice-and-opportunity**
window, not what makes class A safe.

**The two-case generation rule.** A certificate carries the generation of the history it certifies.
**Head case (unchanged):** a certificate presented as the finality evidence of a batch extending the
current checkpoint must carry the current generation, every contributing vote must carry it, and the head
header must carry it — so a discarded branch, whose certificate carries the superseded generation, cannot
be re-landed. **Historical case (new):** a certificate for a block at or below the last accepted checkpoint
must carry the generation of that block's **own header**, every contributing vote must carry the same
value, and it MUST NOT be compared with the current generation; the value is not witness-supplied because
the checkpoint record commits the block's hash (`prevBlockHash`) and the block's header bytes are what L1
already fixes. **Anchor case (explicit):** when a batch opens an epoch, `B_anchor` is the block whose hash
equals `prevBlockHash`, and the guest verifies its certificate under the historical case and recomputes
`cert_hash` into the header's `epoch_anchor`. The first post-resolution epoch-opening batch is therefore
provable: the anchor certificate is judged under the restored block's own (pre-resolution) generation and
the batch's own certificate, head header and votes under the new one, so the two checks read two different
objects. The rule is invariant under repeated resolutions because `B_anchor`'s header never changes. The
generation is **not** stored in the checkpoint record.

**The four owner decisions (binding).**
1. **The churn rule is CONSUMPTION-ONLY.** The progress-earned candidate — no new entry until the
   checkpoint advances past the previous execution's restore point — is **not adopted**: it would deadlock
   the certified-but-unprovable case, and L1 cannot decide whether such a range exists (the `h_close`
   referent class that gates `CONS-16`). An entry is consumed by execution and the generation increments
   exactly once per executed entry; governance-driven churn stays **disclosed** as **F-GOV-3** (one
   generation per fresh DAO transaction plus a full window) rather than constrained. This is the same call
   as increment 04's: do not add a new condition to rescue an existing falsifier — state the condition
   instead.
2. **Slot 268 is a migration-audit item, not a design decision.** The design **requirement** is a stored
   `govResumeExecutableAt`, written once when the entry is queued and read by `execute()`. Whether the
   preserved 27-of-32-byte packing at slot 268 is repacked or a slot is added is the **migration audit's**
   call, named as an explicit open obligation; it is not assumed to fit and it MUST NOT be carved from a
   deprecated slot.
3. **A superseded-generation proposal is NOT a new offence.** No slashable offence is created or revived,
   consistent with increment 04's owner decision 6 and D-16's tombstoning of the offence rows. A proposal
   or vote under a superseded generation is invalid, and the enforcement is the rejected proof or the
   reverted call — nothing else.
4. **The smaller items stay as the delta states them.** The trigger's conforming floor strength, the
   contents of `MARGIN` and the window relation remain **symbolic and unmeasured**; there is **no distinct
   `cancelled` state** (a cancelled entry is not queued, and adding a state adds surface without adding a
   property); and the generation is **not** stored in the checkpoint record — it is read from that block's
   own header, which is what the two-case rule above already does.

**Falsifiers, with their classes.** **F-GOV-1** (**Open**) — clearing a stall depends on governance
liveness with no protocol bound: if governance never queues, or queues and never has the entry executed,
the stall persists; a captured or coerced governance can also wait for a genuine stall and have an
unfavourable provisional range discarded. **F-GOV-2** (**Open**) — the window relation and its terms
(`W_root`, `WITHDRAWAL_DELAY`, `T_VETO`, `MARGIN`) are unmeasured and conditional on `MEM-15`(2b).
**F-GOV-3** (**Disclosed**) — governance-driven churn, as owner decision 1 states it. **F-GOV-4**
(**Disclosed**) — future-entry parameter discretion: one published rules change may move `T_STALL_GOV` and
`T_GOV_RESUME` to their conforming minima for entries queued afterwards, while an already-queued entry's
stored deadline is protected and the relations are constructor-time assertions. **F-GOV-5** (**Open**,
implementation-verified) — the anchor rule depends on the deployment pinning `B_anchor` by `prevBlockHash`
and on no client comparing the anchor certificate with the current generation. **F-GOV-6** (**Open**,
implementation-verified) — a resolution could be implemented so that it re-clocks a publication record,
lowers the settlement frontier, gates a withdrawal root or delays the exit; the non-interaction clauses
forbid it.

**What the action does not do.** It does not give any account a recovery entry point; it does not let any
caller choose a height, state, checkpoint, range, subset, beneficiary or generation; it does not rewrite,
re-judge or delay history at or below the checkpoint; it creates no bond, reward, escrow, fee, treasury
transfer or slashable offence; it reduces no validator's weight and rotates no set; it does not gate the
exit, the root, the veto, forced inclusion, settlement or staking exits; it does not retire a height or
store a resume record; it does not bound the number of resolutions (pacing is the DAO transaction plus the
stored window, F-GOV-3); it does not revive `CONS-16` or aggregation; and it does not promise that a
resolution will ever be queued, executed or needed. It also cannot clear an unavailable quorum, unavailable
data or an economics stall.

**Status:** decided; specification, register, index and course changes in flight. The increment ships only
after its own review rounds are clean.
<!-- END QUOTED D-19 -->

*The numbered four-item summary this section carried before this correction was a paraphrase of D-19's
owner decisions, not the decision text; it is superseded by the quoted block and MUST NOT be cited as
D-19. Nothing above reopens D-15, D-16 or any v1 decision.*

---

## Review corrections (increment 5, round 2 — R5R2-C-01)

**RC-R5R2-C-01 — the effect of the stall resolution is stated in its enforced form: the mechanism resumes,
it does not erase; the generation rule is head-only. The owner has ruled on round 2's Medium R5R2-C-01
(claim-versus-rule mismatch: the preamble and the G-3 derivation claimed a "full-range discard" and an
"unlandable" branch that the operative checks do not enforce).**

**The corrected statement of the effect, binding on this delta and on every text that summarises it:**

> The resolution resumes settlement on the same chain: it leaves the checkpoint and everything at or below
> it untouched; it invalidates a superseded certificate **only as a batch's head evidence** — a superseded
> certificate cannot serve as the head certificate of an extending batch, which is exactly what the
> enforced checks say, since the head certificate, its contributing votes and the head header must carry
> the current generation (`CONS-05(2)(a)`, `PRF-04(i)`); the range above the latest L1-accepted checkpoint
> remains **valid history that can be extended under the new generation**, and nothing in the rule
> invalidates or forbids a block on account of the generation in its own header (`CONS-10(7)`: the
> generation is part of the header bytes, so every other header legitimately carries the generation it was
> produced under); and the class above the checkpoint is unprotected for a different and narrower reason
> than erasure: the user's signals are not carried into the settlement the resumed chain produces, so they
> must be resubmitted, with no compensation (`ECON-11`).

**The reason.** Making the range genuinely unlandable would ADD a history-rewriting power that `REC-01` and
the boundary design forbid, and would contradict the guarantee this mechanism exists to provide. The
mechanism resumes; it does not erase. The operative checks constrain only the head certificate, the
contributing votes and the head header — every other header legitimately carries the generation it was
produced under — and no rule invalidates a block whose header carries an older generation or forbids such a
block inside a batch. A batch whose intermediate blocks are the provisional range (headers under the old
generation) and whose head is a new block under the new generation therefore satisfies every check and
settles that range; a validator that reads an overstated preamble and rejects it diverges from the rules.
The range-wide alternative was considered and **not adopted**: it is a substantive rule change, and the
owner's decision is the resume form.

**Consequences recorded, so the superseded forms cannot be restored.** (i) The words "a full-range discard
of everything strictly above the latest L1-accepted checkpoint" and "a generation increment that makes the
discarded branch unlandable" (this delta's scope paragraph, the applied `GOV-04` preamble and their echoes)
are **withdrawn**; the corrections are applied in place in this delta, in `spec/08`'s `GOV-04` and its
other statements of the action's effect, in `spec/02`'s superseded-generation clauses, and in `spec/10`'s
trust-model and limitation text, each marked R5R2-C-01. (ii) This delta's §5.2 step 4 is corrected: the
premise that a block of the range "would have to be the head of a batch extending the checkpoint" was
false — it may be an **ancestor**, and only its certificate's use as head evidence is rejected. (iii) The
client-divergence half is closed where a validator reads it: `GOV-04`'s preamble and clause (h) state
plainly what the action does enforce, including that intermediate headers are not compared with the current
generation, and §9 item 16(vii) adds the conformance vector — a batch with pre-resolution ancestor headers
and a head certified under the new generation MUST verify and land. (iv) The class above the checkpoint is
stated as **unprotected because its signals are not carried into the resumed settlement**, not because
governance erases it; no compensation is promised (`ECON-11`). (v) Within the quoted D-19 block above, the
descriptive words "discarded by rule" and "cannot be re-landed" are read with this ruling: they describe
the class as unprotected and a superseded certificate as unusable head evidence. D-19's operative content —
the consumed entry, the stored deadline, the two-case generation rule, the anchor case — is unchanged, and
`DECISIONS.md` remains the authority for D-19; a note carrying this reading belongs there, and this delta's
verbatim reproduction MUST NOT be edited to carry it.

