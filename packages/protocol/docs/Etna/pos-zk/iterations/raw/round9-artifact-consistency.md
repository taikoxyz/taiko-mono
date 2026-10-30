# Round 9 — angle: the whole artifact (confirmation pass)

Snapshot `3b4096a77`. Read: `iterations/08-freeze.md`, `DEFERRED.md`, all four `iterations/raw/round8-*.md`,
then every `spec/*.html` (12 pages), `learn/*.html` (13 pages), the register in `09-parameters.html`,
`index.html` and the top-level `*.md`.

**Severity counts: 0 Critical, 0 High, 0 Medium, 3 Low. No attack found; no contradiction found.**

I ran the round-8 charge mechanically rather than by reading: an artifact-wide link/anchor resolver, a tag-balance
parser for every HTML file, a tombstone classifier over all 161 rule divs, a sentence-level scan of every
tombstoned rule/parameter/record name inside live rules and page prose, a register orphan audit in both
directions, an index rule-index and parameter-map diff, and a course scan for every deferred vocabulary item.
The result is clean except for the three Low items below (one markup imbalance, three broken links in a
research digest that round 8 already reported, and one present-tense purpose clause in MIG-02 that the same
paragraph then discloses as deferred).

All seven round-8 repairs are present and internally consistent (verification in the last section).

---

## R9-AC-01 — Low — `spec/08-migration-upgrades.html` does not have balanced tags: a paragraph block is missing its `<p>` opener.

*Rationale: the round-9 charge explicitly requires every HTML file's tags to balance; this is the only file that fails an artifact-wide stack check (24 HTML files), and the effect is one stray `</p>` and a paragraph rendered outside any paragraph element.*

- **Rules / missing rule.** `spec/08-migration-upgrades.html`: the paragraph that begins at line 328 ("**D-11's publication record, budgeted (slots 275–277).** Data may be published before the proof, so the Inbox must hold the record the later proof references and the cursors that the due-set rule of 04 drains: ...") is never opened with `<p>`; it terminates at line 396 with `</em></p>`. The file contains 18 `<p` opens and 19 `</p>` closes. **Missing:** the `<p>` opener before the `<strong>` at line 328 (the previous paragraph closes at line 327 with `</em></p>`).
- **Assumptions.** None; this is a markup-integrity check, not a semantic one.
- **Attack trace (drift trace).** A stack parser over all tags reports `</p> at 46592 closes <main> opened at 1075`; browsers recover by synthesising an empty paragraph, so the rendered page is legible, but a strict HTML consumer, a diff-driven tool or a future automated markup check sees a malformed document.
- **Fault-model verdict.** No fault model involved; documentation integrity only.
- **Attacker cost.** None.
- **Requirement affected.** The round-9 verification list ("every HTML file's tags balance").
- **Evidence.** `spec/08-migration-upgrades.html` lines 327–328 and 391–396; artifact-wide tag-stack check: 24 files, exactly 1 failure.

---

## R9-AC-02 — Low — the three broken links in `research/consensus-survey-raw.md` remain (round-8 R8-AC-05 is not closed).

*Rationale: the round-8 finding asked for the repo-root-relative paths to be corrected; the file is unchanged, so the artifact-wide link check still fails by exactly three links.*

- **Rules / missing rule.** `research/consensus-survey-raw.md` line 51 links twice to `packages/protocol/contracts/layer1/core/impl/Inbox.sol` and line 52 to `packages/protocol/contracts/layer1/mainnet/TaikoToken.sol`. Those paths exist at the repository root but resolve against `packages/protocol/docs/Etna/pos-zk/research/`, so all three 404. **Missing:** the `../../../../` prefix or repo-root-absolute hrefs. Everything else resolves: 3,721 internal `href`s across spec and course, 0 broken files, 0 broken anchors.
- **Assumptions.** None.
- **Attack trace (drift trace).** A reader of the digest cannot open the two contracts its claims rest on; no rule or disclosure depends on the digest.
- **Fault-model verdict.** Link integrity only; no fault model.
- **Attacker cost.** None.
- **Requirement affected.** The round-9 verification list ("every link and anchor resolves"); GEN-03 evidence discipline.
- **Evidence.** `research/consensus-survey-raw.md` lines 51–52; artifact-wide resolver (3,721 HTML links + all Markdown links: 3 failures, all here).

---

## R9-AC-03 — Low — `spec/08-migration-upgrades.html` MIG-02 still describes the publication-order map and clock cursors as serving the deferred FIFO in the present tense, two sentences before it discloses that no v1 rule reads them.

