# Round 8 — raw adversarial review: the consensus core and the halt, final pass

**Reviewer:** r6-gov-generations (task-13), independent adversarial reviewer, round 8.
**Snapshot:** specification content at `fb67df660`; HEAD `71b4996f1` is the freeze commit and changes only
`iterations/08-freeze.md` (verified: `git diff --stat fb67df660 HEAD`). Working tree clean. The reviewed
content is therefore identical to the named snapshot.
**File name note:** the shared task's write scope said `round8-r6-gov-generations.md`; I followed the Lead's
explicit instruction and wrote `round8-core-consensus.md` (the round-7 convention) to keep the round
naming stable.
**Method:** rules judged as written; in-text notes, "closes review round N" tags and the freeze's
verification claims are claims, not evidence. Citation: `NN:line` = `spec/NN-*.html`; `D-n` =
`DECISIONS.md`; `R7-CC-nn` = `iterations/raw/round7-core-consensus.md`.

**Counts: Critical 0 · High 0 · Medium 1 · Low 4.**
**No Critical or High is outstanding; the two Medium/Low-adjacent subjects that are inside the fault model
are R8-CC-01 and R8-CC-02, and neither requires an adversary.**

**Headline.** The assigned verifications pass. The signed generation is now explicitly constant in v1 and
**every rule that scopes by it is coherent**: CONS-01(vii), CONS-02 (store and uniqueness), CONS-04 (locks),
CONS-05 (certificate validity), CONS-08 (validity), CONS-10(7) (header), CONS-11 (conflict) and CONS-12
(uniqueness) each state the one-generation regime and none depends on an advance; with no generation change
the conflict predicate degenerates correctly to same-generation-only and CONS-12's invariant is *stronger*
than its text claims (unconditional per-height uniqueness). The halt disclosure is now consistent across
spec/01, 02, 03, 06, 07, 08, 09, 10 and the index except for one residue: the quorum-loss halt is described
as ending "until a future protocol update" in five places while HALT-01 itself says it ends when the quorum
returns (R8-CC-01). MEM-05/MEM-09/MEM-14/MEM-15 are mutually consistent, including the new exit funding
chain (MEM-15(2b) ↔ L1-13(5) ↔ L1-11 `attestRewardPaid` ↔ ECON-02 clause 5), with two stale register rows
(R8-CC-05). The 1/3-stop state is correctly described in substance, with the cohort-return escape and the
true permanence barrier under-stated (R8-CC-01) and the stake/exit asymmetry not joined in one place
(R8-CC-02). **v1 is implementable as written**, subject to not resurrecting the dormant recovery clauses and
to the five fixes below.

---

## Finding R8-CC-01 — Medium: the quorum-loss halt is described two ways, and the reason given for its permanence is not the reason

**Severity: Medium.** One-line rationale: HALT-01 says a halt caused by an unavailable quorum "persists until
the entry is appended and Ethereum-final **or the quorum returns**", while MEM-13's tombstone, the
membership table, the nine heartbeat parameter rows, the index row and LIM-01 say production halts "until a
future protocol update"/"until an upgrade" — so a reader cannot tell whether an offline third can be
answered by the cohort coming back (it can, with no protocol change) or only by an upgrade; and the reason
those places give ("its committed weight stays in every set version") is not what makes the halt permanent
even if the weight later leaves future versions.

**Exact rule / missing rule.**
- `06:121-127` (**HALT-01**): "a halt under (b) or (d) persists until the entry is appended and
  Ethereum-final **or the quorum returns** (LIVE-01). … where (b) is caused by validators that have stopped
  attesting, the halt is not escapable by any rule of v1." Both halves are true as written (no *rule*
  escapes it; the *quorum returning* is an event, not a rule), but only HALT-01 carries the second half.
- `03:528` (**MEM-13 tombstone**): "a cohort that stops participating halts production **until a future
  protocol update**, because its committed weight stays in every set version and nothing can draw a reachable
  set around it."
