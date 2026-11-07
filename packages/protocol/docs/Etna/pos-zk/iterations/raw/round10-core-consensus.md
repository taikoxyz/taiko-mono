# Round 10 — raw adversarial review: the consensus core after the residue (confirmation)

**Reviewer:** r6-gov-generations (task-21), independent adversarial reviewer, round 10.
**Snapshot:** `cd8386c2c` (branch `etna-pos-zk`). Verified: HEAD `9b6dbdc72` differs from the snapshot only by
`iterations/10-freeze.md` (`git diff --stat cd8386c2c HEAD` = 1 file, +18) and the working tree is clean.
**Method:** rules judged as written; "closes review round N" notes and the freeze's verification claims are
claims, not evidence. Citation: `NN:line` = `spec/NN-*.html`; `R9-CC-nn` = my round-9 report.

**Counts: Critical 0 · High 0 · Medium 0 · Low 1.**
**Round 10 is clean on the stated definition: no Critical and no High.** All five subjects charged to this
round pass, the round-9 residue introduced **no rule-level defect**, and my three round-9 Lows are closed in
the specification. The single Low is an artifact-propagation miss: the course's parallel copies of the
Vote/CommitCertificate canonical field lists were not swept when CONS-05 was repaired, so two pages still
state different canonical encodings for objects whose generation field is now normative in the spec.
**Strongest attack: none.** I could not construct an attack, a broken requirement or a live contradiction
in the consensus core at this snapshot. **I would build on this specification** (with the one Low fixed).

---

## Finding R10-CC-01 — Low: the CONS-05 tuple repair did not propagate to the course's parallel canonical field tables

