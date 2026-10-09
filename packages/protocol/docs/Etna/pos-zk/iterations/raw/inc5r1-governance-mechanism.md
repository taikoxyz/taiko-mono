# Increment 5 round 1 — the governance stall resolution, mechanism attack

**Reviewer:** r6-gov-generations (task-65), independent adversarial reviewer.
**Snapshot:** `1cd1dd6af` (working tree clean at claim). **Angle:** attack the mechanism itself — entry
consumption, generation writes, cancellation, the deadline, re-opening, void/replay, the two-case generation
rule, replay of superseded certificates, and the trigger. **Standing charge:** read both sides of every seam,
ask of each pair of clauses whether they are individually true and jointly false, and verify every quotation,
count and enumeration **by measurement**.
**Method:** the delta is authoritative for the review (`increments/05-governance-design.md`, marked
IMPLEMENTED, IN REVIEW) and the specification carries the applied rules; I read both and measured. Citations:
`delta:n` = the delta; `NN:line` = `spec/NN-*.html`; `D-19` = `DECISIONS.md`.

**Counts: Critical 0 · High 0 · Medium 2 · Low 1.**
**Verdict: the mechanism survives the attack — no Critical and no High.** The entry is consumed exactly once
by one code path; the generation has exactly one writer; a void entry blocks nothing; the stored deadline is
immutable; the executed state is terminal; a reorg carries the entry and the generation consistently; the
two-case rule makes the first post-resolution epoch-opening batch provable and stays provable under repetition
and reorg; and a superseded-generation certificate is void as evidence or inert as a lock. Three documentary
defects remain: the window relation's terms `W_root` and `MARGIN` have no register rows and no derivation
though the relation is a constructor-time assertion (R5R1-G-01, Medium); the delta's §11 claims to reproduce
the binding owner decisions **verbatim** while measurement shows an abridged paraphrase against D-19
(R5R1-G-02, Medium); and the error surface has two names for one case plus one error that exists only in the
delta's analysis table (R5R1-G-03, Low). Slot 268's obligation is consistent everywhere it is described.

---

## Finding R5R1-G-01 — Medium: the window relation's terms have no register rows and no value source, yet the relation must be asserted at construction

