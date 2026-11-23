# Current protocol verification coverage

Assessment2026-11-23, current design unmerged PR22425 at178d7a7a, main360262975.
The existing draft verification branch's stage baseline is03cdafc9. This is a source-
qualified roadmap, not a proof that every protocol obligation is implemented.

## Progress judgement and completion meaning

For latest-source protocol specification plus TLA/property/composition validation,
the root's current working estimate is approximately30percent, with a25–35percent
judgement range. It is not measured coverage or a ratio of test/model counts.
An initial50percent estimate overcredited reusable historical work and was
corrected after independent source mapping identified the missing central
L2-staking/committee/recovery TLA composition.

This scope accepts explicit sound-proof, authenticated-finality, signature and
execution contracts rather than re-proving their cryptography. What still needs
verification is the protocol's use of those contracts: domain, identity, timing,
authority, failure behavior and interactions. Real implementation/proving,
release/deployment, resource and operational acceptance are a separate dimension.
The14 runtime WAITING rows and19 archived INCONCLUSIVE searches are not an
additive percentage denominator.

A completed selected finite graph is evidence at its declared bounds, source
version and premises. Whole-protocol completion requires current-source mappings,
non-vacuous properties and positive histories, composition contracts across
critical boundaries, meaningful semantic controls, explicit fairness/bounds and
independent review. Unbounded proofs cannot be inferred from finite TLC results.
No row below is closed merely because another helper or configuration passes.

| Protocol surface | Existing evidence | Latest-source remaining boundary |
| --- | --- | --- |
| Settlement/frontiers and overlapping proofs | Historical finite histories and binding/atomicity controls; selected source360 correspondence | Compose latest per-height committee/proof-origin and full proof-covered ranges with those frontiers. |
| Per-node trust and finalized targets | Historical trust/import/signer products, source360 version-specific contracts | Full latest-generation trust revocation, signer-session and import composition; implementation remains separate. |
| Signer crash/restart and durable admission | Selected actual stock persistence/transport/handshake components | End-to-end scheduling/recovery/supervisor/WAL contract and its assumptions. |
| Committee selection/activation and staking | Historical L1-epoch TLA; source69 Python boundaries and source178 power/domain traces | Selected latest-source committee/recovery histories and an operational-view cover are reviewed; Free height14 remains OPEN after12 class timeouts. General lifecycle/rounding/weights remain separate. |
| Forced inclusion and execution admission | Historical queue/cursor/legal-skip products and explicit execution contracts | Compose latest committee/authority, queue service, proof range and backpressure across failure/recovery. |
| Proving/DA/backpressure | Selected bounded products and source-level progress contracts | Larger asynchronous products and fairness/resource premises; original wider searches remain OPEN/INCONCLUSIVE. |
| Governance recovery and rollback | Historical atomic authorization/checkpoint products | Selected latest-source rollback/origin/reset histories exist; unrestricted reachability, lagged anchors and cross-frontier composition remain open. |
| Rule upgrades and special fork | Historical scheduling/pause/fork/rollback products and source360 correspondence | Current-source composition with changed EL selection, staking and recovery; actual rehearsal separate. |
| Serialization and shared consumer binding | Public stock/contract components; latest29 raw vote wires and actual library observations | Current end-to-end EL/guest/client correspondence and remaining full encoding/authentication inputs. |
| Public history, resource and operating assumptions | Named source contracts and dependency ledger | Formal progress statements must state these premises; real archive restore and measured budgets remain external acceptance. |

## Historical evidence stays historical

At the earlier5abc1748c checkpoint,52 TLA files and603 configurations were
retained, with493 in the default bank. At this stage baseline03cdafc9 there
are53 TLA files and614 configurations, with503 in the default bank. These counts span historical revisions. The existing
EtnaCommittee models L1 Registry/epochs/activeCommitteeSnapshot, not the source178
L2 staking interface. Existing runtime classifiers, source bundles and claims do
not automatically admit new draft data. See [WORKLIST](WORKLIST.md),
[SOURCE_CORRESPONDENCE](SOURCE_CORRESPONDENCE.md),
[L2 source review](L2_STAKING_REVIEW.md) and
[quorum limits](L2_QUORUM_REVIEW.md).

## Current next evidence

The selected [committee/recovery TLA stage](L2_COMMITTEE_RECOVERY.md) uses an exact
four-bond full-deduction monetary instance and certificate-level contracts.
Its compact free graph and longer externally constrained witnesses have separate
bounds. It does not close arbitrary monetary rounding,128-member scaling,
Comet rounds/locks, guest proof construction or unrestricted protocol liveness.
Progress will be reassessed from closed interactions and remaining risks, not
increased automatically for added cases or elapsed work.

Current selected-kernel review explicitly retains three additional open
interfaces: actual no-code/code restoration at the fixed staking proxy,
anchor-adoption lag, and fair-conditional temporal progress. Finite scheduled
witnesses are existence evidence and are not liveness proofs.

The current selected model reaches ten conditional histories, including a
review-discovered budget-exhausted stale-refusal gap repaired with actual
RED/GREEN. Free height14 is still OPEN after three pre-fix and one corrected
timeout. Default503 = old493 + ten witnesses excludes that Free config. This
partial result does not increase the30percent judgement automatically.

## Free operational-view follow-up

The [current report](L2_FREE_VIEW_REVIEW.md) preserves the original kernel while
adding a reviewed projection and exact12-class input cover. All12 classes have
actual nonempty histories, and11 projection paths plus six exact faults with
restored baselines were independently read. The stronger monolithic run and all
12 class safety searches timed out; Free height14 remains OPEN. Default516 adds
only13 named witnesses to old503, with all new safety cases off-bank. The30percent
judgement,14 runtime WAITING and19 historical INCONCLUSIVE rows are unchanged.
