# Round 7 — angle: the D-16 rollback itself and cumulative consistency

Snapshot `296f44b54` (branch etna-pos-zk, PR #22262), read against `iterations/07-freeze.md`, `DEFERRED.md`,
`DECISIONS.md` D-16, all of `spec/*.html` and the whole course (`learn/*.html`).

Charged question: did the rollback leave no rule reading a tombstoned rule or parameter, no disclosure promising a
deferred guarantee, and no page contradicting another? **No.** Severity counts: **0 Critical, 5 High, 3 Medium, 0 Low.**

The sweep is genuinely good on pages 04, 05, 06, 08, 09 and the index rule index (one exception), and clean in
`learn/01`, `learn/02`, `learn/03`, `learn/05`, `learn/07` — checked and listed at the end. It did not touch
**`spec/01-system-model.html` and `spec/07-economics-slashing.html` at all (0 occurrences of "D-16" in either)**, and it
did not touch the course except `learn/05`. Every finding below is drift with an implementation consequence, not a typo.

---

## R7-RB-01 — High — `spec/01-system-model.html` was never swept: it promises the deferred forced-inclusion obligation as a live user right and presents the deferred governance stall resolution as v1's live, sanctioned replacement path.

*Rationale: the page has zero "D-16" occurrences; it is the page that states user rights, assumptions, halt behaviour and the "only sanctioned replacement" claim, so a reader takes the deferred mechanisms as normative v1.*

- **Rules / missing rule.** `spec/01-system-model.html` (line 531, ROLE-04(b)(i)): "the protocol then owes the **narrow forced-inclusion obligation of FI-10–FI-14**: once a record is due, a batch must resolve it by the capped FIFO prefix of the due set, or discharge it as void on FI-13's objective grounds, and a record whose DA-09 deadline passes unresolved is discarded and may be re-published ... the enforcement point is the proof (FI-11)". Line 346: "History above the last L1-accepted checkpoint has **exactly one sanctioned replacement path: the timelocked, resume-only stall resolution of REC-02/GOV-04**, queued by governance through the ordinary path, **effective only after T_GOV_RESUME** ... (GOV-04). Clearing a stall therefore depends on governance liveness". Line 220: "(h) **Stall-resolution consumption**: the GOV-04 queued entry and the generation state ... the recoveryGeneration counter it increments on execution". Line 164: history "may be replaced only by the timelocked, resume-only stall resolution of REC-02/GOV-04"; also lines 225, 309, 562, 598. **Missing rule/text:** the D-16 tombstones that every other page carries (v1 has no inclusion obligation; v1 has no recovery path of any kind).
- **Assumptions.** None; the drift is textual and needs no adversary.
- **Drift trace (implementation consequence).** A client/contract implementer following 01 implements a due set, a settlement frontier, a forced-data record and an exclusion deadline (the whole FI machinery), and a queued, timelocked L1 action with a `T_GOV_RESUME` window and generation increment — all of which `spec/02` (CONS-16, M3), `spec/04` (L1-04, L1-05 row 36), `spec/06` (REC-02..04), `spec/10` ("in v1 there is no recovery path of any kind — the stall resolution of GOV-04 is deferred by D-16 and MUST NOT be implemented") and `spec/index.html` say MUST NOT be implemented. Two implementers reading different pages produce different state machines and different chains.
- **Inside/outside the fault model.** Inside: the specification is the authority; this is a fixed-decision breach (D-16) with no fault-model assumption.
- **Attacker resources and cost.** None.
- **Requirement / fixed decision affected.** D-16 (four mechanisms deferred with disclosure), the tombstone discipline of GEN-03, and the very question "is the absence disclosed everywhere it used to be promised".
- **Evidence.** `spec/01-system-model.html` lines 164, 220, 225, 309, 346, 531, 562, 598; `spec/04-l1-integration.html` L1-04 and L1-05 row 36; `spec/06-recovery-exceptions.html` REC-02..04; `spec/10-assurance.html` (lines 6110, 11214, 15964, 28921); `spec/index.html` (lines 29694, 60039, 52435).

---

## R7-RB-02 — High — the live `configHash` preimage still enumerates withdrawn parameters, and its closed enumeration forbids removing them without a version change.

*Rationale: PRF-02(5), PRF-04(viii), L1-05 row 23 and PARAM-04 are all live and all require the guest to recompute `configHash` from a closed, domain-tagged field list; that list is built from names the register says MUST NOT be used.*

- **Rules / missing rule.** `spec/05-proof-statement.html` PRF-02(5): Version 1 is, in order, `... uint8 payloadFramingVersion, uint32 MAX_BATCH_BLOCKS, uint8 daModesEnabled, uint64 paramVersion`, **and the recovery parameters `uint64 T_STALL, uint64 T_RECOVERY_DELAY, uint64 REC_COOLDOWN, uint256 B_REC_BASE, uint256 B_REC_KEEP, uint64 D_MAX`**; Version 2 "is version 1's field list with exactly one field added — `uint64 L2_BLOCK_GAS_LIMIT` ... the per-block L2 gas limit the capacity relation of FI-12 is stated against". The same clause: "adding, removing or reordering a field requires a new paramVersion and a new domain tag". PRF-04(viii) (live) binds "the L2 gas limit, parameter version and **the recovery parameters**". `spec/09-parameters.html` PARAM-04 summarises the same preimage as "the epoch schedule and the L1-side clock, the quorum form, the payload-framing version, the batch-length bound, the enabled DA modes, a parameter version, and **the stall-resolution parameters of GOV-04**" — a third, different withdrawn naming for the same slot. **Register state:** `T_RECOVERY_DELAY`, `REC_COOLDOWN`, `B_REC_BASE`, `B_REC_KEEP` are "(withdrawn) ... MUST NOT be used by any rule, client, parameter or migration text" (09 lines 158–167, 97); `L2_BLOCK_GAS_LIMIT` is in the FI set "Withdrawn by D-16 ... MUST NOT be used" (09 line 96, index parameter map); `T_STALL_GOV`/`T_GOV_RESUME` are withdrawn by D-16 (09 lines 97, index parameter map). **Missing rule:** a re-derived preimage enumeration containing only live names, with the paramVersion/domain-tag bump the rule itself mandates.
- **Assumptions.** None.
- **Drift trace (implementation consequence).** An implementer has exactly two incompatible options: (a) implement the preimage as written and read/commit six withdrawn parameters (violating the register's MUST-NOT-USE and, for `L2_BLOCK_GAS_LIMIT`, depending on the deferred FI capacity relation that is the only thing that "reads" it); or (b) drop the dead fields and change the closed enumeration, which the rule says requires a new paramVersion and domain tag — a change no rule authorises and which changes every `configHash`. Either way the same batch is hashed differently by different conforming implementations, and a mismatch is a proof-invalidating condition (PRF-13).
- **Inside/outside the fault model.** Inside; no adversary.
- **Attacker resources and cost.** None.
- **Requirement / fixed decision affected.** PRF-02(5)/PRF-04(viii)/L1-05 row 23/PARAM-04 (live core), the D-16 withdrawal of FI and aggregation, the D-15 withdrawal of the recovery parameters.
- **Evidence.** `spec/05-proof-statement.html` PRF-02(5) (the V1/V2 enumeration) and PRF-04(viii); `spec/09-parameters.html` lines 96, 97, 158–167, 189 (and the PARAM-04 row naming "the stall-resolution parameters of GOV-04"); `spec/index.html` parameter map ("the FI_* set ... Withdrawn by D-16 ... MUST NOT be used").

---

## R7-RB-03 — High — CONS-16 is a tombstone that "MUST NOT be implemented by any client, contract, parameter ...", while the register and the index keep `T_ROTATE`/`T_ROTATE_DELAY` live and owned by it.

*Rationale: the register is the single source for parameter derivation; it currently instructs an implementer to build exactly the rule the page forbids, and the index rule row carries no tombstone at all.*

- **Rules / missing rule.** `spec/02-consensus.html` CONS-16: "deferred by D-16 (tombstone) ... it MUST NOT be implemented by any client, contract, parameter, migration script or later text"; and `spec/03-membership-staking.html` MEM-13: "heartbeat eligibility and its **reachability half CONS-16 are deferred together**". `iterations/07-freeze.md` lists "heartbeat eligibility (MEM-13, **CONS-16**, the heartbeat parameters)" as deferred and tombstoned. **Against this:** `spec/09-parameters.html` line 96 "**Kept in v1**: ... the liveness names `N_MAX`, **`T_ROTATE`**, **`T_ROTATE_DELAY`** ..."; row 201 "`T_ROTATE` ... **CONS-16(1) owns the trigger** ... (the rotation itself is kept ...)"; row 202 "`T_ROTATE_DELAY` ... **CONS-16**: cancellation by honest progress is what bounds the rotation's harm". `spec/index.html` line 402 indexes CONS-16 with no deferral marker ("L1-time-keyed rotation: closing a stalled epoch early — opening threshold `T_ROTATE`, delay `T_ROTATE_DELAY` ...") while every other deferred id's row says "DEFERRED by D-16 (tombstone)"; line 544 says "the rotation itself is kept". **Missing rule:** one owner text; either CONS-16's tombstone or the register rows, not both.
- **Assumptions.** None.
- **Drift trace (implementation consequence).** The register's "Kept in v1" list and the two live rows make the rotation and its L1-time trigger parameterised and budgeted; a client implementing `T_ROTATE` will build an early epoch close and a boundary-record amendment that CONS-16 says MUST NOT exist, and a boundary record amended by a rotation re-partitions heights — the history-moving transition the tombstone's own failure-mode paragraph exists to prevent. Conversely a client that obeys CONS-16 leaves two registered parameters with no live owner (exactly the "parameter row no live rule reads" case).
- **Inside/outside the fault model.** Inside; no adversary.
- **Attacker resources and cost.** None.
- **Requirement / fixed decision affected.** D-16; GEN-03 (one rule, one place); the register's own "MUST-NOT-USE" discipline.
- **Evidence.** `spec/02-consensus.html` CONS-16; `spec/03-membership-staking.html` MEM-13; `spec/09-parameters.html` lines 96, 201, 202; `spec/index.html` lines 402, 544; `iterations/07-freeze.md`.

---

## R7-RB-04 — High — `spec/07-economics-slashing.html` was never swept: it still defines a live slashable offence for breaching a tombstoned obligation, and still mandates the deferred aggregation payout.

*Rationale: 0 occurrences of "D-16" in the page; two of its live rules hand an implementer a penalisable non-offence and a payment obligation to a mechanism that does not exist.*

- **Rules / missing rule.** ECON-04(6) (line 480): "**The narrow forced-inclusion breach (D-12)**, and the limits of the offence ... a record is due at the batch's anchored L1 view A iff `record.l1BlockNumber + FI_INCLUSION_DELAY ≤ A` (FI-10). The breach is a signed proposal whose block ... does not carry the required capped FIFO prefix of the due set: the due set, the prefix, the cap, the includability discharge and the guest's check are fixed by **FI-10–FI-13 and PRF-04(vi)**, and the per-block obligation is **CONS-01(v)**." ECON-04(5) (line 472): "The single inclusion-related offence is the narrow forced-inclusion breach of clause (6)". ECON-02(5)(a) (line 150): "D-12 supersedes D-6 with the narrow forced-inclusion breach of ECON-04 clause (6)". **Against this:** CONS-01(v) is a tombstone and "a proposer that excludes a transaction is not in breach" (D-16). ECON-02(5)(e) (line 215): "the recorded allocation policy **MUST** also fix the share **`AGG_PROVER_PPM`** of `ProvingShare(e)` assigned to the aggregation ... those counts are enforced inside the one accepted object (**L1-14(3), PRF-15(5)**)" — `AGG_PROVER_PPM` is withdrawn with MUST-NOT-USE (09 line 194), and L1-14/PRF-15 are tombstones. **Missing rule:** the D-16 tombstoning of ECON-04(6), and the removal of the aggregation-share MUST and of its tombstoned cross-references.
- **Assumptions.** None.
- **Drift trace (implementation consequence).** (i) Implementing ECON-04(6) creates a slashing rule for conduct the specification says is not an offence, computed from a due set whose parameters (`FI_INCLUSION_DELAY`, `FI_MAX_PER_BATCH` ...) are MUST-NOT-USE — a funds-loss lever and an uncomputable predicate at the same time; a chained/slashing implementation can be pointed at honest proposers. (ii) Implementing the ECON-02(5)(e) MUST pays an aggregator for a proof object v1 does not accept, funded from the same `ProvingShare` the live withdrawal-root path needs.
- **Inside/outside the fault model.** Inside; the exposure is created by the text, not by an adversary (it becomes an attack surface only if implemented).
- **Attacker resources and cost.** None to create; a slashing chain built from it is the resource.
- **Requirement / fixed decision affected.** D-16 (deferral with disclosure), D-12/D-13 deferral; ECON-04's own "objectively decidable" discipline.
- **Evidence.** `spec/07-economics-slashing.html` lines 150, 215, 472, 480; `spec/02-consensus.html` CONS-01(v) tombstone; `spec/09-parameters.html` line 194 (`AGG_PROVER_PPM` withdrawn) and line 96.

---

## R7-RB-05 — High — the course still teaches deferred mechanisms as live on eight of thirteen pages.

*Rationale: the freeze says "the course teaches what the specification now says"; the rollback commit says the course was swept; eight course pages contain no "D-16" at all and teach the deferred mechanisms in the present tense.*

- **Rules / missing rule.** `learn/04-staking-and-epochs.html` line 50: "To be selected into a future set version, a validator **must post a periodic liveness attestation — a heartbeat — on Ethereum**. A validator that stops attesting is simply not selected next time ..."; plus the "heartbeat key" section and "The L1-time rotation (CONS-16) draws a stalled chain's restart set from eligible validators". `learn/08-when-things-go-wrong.html` line 70: "The condition is measured on L1, so no participant's local view can declare it early (GOV-04)"; line 155: "The L1-time rotation (CONS-16) can close a stalled epoch early and draw the restart set from eligible validators"; plus heartbeat eligibility and "a missed heartbeat is not an offence". `learn/09-censorship-and-the-bridge.html` line 50: the "capped prefix of the due set (FI-10–FI-14)" obligation as live; line 42: "A timelocked, resume-only governance decision **can** restart the chain ... (GOV-04)". `learn/glossary.html` line 156: "**Stall resolution (GOV-04)** The only way a stalled chain moves again"; line 104: the heartbeat key/eligibility entry; plus FI-10–FI-14 in the inclusion entry. `learn/index.html` line 78: "a narrow, proof-enforced inclusion obligation over data published to L1". `learn/limitations.html` line 178: FI-10–FI-14 as the live inclusion statement; line 303: "`T_STALL_GOV` and `T_GOV_RESUME` are unmeasured, and the timelock is long enough that every user can exit ... before a restart executes"; line 27869: "the stall-resolution rule GOV-04". `learn/10-economics.html` line 109: heartbeat gas/key costs and "selection into a future set version requires a heartbeat on L1". `learn/06-data-and-proof-together.html` line 271: the retired height and "`max(lastLandedHeight + 1, resumeHeight)`" (withdrawn by D-15 in round 6, and REC-02 now deferred). **Missing:** the D-16 tombstone pass that `learn/05-the-proof.html` received for aggregation.
- **Assumptions.** None.
- **Drift trace (implementation consequence).** The course is the operator/validator-facing material: validators are told to run a heartbeat key and to expect a rotation; users are told a stall is recoverable and that published data has an inclusion guarantee. None of that is v1. The DEFERRED.md cross-cutting item ("The learning site must be re-synced whenever a deferred mechanism returns") is inverted — it must be re-synced now, because the mechanisms left.
- **Inside/outside the fault model.** Inside; no adversary.
- **Attacker resources and cost.** None.
- **Requirement / fixed decision affected.** D-16's disclosure duty; the freeze's own round-7 acceptance test.
- **Evidence.** `learn/04-staking-and-epochs.html` lines 50 ff.; `learn/06-data-and-proof-together.html` line 271; `learn/08-when-things-go-wrong.html` lines 70, 155; `learn/09-censorship-and-the-bridge.html` lines 42, 50; `learn/glossary.html` lines 104, 156; `learn/index.html` line 78; `learn/limitations.html` lines 178, 303, and its rule list; `learn/10-economics.html` line 109.

---

## R7-RB-06 — Medium — live rules still read the deferred recovery and rotation as contingencies (spec/02, spec/03, spec/10).

*Rationale: the clauses cannot fire in v1 (the generation never advances; no rotation exists), but they are stated as live validity conditions, so an implementer builds the paths they describe.*

- **Rules / missing rule.** `spec/02-consensus.html`: CONS-01(iii) (line 71) "after an executed stall resolution (REC-02) the resumed chain begins at `resumeHeight = lastLandedHeight + 1`"; CONS-01(vii) (line 73) "a proposal whose header generation is not the current generation is invalid, **because the history it extends above the latest L1-accepted checkpoint was discarded by the executed stall resolution of REC-02**"; CONS-05 lock release "within g (CONS-05, REC-02)" (line 100); CONS-09(2) "the ordinary duties of this rule apply with B_anchor the restored checkpoint block ... (REC-04(2))"; and line 493 "the only sanctioned way history above the last L1-accepted checkpoint may be replaced is the timelocked, resume-only stall resolution of REC-02/GOV-04, which executes on L1 under its own trigger, timelock and void-on-progress rules". `spec/03-membership-staking.html` line 350 (MEM-15): "does not apply to a checkpoint above the **recovery floor** (REC-01, REC-02): a completed recovery restores that same checkpoint ... (REC-02, replay row)" — the recovery floor itself was withdrawn by D-15. `spec/10-assurance.html` line 51 (INV class): "**A completed rotation of CONS-16** is the second, narrower event of the same class: it re-partitions only heights that no validator produced ...". **Missing:** a tombstone clause stating these are dead contingencies (as CONS-16 and M3 do on the same pages).
- **Assumptions.** None.
- **Drift trace.** An implementer of CONS-01 implements a generation check plus the assumption that something increments it; an implementer of MEM-15 implements a "recovery floor" comparison that no live rule defines; an implementer of 10's invariant argument implements the rotation as an allowed history-moving event. Each diverges from a reader of 02's CONS-16 tombstone / 06's REC-02 tombstone.
- **Inside/outside the fault model.** Inside; no adversary.
- **Attacker resources and cost.** None.
- **Requirement / fixed decision affected.** D-16; GEN-03.
- **Evidence.** `spec/02-consensus.html` lines 71, 73, 100, 493 (and CONS-09); `spec/03-membership-staking.html` line 350; `spec/10-assurance.html` line 51.

---

## R7-RB-07 — Medium — the live `K_PROOF_BACKENDS` register row still says the count is enforced through the deferred aggregation object.

*Rationale: a live row whose derivation names two tombstones and a withdrawn enforcement mechanism; the sibling rows were updated, this one was not.*

- **Rules / missing rule.** `spec/09-parameters.html` line 191: "`K_PROOF_BACKENDS` ... the required count for an epoch-boundary withdrawal root **L1-13(1) and L1-14(3)** (D-13): the count is **enforced by the Inbox over the aggregation public input**, so L1 still performs one verification per purpose; **fixed by S1's measured aggregation cost**". L1-14 is a tombstone ("MUST NOT be implemented"), there is no aggregation public input in v1, and L1-13's own rule now says "without aggregation a root is k attestations verified on L1" (index row and L1-13). The adjacent rows were swept correctly: `N_PROOF_BACKENDS` (line 192) explicitly says "aggregation is deferred by D-16, so there is no reserved aggregation route"; `K_SETTLE_BACKENDS` (line 190) is withdrawn. **Missing:** the same one-line correction on row 191 ("enforced directly on L1 over k attestations; the aggregation cost line is deferred").
- **Assumptions.** None.
- **Drift trace.** An implementer of the withdrawal-root path cannot tell from row 191 whether to verify k attestations directly (L1-13, D-16) or to expect an aggregation public input (row 191, L1-14 — forbidden). The two answers give different verifier entry points and different gas budgets, i.e. different chains.
- **Inside/outside the fault model.** Inside; no adversary.
- **Attacker resources and cost.** None.
- **Requirement / fixed decision affected.** D-16; D-13; the register's derivation discipline.
- **Evidence.** `spec/09-parameters.html` lines 190, 191, 192; `spec/04-l1-integration.html` L1-13(1); `spec/index.html` line 42329 (L1-13 row).

---

## R7-RB-08 — Medium — the live `PUB_RECORD_RETENTION` parameter and DA-09 still promise a permissionless prune that no v1 entry point performs.

*Rationale: the prune function was deleted with D-12's expiry machinery, but the retention parameter that exists to bound register growth still describes its own effect as a permissionless advance of `pruneCursor`, and no rule or ABI provides it.*

- **Rules / missing rule.** `spec/09-parameters.html` line 180 (live row): "`PUB_RECORD_RETENTION` ... pruning after `PUB_RECORD_RETENTION` **is a permissionless, objective reclamation** of the register's entry slot and changes no acceptance decision. The register has no other expiry, and **without this parameter it would grow without bound**." `spec/08-migration-upgrades.html` line 350: "pruning after `PUB_RECORD_RETENTION` is a permissionless advance of `pruneCursor`, so the register does not grow without bound". `spec/04-l1-integration.html` DA-09(1) keeps "a pruned record is treated as absent". `L1-08` has **no** prune function — its own note says D-12's "expiry prune and a frontier event ... D-16 defers that whole machinery, so none of those functions, events or errors exists in v1" (line 259) — and no rule names a caller, a condition or an effect for the advance. **Missing rule:** either a v1 entry point and rule for the retention prune (of the record entry only, with no due set), or the deletion of the permissionless-prune claims and an explicit statement that the register grows without bound in v1.
- **Assumptions.** None.
- **Drift trace (implementation consequence).** An implementer must either invent a permissionless storage-reclamation entry point (a state-changing function the interface says does not exist, and one that touches the record the guest may still read) or let `publications`/`publicationOrder` grow forever while the parameter that was sized for reclamation is registered and unmeasured. Note the interaction with DA-09: the record entry is only required to be readable for `≥ T_PROVE_DEADLINE`, so the prune is legal, but there is no rule that performs it.
- **Inside/outside the fault model.** Inside; no adversary.
- **Attacker resources and cost.** None (unbounded growth is a cost, not an attack).
- **Requirement / fixed decision affected.** DA-09/PUB_RECORD_RETENTION (live core); the L1-08 interface's "exactly these functions" discipline.
- **Evidence.** `spec/09-parameters.html` line 180; `spec/08-migration-upgrades.html` lines 340–350, 426–431; `spec/04-l1-integration.html` DA-09(1) and L1-08 line 259.

---

## Checked, and holds (the sweep that is clean, and the bidirectional audits)

- **Pages 04, 05, 06, 08, 09, 10 tombstones.** `L1-05` row 36 `forcedBoundary` is "(withdrawn — decision D-16) ... no contract may store it, and no journal field may carry it"; `PRF-04(vi)` is a tombstone with the journal note at `spec/05` line 162; `L1-08`'s note records the deleted forced-inclusion entry points, the settlement view, the expiry prune and the frontier event; `MIG-02` records the govResume fields as withdrawn and (lines 342–344) the FI due-set cursors as "budgeted register state [that] no v1 rule reads"; `CONS-01(v)`, `CONS-16`, `M3`, `M7`, `MEM-13`, `GOV-04`, `REC-02..04`, `PRF-15`, `L1-14`, `FI-10..FI-14`, `FI-REMOVED-01`, `FI-PLANNED-01`, `DA-10` all carry explicit tombstones with MUST-NOT-USE or disclosure language; `REC-01` is correctly kept and re-stated.
- **Rule index both directions.** 161 rule divs across the eleven pages; every id has an index row and every index id has a rule (the `GEN-*`/`STATUS-*` rules are defined on `index.html` itself). The **only** rule-index row that describes a tombstoned rule as live is CONS-16 (R7-RB-03). `L1-14`, `PRF-15`, `MEM-13`, `GOV-04`, `REC-02..04`, `FI-10..FI-14`, `FI-REMOVED-01` rows all read "DEFERRED by D-16 (tombstone)".
- **Parameter register both directions.** Every value a live rule reads has a row (spot-checked: `D_MAX` 120, `T_PROVE_DEADLINE` 179, `PUB_RECORD_RETENTION` 180, `K_PROOF_BACKENDS` 191, `N_PROOF_BACKENDS` 192, `W_ROOT_WAIT_MAX` 196, `T_VETO` 197, `N_MAX` 200, `WITHDRAWAL_DELAY`, `DRAIN_DEADLINE`). Withdrawn rows carry MUST-NOT-USE reasons (the recovery-bond set, the heartbeat set, the aggregation set, the FI set, `T_STALL_GOV`/`T_GOV_RESUME`, `govResume*`, `K_SETTLE_BACKENDS`, `M_AGG_MAX`, `AGG_PROVER_PPM`, `T_AGG_ROTATE_MAX`). The exceptions are R7-RB-02 (configHash preimage), R7-RB-03 (`T_ROTATE`/`T_ROTATE_DELAY`) and R7-RB-07 (`K_PROOF_BACKENDS` text).
- **`L2_BLOCK_GAS_LIMIT`.** Withdrawn in the register and in the index parameter map; its residual is exactly the configHash V2 preimage field (R7-RB-02). It is not read anywhere else.
- **Aggregation.** `L1-13` is correctly rewritten to "k attestations verified on L1" without an aggregation object, `learn/05-the-proof.html` states "No aggregation: v1 accepts one proof per batch from one registered backend", and `spec/10`/index disclose the single-backend soundness. The residuals are R7-RB-04 (07's economic MUST) and R7-RB-07 (09's row text).
- **Course pages clean:** `learn/01`, `learn/02`, `learn/03`, `learn/05`, `learn/07` contain no live reference to a deferred mechanism (checked every tombstoned token).

## Fault-model verdict

This angle needs no fault-model assumption: every finding is a textual/integrational drift, and the drifts are inside the "specification is the authority" model rather than triggers of an in-protocol attack. The two with security consequence at the implementation boundary are R7-RB-04 (a live slashing rule for a non-existent, uncomputable obligation — a funds-loss lever if implemented) and R7-RB-03 (a register that instructs an implementer to build a forbidden history-moving transition). R7-RB-02 is the one that makes conformance undecidable: two honest implementers of the same page set produce different `configHash` preimages.

## Is v1 implementable as written?

**Not yet, on the current text.** The core rules (L1-01..L1-13, DA-*, PRF-* minus the tombstones, MEM-*, ECON-*, HALT-*, MIG-*, GOV-01..03, REC-01) are consistent and implementable; the rollback broke conformance in four places that a build would hit immediately: the closed `configHash` preimage containing MUST-NOT-USE names (RB-02), the register/index split on CONS-16 and its parameters (RB-03), the live forced-inclusion offence and aggregation-share MUST in 07 (RB-04), and the un-swept system-model page and course that contradict the tombstones for users and implementers (RB-01, RB-05). All five are mechanical to fix: sweep 01 and 07 and the eight course pages the way 04/05/06/08/10 were swept; re-derive PRF-02(5)'s enumeration to live names only and bump paramVersion/domain tag (or state explicitly that the withdrawn fields stay as fixed-width padding with constant values); decide CONS-16 kept-or-deferred once and align 02, 09, the index and the freeze; correct row 191; and give `PUB_RECORD_RETENTION` an owner or delete its prune claims.

## Counts

| Severity | Count | Ids |
|---|---|---|
| Critical | 0 | — |
| High | 5 | R7-RB-01, R7-RB-02, R7-RB-03, R7-RB-04, R7-RB-05 |
| Medium | 3 | R7-RB-06, R7-RB-07, R7-RB-08 |
| Low | 0 | — |
