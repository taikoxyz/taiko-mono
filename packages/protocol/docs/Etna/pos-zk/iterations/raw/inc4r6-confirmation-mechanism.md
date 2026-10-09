# Increment 4 round 6 — the confirmation round

**Reviewer:** r6-gov-generations (task-61), independent adversarial reviewer.
**Snapshot:** `e6f650541` (working tree clean at claim). **Charge:** confirm the mechanism after five repair
waves — walk the whole test set against the current text, verify every quotation claim and every count **by
measurement**, read both sides of every seam the round-5 repairs touched, and state the verified property.
**Snapshot note:** the tree moved after the snapshot while this round ran (the delta and `spec/04` were
edited again); every measurement below was re-run against `git show e6f650541:…` and holds for the snapshot,
and `learn/glossary.html` — the one finding's file — is unmodified in both.
**Measurements:** normalized comparisons (HTML tags stripped, entities unescaped, whitespace collapsed,
space-before-punctuation removed; "nospace" removes all whitespace). Citations: `NN:line` = `spec/NN-*.html`.

**Counts: Critical 0 · High 0 · Medium 1 · Low 0.**
**Verdict: this is the second consecutive round with no Critical and no High — the increment is clean at the
bar and safe to ship.** Every round-5 repair is real and measured: the no-room ground is the turn's block
alone in FI-13(1)(a), CONS-01(v) and PRF-04(vi), with the joint sentence stating that a later block's room
neither rescues nor condemns; FI-11(4)'s "CONS-01(v) reads, in full" is now **exactly** the clause
(9,136 = 9,136 normalized characters) and the delta's blockquote is the same 9,136; the falsifier range
`F-FI-1…F-FI-8` has zero stale occurrences outside the raw review reports; the FI set is nine live names
including `FI_MIN_EXEC_FEE_CAP`; class (E) now says it is a policy floor, not an uncarryability; and the Open
falsifier convention (carried Open with a falsifier, never denied) is stated and applied. The one Medium is a
disclosure survivor: **learn/glossary.html still teaches the deleted wide form** in two live entries — the
exact reading the round-5 repair removed — so the fix list's "course pages and the glossary" item missed the
glossary. It is non-normative; the rules, the guest check and all three course pages are correct. Nothing else
was found.

---

## Finding R4R6-G-01 — Medium: the glossary still teaches the deleted wide no-room form in two live entries

