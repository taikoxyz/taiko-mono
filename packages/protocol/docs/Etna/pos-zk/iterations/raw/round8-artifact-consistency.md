# Round 8 — angle: the whole artifact, final pass

Snapshot `fb67df660` (branch etna-pos-zk). Read: `iterations/08-freeze.md`, `DEFERRED.md`,
`iterations/raw/round7-*.md` (all four), then every `spec/*.html`, `learn/*.html`, `09-parameters.html`,
`index.html` and the top-level `*.md`.

**Severity counts: 0 Critical, 1 High, 0 Medium, 6 Low.** v1 is implementable as written; the High is a
single live rule that still reads a tombstoned one (the same class round 7 fixed in its two siblings), and
everything else is citation/naming/link drift. The mechanical claims in the freeze reproduce: **161 rule ids,
all indexed; 0 broken links or anchors across spec + course; every genuinely deferred rule tombstoned with a
MUST-NOT-USE reason and a DEFERRED.md or history pointer; the register's only unowned rows are
`value_at_risk(D_MAX)` (disclosure-only) and `PUB_RECORD_RETENTION` (retained-but-unused); the course no
longer teaches any deferred mechanism in the present tense.**

---

## R8-AC-01 — High — CONS-12, the live safety invariant, still conditions v1's provisional-history rule on the deferred REC-02 stall resolution in the present tense; the round-7 R7-RB-06 repair was applied to CONS-01(iii)/(vii) and missed this clause.

*Rationale: CONS-12 is normative (the uniqueness-of-the-finalized-prefix invariant). It states that "the timelocked, resume-only action of REC-02 may discard that history by incrementing the generation" — a path D-16 forbids, whose rule is a tombstone, and which contradicts INV-01 on page 10 ("in v1 the generation does not advance ... v1 has no second history-moving event at all") and REC-02's own tombstone on page 06.*

- **Rules / missing rule.** `spec/02-consensus.html` line 394, **CONS-12**: "Above the last accepted checkpoint the invariant is conditional on the stall-resolution rules: a certificate at a height above that checkpoint is a claim on provisional history, and **the timelocked, resume-only action of REC-02 may discard that history by incrementing the generation**, without any certificate being forged or re-judged." The only note attached is "(user decision D-15: the invariant is restated relative to the authenticated checkpoint and made conditional on the stall-resolution rules for history above it.)" — no D-16 note. Contrast the sibling clauses that were repaired in round 7: line 71 **CONS-01(iii)** ("v1 has no resumed chain: the stall resolution of REC-02 and its restart linkage REC-04 are deferred by D-16 and MUST NOT be implemented ... This closes review round 7 finding R7-RB-06") and **CONS-01(vii)** ("in v1 no live rule increments it — the stall resolution that would have is deferred by D-16 ... This closes review round 7 finding R7-RB-06"). **Missing:** the same one-clause tombstone note in CONS-12, or a restatement of the conditional as historical ("were a stall resolution live ...").
- **Assumptions.** None; purely textual, no adversary, no parameter.
- **Attack trace (drift trace, implementation consequence).** A client implementer treating CONS-12 as the normative safety statement implements the condition it asserts: a generation that can be incremented by a timelocked L1 action and heights above the checkpoint that the action may discard. CONS-16/GOV-04/REC-02 are tombstones that MUST NOT be implemented, CONS-01(vii) says the generation is constant in v1, and 10's INV-01 says no rule produces a second history-moving event; a node built from CONS-12 diverges from a node built from CONS-01(vii)/INV-01 on whether a generation-increment path exists at all.
- **Fault-model verdict.** Inside the "specification is the authority" model; no fault-model assumption and no attacker required. It is a contradiction between normative rules, not an exploitable path (nothing in v1 can increment the generation).
- **Attacker cost.** None.
- **Requirement affected.** D-16 (four mechanisms deferred and tombstoned; "no rule still reads a tombstoned mechanism"), GEN-03 (one rule, one place), INV-01.
- **Evidence.** `spec/02-consensus.html` lines 71 (CONS-01(iii)), 73 (CONS-01(vii)), 394 (CONS-12); `spec/06-recovery-exceptions.html` REC-02 tombstone; `spec/10-assurance.html` INV-01 lines 51–55 ("That mechanism is deferred by D-16 ... v1 has no second history-moving event at all"); `iterations/raw/round7-rollback-consistency.md` R7-RB-06.

---