**Severity: Medium.** One-line rationale: `GOV-04(g)` requires the implementation to refuse to initialise
unless `T_GOV_RESUME >= W_root + WITHDRAWAL_DELAY + T_VETO + MARGIN` holds; the register has rows for
`T_STALL_GOV`, `T_GOV_RESUME` and `govResumeExecutableAt`, and a measurement row that names the relation's
terms, but `W_root` and `MARGIN` have **no rows of their own and no stated derivation**, so the
constructor assertion has no value source; PARAM-01's discipline ("every parameter has exactly one registered
spelling … changing a value is a governance action recorded in the decision log") is not met for two named
terms of the relation the G-2 closure rests on.
**File + rule id.** `delta:340-350` (GOV-04(g)) and `08:GOV-04` (the applied rule, clause (g));
`delta:311-324` and the spec's GOV-04(f) ("`W_root` is the worst-case time to produce and record the
checkpoint's `k` attestations; every term is **unmeasured** and `MARGIN` is a stated, unmeasured margin");
`09:183-186` (rows for `T_STALL_GOV`, `T_GOV_RESUME`, `govResumeExecutableAt`) and `09:262` (the
measurement row that lists "`W_root`, `WITHDRAWAL_DELAY`, `T_VETO`, `MARGIN`" as Phase-B measurements);
the spec's GOV-04(i) ("the trigger floor, the window relation and MARGIN stay symbolic and unmeasured").
**Missing rule / correction:** give the two terms a home — register rows (units: seconds; "unset; unmeasured;
symbolic term of the window relation, Phase-B measurement") or an explicit derivation the constructor reads
(for example `W_root` from `k` and the attestation-production bound already owed for `W_ROOT_WAIT_MAX`,
and `MARGIN` from the named contents the measurement row lists) — so the assertion of (g) can be evaluated.
**Assumptions.** None. **Attack trace.** None in-protocol: this is the assertion the implementation must
evaluate before it can be deployed; with no value source, an implementer invents `W_root`/`MARGIN`, and the
exit-window guarantee of (f) is then sized by an unregistered number — the class of defect the register exists
to prevent.
**Fault-model verdict.** Inside (register discipline; no adversary). **Attacker cost.** None.
**Requirement affected.** GOV-04(f)/(g); PARAM-01; `09`'s frozen-parameter discipline; the measured basis of
F-GOV-2. **Evidence.** the four citations above.

---

## Finding R5R1-G-02 — Medium: the delta's §11 "reproduced verbatim" claim for the owner decisions is false by measurement against D-19

**Severity: Medium.** One-line rationale: §11's header says "The decisions below are **reproduced verbatim**
and are binding on this increment; they are recorded as D-19 in `DECISIONS.md`", but measurement shows §11 is
an abridged paraphrase: §11 is **1,636** non-space characters, D-19 is **8,992**, and neither contains the
other; the churn decision alone differs in substance — D-19: "the progress-earned candidate — **no new entry
until the checkpoint advances past the previous execution's restore point** — is not adopted: it would
deadlock the certified-but-unprovable case, and L1 cannot decide whe[ther] …", against §11: "The
progress-earned candidate is NOT adopted: it deadlocks the certified-but-unprovable case and L1 cannot decide
`h_close`." Because the delta is "what the increment's adversarial review round is built from", an abridged
decision record that claims to be the binding text is a record-integrity defect: a reviewer (or an
implementer) can miss a clause of the decision.
**File + rule id.** `delta:954-965` (§11) against `DECISIONS.md` D-19. **Missing rule / correction:**
reproduce D-19 verbatim in §11 (the delta already says it is appended verbatim), or drop the word "verbatim"
and state that §11 summarises D-19, which is the binding text.
**Assumptions.** None. **Attack trace.** None (documentary); the operational risk is a decision clause read
from §11 alone.
**Fault-model verdict.** Inside (documentation). **Attacker cost.** None.
**Requirement affected.** The delta's own record claim; D-19's status as the decision of record.
**Evidence.** measured lengths and the two churn sentences above; `delta:954`; D-19.

---

## Finding R5R1-G-03 — Low: the error surface has two names for one case, and the timelock error exists only in the delta's analysis table

**Severity: Low.** One-line rationale: (i) the delta's §3.2 transition table groups "`none`, `executed` →
`execute()` → reverts `NoQueuedEntry`", while its own §2(d) table — and the applied rule in `08:GOV-04(d)` —
distinguish `none` (`NoQueuedEntry`) from `executed` (`EntryAlreadyExecuted`, "for every caller, in every
block, with every calldata"); (ii) the timelock revert's error `TimelockNotElapsed` appears **only** in the
delta's §3.2 table: the applied rule's clause (c) says "It MUST revert before the stored
`govResumeExecutableAt`" without a name, and the rule's table cell names no error for it, while the other six
errors are named there. An implementer therefore has two names for one condition and no name for another.
**File + rule id.** `delta:495-512` (§3.2) against `delta:283-291` (§2(d)) and `08:GOV-04(d)` (the applied
table); `08:GOV-04(c)` and `04` L1-08 (`TimelockNotElapsed` appears in no `spec/*.html`; measured: the six
other names occur in the GOV-04 rule, the seventh does not).
**Missing rule / correction:** pick one — the applied rule already picked §2(d), so correct §3.2's row to
`EntryAlreadyExecuted`, and either name the pre-deadline error in the rule/table (and the interface) or state
that it is deliberately unspecified.
**Assumptions.** None. **Attack trace.** None (interface/tooling): off-chain tooling cannot distinguish
"no entry" from "entry already executed", and cannot match the timelock revert at all.
**Fault-model verdict.** Inside (documentation/interface). **Attacker cost.** None.
**Requirement affected.** GOV-04(b)-(d); the entry-point error surface; the owner's carried flag 1.
**Evidence.** the delta's two tables; `08:GOV-04(c)/(d)`; the measured absence of `TimelockNotElapsed` in the
specification.

---

## The mechanism, attacked and held

| Attack | Result |
|--------|--------|
| Re-execute a consumed entry | `execute()` requires `queued`; success sets `executed`; from `executed` every call reverts `EntryAlreadyExecuted` for every caller/calldata; no upgrade may re-open it (`GOV-04(j)`, SM-3). Held. |
| Double-consume across a reorg | An execution reorged out never took effect: the entry returns to `queued` with its stored deadline and the generation returns to its prior value (SM-6); "at most one successful `execute()` exists in any L1 state" (SM-2). Held. |
| Generation twice from one entry / without an executed entry | One code path writes it — the live-`queued`→`executed` transition, in the same transaction that sets `executed` (SM-1); the spec repeats "by exactly one … and by nothing else" in 01, 04, 05, 08 and 09. Held. |
| Cancel by the wrong party | `cancel()` is permissionless but only for a **void** entry (checkpoint advanced); a live entry reverts `EntryNotVoid`; cancellation transfers no value; a void entry is replaceable, so the mechanism never needs a canceller. Held. |
| Void entry blocks a later one / queue-over-void replayed | A void entry is replaceable (§2(d) third row; SM-5) and a replacement is a **new** entry with fresh fields and a fresh deadline; a replay of the old queue calldata is simply a new DAO queue and still needs the trigger. Held. |
| Stored deadline manipulated | `govResumeExecutableAt` is written once at queue time and read by `execute()`; no upgrade, initialiser, parameter change, governance call or client path may move, shorten, extend or recompute it (SM-4; 09's row); a `T_GOV_RESUME` change applies only to entries queued after it (GOV-03(e)). Held. |
| Later entry queued over an executed generation | Allowed by design (a fresh entry; the trigger still holds because execution does not advance the checkpoint) — the churn residue, **Disclosed** as F-GOV-3 and consumption-only per the owner decision; it is not a re-opening of the executed entry. Held (disclosed). |
| First post-resolution epoch-opening batch unprovable | The rule is two-case (CONS-05(2)): a batch extending the checkpoint carries the current generation in its head certificate, votes and head header; `B_anchor` (the block at `prevHeight = lastLandedHeight`) is at or below the checkpoint, pinned by `prevBlockHash`, and its certificate is judged under **its own header generation**, not compared with the current; `cert_hash` recomputes into `epoch_anchor`. Both checks read different objects and are satisfiable in one proof (delta §5.2). Held. |
| Repetition / reorg robustness of the rule | A second resolution changes `g_now` but not `B_anchor`'s immutable header bytes, so the anchor case is judged under the same generation however many resolutions run; an L1 reorg carries the generation and the entry state with it. Held. |
| Superseded-generation certificate replayed as evidence | As the finality evidence of an extending batch it is **void at acceptance** (CONS-05(2)(a)); a historical certificate is judged under its own block's header generation (CONS-05(2)(b)) — that is the rule, not a replay hole; the `cert ≤ current` relation is checked. Held. |
| Superseded-generation certificate replayed as a **commit** | Locks and the halt sentence are generation-scoped (CONS-04(2), CONS-15(2), CONS-05(2)(c)): a superseded certificate certifies a discarded branch, not the restored chain, and is not a conflicting finalized block. Held. |
| Resolution triggered with no stall | The trigger is `block.timestamp − lastAcceptedBatchTime >= T_STALL_GOV` with the registered floor `T_STALL_GOV > T_PROOF_ENVELOPE + T_SETTLE_PIPELINE` (09:183), so a normal slow proof or one prover failure cannot make it true; a live entry implies no acceptance since queueing, hence the trigger still holds (SM-7, and the trigger can only become false through an acceptance, which voids the entry). Held. |
| Resolution fails to trigger where there is one | Governance liveness has no protocol bound — F-GOV-1 **Open** and disclosed, with the opportunistic-capture case in `GOV-04(i)`/A-GOV-2. Held (disclosed). |
| Left unconsumed | A queued entry may be left unconsumed (nobody calls `execute()`), which leaves the stall in place; that is F-GOV-1's class, and a void entry left in place blocks nothing. Held (disclosed). |

**Two seam notes, checked and not counted.** (i) `GOV-04(i)`'s disclosed opportunistic case: a captured or
coerced governance can act inside the trigger and discard an unfavourable provisional range — inside the
stated assumption, not a mechanism hole. (ii) Reorg of an executed resolution: the delta's (j)/SM-6 carries
the **state** consistently, and the interim L2 blocks produced under the reorged-out generation carry a
generation that is no longer current, so they cannot be finalised as extending batches and must be
re-produced from the checkpoint — which is exactly the existing `REC-01`/D-16 boundary statement that
everything above the last accepted checkpoint is provisional and discardable; the delta could say so in one
sentence, but it is inside the disclosed boundary, not a new hole.

## Measurements (counts and quotations)

| Claim | Measurement | Verdict |
|-------|-------------|---------|
| `govResumeState` has three values | `none`/`queued`/`executed` in the delta and the applied rule; no fourth state, no distinct "cancelled" state (owner decision) | ✓ |
| The entry tuple has four fields | `govResumeQueuedAt`, `govResumeQueuedHeight`, `govResumeExecutableAt`, `govResumeState` (the spec's transition table writes "the four entry fields") | ✓ |
| Falsifiers are F-GOV-1…F-GOV-6 | delta, spec/10 and D-19 each carry exactly six; spec/09 cites the four its rows need (F-GOV-1…F-GOV-4) without claiming a set | ✓ |
| The four owner decisions | §11 lists four (churn consumption-only; slot 268 an audit item; superseded-generation proposal no new offence; smaller items as stated) | ✓ count, but see R5R1-G-02 for the "verbatim" claim |
| The window relation's terms | `T_GOV_RESUME >= W_root + WITHDRAWAL_DELAY + T_VETO + MARGIN` appears in the delta and in the applied rule (f)/(g); rows exist for `T_STALL_GOV`, `T_GOV_RESUME`, `govResumeExecutableAt`; **`W_root` and `MARGIN` have no rows** | ✗ R5R1-G-01 |
| Slot 268's obligation stated consistently | spec/08 states the re-derivation obligation in the change list ("the added `govResumeExecutableAt` MUST NOT be assumed to fit the preserved 32-byte word; the packing and the declaration count MUST be re-derived from the generated layout; the field MUST NOT be carved out of a deprecated slot"), in the packing note ("the preserved word held 27 of 32 bytes … the entry now carries one additional `uint64`") and in the budget/audit rows; no place asserts that it fits | ✓ (owner flag 3 closed) |
| The two-case rule is implemented | spec/02 CONS-05(2): the two cases, the `cert ≤ current` check, the `prevBlockHash` pinning and the generation-scoped halt sentence all present; CONS-12 makes a certificate that does not satisfy its case void at acceptance | ✓ |
| The error surface | six error names occur in the applied rule's table; `TimelockNotElapsed` occurs in no spec file; the delta's §3.2 uses `NoQueuedEntry` where §2(d) uses `EntryAlreadyExecuted` | ✗ R5R1-G-03 |

## Summary for the lead

| Severity | Count | Findings |
|----------|-------|----------|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 2 | R5R1-G-01 (the window relation's `W_root`/`MARGIN` have no rows and no value source, though GOV-04(g) asserts the relation at construction) · R5R1-G-02 (the delta's §11 "reproduced verbatim" claim is false by measurement: 1,636 vs D-19's 8,992 non-space characters, an abridged paraphrase) |
| Low | 1 | R5R1-G-03 (two names for the executed-entry execute() revert, and the timelock error named only in the delta's analysis) |

**Strongest attack: none found.** Every mechanism question in the angle is answered by the rule as applied:
the entry is consumed exactly once by one code path, the generation has one writer, the void/replace/cancel
lattice cannot block a later entry, the stored deadline is immutable, the executed state is terminal, the
generation and entry state carry with an L1 reorg, the two-case rule makes the first post-resolution
epoch-opening batch provable and keeps it provable under repetition and reorg, a superseded certificate is
void as evidence and inert as a lock, and the trigger cannot fire on a normal slow proof. The three findings
are documentary/interface defects, two of which the owner's own carried flags named.

**Is the increment safe to ship?** **Not yet as documented, but there is no mechanism blocker.** Fix
R5R1-G-01 (rows or derivations for `W_root`/`MARGIN` — the constructor assertion depends on them),
R5R1-G-02 (reproduce D-19 verbatim or drop the claim) and R5R1-G-03 (align §3.2 with §2(d) and name the
timelock error), and the increment has a clean first round with no Critical and no High; a second clean round
is then required before shipping, per the increment's own bar.