**Severity: Low.** One-line rationale: the round-9 repair added `recovery_generation` to CONS-05's certificate
tuple and the spec's encoding table was already correct, but the learning course keeps its own copies of the
same canonical field lists and of the commit-rule validity conditions, and those copies still omit the field —
so the artifact now states two different canonical encodings for the signed vote and for the certificate; in
v1 the generation is constant, so no acceptance decision can diverge, but a reader implementing from the
course builds objects without a signed field the specification requires, and the course's own prose elsewhere
teaches that the field is carried.
**File + rule id / location:**
- `learn/03-consensus.html:118` — "Vote `chain_id:u256, epoch:u64, height:u64, round:u32, type:u8, block_id,
  validator_index:u32, timestamp:u64` … `"TAIKO_ETNA_VOTE_V1"`" versus `02:35-37` ("Vote `chain_id:u256,
  epoch:u64, **recovery_generation:u64**, height:u64, …`" and the signed preimage "… `epoch, recovery_generation,
  height, round, type, …`").
- `learn/03-consensus.html:120` — "CommitCertificate `chain_id:u256, epoch:u64, height:u64, round:u32,
  block_id, set_root:bytes32, signers:bytes, signatures:bytes[]` … its own hash uses
  `"TAIKO_ETNA_CERT_V1"`" versus `02:41-42` (`CommitCertificate` includes `recovery_generation:u64` after
  `epoch`, "carried so the acceptance rule can reject a superseded generation without re-deriving it").
- `learn/03-consensus.html:170-173` — "A commit certificate at (H,R) for block B is `(chain_id, epoch, H, R, B,
  set_root(epoch), signers, signatures)`. It is valid only if `epoch = epoch_of(H)`, `set_root(epoch)` equals
  …, and more than two thirds … (CONS-05)" versus `02:178-180` (the repaired tuple now carries
  `recovery_generation` and the validity clause requires it) and `02:243` (CONS-08(1)) / `02:360` (CONS-10(7)).
- The course's own text elsewhere carries the field: `learn/08-when-things-go-wrong.html:122` ("The recovery
  generation is carried in the signed vote and header bytes; v1 never advances it"), `:448-449`,
  `learn/05-the-proof.html:164-168`, `learn/06-data-and-proof-together.html:271-274`,
  `learn/glossary.html:141`. Only `learn/08` was touched by the round-10 sweep (7 lines); `learn/03` was not.
**Evidence.** `02:35-37`, `02:41-42`, `02:178-180`, `02:243`, `02:360`; `learn/03-consensus.html:118`,
`:120`, `:169-173`; `learn/08-when-things-go-wrong.html:122`; `learn/05-the-proof.html:164-168`;
`learn/06-data-and-proof-together.html:271-274`; `learn/glossary.html:141`. This is the propagation half of
R9-CC-01, whose specification half is correctly closed.
**Impact and fix.** No v1 decision changes: the generation is a constant, so a certificate or vote built to
the course's field list still verifies against the same value, and the guest's three-way equality
(`02:180`, PRF-04(viii)) closes the acceptance path. The defect is that the teaching artifact's "Fields
(canonical order)" tables are wrong for a signed object, and the certificate tuple it states is the pre-fix
tuple. Fix: add `recovery_generation:u64` after `epoch` in the Vote and CommitCertificate rows and add the
generation-equality condition to the commit-rule sentence.

---

## Verification of the five subjects charged to this round

**1. CONS-02's store prohibition is unambiguous and cannot be read as instruction by a revival.** The single
normative sentence now reads: "The store MUST NOT be cleared, truncated, rewritten or restarted from empty
**by any rule — a restart, a resync or a revived stall resolution included** — and no v1 rule clears it: the
stall resolution is deferred by D-16 and MUST NOT be implemented, **and were it revived it would not be an
exception, because a resolution's scoping change only disregards superseded-generation entries for new
signing and never erases the record of what was signed**." (`02:100`.) I checked the exact failure the round
was asked to exclude: a reviver searching for a rule that authorises clearing the store finds the opposite
— an explicit denial that names the revival — and the surrounding text keeps the durability obligation
("A validator that discards its record of what it signed is in breach (HALT-02(a), CONS-15(4))"), which
matches `06:143-146` (HALT-02(a)) and `02:502-514` (CONS-15(4)). The page contains exactly one
"restarted from empty" sentence (no duplicate or contradicting copy). **Pass.**

**2. CONS-05's tuple matches the encoding table, CONS-08 and CONS-10.** `02:178`: "C = `(chain_id, epoch,
recovery_generation, H, R, B, set_root(epoch), signers, signatures)` — the tuple of the encoding table, with
the signed recovery_generation the validity predicate below reads." Field set and order are identical to
`02:41-42` (`chain_id, epoch, recovery_generation, height, round, block_id, set_root, signers, signatures`);
the validity clause (`02:179-180`) requires the generation the Inbox holds and the generation signed by
every contributing vote; CONS-08(1) `02:243` ("every vote and certificate also carries the recovery
generation") and CONS-10(7) `02:360` ("carried by every certificate (CONS-05)") are now true of the object
CONS-05 defines. `cert_hash` (`02:344`) lists the same field set in an explicit preimage order with the
generation after `round`; that order is normative in its own right ("any other field order … is a different
object and MUST NOT be accepted as cert_hash", `02:348`), the object is not signed as a whole (`02:42`), and
`epoch_anchor` recomputes `cert_hash` consistently (`02:340-343`), so the two orderings cannot be confused:
the certificate's canonical order is the tuple's, the hash's preimage order is the one written out. **Pass.**

**3. The generation-constant regime is untouched.** The round-10 diff of `spec/02` is exactly two hunks —
CONS-02's store sentence and CONS-05's tuple — and `spec/03` is byte-identical to the round-9 snapshot.
The round-9 verified statements are intact: `02:73` (CONS-01(vii): the current generation is the L1-held
activation value; no live rule increments it), `02:145-156` (CONS-04: per height and per generation; the
generation-change release is dormant; locks are released by (1)(a) or (2)), `02:179-180` (CONS-05),
`02:243-255` (CONS-08), `02:360` (CONS-10(7): "no upgrade, operator, client or rotation may change it
either"), `02:363-369` (CONS-11: no generation change occurs in v1), `02:393-428` (CONS-12: the deleted
unconditional claim is explained as "were it live", "In v1 no such event exists"), `02:485-497` (CONS-15:
trigger (2) dormant). A whole-page scan of `spec/02` and `spec/03` for 23 deferred names (`REC-02/03/04`,
`GOV-04`, `MEM-13`, `CONS-16`, `PRF-15`, `L1-14`, `FI-10…FI-14`, `HEARTBEAT_*`, `T_ROTATE`, `T_STALL_GOV`,
`T_GOV_RESUME`, `FI_*`, `M_AGG_MAX`, `AGG_PROVER_PPM`, `forcedBoundary`, `govResume`, `FREEZE_MAX`) returns
**zero live candidates**: every hit is deferred, dormant, counterfactual or a tombstone's own text. **Pass.**

**4. The halt story is told one way.** HALT-01 `06:121-127` ("a halt under (b) or (d) persists until the entry
is appended and Ethereum-final **or the quorum returns**"), MEM-13's tombstone `03:526-528` (the coalesced
form: the halt "ends with no protocol change if that committed cohort returns to vote", permanent "only while
that cohort never returns" because the epoch containing the next unfinalised height is committed and
immutable, plus the stake/exit asymmetry), the membership offline row `03:636`, the ten heartbeat rows
`09:212-221`, and `10:37`, `10:217`, `10:359`. The two artifacts my round-9 R9-CC-03 named are now aligned:
`index.html:429` (MEM-13 row: "The halt ends with no protocol change if that committed cohort returns to
vote, and it is permanent only while that cohort never returns …") and
`learn/08-when-things-go-wrong.html:132-139` ("The halt ends with no protocol change when the committed
cohort of the epoch containing the next unfinalised height returns to vote … Changing the set, the schedule
or the mechanism is what would need a protocol update, not the cohort's return."). No artifact I found still
states the unconditional "until an upgrade" form. **Pass.**

**5. The round-9 residue introduced no new contradiction in the core.** Verified item by item:
- *The bounded freeze cascade (FREEZE_MAX).* The new text (`07:228-262`, `09:139`, `index.html:553`) bounds
  each pool-touching call's cascade at `FREEZE_MAX` pending epochs, allows a bounded-prefix return, drains a
  backlog of p in `ceil(p/FREEZE_MAX)` permissionless calls, makes a claim/proving-share transfer revert with
  no effect unless its epoch is inside the call's prefix, and makes an inflow-credit freeze the whole pending
  set or revert retriable. `spec/03` contains **no** reference to `freezeEpoch`, `FREEZE_MAX` or a "frozen
  participant set", so there is no interface to contradict; MEM-05(3)(b)'s predicate is "the evidence window
  `W_EVIDENCE` has closed", which `07:224-225` still defines as the time instant `evidenceClose(e)` (a call
  that freezes earlier reverts), not as a condition on the cascade having executed; MEM-06(1)'s retention
  ("until the later of the end of the evidence window for e and settlement of any slash for e") is likewise
  independent of the freeze. So a validator's withdrawal path is unchanged by the bounding, and the
  bounded-cascade liveness (claims/inflows revert until drained) is disclosed in the owner rule rather than
  silently inherited by membership.
- *The exit dependency and the front-running disclosure.* `04:453-459` (L1-11 `attestRewardPaid`) now
  discloses that a mempool-observed attestation proof can be copied by another account, which collects the
  reward while the producing prover is unpaid, as the same accepted property as L1-10's landing race, with
  best-effort payment that never gates the attestation; `04:766-770` (MSG-03) names both dependencies
  (funding and retrievable inputs) and points at MEM-15(2b); the index rows and STATUS-08 do the same. All of
  this is consistent with MEM-15(2a) ("submission is permissionless — any account may carry the attestations
  and any prover may produce a proof") and MEM-15(2b) (two assumptions: the funded proving market and the
  availability of the recorded certificate, batch data and pre-state witness): the race changes who is paid,
  never whether the root forms, and payment is best-effort by construction (`04:453-455`).
- *Markup.* A tag-stack check (bundled Python, `html.parser`) on `spec/02`, `spec/03` and the repaired
  `spec/08` reports zero unclosed tags and zero mismatches; `spec/08`'s truncated sentence and the
  `research/consensus-survey-raw.md` links were repaired in the same sweep.
- *My round-9 Lows.* R9-CC-01 (CONS-05 tuple) fixed at `02:178`; R9-CC-02 (store) fixed at `02:100`;
  R9-CC-03 (index + course) fixed at `index.html:429` and `learn/08:132-139` — with the propagation miss that
  is R10-CC-01.

## Checked, and holds (positive results)

- **Nothing in the core depends on a deferred mechanism.** The four deferred mechanisms' absence is
  disclosed in `10:24-33` (guarantee-class preamble), REC-01, HALT-01/04, LIVE-01/05, LIM-01 and
  DEFERRED.md; forced inclusion has no validity condition (CONS-01(v) tombstone, no rule in spec/02/03 reads
  it); heartbeat eligibility does not filter any roster (`03:467-474` MEM-09(1), `02:440-441` CONS-13(2));
  the rotation is not a live transition (`02:440`, `02:460`, `02:496`, CONS-16 tombstone); aggregation is
  absent from both pages (zero `PRF-15`/`L1-14` references) and the exit is k attestations (`03:346-347`).
- **MEM-05 / MEM-09 / MEM-14 / MEM-15 remain mutually consistent**: effectiveness is fixed at a snapshot point
  by the rule that owns set formation (`03:290-303`), the roster is the active bonded set drawn at that point
  (`03:467-474`), `N_MAX` is applied at set formation and never by eviction (`03:249-253`), and the exit is
  independent of settlement progress with its two named dependencies (`03:344-352`).
- **A third of validators stopping is described consistently**: finality halts; the checkpoint can still
  advance over already-certified heights (`03:348`, MEM-15(3)); users at or below it exit through a
  k-attestation root over any already-accepted checkpoint, funded best-effort; value above freezes; the
  cohort keeps its stake, slots and standing, is not punished for silence, and may exit and withdraw after
  `D_WITHDRAW`; the halt ends with no protocol change if the committed cohort returns and is permanent only
  while it never does.
- **Round-9 repairs in other pages are real**: the freeze cascade bounded and resumable (`07:228-262`),
  FREEZE_MAX registered in both directions (`09:139`, `09:261`, `index.html:553`), the "no new tunable"
  claim corrected (`09:99`), MSG-03/L1-11/STATUS-08/index carrying both exit dependencies, the
  front-running race disclosed (`04:453-459`).

## Summary for the lead

| Severity | Count | Findings |
|----------|-------|----------|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 0 | — |
| Low | 1 | R10-CC-01 (the course's parallel Vote/CommitCertificate field tables and commit-rule conditions still omit `recovery_generation`; the spec side of R9-CC-01 is correctly closed) |

**Strongest attack: none.** I spent this round trying to break the five charged items and the round-9
residue (bounded freeze cascade, store prohibition, tuple repair, exit-dependency propagation, front-running
disclosure) and found no attack, no broken requirement, no live tombstoned read, and no contradiction inside
spec/02 or spec/03. The one Low cannot affect an acceptance decision in v1 and is a one-table fix in the
course.

**Would I build on this specification? Yes.** On the consensus core as written and on the artifact as a
whole once R10-CC-01 is fixed, leaving the four deferred mechanisms tombstoned until their revive criteria
are met. Round 10 is a clean round on the stated definition (no Critical, no High).