## R8-AC-02 — Low — CONS-04 cites the tombstoned REC-02 as the owner of an evidentiary element that ECON-04 owns.

*Rationale: a live rule (lock/equivocation conduct) points readers at a tombstone for a live evidentiary rule.*

- **Rules / missing rule.** `spec/02-consensus.html` line 156, **CONS-04**: "A conflicting signed pair under the same generation remains admissible evidence under ECON-04, **exactly as REC-02's late-certificate element states**." REC-02 is a D-16 tombstone; the element it describes (a late certificate admissible as evidence) exists, if anywhere, in ECON-04 or is a leftover of the withdrawn recovery. **Missing:** the citation removed or repointed at ECON-04.
- **Assumptions.** None.
- **Attack trace (drift trace).** A reader following the citation reaches a tombstone that MUST NOT be implemented and finds a "late-certificate element" defined for a mechanism v1 does not have; the admissibility rule itself is stated at ECON-04 and is unaffected.
- **Fault-model verdict.** Inside; textual. No attacker.
- **Attacker cost.** None.
- **Requirement affected.** D-16 tombstone discipline.
- **Evidence.** `spec/02-consensus.html` line 156; `spec/06-recovery-exceptions.html` REC-02; `spec/07-economics-slashing.html` ECON-04.

---

## R8-AC-03 — Low — PRF-05 cites the tombstoned REC-04(1) for the contiguity duty that L1-06 owns.

*Rationale: a live proof rule attributes a live duty to a deferred rule; both citations in the same sentence are correct only for L1-06.*

- **Rules / missing rule.** `spec/05-proof-statement.html` line 276, **PRF-05**: "every batch starts at L1-06's `lastLandedHeight + 1` **(REC-04(1))**, with no height gap". REC-04 is a tombstone ("the restart linkage after an executed stall resolution ... is not normative in v1 and MUST NOT be implemented"); the contiguity equality is owned by L1-06, which the sentence already names. **Missing:** the parenthetical removed.
- **Assumptions.** None.
- **Attack trace (drift trace).** None operational: L1-06 states the same equality, so an implementer following either name implements the same check. The drift is that the cited owner does not exist.
- **Fault-model verdict.** Inside; textual. No attacker.
- **Attacker cost.** None.
- **Requirement affected.** D-16 tombstone discipline; GEN-03.
- **Evidence.** `spec/05-proof-statement.html` line 276; `spec/04-l1-integration.html` L1-06; REC-04 tombstone.

---

## R8-AC-04 — Low — the page-02 introduction still claims the page "states CONS-01 – CONS-16 in full", but CONS-16 is a tombstone stub.

*Rationale: a self-description that no longer matches the page; a reader who takes it literally expects the deferred rotation's full text and finds only a tombstone summary.*

- **Rules / missing rule.** `spec/02-consensus.html` line 16: "This page states `CONS-01` – `CONS-16` in full; they are listed once and referenced elsewhere by identifier (GEN-03)." CONS-16's div is a tombstone whose former text is preserved only in repository history (`iterations/07-freeze.md`; the tombstone says "the former text is preserved in the repository history"). **Missing:** "states CONS-01 – CONS-15 in full and CONS-16 as a tombstone", or equivalent.
- **Assumptions.** None.
- **Attack trace (drift trace).** A reader looking for the rotation's full specification on the page that claims completeness finds a five-line tombstone; the pointer to history is present, so the consequence is a misread page contract.
- **Fault-model verdict.** Inside; textual. No attacker.
- **Attacker cost.** None.
- **Requirement affected.** GEN-03; D-16 disclosure discipline.
- **Evidence.** `spec/02-consensus.html` line 16 and the CONS-16 tombstone; `spec/index.html` CONS-16 row ("DEFERRED by D-16 (tombstone) ... register entry DEFERRED.md §2").

---

## R8-AC-05 — Low — three broken relative links survive in `research/consensus-survey-raw.md`; the "0 broken links" claim holds for the specification and the course but not artifact-wide.

*Rationale: a whole-artifact link check (3,623 internal links in HTML plus every Markdown link) finds exactly three broken links, all repo-root-relative paths written inside a document four levels deep.*

