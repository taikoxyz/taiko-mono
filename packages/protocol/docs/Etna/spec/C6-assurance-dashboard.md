# C6-B. Assurance dashboard

**[assumed: ownership and snapshot]** B maintains this reference-only dashboard under D12/W6/W16. A's C6-R08 owns limitation dispositions; S4-R14 owns requirement tags; S2-R18 owns the six confirmation levels. This page assigns none of those a second meaning or acceptance status. Snapshot: 2026-10-02, after C1's D28 merge and B's W11–W13 reviews; C4 is the W16 submission. A/J have not approved this revision.

**[open: readiness]** Section review is in progress. The cross-opening accountability finding B-D21-01 and the primary-frame authorization finding B-C5-01 remain open at this snapshot. D2 allows unmeasured implementation work, not contradictory rules. Neither historical candidate rounds nor these section reviews constitute the merged-spec convergence rounds.

## 1. Source and review ledger

| Owner | Immutable source | Review state at snapshot |
|---|---|---|
| C1 | [42c76c9b](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/spec/C1-anchor-free-l2.md) | Merged by A under D28; C4/C8 integration and unmeasured evidence remain. |
| C2 | [f67d4d47](https://github.com/taikoxyz/taiko-mono/blob/f67d4d47e7c7b3ac960d4434ac28e5dedf5b64da/packages/protocol/docs/Etna/spec/C2-landing.md) | B request-changes; D23/W15 recovery head pending. |
| C3 | [13d0e119](https://github.com/taikoxyz/taiko-mono/blob/13d0e119f87ce6dc33c59f48b1aeade274884277/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md) | B request-changes; D18/D22/W15 recovery head pending. |
| C4 | [d1ebe1e6](https://github.com/taikoxyz/taiko-mono/blob/d1ebe1e6e3c68972c0b14cef04db72b0dccee304/packages/protocol/docs/Etna/spec/C4-migration.md) | W16 submitted; A/J review and named integration seams pending. |
| C5 | [595b5f7b](https://github.com/taikoxyz/taiko-mono/blob/595b5f7b192b95cac349617c9c4599c295744221/packages/protocol/docs/Etna/spec/C5-l1-dependencies-and-frames.md) | B request-changes, B-C5-01 High: primary frame authorization missing. |
| C6A | [22948df9](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md) | B request-changes; B-D21-01 propagation and three Mediums. |
| C7 | [fa854f35](https://github.com/taikoxyz/taiko-mono/blob/fa854f3524a9dc20181f47fb04b8e4c4ab6afbf3/packages/protocol/docs/Etna/spec/C7-block-validity.md) | B request-changes; D22/W15 recovery head pending. |
| C8 | [f03f12a7](https://github.com/taikoxyz/taiko-mono/blob/f03f12a77879d625a7a2e8e34c55c516c47c5efd/packages/protocol/docs/Etna/spec/C8-interfaces-and-storage.md) | B request-changes; encoding/layout/authority synchronization. |
| S1 | [6751cb3a](https://github.com/taikoxyz/taiko-mono/blob/6751cb3a1a48af53b3bfe066332f5f7b1af397a3/packages/protocol/docs/Etna/spec/S1-seats-and-sortition.md) | B request-changes; D19/W15 recovery head pending. |
| S2 | [0403a540](https://github.com/taikoxyz/taiko-mono/blob/0403a540a2186f404d7e5bff99496d29a7be3789/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md) | B request-changes; D21 and B-D21-01/D29 pending. |
| S3 | [181acf03](https://github.com/taikoxyz/taiko-mono/blob/181acf03a2e77948aeb730683882b3589bc2adf3/packages/protocol/docs/Etna/spec/S3-slashing-and-economics.md) | B request-changes; D20 plus cross-opening evidence/backing work pending. |
| S4 | [103b7c88](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md) | B request-changes; composed claims and decided projections need repair. |

**[assumed: decision provenance]** [DECISIONS through D28](https://github.com/taikoxyz/taiko-mono/blob/42c76c9bddb24bc8d51a7b4454a0439ab5d8e182/packages/protocol/docs/Etna/DECISIONS.md) governs this snapshot. D27 corrects D24: J is active; the fallback applies only to a head J has not reached within a cycle. D28 accepts C1. D25/D26 govern the migration revision. D29 was announced as pending arbitration of B-D21-01; it is not a decision in this pin.

[W11](https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5945030219) attacks D21–D23; [W13](https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5945170889) owns the snapshot consistency list. The six W15 replacement heads were not yet cited; unchanged historical approvals or partial J closures do not approve unseen recovery predicates.

## 2. Assurance claim index

| Claim to inspect | Sole owning arguments | Current review dependency |
|---|---|---|
| Anchor-free execution and current-root guards | C1-R01/R02/R05/R07/R09 | C1 merged; C4 installation, client/guest parity and C8 projection remain distinct obligations. |
| Checkpoint/header integrity and floor lookup | C1-R06/R08/R10; C2-R13/R15/R19/R21 | C2/C8 must consume C1's merged lookup and installation rule. Floors do not undo custody effects. |
| Local validity versus landed validity | C7-R01 and predicate; C2-R04/R05 | D22 fixed references, mode table and invalid-object preimage residual need recovery review. |
| Slashable actionable confirmation | S2-R18; S3-R08/R10; S4-R07 | B-D21-01 remains open; current collectible backing is not nominal seat capital or a continuously funded reserve threshold. |
| Atomic data/proof landing and races | C2-R01–R05; C5-R12–R15 | B-C5-01 requires complete sender/payment authorization in the primary frame shape. Ordinary land remains a fallback. |
| Forced inclusion and irreversible settlement | C3-R03–R11; C4-R06 legacy adapter | D18/D22 recovery and the exact legacy resource/outcome profile require owner review. |
| Retained custody and upgrade-only powers | C4-R09–R13; C8-R15/R17 | D26 removals are in C4's W16 submission; C8/S4 projections and manifest audit remain. |
| Whole-design safety, liveness and role failures | S4-R01–R14 | Follow S4's premises/exceptions and the explicit B verdict; this index supplies no parallel theorem. |

## 3. Confirmation-level index

**[assumed: reference only]** Use the exact level names and definitions in [S2-R18](https://github.com/taikoxyz/taiko-mono/blob/0403a540a2186f404d7e5bff99496d29a7be3789/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md#L177). The rows below identify their source, not an alternative label system or promise.

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

**[assumed: separate implementation classification]** [IG1](https://github.com/taikoxyz/taiko-mono/blob/22948df900eac650947761f17c651a184316d770/packages/protocol/docs/Etna/spec/C6-threat-model-and-limitations.md#L230) follows C5-R17(d): client/Catalyst integration, not an L1 dependency or an L-id. Its closure and possible reclassification are owned there.

**[open: migration projection]** C4-R04/R05's forced-intake gap runs from the freeze cutoff through actual ACTIVE. FREEZE plus DRAIN_DEADLINE describes the nominal wait until abandonment is available; authenticated repair, data availability and inclusion may extend it. C4-R06/§6 carries ordinary-tail loss, unrecovered old fees and self-funded replay. These are references to C4, not new limitation IDs or an additional time bound. D26's stuck-asset and fixed-resolver consequences are L41/L42; the three operational powers are removed.

### L-PF restart-cost evidence index

**[assumed: accounting references only]** C2-R14, C3's D18 settlement, C4-R06/R12 and C6-R08 L-PF/L37 own the dispositions. Evidence should separate irreversible landing/attestation/pin rewards, FI credits/refunds/burns, new proving/DA/L1 replay costs, and custody actions already executed against a root. Keep ETH and TAIKO separately denominated; S3 owns any rate assumption.

**[proven: accounting identity only]** Rewinding an execution cursor does not create another entitlement from already-settled money. A bounded provisional interval is not itself a monetary loss or restart-cost bound. The owning per-term/entry rules and actual affected workload determine the components.

**[open: evidence, not subsidy]** The register indexes replay workload, actual collectible funding and governance-response assumptions. Quota exposure follows C4-R10/R12: only configured assets and covered paths are capped; quota zero is unlimited, and a rate cap is neither reimbursement nor a total-loss bound with unbounded response time. B-C6A-02 requests that qualification in A's register; this projection does not silently edit its disposition.

## 5. Requirement-review index

**[assumed: sole verdict owner]** Requirement tags are **as [S4-R14](https://github.com/taikoxyz/taiko-mono/blob/103b7c88e28bf488bf2c7de4b06307a891687c6e/packages/protocol/docs/Etna/spec/S4-roles-and-liveness.md#L163)**. B records review state only. An open review can dispute a tag without this page becoming another verdict table.

| Requirement | Tag source | Review state / owning correction |
|---|---|---|
| R1 | as S4-R14 | B requests explicit availability premises for L19/L-PF; D26 removes the three powers, with C4/C8 integration pending. |
| R2 | as S4-R14 | C1 accepted; C4/C8 manifest, retained surfaces and restart schema in review. |
| R3 | as S4-R14 | S4's role/offline analysis reviewed with the P6 scope correction requested. |
| R4 | as S4-R14 | Timing remains an unmeasured owner target under D2; source-level consistency is still required. |
| R5 | as S4-R14 | User permits seconds and L1 block numbers. D22 locality and C5 dependency projections are in review. |
| R6 | as S4-R14 | S2/S3 evidence and D19/D20 economic/assignment recovery under review; no independent pass assigned here. |
| R7 | as S4-R14 | C2/C5/C8 integration pending, including B-C5-01's primary-frame correction. |
| D1 | as S4-R14 | B-D21-01 remains open. Only the user can approve a requirement relaxation. |
| D2 | as S4-R14 | Specification-only scope; implementation and measurements are not newly imposed gates. |
| Convergence | README/WORK criterion, owned by A | Merged-spec rounds and J's readiness audit have not been completed at this snapshot. |

## 6. Learning-site synchronization

**[assumed: publication evidence]** The integration snapshot contains the charter, work orders and accepted C1; no converged learning site is present. Historical candidate courses remain historical. This revision supplies an exact handoff rather than relabeling one of those courses as the accepted specification.

| Lesson dependency | Accepted source or pending seam to consume |
|---|---|
| Standard operations and roots | Accepted C1 at the merged pin above; C4 installation/migration remains in review. |
| Seats and local validity | S1/S2/C7 recovery, including fixed references and sentinel modes, before teaching final predicates. |
| Actionable confirmation | S2/S3's eventual D29 disposition, actual backing and all six exact S2-R18 names; distinguish IG1 from running-client evidence. |
| Landing and recovery | C2/C3/C5 with the repaired complete frame shape, due clocks, settlements and replay costs. |
| Custody and migration | C4/C8, D26 removals, legacy profile, actual activation/ref floors, no lower-than-published rollback, L41/L42. |
| Full argument | Reviewed S4 and both C6 halves, each accepted residual and the actual merged-round closure commits. |

**[open: publication]** Each future lesson must retain the original brief's small prerequisite-ordered mechanism, diagram, worked example, attacks, hidden answers and challenge box. Pin its accepted source and update dependent examples whenever that source changes. WORK assigns the course owner; no implementation-ready or synchronized-course claim is made while that site is absent.

## 7. Review provenance

**[assumed: record]** This W16 revision applies A's [5944784586](https://github.com/taikoxyz/taiko-mono/pull/22206#issuecomment-5944784586): full owner-only limitation coverage, S2 names, S4 verdict ownership and separate economic closure tests. Earlier J clearances apply to their cited heads, not this revision. W12 request-changes comments remain linked from the umbrella W13 list. Internal support reviews are not J's independent verdict, arbiter decisions, tests or measurements.
