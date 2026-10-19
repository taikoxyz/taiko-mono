# Round 9 — raw adversarial review: the consensus core, confirmation pass

**Reviewer:** r6-gov-generations (task-17), independent adversarial reviewer, round 9.
**Snapshot:** `3b4096a77` (branch `etna-pos-zk`). Verified: `git diff --stat 3b4096a77 HEAD` is empty and the
working tree is clean, so the reviewed content is exactly the named snapshot.
**Method:** rules judged as written; in-text "closes review round N" notes and the freeze's verification
claims are claims, not evidence. Citation: `NN:line` = `spec/NN-*.html`; `R8-CC-nn` =
`iterations/raw/round8-core-consensus.md`; `R8-AC-nn` = `round8-artifact-consistency.md`.

**Counts: Critical 0 · High 0 · Medium 0 · Low 3.**
**This is a clean round on the lead's definition: no Critical and no High. I found no attack, no
broken requirement and no unresolved contradiction in spec/02 or spec/03.** The three Lows are residuals:
one carried unfixed from round 8 (CONS-05's certificate tuple), two created or missed by the round-9
sweep (a reversed signing-store obligation in a dormancy note, and two artifacts that still lack the
cohort-return escape). None affects a v1 decision; all three should be fixed before the next revival.

**Would I build on this specification? Yes.** The consensus core is internally consistent, complete at
the level of the rules it states, and (with the caveats it names) implementable; the round-8 CONS-12
repair is real and complete, every generation-scoping rule is coherent with a constant generation, the
halt is now told one way, and nothing in spec/02 or spec/03 depends on a deferred mechanism.

---

## Finding R9-CC-01 — Low: CONS-05's certificate object still omits the generation field that the same page's encoding table and three other rules say it carries

**Severity: Low.** One-line rationale: the object definition and the validity predicate of the same rule
disagree, and the round-8 close-out did not touch it — `C = (chain_id, epoch, H, R, B, set_root(epoch),
signers, signatures)` has no `recovery_generation`, yet the predicate requires it, CONS-08(1) and
CONS-10(7) say every certificate carries it, and the encoding table says it is carried "so the acceptance
rule can reject a superseded generation without re-deriving it"; in v1 the generation is constant, so no
acceptance decision changes, but this is the field the whole generation scoping is defined over.
**File + rule id:** `spec/02-consensus.html` CONS-05 (tuple at `02:178`), versus `02:179-180` (validity),
`02:41-42` (encoding table `CommitCertificate`), `02:243` (CONS-08(1)), `02:344` (CONS-10(6) `cert_hash`),
`02:360` (CONS-10(7) "carried by every certificate (CONS-05)"). Carried from round-6 G-5 through round-8
R8-CC-03 and reported as closed there; the round-9 diff to spec/02 (five hunks) does not include it.
**Missing rule:** add the field to CONS-05's tuple, or state where a verifier reads the certificate's
generation, so the object, the predicate and the encoding agree.
**Assumptions.** None.
**Attack trace.** Not exploitable in v1: the generation is constant, so a verifier that reads it from the
Inbox and one that reads it from the certificate compute the same value, and a certificate whose signed
votes disagree with the header is rejected in-guest anyway (PRF-04(viii)). The defect is definitional: one
page gives two field lists for the object that carries the signed generation, and the claim that the
field is carried so the acceptance rule need not re-derive it is false of the object CONS-05 defines. It
becomes load-bearing the moment a generation can advance (DEFERRED.md §3 revival).
**Fault-model verdict.** Inside (specification defect; no adversary, no assumption failure).
**Attacker cost.** None.
**Requirement affected.** D-15's signed-generation binding as kept by D-16; CONS-05/CONS-08/CONS-10
consistency; the round's "certificate validity is coherent when the generation never advances" check —
coherent in effect, inconsistent in definition.
**Evidence.** `02:41-42`, `02:178-180`, `02:243`, `02:344`, `02:360`.

---

## Finding R9-CC-02 — Low: the round-9 dormancy note reverses who may clear the signing store

**Severity: Low.** One-line rationale: the pre-round-9 obligation forbade a stall resolution from clearing
the durable sign-state store ("MUST NOT be cleared, truncated, rewritten or restarted from empty **by a
stall resolution**, a restart or a resync"); the round-9 note drops the stall resolution from that
prohibition and instead says "the only action that would have cleared it is the stall resolution" — which
inverts the original obligation and would invite a revival to make the resolution clear the store, the
amnesia breach the rule exists to prevent.
**File + rule id:** `spec/02-consensus.html` CONS-02, the store paragraph (`02:100`). Current text:
"The store MUST NOT be cleared, truncated, rewritten or restarted from empty **by a restart or a resync**,
and no v1 rule clears it: **the only action that would have cleared it is the stall resolution**, which is
deferred by D-16 and MUST NOT be implemented." Round-8 text (git `fb67df660`): "… restarted from empty
**by a stall resolution**, a restart or a resync". The original design's scoping change on a resolution
was to *disregard* superseded-generation entries for new signing, never to erase the record.
**Missing rule:** keep the prohibition's object complete — nothing (including a revived resolution) may
clear the store; a resolution changes only the generation scoping of entries.
**Assumptions.** None for v1 (no action clears the store either way; the sentence's operative half is
correct). The defect is in the historical/revival statement.
**Attack trace.** Not in v1 (nothing clears the store). Failure trace for a revival: an implementer reads
`02:100`, builds the revived stall resolution to clear or truncate the store, and re-opens the amnesia
attack CONS-02 exists to prevent ("a node restarts without a durable sign-state store … becomes slashable
while also making two conflicting certificates possible", `02:101-102`).
**Fault-model verdict.** Inside (specification hygiene with a security-relevant revival consequence; no
adversary in v1). **Attacker cost.** None.
**Requirement affected.** D-16's tombstone discipline; CONS-02's durability obligation; HALT-02(a)/
CONS-15(4).
**Evidence.** `02:94-102` (current), versus `git show fb67df660:…/02-consensus.html` line 100.

---

## Finding R9-CC-03 — Low: the cohort-return escape is still missing from the rule index and one course paragraph

**Severity: Low.** One-line rationale: the round-8/9 repair states the quorum-loss halt correctly in
HALT-01, MEM-13's tombstone, the membership offline row and the ten withdrawn heartbeat rows — production
halts, **ends with no protocol change when the committed cohort returns to vote**, and is permanent only
while it never returns — but two artifacts still carry the old unconditional phrasing, so the artifact as
a whole does not tell the halt one way.
**File + rule id:**
- `spec/index.html:424` (MEM-13 index row): "membership has no liveness gate, a cohort that stops
  participating **halts production until an upgrade**, and A-CONS-1 is unchanged." The index file was not
  in the round-9 diff, so this row still omits the escape (and states the old reason).
- `learn/08-when-things-go-wrong.html:135` (the silent-cohort paragraph): "The silent validators keep their
  whole bonded stake; they forfeit only the rewards they did not earn. **Clearing the halt needs a future
  protocol update**, not a rotation." In context this is the quorum-loss halt, where the cohort's return is
  the escape and no protocol update is needed.
- Correct statements to align with: `06:123-124` (HALT-01: "persists until the entry is appended and
  Ethereum-final **or the quorum returns**"), `03:527` (MEM-13 tombstone: "the halt ends with no protocol
  change if that committed cohort returns to vote … permanent only while that cohort never returns"),
  `03:636` (offline row, including the stake/exit asymmetry), `09:212-221` (all ten withdrawn heartbeat
  rows), `10:37`, `10:217`, `10:359`.
**Missing rule:** bring the index row and the course paragraph to the same formulation (the halt ends when
the committed cohort returns; only changing the set, the schedule or the mechanism needs an upgrade).
**Assumptions.** None. **Attack trace.** None; a reader of the index or the course is told a returning
cohort cannot clear the halt, which is false and could steer a validator, user or future change order
toward an unnecessary protocol change.
**Fault-model verdict.** Inside (disclosure consistency; no attacker). **Attacker cost.** None.
**Requirement affected.** D-16's halt disclosure; the round's "halt story told one way" criterion;
R8-CC-01 (its fix did not reach these two artifacts).
**Evidence.** `index.html:424`; `learn/08-when-things-go-wrong.html:135`; `06:121-127`; `03:526-528`,
`03:636`; `09:212-221`; `10:37`, `10:217`, `10:359`.

---

## Verification of the assigned subjects

**1. The CONS-12 repair is real and complete; no live sentence stages the deferred stall resolution or a
generation advance.** Verified by reading the rule and by a whole-page scan of spec/02 and spec/03 for 23
deferred names (`REC-02`, `REC-03`, `REC-04`, `GOV-04`, `MEM-13`, `CONS-16`, `PRF-15`, `L1-14`,
`FI-10…FI-14`, `HEARTBEAT_*`, `T_ROTATE`, `T_STALL_GOV`, `T_GOV_RESUME`, `FI_*`, `M_AGG_MAX`,
`AGG_PROVER_PPM`, `forcedBoundary`, `govResume`): **zero live candidates in either page** — every hit is
explicitly deferred, dormant, counterfactual ("would", "were it live", "cannot arise in v1") or a
tombstone's own text. The generation scan in spec/02 returns only the constant-regime clauses (vote bytes
`02:35-37`, certificate `02:41-42`, validity `02:84-86`, `02:179`, header `02:360`, `cert_hash` `02:344`,
uniqueness `02:94`, locks `02:145-146`, CONS-12 `02:393-394`); "may discard" has zero hits, and the only
"conditional on the stall-resolution rules" sentence now ends "**D-16 retires the condition with the
mechanism — with the resolution deferred, no event in v1 can discharge it**" (`02:394`). CONS-12's opening
says the deleted unconditional claim was deleted because a history-discarding event "**were it live**"
would produce a second certified height, and "**In v1 no such event exists** … the generation never
advances, no height is discarded or re-produced, and the generation-scoped form below is exactly as strong
as the unconditional one" (`02:394`). An artifact-wide scan (spec + learn, same 23 names) found only
tombstone prose in other pages (checked individually: `07:511-518` ECON-04(6) tombstone, `08:377`
withdrawn parameters, `01:611-613` tombstone reference, `06:391-402` REC-02 tombstone).

**2. The generation is constant and every scoping rule is coherent.** `02:73` (CONS-01(vii): the current
generation is the L1-held activation value; "no live rule increments it"), `02:100` (CONS-02: "the
generation stays at its activation value … this scoping is a keying discipline"), `02:145-156` (CONS-04:
per height and per generation; the generation-change release is dormant and not needed — locks are released
by the commit of the locked value or a strictly later same-height PoLC), `02:179-180` (CONS-05: "no
certificate can be voided by a supersession"), `02:243-255` (CONS-08: epoch-scoped forever; canonical
status "not adjudicated by any v1 rule"), `02:360` (CONS-10(7): "no upgrade, operator, client or rotation
may change it either"), `02:363-369` (CONS-11: "no generation change occurs in v1 … every admissible pair
is within one generation"), `02:393-428` (CONS-12), `02:485-497` (CONS-15: trigger (2) is dormant because
"no generation is superseded"). Nothing in the core requires an advance: every check is an equality
against one value, and with one generation CONS-12 is in effect the stronger unconditional per-height
uniqueness its text says it deleted.

**3. The halt story is now told one way.** HALT-01 `06:115-130` (no recovery path; a (b)/(d) halt persists
"until the entry is appended and Ethereum-final **or the quorum returns**"); MEM-13's tombstone `03:526-528`
names the permanence barrier (the epoch containing the next unfinalised height is already committed and
immutable; no rule may skip, re-partition or re-open a height; later set versions may become reachable but
cannot be consumed for the stuck height) and the stake/exit asymmetry (the cohort keeps its stake, slots
and standing, is not penalised for silence, and may exit and withdraw after `D_WITHDRAW` and the evidence
window closes, while the stuck height cannot be passed); the offline row `03:636` repeats both and fixes
the reason ("no rule removes it from a future version either — its owner's exit and a slashing are the only
paths"); the ten heartbeat rows `09:212-221`, the guarantee-class preamble `10:37`, LIVE-01 `10:217` and
the cartel row `10:359` all state the cohort-return escape. R8-CC-01 and R8-CC-02 are fixed — except for
the index row and the course paragraph in R9-CC-03.

**4. Nothing in the core depends on a deferred mechanism.** Forced inclusion: CONS-01(v) is a tombstone and
no validity condition anywhere in spec/02/03 reads it (0 hits). Heartbeat eligibility: membership is the
bonded set, and `03:467-474` (MEM-09(1)) draws each set version from the active ledger entries with no
liveness gate; `02:440-441` (CONS-13(2)) says the same for the boundary record. Rotation: the schedule is
the fixed default (`02:440`), and the boundary halt `02:455-465` and `03:509-518` are stated without
it. Aggregation: settlement is one proof from one registered backend and withdrawal roots are k
attestations (`03:346-347`, MEM-15(2a)); spec/02/03 contain no `PRF-15`/`L1-14` reference at all.
Stall resolution: no rule in either page reads `REC-02`/`REC-04`/`GOV-04` outside a tombstone or a
dormancy note. The core's liveness path (epoch entry from L1-committed entries, boundary halt, backpressure
halt, quorum-return) is complete without any deferred mechanism.

**Also re-verified (round-8 repairs in my pages).** `02:16` states CONS-01–CONS-15 in full and CONS-16 as a
tombstone (R8-AC-04); `02:76` limits the objectively decidable offence scope to the checkpoint case
(R8-CC-04); `02:100` and `02:156` are restated as dormant/historical with the carve-out justified by the
deferral rather than by a discard (R8-CC-04 — with the R9-CC-02 wording slip); `03:46-48` states D5 in its
D-11-relaxed form and `03:310-311` (MEM-05(5)) no longer argues from the one-transaction premise
(R8-EBA F5); MEM-15(1)/(2a)/(2b) name both exit dependencies (funded proving market and retained
witness inputs) with their falsifier and anchor the delay on the root record's own `l1BlockNumber`
(R8-EBA F4/F6); `09:204` explains the `E_EPOCH` term in `W_ROOT_WAIT_MAX` as the owner rule's own
registered allowance and `09:259` no longer claims the attach payer is unfunded (R8-CC-05);
`07:224-239` (ECON-07) makes `evidenceClose(e)` a time instant with a permissionless `freezeEpoch` and an
ascending-epoch cascade, which is consistent with MEM-05(3)(b)'s "the evidence window `W_EVIDENCE` has
closed" predicate and MEM-06(1)'s retention rule.

## Checked, and holds (positive results for the confirmation)

- CONS-12 is exactly as strong as it needs to be in v1, and its scoping machinery is retained for revival
  without any v1 rule reading it (`02:393-394`, `02:414-420`).
- The signing-uniqueness store, the lock rule and the conflict predicate are the ordinary CometBFT rules
  under a constant generation; no acceptance path, lock release, conflict predicate or halt trigger is
  satisfied or defeated by a generation that never changes.
- `MEM-05`/`MEM-09`/`MEM-14`/`MEM-15` remain mutually consistent (effectiveness at a snapshot point vs
  the roster drawn at that point; `N_MAX` applied at set formation and never by eviction; the exit
  independent of settlement progress), and the exit's funding chain (MEM-15(2b) ↔ L1-13(5) ↔ L1-11
  `attestRewardPaid` ↔ ECON-02 clause 5) is coherent.
- A third of validators stopping is correctly described in the rules: finality halts; the checkpoint can
  still advance over already-certified heights (MEM-15(3), `04:98-109`); users at or below the resulting
  checkpoint exit through a k-attestation root over any already-accepted checkpoint, funded best-effort;
  value above the checkpoint freezes; the cohort keeps its stake, its slots and its standing, is not
  punished for silence, and can exit and withdraw after `D_WITHDRAW`; the halt ends with no protocol
  change if the committed cohort returns, and is permanent only while it never does.
- No live rule in spec/02 or spec/03 reads a tombstoned rule, parameter or record.

## Summary for the lead

| Severity | Count | Findings |
|----------|-------|----------|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 0 | — |
| Low | 3 | R9-CC-01 (CONS-05 certificate tuple omits `recovery_generation`; carried from R8-CC-03) · R9-CC-02 (CONS-02's dormancy note reverses who may clear the signing store) · R9-CC-03 (index:424 and learn/08:135 still lack the cohort-return escape) |

**Strongest attack: none.** I could not construct an attack, a broken requirement or a live contradiction
in the consensus core at this snapshot. The three Lows are wording/definition residuals: none changes an
acceptance decision, a lock, a conflict predicate, a halt trigger or a user guarantee in v1.

**Inside the fault model?** R9-CC-01 and R9-CC-03 are disclosure/definition defects inside it (no
adversary needed, nothing to exploit); R9-CC-02 is a latent revival hazard with no v1 effect. No Critical
or High is outstanding.

**Would I build on this specification? Yes** — on the consensus core as written, with the three Lows fixed
(R9-CC-01 and R9-CC-02 before any generation-scoping revival; R9-CC-03 for artifact consistency), and with
the deferred mechanisms left tombstoned until their revive criteria are met.
