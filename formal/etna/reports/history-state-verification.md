# Historical context and combined state verification

Historical report: counts, source line IDs and audit packaging below describe the original batch; see [review corrections](review-corrections.md) for the current schema, bindings and checks.
Baseline: PR #22292 at `cc44e3b43adf78f45540d4bb4b5a4649afea4d3c`. Scope is only `formal/etna`; production code is unchanged. The frozen bilingual 2026-10-27 04:07Z edits remain the specification authority. The first-batch report and validation are historical records; current validation is in [review corrections](review-corrections.md).

## Coverage calibration

All 411 audited declarations have a reverse entry in `spec-coverage.json`. Roles distinguish general properties, supporting lemmas and finite regressions. The checker requires a complete, duplicate-free declaration inventory, known source IDs, nonempty scope notes and exact bidirectional agreement. A clause linked only to an example or helper cannot be marked partial/proved. Existing power-bound and fee-sweep proofs are now mapped rather than silently left unmapped.

The 619 bilingual source clauses are **174 partial, 439 deferred and 6 design-pending**; none is fully proved. These are paragraphs/list items/table rows/code blocks, not atomic requirements or a coverage percentage. All original 294 complete theorem contracts (including the original 227) are unchanged. This batch adds 117 contracts: 76 properties/supporting lemmas and 41 kernel-checked regressions. Semantic source correspondence and bilingual equivalence remain human review obligations; a link covers only the exact audited proposition and its premises.

## Added conditional properties

| Module | Established property | Boundary |
| --- | --- | --- |
| `RegistryHistory` | Slot reuse retains lifetime used-key identity; evidence for a previous occupant cannot target a replacement key. Bond edits reuse existing staking rules. Owner/confirmation metadata does not alter election entries. Same-block changes replace one checkpoint; ordered history selects the latest checkpoint at/before cutoff. Strictly older snapshots survive later edits/recovery/rollback. | Decoded canonical key identities, signature results, parameters and L1 clock are logical inputs; no byte/PoP/token-call refinement or aggregate principal accounting. |
| `HistoricalContext` | Builds context from current-generation origin mapping, ordered registry history and sorted covered anchor archive. Missing origin/snapshot and an invalid initial election reject. The selected checkpoint is maximal at/before cutoff; ordinary cutoff derives from committed D(t) anchors with the recovery-origin floor. A covered header lookup equals a present archive entry. | L1 finality, raw-header ancestry, MPT/root/entry authentication and complete archived material are external. The total lookup beyond the archive is not treated as authenticated. |
| `ProtocolState` | A common transition relation composes landing, registration/bond edits, FI enqueue/sweep, recovery and exceptional rollback. From structural `Core`, arbitrary mixed traces retain current-record/grid consistency, unique retained heights, cursor bounds, fee arithmetic, registry keys/identities/snapshots and FI index sequence. Generation and L1 clock do not decrease; origin archive is append-only and used keys persist. | Transaction atomicity and decoded environment are assumed. Core does not establish exact FI contents, origin uniqueness, authentic EL execution or whole-protocol economic safety. Raw accepted landings may represent verifier failure. |
| `ProtocolState.accepted_snapshot_from_history` | Strengthens settlement with a built historical context, a valid decoded batch and shared statement. Accepted active snapshot is the derived terminal committee cutoff; every queried height through terminal has a present typed archive entry. | Real guest correctness, root/signature/payload/EL relations and full header-chain authentication remain external. |
| rollback properties | Restoring a retained trusted checkpoint preserves structural invariants and rechecks confirmations against the supplied restored snapshot. Generation/origins, registry history/used keys, FI tail/queue remain. A checkpoint below its generation origin rejects every landing until recovery. | Choosing/authenticating the correct rollback target/snapshot is trusted governance work. No claim to restore irreversible stake/bridge payouts. |

The six `HS-*` entries in the inventory are narrow conditional proof claims. They do not claim full coverage of their linked source clauses.

## Regression evidence and known boundary

`SecondBatch` includes a successful typed historical landing and an eight-step trace: landing → recovery → exceptional rollback → recovery → FI enqueue → sweep → registration → exit request. The trace demonstrates non-vacuity of `Core` preservation, generation 0→1→2, retained origin history, strict-past snapshot preservation and fee conservation. Other cases cover lifetime key reuse rejection, free-slot reuse, same-block replacement, stale evidence, missing context data, empty initial election, pre-initialization/foreign-domain evidence, rollback confirmation invalidation and blocked landings below the origin.