- **Rules / missing rule.** `research/consensus-survey-raw.md` lines 51–52 link to `packages/protocol/contracts/layer1/core/impl/Inbox.sol` (twice) and `packages/protocol/contracts/layer1/mainnet/TaikoToken.sol`. The files exist at the repository root, but the links resolve relative to `packages/protocol/docs/Etna/pos-zk/research/` and therefore 404. **Missing:** a `../../../../` prefix (or repo-root-absolute paths). The freeze's "0 broken links or anchors" is accurate for `spec/*.html` and `learn/*.html` (I checked every `href` and every fragment target: 0 broken).
- **Assumptions.** None.
- **Attack trace (drift trace).** A reader of the research digest cannot open the two contracts the digest's claims rest on.
- **Fault-model verdict.** Inside; link integrity only. No attacker.
- **Attacker cost.** None.
- **Requirement affected.** The round-8 charge ("every link and anchor resolves"); GEN-03 evidence discipline.
- **Evidence.** `research/consensus-survey-raw.md` lines 51–52; artifact-wide link scan (3,623 HTML links, 0 broken in spec/course).

---

## R8-AC-06 — Low — parameter naming gap: the register row is `MIN_STAKE`, every live rule uses `S_min`, and no rule declares the mapping.

*Rationale: the register's own canonical-name discipline (`D_activation`/`D_withdraw`, `PUBLICATION_PROOF_DEADLINE`) requires one canonical name per parameter; here the rule-side symbol and the row name differ and the mapping is only implicit in the row's formula.*

