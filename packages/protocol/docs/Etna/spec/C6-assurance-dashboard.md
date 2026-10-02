# C6-B. Assurance dashboard

**[assumed: ownership and snapshot]** B maintains this reference-only dashboard under D12/W6/W16. A's C6-R08 owns limitation dispositions; S4-R14 owns requirement tags; S2-R18 owns the six confirmation levels. This page assigns none of those a second meaning or acceptance status. Snapshot: 2026-10-02, after C1's D28 and C5's D31 merges, B's commit-pinned W12 recovery reviews and the second W16 migration revision. A/J have not approved this C6-B revision.

**[open: readiness]** Section review is in progress. B-D21-01 remains open. B approved C5's repaired authorization shape and A merged it under D31; the new provisional-conflict output, S6 witness-authentication and collectible-backing findings remain open in their owning section reviews. D2 allows unmeasured implementation work, not contradictory rules. Neither historical candidate rounds nor these section reviews constitute the merged-spec convergence rounds.

## 1. Source and review ledger

| Owner | Immutable source | Review state at snapshot |
|---|---|---|
| C1 | [42c76c9b](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md) | Merged by A under D28; C4/C8 integration and unmeasured evidence remain. |
| C2 | [6e2b7321](https://github.com/taikoxyz/taiko-mono/blob/6e2b73215ea7031a4d67571049980d9742be13dc/packages/protocol/docs/Etna/spec/C2-landing.md) | B request-changes: new provisional-conflict output/interface gaps; original D23 binding repaired. |
| C3 | [4aa0299c](https://github.com/taikoxyz/taiko-mono/blob/4aa0299c00ef25b77fc99ea54499839ddaa503a4/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md) | B request-changes: inherited floor, renewable waivers and multi-cut/recovery/legacy seams; original D18 vectors repaired for new entries. |
| C4 | [93d9038b](https://github.com/taikoxyz/taiko-mono/blob/93d9038bd05652f95ce73b9270c8db7b2b034b82/packages/protocol/docs/Etna/spec/C4-migration.md) | Second W16 revision submitted: separate settlement flag, explicit restart initialization and D30; A/J re-review and owner seams pending. |
| C5 | [66e37373](https://github.com/taikoxyz/taiko-mono/blob/66e37373b5acd9baf9fee8b1ccc53d2eb3d9f451/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md) | Merged by A under D31 after B's approval; B-C5-01 closed. Downstream C2/S3 propagation remains separate. |
| C6A | [22948df9](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md) | B request-changes; B-D21-01 propagation and three Mediums. |
| C7 | [515f3be4](https://github.com/taikoxyz/taiko-mono/blob/515f3be43404dc301d4ce4bd42f8879214ba5a45/packages/protocol/docs/Etna/spec/C7-block-validity.md) | B request-changes: hold re-entry, mode/bootstrap definitions and acknowledged liveness gaps; D22 repairs partially close prior traces. |
| C8 | [f03f12a7](https://github.com/taikoxyz/taiko-mono/blob/f03f12a77879d625a7a2e8e34c55c516c47c5efd/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md) | B request-changes; encoding/layout/authority synchronization. |
| S1 | [e72e55e8](https://github.com/taikoxyz/taiko-mono/blob/e72e55e825ff53f2f6a9b761f0d004ef2444812b/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md) | B request-changes: D19 original traces repaired; fresh-owner lifecycle, sentinel reference and interval/dating choices remain. |
| S2 | [ab391fe4](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md) | B request-changes: original witness/chronology/suppression repairs pass; D29, S6 witness authentication and reference convergence remain. |
| S3 | [a0f3232a](https://github.com/taikoxyz/taiko-mono/blob/a0f3232a654580d491aecbd88c8716cd9794ea57/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md) | B request-changes: MISS floor repaired; quorum-inventory versus deterrent, S6 evidence and backing/lifecycle consistency remain. |
| S4 | [103b7c88](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md) | B request-changes; composed claims and decided projections need repair. |

**[assumed: decision provenance]** [DECISIONS through D31](https://github.com/taikoxyz/taiko-mono/blob/673a1179d44314552fb5c69aed3d08c8fdd78057/packages/protocol/docs/Etna/DECISIONS.md) governs this snapshot. D27 corrects D24: J is active; the fallback applies only to a head J has not reached within a cycle. D28 accepts C1. D25/D26 govern migration and operational removals; D30 rejects plain-Ether Bridge funding uniformly; D31 merges C5. D29 was announced as pending arbitration of B-D21-01; it is not a decision in this pin.

[W11](https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5945030219) attacks D21–D23; [W13](https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5945170889) owns the snapshot consistency list. All six W15 replacement heads and the C5 repair are pinned above. Recovery reviews close particular prior traces and identify remaining/new defects; no unchanged historical approval or partial J closure approves the revised section as a whole.

## 2. Assurance claim index

| Claim to inspect | Sole owning arguments | Current review dependency |
|---|---|---|
| Anchor-free execution and current-root guards | C1-R01/R02/R05/R07/R09 | C1 merged; C4 installation, client/guest parity and C8 projection remain distinct obligations. |
| Checkpoint/header integrity and floor lookup | C1-R06/R08/R10; C2-R13/R15/R19/R21 | C2/C8 must consume C1's merged lookup and installation rule. Floors do not undo custody effects. |
| Local validity versus landed validity | C7-R01 and predicate; C2-R04/R05 | D22 fixed-reference, mode and hold re-entry gaps remain; the S6 witness must be authenticated separately from the logical opening ID. |
| Slashable actionable confirmation | S2-R18; S3-R08/R10; S4-R07 | B-D21-01 remains open. D20 adopts S3's assumed threshold-based collectible bound; B disputes its continuous funding and the new quorum-sum interpretation. These are open review items pending D29/the D20 amendment, not a replacement bound adopted by this index. |
| Atomic data/proof landing and races | C2-R01–R05; C5-R12–R15 | B approved C5's complete sender/payment authorization; C2/S3 must consume it. C2's new derived-output conflict handling remains open. Ordinary land remains a fallback. |
| Forced inclusion and irreversible settlement | C3-R03–R11; C4-R06 legacy adapter | Original D18 new-entry vectors pass; inherited floor, recurring waivers, multi-cut and legacy resource/outcome decisions remain open. |
| Retained custody and upgrade-only powers | C4-R09–R13; C8-R15/R17 | D26 removals are in C4's W16 submission; C8/S4 projections and manifest audit remain. |
| Whole-design safety, liveness and role failures | S4-R01–R14 | Follow S4's premises/exceptions and the explicit B verdict; this index supplies no parallel theorem. |

## 3. Confirmation-level index

**[assumed: reference only]** Use the exact level names and definitions in [S2-R18](https://github.com/taikoxyz/taiko-mono/blob/ab391fe4710382f089f367b54261c0296e54cc67/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L214). The rows below identify their source, not an alternative label system or promise.

| S2 level | Definition and exceptions | Review notice |
|---|---|---|
| sequenced | S2-R18, sequenced row; C7 local predicate | Fixed-reference/mode integration pending. |
| attested | S2-R18, attested row | A certificate's precise commitments, quorum and witness are S2-owned. |
| locked | S2-R18, locked and “what locked is not” rows | B-D21-01 and current-backing review remain open; show the owner's exceptions beside the label. |
| landed | S2-R18, landed row; C2 publication state | L1 inclusion and finality remain separate in the owner definition. |
| landed (provisional) | S2-R18, provisional row; C2-R12–R15 | L-PF and L37 are indexed below; no custody checkpoint is inferred merely from this label. |
| final | S2-R18, final row | Read its L1-finality premise and proof/upgrade assumptions; this index does not strengthen it. |

**[open: client evidence]** IG1 in C6 and C5-R17(d) identifies the inspected anchorless client's unimplemented confirmation path. The [unmeasured register](C6-unmeasured-register.md#external-implementation-evidence-outside-d2) pins the source. A specified level is not evidence that a client currently executes it.

## 4. C6-R08 limitations index

**[assumed: reference-only projection]** Exactly one row per id in [C6-R08](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L177). Every status is **as C6-R08**; this page neither ratifies a proposed residual nor changes a user-gated decision. A technical review of faithful transcription is not acceptance of a D1 relaxation. Full consequence, severity, rationale and acceptance evidence remain in the linked row.

| C6-R08 id | Owning rules / section, as named there | Status |
|---|---|---|
| [L1](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L183) | S1-R11, S2-R07 | status: as C6-R08 |
| [L2](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L184) | S2-R07, S2-R13, S2-R14, S2-R16, S3-R28 | status: as C6-R08 |
| [L3](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L185) | S2-R20, C2-R08 | status: as C6-R08 |
| [L4](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L186) | S2-R07, S2-R10 | status: as C6-R08 |
| [L5](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L187) | S2-R10, S2-R13, S2-R14 | status: as C6-R08 |
| [L6](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L188) | C2-R08, C2-R09, C3-R11 | status: as C6-R08 |
| [L7](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L189) | C2-R03 | status: as C6-R08 |
| [L8](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L190) | C3-R02, C3-R08, C7-R13 | status: as C6-R08 |
| [L9](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L191) | S1-R19, S3-R27, S3-R28 | status: as C6-R08 |
| [L10](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L192) | S3-R03 | status: as C6-R08 |
| [L11](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L193) | C7-R09, C2-R20, C5-R05 | status: as C6-R08 |
| [L12](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L194) | C3-R16, C5-R10, S1-R04 | status: as C6-R08 |
| [L13](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L195) | C2-R20, C5-R17, C5-R18 | status: as C6-R08 |
| [L14](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L196) | C2-R10, S2-R18, C2-R08 | status: as C6-R08 |
| [L15](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L197) | S3 §11 (A-ECON) | status: as C6-R08 |
| [L16](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L198) | S2-R02, S2-R16, S2-R18, S3-R10, S1-R08, S1-R13, S1-R18 | status: as C6-R08 |
| [L17](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L199) | C4 (B's draft #22205, D25), C3-R05 | status: as C6-R08 |
| [L18](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L200) | C6-R11, C3 §11 | status: as C6-R08 |
| [L19](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L201) | C2-R11, S4-R04 | status: as C6-R08 |
| [L20](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L202) | S3-R21 to S3-R25, C2-R17 | status: as C6-R08 |
| [L21](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L203) | C1-R10 | status: as C6-R08 |
| [L22](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L204) | C1-R05, C1-R08, C3 §13 | status: as C6-R08 |
| [L-OP](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L205) | C4 (B's draft #22205; D25 adopts its change table, D26 removes three of its retained rows), S4-R04 | status: as C6-R08 |
| [L-PF](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L206) | C2-R12 to C2-R15, C2-R21 | status: as C6-R08 |
| [L23](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L207) | C3-R02, C3-R03, C3-R06, C3-R09, C3-R10 | status: as C6-R08 |
| [L24](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L208) | S2-R18, S3-R10, S3 §15 (D1 discharge record) | status: as C6-R08 |
| [L25](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L209) | C2-R18, S2-R22 | status: as C6-R08 |
| [L26](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L210) | C1-R05, C1-R08, S3-R11 | status: as C6-R08 |
| [L27](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L211) | C5-R12, C5-R15 | status: as C6-R08 |
| [L28](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L212) | C5-R12, C5-R18 | status: as C6-R08 |
| [L29](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L213) | C5-R10 | status: as C6-R08 |
| [L30](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L214) | C5-R18 | status: as C6-R08 |
| [L31](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L215) | C7-R01, C2-R07, C3-R06 | status: as C6-R08 |
| [L32](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L216) | S3-R08 | status: as C6-R08 |
| [L33](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L217) | S2-R13 | status: as C6-R08 |
| [L34](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L218) | S4-R05, S4 §8 | status: as C6-R08 |
| [L35](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L219) | S1-R11, S1-R17 | status: as C6-R08 |
| [L36](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L220) | C2-R02, C2-R04, C2-R09, S2-R10 | status: as C6-R08 |
| [L37](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L221) | C2-R14, C2-R21, C4 (rollback table) | status: as C6-R08 |
| [L38](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L222) | C7-R15, S3-R05, S2-R21 | status: as C6-R08 |
| [L39](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L223) | C7-R09, C2-R19, C3-R07, C3-R08, C3-R11 | status: as C6-R08 |
| [L40](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L224) | C3-R03, C3-R09 step 5, C3-R13, C2-R14 | status: as C6-R08 |
| [L41](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L225) | C4-R10, S4-R04 | status: as C6-R08 |
| [L42](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L226) | C4-R10, C4-R11 (storage compatibility), S4-R04 | status: as C6-R08 |

**[assumed: separate implementation classification]** [IG1](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L234) follows C5-R17(d): client/Catalyst integration, not an L1 dependency or an L-id. Its closure and possible reclassification are owned there.

**[open: migration projection; source: [C4 §10's C6 obligation](https://github.com/taikoxyz/taiko-mono/blob/93d9038bd05652f95ce73b9270c8db7b2b034b82/packages/protocol/docs/Etna/spec/C4-migration.md#L351)]** C4-R04/R05's forced-intake gap runs from the freeze cutoff through actual ACTIVE. FREEZE plus DRAIN_DEADLINE describes the nominal wait until abandonment is available; authenticated repair, data availability and inclusion may extend it. C4-R06/§6 carries ordinary-tail loss, unrecovered old fees and self-funded replay. These are references to C4, not new limitation IDs or an additional time bound. D26's stuck-asset and fixed-resolver consequences are L41/L42; the three operational powers are removed. C4's second revision chooses no initial treasury sweep, so L41's projection must include the accumulated pre-Etna base-fee treasury. D30 removes the receive allowlist through uniform rejection.

### L-PF restart-cost evidence index

**[assumed: accounting references only]** C2-R14, C3's D18 settlement, C4-R06/R12 and C6-R08 L-PF/L37 own the dispositions. Evidence should separate irreversible landing/attestation/pin rewards, FI credits/refunds/burns, new proving/DA/L1 replay costs, and custody actions already executed against a root. Keep ETH and TAIKO separately denominated; S3 owns any rate assumption.

**[proven: accounting identity only]** Rewinding an execution cursor does not create another entitlement from already-settled money. A bounded provisional interval is not itself a monetary loss or restart-cost bound. The owning per-term/entry rules and actual affected workload determine the components.

**[open: evidence, not subsidy]** The register indexes replay workload, actual collectible funding and governance-response assumptions. Quota exposure follows C4-R10/R12: only configured assets and covered paths are capped; quota zero is unlimited, and a rate cap is neither reimbursement nor a total-loss bound with unbounded response time. B-C6A-02 requests that qualification in A's register; this projection does not silently edit its disposition.

## 5. Requirement-review index

**[assumed: sole verdict owner]** Requirement tags are **as [S4-R14](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L163)**. B records review state only. An open review can dispute a tag without this page becoming another verdict table.

| Requirement | Exact tag, as S4-R14 | Review state / owning correction |
|---|---|---|
| R1 | **proven conditionally** ([as S4-R14](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L169)) | B requests explicit availability premises for L19/L-PF; D26 removes the three powers, with C4/C8 integration pending. |
| R2 | **proven** for addresses and the one unchanged checkpoint call; **open** for the audit ([as S4-R14](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L170)) | C1 accepted; C4/C8 manifest, retained surfaces and restart schema in review. |
| R3 | **proven** that every role has a stated entry, exit and gate-free rule; **assumed** for magnitudes ([as S4-R14](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L171)) | S4's role/offline analysis reviewed with the P6 scope correction requested. |
| R4 | **assumed** target, **unmeasured** ([as S4-R14](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L172)) | Timing remains an unmeasured owner target under D2; source-level consistency is still required. |
| R5 | **proven** for slots and epochs ([as S4-R14](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L173)) | See S4 §10 item 12 and C6-A §11 item 13 for the owning open question; this index adds no answer. D22 locality integration remains in review. |
| R6 | **proven** for objectivity; **assumed** for anti-monopoly ([as S4-R14](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L174)) | S2/S3 evidence and D19/D20 economic/assignment recovery under review; no independent pass assigned here. |
| R7 | **proven** for one action carrying data and proof; **assumed** for explicit data availability and minute-level landing ([as S4-R14](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L175)) | C5 frame correction approved by B; C2 conflict/output and C3 recovery findings plus C8 projection remain open. |
| D1 | **open** ([as S4-R14](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L176)) | B-D21-01 remains open. Only the user can approve a requirement relaxation. |
| D2 | **assumed** scope ([as S4-R14](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L177)) | Specification-only scope; implementation and measurements are not newly imposed gates. |
| Convergence | README/WORK criterion, owned by A | Merged-spec rounds and J's readiness audit have not been completed at this snapshot. |

## 6. Learning-site synchronization

**[assumed: publication evidence]** The integration snapshot contains the charter, work orders and accepted C1; no converged learning site is present. Historical candidate courses remain historical. This revision supplies an exact handoff rather than relabeling one of those courses as the accepted specification.

| Lesson dependency | Accepted source or pending seam to consume |
|---|---|
| Standard operations and roots | Accepted C1 at the merged pin above; C4 installation/migration remains in review. |
| Seats and local validity | S1/S2/C7 recovery, including fixed references and sentinel modes, before teaching final predicates. |
| Actionable confirmation | S2/S3's eventual D29 disposition, actual backing and all six exact S2-R18 names; distinguish IG1 from running-client evidence. |
| Landing and recovery | Accepted C5 four-frame shape under D31; C2/C3 must consume it and resolve due clocks, settlement and restart edges before those dependent lessons are taught as settled. |
| Custody and migration | C4/C8, D26 removals, legacy profile, actual activation/ref floors, no lower-than-published rollback, L41/L42. |
| Full argument | Reviewed S4 and both C6 halves, each accepted residual and the actual merged-round closure commits. |

**[open: publication]** Each future lesson must retain the original brief's small prerequisite-ordered mechanism, diagram, worked example, attacks, hidden answers and challenge box. Pin its accepted source and update dependent examples whenever that source changes. WORK assigns the course owner; no implementation-ready or synchronized-course claim is made while that site is absent.

## 7. Review provenance

**[assumed: record]** This W16 revision applies A's [5944784586](https://github.com/taikoxyz/taiko-mono/pull/22206#issuecomment-5944784586): full owner-only limitation coverage, S2 names, S4 verdict ownership and separate economic closure tests. Earlier J clearances apply to their cited heads, not this revision. W12 request-changes comments remain linked from the umbrella W13 list. Internal support reviews are not J's independent verdict, arbiter decisions, tests or measurements.

**[assumed: second W16 review record]** This revision also applies A's [5945408758](https://github.com/taikoxyz/taiko-mono/pull/22206#issuecomment-5945408758): value-free register identifiers, no index-owned backing decision, exact S4 tag text, corrected IG1/source anchors and refreshed recovery sources. It consumes C4's second W16 revision without approving its remaining owner seams.

**[assumed: immutable-head recovery verdicts]** [C2: request changes](https://github.com/taikoxyz/taiko-mono/pull/22196#issuecomment-5945458948); [S2: request changes](https://github.com/taikoxyz/taiko-mono/pull/22197#issuecomment-5945463611); [C7: request changes](https://github.com/taikoxyz/taiko-mono/pull/22199#issuecomment-5945469204); [C3: request changes](https://github.com/taikoxyz/taiko-mono/pull/22200#issuecomment-5945484944); [S1: request changes](https://github.com/taikoxyz/taiko-mono/pull/22201#issuecomment-5945496141); [S3: request changes](https://github.com/taikoxyz/taiko-mono/pull/22202#issuecomment-5945516240); [C5: approve](https://github.com/taikoxyz/taiko-mono/pull/22209#issuecomment-5945442854). Each review names its full commit and separates repaired traces from remaining/new findings. The C3 review includes the C4 restart-edge clock regression. A merged C5 under D31; none of these B verdicts merges another section or changes a C6-R08 disposition.