*Rationale: a live migration rule's purpose clauses read a tombstoned mechanism as the state's current consumer; the disclosure that follows makes the practical risk small, which is why this is Low and not a contradiction.*

- **Rules / missing rule.** `spec/08-migration-upgrades.html` line 282 "`(276) publicationOrder map` ... the append-only register order **the capped FIFO prefix drains**, so **the due set** is a prefix of one sequence rather than a scan of the identity map"; line 283 "`(277) publication clock`, packed — `nextSeq` ... + `dueHead` (**the FIFO head the capped prefix drains from**) + `dueTail` + `dueCount` + `pruneCursor`"; lines 338–339 repeats it in prose. Lines 342–345 then state "The clock's `dueHead`, `dueTail`, `dueCount` and `pruneCursor` are the state the **deferred** narrow forced-inclusion and expiry machinery **would** drain; **no v1 rule reads or advances them** ... so they are retained only as budgeted register state", and line 430 says "the first post-activation batch faces an empty register (**the due set is not a v1 object**)". **Missing:** the same "deferred / retained-only" qualifier on the two purpose clauses, so the slot list does not read the FIFO as live.
- **Assumptions.** None.
- **Attack trace (drift trace).** An implementer reading only the slot table (MIG-02's declaration list) is told the order map and clock exist to drain a capped FIFO due set — the mechanism `FI-10..FI-14` tombstoned by D-16 — and could wire a drain that MUST NOT be implemented; the following paragraph corrects it, and no rule consumes the cursors.
- **Fault-model verdict.** No fault model; a live rule's description reads a tombstoned mechanism in the present tense.
- **Attacker cost.** None.
- **Requirement affected.** D-16 tombstone discipline; the round-9 charge ("no live rule reads a tombstoned rule, parameter or record").
- **Evidence.** `spec/08-migration-upgrades.html` lines 282–283, 338–345, 430; `spec/04-l1-integration.html` FI-10..FI-14 tombstones; `DEFERRED.md` §1.

---

## Verified clean (the checks behind the confirmation)

- **Links and anchors.** 3,721 internal `href` targets across all 12 spec pages and 13 course pages: 0 missing files, 0 missing fragments. Only R9-AC-02's three Markdown links fail artifact-wide.
- **Tag balance.** All 24 HTML files parsed with a stack checker (void elements skipped, optional-end elements auto-closed): exactly one failure, R9-AC-01. No other file has an unbalanced or mis-nested tag.
- **Rule index both directions.** All 161 rule ids have an index row and every row resolves to a rule. Every genuinely deferred rule's row reads "DEFERRED by D-16 (tombstone)" with a DEFERRED.md pointer: `FI-10..FI-14`, `FI-REMOVED-01`, `FI-PLANNED-01`, `MEM-13`, `CONS-16`, `GOV-04`, `REC-02..REC-04`, `PRF-15`, `L1-14`. The single "unmarked" candidate is `LIM-02`, which is a live rejected-alternatives rule that legitimately contains "withdrawn or deferred" dispositions — not a deferred mechanism.
- **Tombstone completeness.** Of the 18 rule divs classified as deferred/withdrawn, all carry a MUST-NOT ("MUST NOT be implemented" / "MUST NOT be used" / "not normative in v1") except `FI-PLANNED-01`, which is the planned-update clause (preservation duties for a future widening) and correctly rules nothing in or out; every one carries a DEFERRED.md, D-16 or repository-history pointer.
- **No live rule reads a tombstoned name.** Sentence-level scan of the full deferred set (FI-*, `MEM-13`, `CONS-16`, `GOV-04`, `REC-02..04`, `PRF-15`, `L1-14`, the heartbeat names and parameters, `T_ROTATE`/`T_ROTATE_DELAY`, `T_STALL_GOV`, `T_GOV_RESUME`, `govResume*`, `L2_BLOCK_GAS_LIMIT`, the aggregation set, `dueHead/dueTail/dueCount/pruneCursor`) across spec and course: every hit in a live rule is either inside a tombstone disclosure in the same sentence or is the benign historical/tombstone prose summarised in R9-AC-03 and in `09`'s withdrawal table and index map. In particular **CONS-12 is repaired** ("In v1 no such event exists: the stall resolution that would increment the generation is deferred by D-16 and MUST NOT be implemented ... This closes review round 7 finding R7-RB-06"), and its siblings CONS-01(iii)/(vii) and CONS-05 carry the same note.
- **Register both directions.** All 92 parsed register rows have a unit, an owner or a status; every row a live rule reads is present, including the round-8 additions `freezeEpoch(e)`, `allocRecord[e]` (`frozenAt`, `reservedBefore(e)`, `Alloc(e)`, `ProvingShare(e)`, `participantCount(e)`, `claimedCount(e)`, `paid(e)`, `provingTransferred(e)`), `PROVING_LAND_PPM`, `PROVING_ATTEST_PPM`, `attestRewardPaid` and `attestedFamilies`. The only rows without a live-rule consumer are `value_at_risk(D_MAX)` ("a disclosure-only exposure statistic — no rule uses it to set a value") and `PUB_RECORD_RETENTION` ("Retained-but-unused state in v1 ... no live rule reads this parameter"), both explicitly marked; `POINT_EVALUATION_PRECOMPILE_GAS` names its live consumers and is marked "consumed by value only"; `REWARD_ASSET`, `DRAIN_DEADLINE` and `C_PUBLISH` are consumed by the parameter tables of `07`/`08`; `MIN_STAKE` is deprecated in favour of the rule-side `S_min`, which the row now carries (round-8 R8-AC-06/R8-AC-07 closed).
- **Index parameter map.** 12 grouped rows, 49 names; every deferred set is marked withdrawn with the same status as `09`, the live names match the register, and the map states that `09` is the single register.
- **Course.** All 13 pages scanned for every deferred name and for heartbeat/rotation/stall/aggregation/forced-inclusion vocabulary: no present-tense teaching of a deferred mechanism remains. The exit is now taught in full everywhere it appears — withdrawal root, k attestations from k distinct registered families verified directly on L1, one verification per attestation, `WITHDRAWAL_DELAY` from the root checkpoint record's own `l1BlockNumber`, the unexpired veto, the funded proving market and the still-retrievable data/witness (`learn/01`, `02`, `05`, `06`, `07`, `08`, `09`, `10`, `glossary`, `index`, `limitations`) — matching `MSG-03`'s repaired anchor and `MEM-15`(2a)/(2b). Every "guarantee" mention in the course is a caveat, not a promise.
- **No disclosure promises what v1 lacks.** The three absences are stated consistently in spec and course: no inclusion obligation (`LIVE-04`(1), `FI-REMOVED-01`, `FI-PLANNED-01`, index, `learn/09`); no recovery path of any kind (`LIM-01`, `MEM-12`, `HALT-*`, `MEM-15`, `MSG-03`, `INV-01`, index, course); settlement soundness is that of the weakest approved backend with aggregation deferred (`PRF-09`, `PRF-14`(4)(b), `ECON-02`(5)(e), index, `learn/05`).
- **No page contradicts another** on the round-8 mechanisms: the freeze is `freezeEpoch(e)` freezable exactly at `evidenceClose(e)`, with the mandatory ascending-epoch cascade before any pool-touching call and the epoch's own first claim as backstop (`07` 226/229, `09` 131/135/138, `learn/10` 122); the reservation release is reachable (last claim releases the floor remainder; empty participant set releases at the freeze) (`07` 155/244, `09` 135–137); the referenced path's `daMode` and challenge index are derived from the record / the statement's ordinal, with `DataModeMismatch` and the equal-challenge requirement (`04` 124/150/522/557/657, `05` 337); `L1-08` exposes `attestedFamilies(uint64)` and `L1-13`(3) records the family per attestation (`04` 334/420); the proving split is "a policy target, not an on-chain bound" (`07` 251, `09` 132/134, index 547); the pool identity `pool_balance = free + Σ_e outstanding(e)` is stated identically in `07`, `09` and the index.

## Fault-model verdict

No finding needs a fault model, an assumption or an adversary: the three items are a markup imbalance, three broken links in a research digest, and one present-tense purpose clause mitigated by its own following disclosure. **No Critical and no High; nothing inside the fault model.**

## Would I build on this specification?

**Yes.** The v1 core is internally consistent, every deferred mechanism is tombstoned with a MUST-NOT-USE reason and a pointer, every parameter a live rule reads is registered in both directions, the disclosures match the rules, the course matches the specification (including withdrawal timing), and the artifact-wide link and tag checks pass except for the two mechanical Lows (R9-AC-01, R9-AC-02). I would fix those two before publishing the artifact, and I would not treat R9-AC-03 as blocking.

## Counts

| Severity | Count | Ids |
|---|---|---|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 0 | — |
| Low | 3 | R9-AC-01, R9-AC-02, R9-AC-03 |