- **Rules / missing rule.** `spec/09-parameters.html` row `MIN_STAKE` ("`MIN_STAKE` TAIKO `S_min ≥ C_op_annual / (r_gross − ρ_ops)` ... ECON-09"); the live rules and the course use `S_min` only — `spec/03-membership-staking.html` MEM-03 ("requires `amount ≥ S_min`", "The gate is the objective predicate `amount ≥ S_min`; the derivation of `S_min` is ECON-09 and its value is a parameter subject to PARAM-01"), `spec/07-economics-slashing.html` ECON-09 (16 uses), `learn/04`, `learn/10`. **Missing:** one line in the row or MEM-03 stating that `S_min` is the rule-side symbol of the registered `MIN_STAKE` (the register preamble's alias discipline exists for exactly this class).
- **Assumptions.** None.
- **Attack trace (drift trace).** An implementer searching the register for the name used by MEM-03/ECON-09 finds no row called `S_min`; the value is findable through the formula, so the risk is a mapping error in a client or migration script, not an ambiguity in the rule itself.
- **Fault-model verdict.** Inside; naming discipline. No attacker.
- **Attacker cost.** None.
- **Requirement affected.** PARAM-01's canonical-name discipline; the register's both-directions requirement.
- **Evidence.** `spec/09-parameters.html` MIN_STAKE row (and the canonical-name paragraph before it); `spec/03-membership-staking.html` MEM-03; `spec/07-economics-slashing.html` ECON-09.

---

## R8-AC-07 — Low — register/index reverse-direction nits: `POINT_EVALUATION_PRECOMPILE_GAS` is named by no rule, and `FI_PREFIX_CAP` appears in the index parameter map but nowhere in the register.

*Rationale: the lead's both-directions criterion; the first is a sourced constant used only by value, the second a withdrawn spelling whose register anchor was dropped when its row became a tombstone.*

- **Rules / missing rule.** `spec/09-parameters.html` names `POINT_EVALUATION_PRECOMPILE_GAS` once ("Blob KZG opening check cost 50,000 gas per blob — EIP-4844 — sourced"); the live rules that use the quantity state the number, not the name (`spec/04` DA-03(iii) "the call costs 50,000 gas sourced (EIP-4844)", `spec/05` PRF-07(b)(iii)). `spec/index.html`'s parameter map says the FI set is withdrawn "including the withdrawn `FI_PREFIX_CAP` spelling", but `FI_PREFIX_CAP` no longer occurs anywhere in `spec/09-parameters.html` (0 hits). **Missing:** either a "used by value only" note on the sourced row, or the name dropped from the map; and either the withdrawn-spelling note restored in 09 or removed from the index.
- **Assumptions.** None.
- **Attack trace (drift trace).** None operational — DA-03's number is authoritative and FI_PREFIX_CAP is already forbidden; the gap is that the register's reverse direction is not literally exact, which the round-8 charge tests.
- **Fault-model verdict.** Inside; register discipline. No attacker.
- **Attacker cost.** None.
- **Requirement affected.** PARAM-01 both-directions register discipline; the index map's "the parameter table of 09 is the single register".
- **Evidence.** `spec/09-parameters.html` (single `POINT_EVALUATION_PRECOMPILE_GAS` row; no `FI_PREFIX_CAP`); `spec/index.html` parameter map FI block; `spec/04-l1-integration.html` DA-03(iii); `spec/05-proof-statement.html` PRF-07(b)(iii).

---

## Verified clean (the checks behind the "clean" claims)

- **Links and anchors.** 3,623 internal `href` targets across `spec/*.html` and `learn/*.html`: 0 missing files, 0 missing fragments, 0 fragments on non-HTML. Only the three Markdown links in R8-AC-05 fail artifact-wide.
- **Rule index both directions.** All 161 `<div class="rule">` ids have an index row and every index row resolves to a rule (the `GEN-*`/`STATUS-*` rules live on `index.html` itself). Every deferred rule's index row reads "DEFERRED by D-16 (tombstone)" with a DEFERRED.md pointer: `FI-10..FI-14`, `FI-REMOVED-01`, `FI-PLANNED-01`, `MEM-13`, `CONS-16`, `GOV-04`, `REC-02..REC-04`, `PRF-15`, `L1-14`. The only unmarked "tombstone-like" row is `LIM-02`, which is a live rejected-alternatives rule that legitimately contains "withdrawn or deferred" dispositions — not a deferred mechanism.
- **Tombstone completeness.** Of the 17 rule divs whose heading marks them deferred/tombstoned, all but `FI-PLANNED-01` carry an explicit MUST-NOT ("MUST NOT be implemented" / "MUST NOT be used" / "not normative in v1"); `FI-PLANNED-01` is the planned-update clause (preservation duties for a future widening), not a shipped mechanism, and it states "Version 1 has no inclusion obligation at all ... R10 is not satisfied" with a DEFERRED.md §1 pointer. Every tombstone names its register entry or history location.
- **No live rule reads a tombstoned parameter.** Token scan of the full deferred name set (FI set, `MEM-13`, `CONS-16`, `GOV-04`, `REC-02..04`, `PRF-15`, `L1-14`, `HEARTBEAT_*`, `hbWindow/hbSeq/heartbeatKey/lastHeartbeat*`, `T_ROTATE/_DELAY`, `T_STALL_GOV`, `T_GOV_RESUME`, `govResume*`, `L2_BLOCK_GAS_LIMIT`, `AGG_PROVER_PPM`, `M_AGG_MAX`, `K_SETTLE_BACKENDS`, `T_AGG_ROTATE_MAX`, `dueHead/dueTail/dueCount/pruneCursor`) across spec and course, at sentence granularity inside live rule divs, leaves only R8-AC-01/02/03 plus benign list prose in `09`'s kept/withdrawn summary and the index map. Round-7's `T_ROTATE`/`T_ROTATE_DELAY` (R7-RB-03), configHash preimage (R7-RB-02), `K_PROOF_BACKENDS` (R7-RB-07), `PUB_RECORD_RETENTION`/prune (R7-RB-08) and the MIG-02 cursors (disclosed as budgeted, retained-only state) are all closed.
- **configHash preimage.** V1 and V2 are historical-only with their withdrawn fields explicitly labelled ("now-withdrawn recovery parameters ... all five are D-15/D-16 tombstones with MUST-NOT-USE reasons in 09 ... no live rule reads them"; "that field, and the capacity relation of FI-12 it served, are withdrawn by D-16"), and the new **V3** enumeration is the only live one: it removes the five recovery names and `L2_BLOCK_GAS_LIMIT` and lists only parameters a live rule reads, under PARAM-04's append-only future-epochs-only rule. R7-RB-02 closed.
- **Register both directions (spot-audited).** Kept rows have live consumers (`T_PROVE_DEADLINE`, `D_MAX`, `K_PROOF_BACKENDS`, `N_PROOF_BACKENDS`, `W_ROOT_WAIT_MAX`, `T_VETO`, `N_MAX`, `WITHDRAWAL_DELAY`, `DRAIN_DEADLINE`, `ALLOC_VAL_PPM/ALLOC_PRV_PPM`, `MIN_STAKE` (R8-AC-06), `REWARD_ASSET`, `POOL_TOPUP`, `W_EVIDENCE`, ...). The two rows with no live owner are explicitly marked: `value_at_risk(D_MAX)` "a disclosure-only exposure statistic — no rule uses it to set a value" and `PUB_RECORD_RETENTION` "Retained-but-unused state in v1 ... L1-08 exposes no prune function in v1 ... no live rule reads this parameter". All deferred sets are withdrawn with MUST-NOT-USE reasons (`FI_*`, `L2_BLOCK_GAS_LIMIT`, capacity relations, `K_SETTLE_BACKENDS`, `M_AGG_MAX`, `AGG_PROVER_PPM`, `T_AGG_ROTATE_MAX`, the heartbeat set, `T_STALL_GOV`, `T_GOV_RESUME`, `govResume*`, `T_ROTATE`, `T_ROTATE_DELAY`, the D-15 recovery-bond set, `T_INACTIVE`, `D_LAPSE_MAX`, `lastObserved`).
- **Index parameter map vs register.** 49 names in the map, 12 grouped rows; the three map-only names are `B_REC` (covered by the withdrawn `B_REC_BASE/B_REC(e)` row), `ALLOC_PRV_PPM` (row exists in 09), and `FI_PREFIX_CAP` (R8-AC-07). No register row that the map claims is missing from 09. The map's withdrawn blocks agree with 09's MUST-NOT-USE statuses, and it states that 09 is the single register.
- **Course teaches only what the specification now says.** Strict sentence-level scan of all 13 `learn/*.html` for every deferred name plus heartbeat/rotation/stall/aggregation/forced-inclusion vocabulary: no present-tense teaching of a deferred mechanism remains. The only survivors are `learn/05` ("the n-of-m aggregation ... is not part of v1") and `learn/limitations.html`'s coverage list naming `FI-REMOVED-01` as "the v1 inclusion position" — both correct. Round 7's eight unswept pages are fixed.
- **Disclosures do not promise what v1 lacks.** Checked the three load-bearing absences end to end: no inclusion obligation (`LIVE-04`(1), `FI-REMOVED-01`, `FI-PLANNED-01`, index, course); no recovery path of any kind (`LIM-01`, HALT, `MEM-15`, `MSG-03`, `INV-01`, index, course — every occurrence now says a settlement stall halts the chain and clearing it needs a future protocol update whose procedure is not specified); single-backend settlement soundness (`PRF-09`, `PRF-14`(4)(b), `ECON-02`(5)(e), MIG, index, course all state "the soundness of the weakest approved backend", and the k-family withdrawal-root requirement is kept with its unbounded-wait residual).
- **Round-8 substance is consistent across pages.** The new `MEM-15`(2a)/(2b) exit (root attestable permissionlessly for **any already-accepted checkpoint**, including the latest; k attestations verified directly on L1; best-effort `attestRewardPaid` from the proving share through L1-11 that MUST NOT gate) reads the same in `spec/03`, `spec/04` (L1-11, L1-13, MSG-03, STATUS), `spec/07` (ECON-02), `spec/09` (`K_PROOF_BACKENDS`, `W_ROOT_WAIT_MAX`), `spec/index.html` and the course; no page retains the withdrawn "epoch-boundary withdrawal root" or "up to one epoch" phrasing (0 hits). The reward-pool identity `pool_balance = free + Σ_e outstanding(e)` is stated identically in `ECON-02` clauses 5(a)/(d)/(e), the 09 row and the index.
- **Not re-reported:** nothing from round 7 survives except the CONS-12 clause (R8-AC-01) and the citation nits; the deferred mechanisms themselves are not reported as defects, per the round-8 charge.

## Fault-model verdict

No finding requires a fault-model assumption: every item is drift, contradiction or link/citation integrity, and the one High is a live rule stating a contingency that D-16 removed. There is **no Critical and no in-protocol attack** in this angle; R8-AC-01's consequence is implementation divergence, not a security break, because nothing in v1 can increment the generation.

## Is v1 implementable as written?

**Yes.** The core (L1-01..L1-13, DA-*, PRF-* minus the tombstones, MEM-*, ECON-*, HALT-*, MIG-*, GOV-01..03, REC-01) is internally consistent, every parameter a live rule reads has a register row, every deferred mechanism is tombstoned and disclosed, and the artifact-wide link/anchor check passes. The seven findings are one clause note (R8-AC-01) and six citation/naming/link cleanups; none blocks an implementation.

## Counts

| Severity | Count | Ids |
|---|---|---|
| Critical | 0 | — |
| High | 1 | R8-AC-01 |
| Medium | 0 | — |
| Low | 6 | R8-AC-02, R8-AC-03, R8-AC-04, R8-AC-05, R8-AC-06, R8-AC-07 |