- `03:636-637` (membership table, *Offline* row): "if enough weight is offline that no certificate can
  gather quorum, production halts **until a future protocol update** … its weight stays in every set version
  it is already committed to and in every future one".
- `10:38` (guarantee-class preamble), `10:353` (LIM-01 Liveness row), `10:360` (cartel row: "the halt can
  persist until a future protocol update"), `09:209-218` (every withdrawn heartbeat row: "a cohort that
  stops participating halts production **until an upgrade**"), `index.html:424` (MEM-13 row: "halts
  production until an upgrade"), and `learn/08-when-things-go-wrong.html:375-377` ("clearing it needs a
  future protocol update").
- Why the stated reason does not carry the conclusion: `03:290-292` (**MEM-05(2)**) removes an exiting
  entry from every later set version and `03:467-474` (**MEM-09(1)**) redraws each version from the entries
  active at its snapshot, so later versions can be reachable. What actually makes the halt permanent is
  **the epoch containing the next unfinalised height has an immutable, already-committed mapping
  (`03:504-507`, MEM-09(4); `02:244-246`, CONS-08(2)), the height schedule is the fixed default
  (`02:429-450`, CONS-13(2); CONS-16 is a tombstone), and no batch may skip a height (`04:217`, L1-06;
  `02:69-71`, CONS-01(iii))** — so later, reachable set versions can never be consumed. That barrier is
  stated only incidentally, in `10:362` (LIM-01: "an epoch with more than one third of its committed weight
  gone cannot be passed, so the chain can wedge permanently"), under a different subject.
- **Missing rule:** one statement in the halt rules that (i) a quorum-loss halt ends when the committed set
  of the epoch containing the next unfinalised height can form a quorum again — normally the offline cohort
  returning to vote — with no protocol change required, and (ii) it is permanent only while that set never
  returns, because the mapping is immutable and no rule re-partitions or skips a height (a protocol update
  is required to change the set, the schedule or the mechanism, not to let returning validators vote).

**Assumptions.** A cohort holding ≥ 1/3 of one committed epoch's weight stops while remaining bonded. No
adversary, no assumption failure beyond the liveness assumption that failed.

**Attack trace / failure trace.** No attack: the failure is in the disclosure and in what a reader does with
it. (1) The cohort goes offline; ≥ 1/3 is missing, so `3s > 2W` fails for every height and finality halts at
the last certified height (CONS-03, CONS-08(2); HALT-01(b)). (2) A validator or user reading `03:528`,
`09:209-218`, `index:424` or `10:353` concludes the chain needs a protocol update and that returning is
pointless or insufficient; a validator reading `06:123-124` learns that returning restores quorum. (3) A
reviver or a future change order that trusts the stated reason ("the weight stays in every set version")
would design a fix that excludes or re-weights the cohort from *future* versions — which does not touch the
stuck epoch whose mapping is immutable — and would not fix the brick. The correct description is the one in
the missing rule; a protocol update is needed only for the classes where no member of the committed set can
ever return, or to change the epoch machinery.

**Fault-model verdict.** Inside (disclosure inconsistency; no assumption failure, no attacker).
**Attacker cost.** None.
**Requirement affected.** D-16's disclosed halt position; HALT-01's consistency; LIVE-01/LIVE-05; the
round-8 criterion that production stopping is described consistently; MEM-13's tombstone accuracy.
**Evidence.** `06:115-130`; `03:290-292`, `03:467-474`, `03:504-507`, `03:528`, `03:636-637`;
`02:69-71`, `02:244-246`, `02:429-450`, `02:505-522`; `04:217`; `09:209-218`; `10:38`, `10:353`,
`10:360`, `10:362`; `index.html:424`; `learn/08-when-things-go-wrong.html:375-377`.

---

## Finding R8-CC-02 — Low: the stake/exit asymmetry of a stopping cohort is disclosed in pieces, never in one place

**Severity: Low.** One-line rationale: the round's criterion asks for the 1/3-stop state to be stated with
its asymmetry — the cohort keeps its stake, its slots and its standing, is not punished for silence, and can
request exit and withdraw after `D_WITHDRAW`, while value above the frozen checkpoint cannot leave at all —
and no single rule joins the two halves, although the course comes closest on one page.

**Exact rule / missing rule.** The cohort half: `03:286-306` (MEM-05(1)-(3): the entry remains in every
committed set, remains fully slashable but is not penalised for silence, and may withdraw once the exit is
effective for `D_WITHDRAW`, the evidence window closed and no exposure remains), `03:528` and
`03:636-637` (no rule excludes an entry for failing to attest, no rule reduces weight),
`03:249-253` (MEM-14(2): the `N_MAX` bound delays new entrants rather than evicting anyone, so a
full set stays full while the cohort holds its slots), `10:360` ("A cartel of at least one third can halt
the chain … Denial of service, not a safety break"). The user half: `03:350` (MEM-15(4): value above the
latest accepted checkpoint has no L1-provable claim and becomes withdrawable only when a later checkpoint
covers it, or when the L2 resumes), `10:325-329` (LIVE-05 table), `10:359` (LIM-01 exit-scope row).
The closest joined statement is the course: `learn/08-when-things-go-wrong.html:365-366` (silence keeps
stake and place) and `:381-386` (silence is unpunished; production halts, the set does not change) — but
it does not say the cohort can *withdraw* while the users above the checkpoint cannot.
**Missing rule:** one sentence, in HALT-01 or LIM-01, stating both halves together and naming the
consequence: a stopping coalition pays no penalty, keeps its stake and can leave after `D_WITHDRAW` (subject
to ECON-07's evidence-window Open item), while the value it strands above the last accepted checkpoint is
frozen for as long as the halt lasts.
**Assumptions.** The cohort stays bonded and silent; the evidence window closes or is undefined (the Open
item of `10:362`). No adversary.
**Attack trace.** Not an attack: a user deciding whether to wait, or a reviewer judging whether the halt is
"priced", cannot find the asymmetry stated once; the two halves are in different rules and pages, and the
LIM-01 cartel row frames the halt as an unpriced denial of service without noting that the cohort can exit
with its stake while the stranded value cannot.
**Fault-model verdict.** Inside (disclosure completeness; no attacker needed).
**Attacker cost.** None.
**Requirement affected.** D-16's halt disclosure; the round-8 criterion ("the asymmetry stated in one
place"); LIM-01's "none may be silently dropped when the design is summarised".
**Evidence.** `03:249-253`, `03:286-306`, `03:345-350`, `03:528`, `03:636-637`; `10:323-329`,
`10:353`, `10:359-360`, `10:362`; `learn/08-when-things-go-wrong.html:365-366`, `:381-386`.

---

## Finding R8-CC-03 — Low: CONS-05's certificate object omits the generation field that the same page's encoding table and three other rules say it carries

**Severity: Low.** One-line rationale: the object definition and the validity predicate of the same rule
disagree — `C = (chain_id, epoch, H, R, B, set_root(epoch), signers, signatures)` has no
`recovery_generation`, yet the predicate requires it, CONS-08(1) and CONS-10(7) say every certificate
carries it, and the encoding table says it is "carried so the acceptance rule can reject a superseded
generation without re-deriving it"; in v1 the generation is constant so no acceptance decision changes, but
this is the field the whole generation scoping is defined over and it must be fixed before any revival.
**Exact rule / missing rule.** `02:178` (CONS-05 tuple) versus `02:179-180` (validity: "`recovery_generation`
equals the generation the Inbox holds at acceptance and the generation signed by every contributing vote"),
`02:41-42` (encoding table: `CommitCertificate` includes `recovery_generation:u64`), `02:243` (CONS-08(1):
"every vote **and certificate** also carries the recovery generation"), `02:347` (CONS-10(6) `cert_hash`
preimage includes it), `02:360` (CONS-10(7): "carried by every certificate (CONS-05)"). Carried from round 6
finding G-5 and never reviewed or repaired since. **Missing rule:** add the field to CONS-05's tuple (or
state where a verifier reads it), so the object, the predicate and the encoding agree.
**Assumptions.** None.
**Attack trace.** Not exploitable in v1: the generation is constant, so a verifier that reads it from the
Inbox and one that reads it from the certificate compute the same value, and a certificate whose signed
votes disagree with the header is rejected in-guest anyway (PRF-04(viii)). The defect is definitional: one
page gives two field lists for the object that carries the signed generation, and the claim that the field
is carried so the acceptance rule need not re-derive it is false of the object CONS-05 defines. It becomes
load-bearing the moment a generation can advance (DEFERRED.md §3 revival).
**Fault-model verdict.** Inside (specification defect; no adversary). **Attacker cost.** None.
**Requirement affected.** D-15's signed-generation binding as kept by D-16; CONS-05/CONS-08/CONS-10
consistency; the round's "certificate validity is coherent when the generation never advances" check (it is
coherent in effect, not in definition).
**Evidence.** `02:41-42`, `02:178-180`, `02:243`, `02:347`, `02:360`; `round6-gov-generations.md` G-5.

---

## Finding R8-CC-04 — Low: four dormant clauses in the consensus and membership pages still read the deferred recovery as a state or mechanism

**Severity: Low.** One-line rationale: the freeze's verification claim is "no live rule reads a tombstoned
rule or parameter", and while every clause that would *do* something with the recovery is now explicitly
dormant, four normative sentences in spec/02 and spec/03 still assert a recovery-produced state or
mechanism; each is inert in v1 but each is exactly the class the check names, and one of them is a
justification for a structural deletion.
**Exact rule / missing rule.**
- `02:76` (**CONS-01**, slashing scope): the objectively decidable set includes "a proposal at or below the
  latest L1-accepted checkpoint **or under a superseded recovery generation**" — no v1 rule can supersede a
  generation, so half of that offence scope is unreachable.
- `02:100` (**CONS-02**): "The store MUST NOT be cleared, truncated, rewritten or restarted from empty **by
  a stall resolution**" and "Re-signing a discarded height under the new generation is not equivocation" —
  both describe a transition v1 forbids.
- `02:156` (**CONS-04(2)**): "The former retired-height carve-out is withdrawn as redundant: a full-range
  discard is generation-scoped, so the generation change is the single mechanism that releases those locks"
  — the justification rests on a discard that cannot occur; any revival must reinstate the carve-out *and*
  the anchor-generation rule that round 6 found missing (G-3).
- `03:519` (**MEM-09(6)**): "an upgrade, a governance call **or a recovery path** may not write, edit or
  rewrite either entry for an epoch already entered" — no recovery path exists in v1.
- Also `02:73` ("superseded-generation heights may not be proposed") and `02:494` ("a lock formed under a
  superseded generation would be void"), which are counterfactual and harmless.
**Missing rule:** delete or tombstone-marker these four sentences. **Assumptions.** None.
**Attack trace.** None; no acceptance, lock or halt decision changes. The cost is that a reader must decide
which sentences are live, and a reviver can mistake the deleted carve-out for a satisfied obligation.
**Fault-model verdict.** Inside (specification hygiene). **Attacker cost.** None.
**Requirement affected.** The freeze's zero-reads claim; D-16's tombstone discipline; R7-CC-02's closure.
**Evidence.** `02:73`, `02:76`, `02:100`, `02:156`, `02:494`; `03:519`; `08-freeze.md` line 11.

---

## Finding R8-CC-05 — Low: two register rows are stale relative to the exit funding and wait rules they register

**Severity: Low.** One-line rationale: L1-13(5) now says the k−1 attach proofs "have a payer, a claimant and
a stated failure mode, and the exit's liveness is no longer an unrepaired Open item", while the register
still asks who pays for the attach proof and calls the attach incentive Open; and the registered
`W_ROOT_WAIT_MAX` still adds `E_EPOCH` although the D-16 exit no longer waits for an epoch boundary.
**Exact rule / missing rule.** `09:256` (PARAM-03 owed-measurement row: "Withdrawal-root and veto costs:
… and **who pays for the attach proof** … The exit path's liveness and the **Open attach incentive of
L1-13(5)** and MSG-04") versus `04:416` (L1-13(5): the proving share of ECON-02 clause 5 funds them, the
claim path is L1-11's ledger, payment is best-effort and never gates the attestation), `04:450-454` (L1-11
`attestRewardPaid`), `07:155` (ECON-02(5): the share funds "the withdrawal-root attestation proofs of
L1-13(5)"), `03:348` (MEM-15(2b)). And `09:201` + `04:416` register
`W_ROOT_WAIT_MAX = E_EPOCH + T_PROOF_MAX_PERMITTED` while `index.html:552` states the wait "is for the
k−1 attestation proofs of an already-accepted checkpoint, **not for an epoch boundary or settlement
progress**". **Missing rule:** re-word the owed row to the residual that genuinely remains open (the
observed willingness to pay / the measurement of the reward rate, as MEM-15(2b)'s falsifier implies) and
drop `E_EPOCH` from the registered wait, or state why the conservative term is kept deliberately.
**Assumptions.** None. **Attack trace.** None; the error direction is conservative (the wait is
over-stated), but the two statements are contradictory and the register is the reviewer's discovery surface.
**Fault-model verdict.** Inside (register consistency). **Attacker cost.** None.
**Requirement affected.** D-16's exit guarantee and its funding; the freeze's "register consistent in both
directions" claim; MEM-15(2b)/L1-13(5)/L1-11 consistency.
**Evidence.** `09:201`, `09:256`; `04:416`, `04:450-454`; `07:155`; `03:348`; `index.html:552`.
Carried in part from round 7 R7-CC-04.

---

## The four assigned verifications

**1. The generation is constant in v1, and every rule that scopes by it is coherent; nothing depends on an
advance.** Verified rule by rule at `fb67df660`. *Vote and store* (`02:82-100`): the vote carries
`recovery_generation` and must equal the Inbox value; uniqueness is per
`(chain_id, height, type, generation)`; the store paragraph now says explicitly that "no generation is
superseded in v1 … the scoping is a keying discipline rather than a recovery contingency". *Header*
(`02:360`): the field is constant, signed, and "no upgrade, operator, client or rotation may change it".
*Certificate* (`02:178-180`): validity compares against the L1-held activation value and "no certificate can
be voided by a supersession". *Locks* (`02:144-156`): per height **and** per generation; with one generation
they are ordinary per-height locks, released by the commit of the locked value or by a strictly later
same-height PoLC — the generation-change release is stated as dormant and is not needed for liveness.
*Validity* (`02:242-255`): epoch-scoped, forever; canonical status is "not adjudicated by any v1 rule".
*Conflict* (`02:363-369`): the same-generation requirement is explicit and "no generation change occurs in
v1, so every admissible pair is within one generation". *Uniqueness* (`02:388-428`): the invariant is
generation-scoped, and with one generation it is the unconditional per-height uniqueness its text no longer
claims — v1 is stronger than the rule states, which is safe. I found **no rule whose correctness depends on
an advance**: no acceptance path, lock release, conflict predicate or halt trigger is satisfied or defeated
by a generation that never changes; the only defects are the definitional residue (R8-CC-03) and the four
dormant sentences (R8-CC-04).

**2. The halt disclosure is complete and consistent wherever production stopping is described.** Verified at
the halt sites: `02:71`, `02:419`, `02:455-465`, `02:485-499` (CONS-01(iii), CONS-12, CONS-13(5),
CONS-15); `03:509-518` (MEM-09(5) boundary halt), `03:528` (MEM-13), `03:636-637` (offline table);
`06:96-136` (HALT-01/02), `06:167-224` (HALT-03 cap), `06:225-253` (HALT-04), `06:39-92` (REC-01);
`10:153-222` (LIVE-01), `10:312-333` (LIVE-05), `10:344-377` (LIM-01); `01:164-169`, `01:220-226`,
`01:327`, `01:346`, `01:350`, `01:563`; `07:33`; `09:45`, `09:180-181`, `09:209-218`;
`index.html:45`, `:358`, `:424`, `:478`, `:484`, `:524`. **Consistent on**: no recovery path of any
kind, no in-protocol bound on a halt, the boundary holds, funds at or below the checkpoint are safe and
exitable (subject to the proving market), value above is frozen, and clearing needs a protocol update for
the settlement-stall and unavailable-data classes. **One inconsistency**: the quorum-loss class
(R8-CC-01) — "until a future protocol update" versus HALT-01's "or the quorum returns", and the permanence
barrier stated only incidentally in LIM-01. **One omission**: the asymmetry is not joined in one place
(R8-CC-02).

**3. MEM-05/MEM-09/MEM-14/MEM-15 are mutually consistent.** Verified. *Exit vs set snapshots*:
MEM-05(2) makes effectiveness part of the ledger state read at the snapshot point `N(k)` and MEM-09(1)
commits "exactly the ledger entries that are active at that same instant" — one rule owns effectiveness, the
other owns the snapshot, and they agree; the churn cap is applied inside the same append (MEM-05(2),
ECON-03(6)). *Admission bound*: MEM-14(2) applies `N_MAX` at set formation, delays rather than evicts, and
never edits a published root — consistent with MEM-09(4)'s immutability and CONS-08. *Exit vs halt*:
MEM-15(3) (settlement keeps raising the checkpoint over already-certified heights while production is
halted) is consistent with MEM-09(5) (a missing *entry* halts epoch entry, not settlement) and with `04:98-109`
(land is permissionless and unconditional). *Exit funding*: MEM-15(2a)/(2b) ↔ L1-13(3)/(5) ↔ L1-11
(`attestRewardPaid`, best-effort, never gating) ↔ ECON-02 clause 5 (the proving share names
withdrawal-root attestations) all agree. *Residual*: MEM-05(3)(b) requires the evidence window closed for
every epoch the entry was in, which depends on ECON-07(1)'s Open anchor (`10:362`) — correctly carried as
an Open item there, not a contradiction here. The only register-level mismatch is R8-CC-05.

**4. A third of the validators stopping: the state is described correctly, with two disclosure gaps.**
Correct as written, in this order: quorum is `3s > 2W` over the committed set of the height's epoch
(`02:104-119`), so with ≥ 1/3 silent no height can be certified and finality halts at the last certified
height (HALT-01(b), `06:102-103`); no rule excludes the silent entries, removes weight or rotates the set
(`03:528`, `03:636-637`), and the epoch containing the next unfinalised height has an immutable committed
mapping, so later (possibly reachable) set versions can never be consumed (MEM-09(4), CONS-13(2), CONS-16
tombstone); the checkpoint can still advance to the last certified height because `land` is permissionless
and unconditional and the certificates already exist (MEM-15(3), `04:98-109`); users at or below the
resulting checkpoint exit on L1 through MEM-15(1)+(2a) with a k-attestation root over any already-accepted
checkpoint, funded via L1-13(5)/L1-11 and resting on the disclosed proving market of MEM-15(2b); value above
the checkpoint, and value never messaged, cannot leave while the halt lasts (MEM-15(4), LIVE-05, LIM-01);
and the cohort keeps its stake, is not punished for silence (non-participation is not an offence and is not evidence of one, `03:637`,
which cites WH-02) and can request exit and withdraw after `D_WITHDRAW` (MEM-05(1)-(3), MEM-06(3)), while
`N_MAX` keeps its slots occupied and delays new entrants (MEM-14(2)). **Gaps:** the cohort-return escape
and the true permanence barrier (R8-CC-01), and the asymmetry in one place (R8-CC-02).

## Is v1 implementable as written?

**Yes.** I found no missing mechanism, no unsatisfiable MUST and no unresolved security-relevant choice in
spec/02 or spec/03 at this snapshot. The generation is a constant that every consumer treats as a constant;
the consensus rules (validity, quorum, locks, commit, epochs, handoff, authentication, equivocation,
uniqueness, halting) are self-consistent; membership (activation, stake, exit, keys, set snapshots, the
`N_MAX` bound, weak subjectivity) is self-consistent with the consensus and settlement pages; the exit and
its funding are specified end to end; and the four deferred mechanisms are tombstoned, with every remaining
read either explicitly dormant or one of the four sentences in R8-CC-04. Implementing v1 requires only
that the dormant clauses are not built as live code and that the five findings below are fixed, none of
which is a blocker: R8-CC-01 (halt wording and reason), R8-CC-02 (asymmetry in one place), R8-CC-03
(CONS-05 tuple), R8-CC-04 (four dormant sentences), R8-CC-05 (two register rows).

## Summary for the lead

| Severity | Count | Findings |
|----------|-------|----------|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 1 | R8-CC-01 (quorum-loss halt described "until a future protocol update" vs HALT-01's "or the quorum returns"; the real permanence barrier is stated only incidentally) |
| Low | 4 | R8-CC-02 (stake/exit asymmetry not joined in one place) · R8-CC-03 (CONS-05 certificate tuple omits `recovery_generation`) · R8-CC-04 (four dormant recovery reads in spec/02/03) · R8-CC-05 (two stale register rows vs L1-13(5)/L1-11) |

**Strongest attack:** R8-CC-01. No adversary is needed: the artifact itself gives two answers for the same
halt. HALT-01 says a quorum-loss halt persists "until the entry is appended and Ethereum-final **or the
quorum returns**"; MEM-13's tombstone, the membership offline table, the nine heartbeat rows, the index row,
LIM-01 and the course say production halts "until a future protocol update"/"until an upgrade". The second
answer omits the only in-v1 escape (the silent cohort returning to vote) and gives a reason — the cohort's
weight stays in every set version — that MEM-05(2)/MEM-09(1) refute, while the actual barrier (the immutable
mapping of the epoch containing the next unfinalised height, with no rule able to skip or re-partition a
height) appears only incidentally in an unrelated LIM-01 row. A reviver who trusts the stated reason would
build a fix that excludes the cohort from *future* versions and would not clear the brick.

**Inside the fault model?** Yes for R8-CC-01 and R8-CC-02 (no assumption failure, no attacker); R8-CC-03,
R8-CC-04 and R8-CC-05 are specification/register hygiene with no fault-model content. **No Critical or High
is outstanding.**

**Checked, and holds (not re-listed):** the round-7 repairs in spec/02 and spec/03 are real and complete
(CONS-01(iii)/(vii), CONS-02, CONS-04(1)/(2), CONS-05, CONS-08(4), CONS-09, CONS-10(7), CONS-11, CONS-12,
CONS-13(5), CONS-15, MEM-15(2a)-(5) all now state the v1 halt disclosure and the constant generation); the
exit's proving-market dependency is disclosed at MEM-15(2b), LIVE-05, LIM-01 and the index with its
falsifier; `attestRewardPaid` is specified in L1-11 and funded by ECON-02 clause 5; the offline-cohort
state, the boundary halt, the backpressure cap, the missing-entry halt and the data-unavailable halt are all
correctly characterised as unbounded liveness failures with no v1 remedy; and the parallel round-7 reports'
findings (spec/07 offence, spec/01 sweep, course, configHash) are repaired or correctly tombstoned — I
re-checked the live-read residue myself rather than relying on the freeze's claim.