**Severity: Medium.** One-line rationale: the round-5 fix removed the summary condition ("no block of the
range at or after the turn had room") from FI-13(1)(a), CONS-01(v) and PRF-04(vi) because its literal reading
is the round-4 S-02 halt — a producer could leave a position unresolved with no rule breach — but the
**glossary's live entries** still carry that form *and its consequence*, so a reader or implementer working
from the course material is taught the exact reading the normative side deleted; the normative artifact is
correct, so this is a disclosure defect, not a rule defect.
**File + rule id.** `learn/glossary.html`, entry **"Resolution (executed, void, dead)"**: "… set aside on any
of four grounds: its declared nonce is not the account's nonce there; the account's balance there is below
gas limit × max fee per gas + value; the account has code there, so no valid block may execute a transaction
from it; or, at that turn, **no block of the range at or after the turn had room to carry it**, judged on the
same remaining gas the per-block duty reads, **so a block that had room and omitted it leaves the position
unresolved** …"; and the entry **"forceable"**: "… the sender has code at that pre-state … or **no block of the
range at or after the turn had room to carry it** — the remaining gas at that turn was below the gas limit the
transaction declares … **so a block that had room and omitted it leaves the position unresolved**". Against
the corrected normative text: `04:740` FI-13(1)(a) "or, at that turn, **the block in which the turn lies** had
no room to carry it … this is the single condition, and it reads the block of the turn alone, so a later
block's room neither rescues nor condemns a transaction whose turn has passed"; `05:271` PRF-04(vi) the same;
`02:64` CONS-01(v)'s joint sentence "One rule, one predicate, both sides read the same quantity: a block with
room to carry the transaction MUST carry it, and the walk discharges the transaction only when, at its turn,
the block in which the turn lies had no room to carry it …"; and `09`'s corrective parenthetical "the ground
reads the block in which the turn lies, not every block at or after the turn". **Missing rule / correction:**
replace the two glossary sentences with the single-condition form and drop the "leaves the position
unresolved" consequence of the summary reading.
**Assumptions.** None. **Attack trace.** None directly: no rule, no guest check and no land path reads the
glossary. The harm is that a reader implementing from it produces the round-5 S-01 semantics (the round-4
S-02 halt) while the deployed rule reads the turn's block alone; it is the same class of artifact-level
divergence the round-5 repair closed elsewhere.
**Fault-model verdict.** Inside (documentation consistency; no adversary, no protocol effect).
**Attacker cost.** None. **Requirement affected.** The round-5 fix (f) ("the three course pages carrying the
wide no-room form, and the glossary"); consistency of the disclosure set. **Evidence.** the two glossary
entries quoted above; `04:740`, `05:271`, `02:64`, `09`.

---

## Measurements (all by comparison, not reading)

| Claim | Measurement | Verdict |
|-------|-------------|---------|
| FI-11(4) "CONS-01(v) reads, in full" | quoted span 9,136 nospace chars = clause (v) 9,136 nospace chars, **equal**; the quote includes the clause's closing annotation and its final ")" | ✓ whole (the round-5 finding is fixed) |
| The delta's transcription of CONS-01(v) | blockquote 9,136 nospace chars = the same clause, **equal** (the earlier strict-prefix defect is gone) | ✓ whole |
| Falsifier range `F-FI-1…F-FI-8` | tree-wide search outside `iterations/raw`: **0** occurrences of `F-FI-1…F-FI-7` or "seven falsifiers"; spec/10 carries `F-FI-1…F-FI-8` four times and "eight falsifiers" once; index twice | ✓ |
| FI parameter set | index and 09 enumerate nine names — `FI_MAX_PER_BATCH`, `FI_MIN_DRAIN`, `FI_ITEM_MAX_BYTES`, `FI_INCLUSION_DELAY`, `FI_RECORD_GAS_MAX`, `FI_MAX_TX_PER_RECORD`, `FI_ANCHOR_MAX_AGE`, `L2_BLOCK_GAS_LIMIT`, `FI_MIN_EXEC_FEE_CAP` — and 09 says "the live forced-inclusion set counts nine names" | ✓ |
| Class (E)'s rationale | now: "this is a **policy floor** that makes the record void by rule, **not a class of transaction no valid block could carry**, because a cap below the floor can still exceed the current base fee and be perfectly carryable" | ✓ corrected |
| The no-room ground | FI-13(1)(a): "the block in which the turn lies had no room … this is the single condition … a later block's room neither rescues nor condemns"; PRF-04(vi): same; CONS-01(v): the joint sentence; no wide form survives in any normative or course page (only the glossary, R4R6-G-01) | ✓ single condition |
| The Open falsifier convention | stated in 04 ("carried Open and falsified by F-FI-8"), 10 ("an execution-validity rule … neither one of the enumerated classes (A)–(G) nor decided by that pre-state is **carried Open rather than denied**") and DEFERRED.md (F-FI-8's row); the operative conditions are distinguished in the guarantee sentences ("holds only while arrivals stay within the forceable drain (F-FI-2, open and unfixed) and while at least one honest or rational producer lands batches (F-FI-5); the remaining falsifiers are F-FI-1, F-FI-3, …") | ✓ stated once and applied; the operative/disclosed split is readable from the text, not inferred |
| Counts inside the FI rules | 3 modes; 3 limbs of (b); classes (A)–(G) = 7 with (E) the fifth; predicate (i)–(viii) = 8; discharge ground = 4 conditions named in both the rule and the guest check | ✓ |

## The test set, walked against the current text

| Shape | Mode | Producer choice changes it? |
|-------|------|------------------------------|
| `[t1 idx0 nonce n+1, t2 idx1 nonce n]` (descending) | (a) mixed: `t2` executes; `t1` is discharged at its turn (the pre-state before `t2`'s position, nonce ahead). The consensus order rule makes the only alternative payload (t2 then t1) invalid, and `t1` cannot execute first | No |
| Mirror `[t1 idx1 nonce n+1, t2 idx0 nonce n]` | (a): both execute in index order (index order = nonce order) | No |
| Same-nonce pair `[s idx0, t idx1]`, `s` in the last block | (a) mixed: `t`'s turn is the state after the record's last earlier appearing transaction; the nonce is consumed → discharged | No |
| Earlier sibling in the last block, later transaction absent | (a) or (b): the tail turn is the state after the sibling (the last block's body-end), the duty reads that block's own remaining gas there; room → must carry (index order fine); no room → discharged | Room vs no-room decides executed vs discharged — the **disclosed** filling cost of F-FI-2/F-FI-4, and the position resolves either way |
| Multi-block record, the turn's block full while a **later** block has room | (a)/(b): the ground reads the turn's block alone ("the single condition … a later block's room neither rescues nor condemns"), so the transaction is discharged; the duty is turn-scoped and demands nothing of the later block | No — the round-5 ambiguity is closed |
| `maxFeePerGas` below the floor | (b) class (E), live-only; dead → (c) first | No |
| Malformed fee market | (b) class (F) | No |
| Oversized initcode | (b) class (G) | No |
| Sender with code | discharge at the turn (EIP-3607); (a) or (b) | No (the account's own state) |
| Zero-transaction record | (b) (nothing to execute), live-only | No |
| Exact byte/tx bound | not over-bound ("at most") → walk applies | No |
| Exact deadline | (c) first and unconditionally | No |
| Two records of one sender | one executes, the other's transaction is discharged at its turn (nonce consumed) | No |
| Reorg across the window | recomputed from the reorged L1 state | No |

## The verified property, and what would falsify it

**Verified property.** With the per-block duty and the proof-side walk scoped to one turn, the turn pinned by
position (including the re-pinned tail), the consensus-side order requirement and the proof-side index
condition, the byte classes (A)–(G) closing every byte-decidable uncarryability the owner has enumerated, the
four discharge conditions read at the same turn against the same remaining gas, and the fee floor's Open
schedule premise: **there is no admissible block, no publisher input and no producer choice that leaves a
position in no mode or makes a certifiable range unprovable within the stated premises.** The shapes above
each resolve by exactly one mode; the only producer-influenced decision is *which* mode (execute vs
discharge by room), which the rules disclose (F-FI-2/F-FI-4) and which never leaves the position unresolved.
**What would falsify it:** (i) `F-FI-1` — a registered relation breach or an L2 gas-limit schedule under
which a compliant batch's headers cannot carry the required gas (a halt premise the register states as Open);
(ii) `F-FI-7` — a fee schedule that can produce a base fee above `FI_MIN_EXEC_FEE_CAP` (then class (E)'s
policy floor no longer bounds carryability and the round-4 F1 halt returns); (iii) `F-FI-8` — an
execution-validity rule a valid block enforces that is neither in (A)–(G) nor decided by the turn pre-state
(a concrete instance to consider inside the enumeration: a transaction of a type the L2's execution rules do
not accept); (iv) `F-FI-2` — arrivals exceeding the drain (a latency, not a halt: the deadline becomes the
exit — the guarantee is exclusion per unit of the censor's L1 spending, not a latency guarantee); and
(v) `F-FI-5` — no honest or rational producer landing batches. None of these is an admissible-block or
producer-choice hole; each is a stated premise or residual.

## Summary for the lead

| Severity | Count | Findings |
|----------|-------|----------|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 1 | R4R6-G-01 (learn/glossary.html still carries the deleted wide no-room form and its "leaves the position unresolved" consequence in two live entries) |
| Low | 0 | — |

**Strongest attack: none found.** I walked the full test set, measured both quotation claims (FI-11(4) and the
delta: 9,136 = 9,136 normalized characters, equal), searched the tree for stale falsifier ranges (0) and the
wide no-room form (normative rules and all course pages clean; glossary only), and checked the nine-name FI
enumeration, the class (E) rationale and the Open-falsifier convention. The one defect is the glossary
survivor, which is non-normative and does not touch any rule, proof check or land path.

**Is the increment safe to ship?** **Yes — this is 2 of 2 consecutive rounds with no Critical and no High.**
Fix the two glossary sentences in the same pass (they teach the deleted reading), and increment 4 is ready:
the mechanism's walk is total over every shape tested, the duty and the walk read one predicate, the
enumerations and quotations are exact by measurement, and the residual risks are the five named falsifiers
carried Open in the register.