`rollback_revives_pair_without_dao_cancellation` confirms an **existing specified boundary**: a landing invalidates an old `(expectedGeneration, expectedC)` pair, but exceptional rollback can restore that pair without incrementing generation. If the DAO has not canceled the outstanding authorization, raw `recover` can accept it again. Frozen §8 **Verifier failure** explicitly requires cancellation; the model deliberately does not pretend Inbox maintains a DAO queue. This is not a new specification defect. DAO authorization/cancellation integration remains unproved.

No new specification defect has been established in this batch. Upgrade activation remains design-pending rather than being asserted safe.

## Remaining gaps, in order

1. Node startup/restart/trust fencing and public reconstruction, including actual parent links, authenticated origin uniqueness and complete material availability.
2. Governance authorization/cancellation and trusted rollback-target/snapshot provenance; full registry evidence/token accounting and exact FI-content invariants beyond the current structural projection.
3. Full Comet locking/cross-round safety, durable signer/storage behavior and conditional progress under explicit network/availability assumptions.
4. Raw L1/MPT/header, crypto/signature/KZG/payload and complete EL/zk-gas refinement; real guest soundness/completeness and production conformance.
5. Deployment/upgrade activation decisions and measured resource/latency acceptance. The six design-pending clauses remain open.

## Validation and review

Pinned Lean 4.35.0-rc4: `lake build` has zero warnings; audit checks 411 full theorem types and transitive axioms; 37 Python tests pass, including 41 new finite kernel regressions and coverage mutation checks. Allowed axioms remain only `propext`, `Classical.choice` and `Quot.sound`. No `sorry`, custom/native-evaluation axiom, dependency or CI was added. The same commands as README reproduce the local checks. Hosted `gitleaks` and `check-links` passed on the pushed proof/mapping commit `4cef7bc`; other reported jobs were skipped.

A fresh independent whole-change review verified all five focus cases, all baseline contracts and the local suite/audit. It found one Important inventory-calibration defect and two related Minor evidence-description defects. The latter were regraded Important: treating a finite vector as general proof or claiming a conclusion absent from a theorem can mislead a user of the evidence inventory just as an unrelated source link can.

One fix pass replaces older family-level mappings with reviewed per-property source IDs/scopes, classifies ten concrete Budget/Keys vectors as regressions, and limits RegistryHistory step/trace descriptions to their actual `KeysValid`, `IdentitiesValid`, `Ordered` conclusions. `EN-0132`/`ZH-0134` node-local history comparison and `EN-0480`/`ZH-0473` DAO preauthorization obligations are deferred. Four regressions failed before these corrections and pass afterward: deferred unsupported node/DAO checks, concrete-vector roles, exact registry scope, and rejection of a partial clause supported solely by a finite vector. The complete suite is 37/37; theorem contracts/definitions did not need changes. No deferred minor remains.

## Execution decisions

- Retain the previously frozen 04:07Z bilingual sources, so conclusions are reproducible. Cost if wrong: a later specification revision needs an explicit source refresh.
- Reuse the existing isolated PR clone and keep plan/materials under `formal/etna`. Cost if wrong: the temporary checkout is not managed by the desktop app; the user's checkout remains untouched.
- Treat snapshots, key identities and votes as typed authenticated objects, rather than implementing MPT/secp/EL. Cost if wrong: no production cryptographic conformance follows.

## Review scope decisions

The following considered behaviors remain explicit boundaries, with no stronger safety claim:

- Production/EVM execution conformance: excluded by the requested formal-only scope; cost if wrong is an unverified implementation/refinement gap.
- Raw crypto/L1/MPT/KZG/payload/EL correctness: typed relations are external; cost if wrong is unsound real-world instantiation despite sound structural proofs.
- Full Comet locking/network liveness/durable signer/node trust: absent from structural Core; cost if wrong is an unproved consensus/progress/operational property.
- Trusted rollback targets/snapshots, DAO cancellation and irreversible payouts: remain governance/economic boundaries; cost if wrong is unsafe real-world rollback/authorization despite the narrower structural result.
- Origin uniqueness and exact FI contents: excluded from Core; cost if wrong is a stronger origin/queue claim unsupported by these theorems.
- Raw landing on a false verifier result: intentionally representable for rollback analysis; cost if misread as authentic settlement is a false safety claim. The stronger accepted-history theorem separately requires a valid batch and binding.
- Authorization revival after rollback: already anticipated by §8 **Verifier failure** and retained as a finite counterexample without DAO cancellation; cost if cancellation is omitted is execution of a previously invalidated authorization.
