# Etna implementation-correspondence evidence

## C01 — current Lean and real Registry8 baseline

Measured locally on2026-11-15. Exact pins and source manifests are adjacent.
SPEC `d18357214fab30ea512ae9858a11699806d72ba1`; current main
`5ef06b61e8deea716c1002fd53015babfb674f9a` had the same SPEC blob.
Lean source `cdbc346b8cee1ee3b332063832c60b88f649eb7b`; contract source
`89f419915de4b73bb57c53bf970f6dea9e8e8c8c`. No production source was changed.

| Execution                                                    | Observed result                                | Boundary                                                                                                               |
| ------------------------------------------------------------ | ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Lean4.35.0 `lake --no-cache build`, empty shared Lake output | PASS,332.919s                                  | Five default model/statement/proof/witness/vector libraries; not the separate full independent-kernel replay           |
| Same build with source-before/after recorder                 | PASS,0.290s incremental                        | Same artifacts/cache; the original cold execution remains distinct                                                     |
| Actual `etna-vectors --write`, two fresh directories         | PASS,3.646s combined; both exact golden SHA256 | Registry8 only; not historical CLI/vector families                                                                     |
| Original Solidity Registry8 consumer                         | PASS; one selected method, eight cases         | Foundry1.4.2, Solc0.8.30/Osaka; original fixture and real Registry implementation                                      |
| Final recorded Registry8 execution                           | PASS,20.084s                                   | Exact564-file source verified before/after; config overlay changes only `ffi=true` to `false`; real test JSON consumed |

The generated vector SHA256 is
`529a76149e13424c05d12e4d8c6483fe19a02be2519c3af83f11eaace4c5a969`.
The unchanged contract fixture has SHA256
`df9c4e93f136c6f3b06a42dced5fd676da9fae7e9406d30685fd0d412c2ea704`.
All content except the explicitly pinned `authorityCommit` is identical;
canonical semantic SHA256:
`92520cb18396bee5ce6f95cb820cc49d63b05bbc958b5075ae7fb33b9b0833df`.
The original consumer's authority assertion validates this metadata, not contract
arguments. This is a disclosed transitive vector bridge, not exact raw identity.

The actual consumer loops over exactly eight cases and rejects a ninth. Each
case initializes4096 real registrations with valid keys/PoPs:32768 total. It
checks admission and observed state/log/payment effects. The committee snapshot
is mocked. The Lean table starts seeded; this run does not establish that every
seeded table is reachable by arbitrary real histories.

### Adapter calibration and execution integrity

Source/vector regression tests reject changed bytes, authority and non-authority
mismatches, duplicate/missing cases, skipped/failed phases, absent/failed selected
Forge tests, substituted stream/artifact hashes and missing source attestations.
A timeout test initially demonstrated an orphaned command child; the recorder
now kills the process group. Isolation tests validate explicit mounts/env and
child timeout behavior. The independent execution probe observed read-only
source, private PID/proc/network namespaces, no home/inherited sentinel,
zero capabilities/no-new-privileges, writable explicit output and child cleanup.

Initial configuration rebasing and a signature-incompatible test filter produced
zero tests with Forge exit0. That run is not a PASS. Source snapshot inspection
and discovery corrected the invocation, followed by the actual selected method.
These are adapter/setup defects, not protocol findings. Source/artifact digest
binding was added after independent review identified that unrelated prior JSON
could otherwise be collected; final collection reads the recorded stdout itself.
Reports remain trusted local evidence, not signed or hostile-author attestations.

Raw command logs and temporary build outputs remain outside Git. Retained report
stream digests: cold Lean stdout
`546241706e2aad423d5d647696e1b791068a62948b705e05d8067d354e271888`;
final contract stdout
`4080c61803f6416d9f8c28fc9e8a58712782eae2fc9865b5b70fc494301ebc98`.
Full commands were executed with bounded timeouts, clean allowlisted environment,
network disabled, read-only selected sources and a single shared build/cache.

Independent final source/artifact/argv review passed. One independently
reproduced helper defect allowed a single generated file listed twice to count
as two outputs; recorder and collector now require distinct resolved paths.
The new alias regression failed first, then passed with the fix; the original
reviewer reproduced rejection at both entry points. Actual evidence used two
distinct fresh directories throughout, so no Lean/Forge rerun was required.
Sixteen baseline tests and five launcher tests pass. The dedicated tester ran
the actual real-contract fixture; root separately built/regenerated Lean, verified
all source/artifact hashes and inspected the actual contract result. No actual
protocol/implementation bug was established. The next two replay increments are
reported when their separate gates complete.

## C02 — actual settlement/authorization replay

The actual unchanged TLA settlement actions produced8 scripts and45 receipts
(including8 initial observations),94 generated/90 distinct states, final queue0.
Source and output fixture hashes are embedded in the versioned JSON. Actual
`--check` regeneration was independently repeated and was identical.

| Scenario                               | Public behavior checked                                                                                       |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Compatible overlap                     | Originally prepared range lands after another checkpoint; retained record parent is actual current checkpoint |
| Stale checkpoint / nonce               | Captured original authorization is rejected after another landing or explicit invalidation                    |
| Inclusive deadline and replay          | Exact-expiry execution succeeds; reuse is rejected                                                            |
| Expired then fresh                     | Expired original fails; fresh authorization succeeds                                                          |
| Old proof at genesis / retained origin | Original full statement fails against new recovery domain; exact `ProofRejected`, not another guard           |
| Same-checkpoint recoveries             | Generation/nonce advance and each immutable origin remains correct                                            |

Pinned real Inbox test `test_conformance_settlementReplay()` passed, with all8
case identities and45 observations executed. It checks every bounded retained
landing record and all three generation origins, exact checkpoint/generation/
nonce, empty queue, recovery snapshot preservation, and full selected public
before/after digest for failed/offchain calls. The final Solidity adapter SHA256
is `d4bcc73ccf61d93bbc73f3a745e76b48787a5cecced885911ba95e974f56818e`;
executed fixture SHA256
`eb15a28d24550ed8eb761e14996b9a872d4ff572c9a331220805638e2d214954`.
The commit hook formats the published JSON; its raw SHA256 is
`07d6b3f792b389e68ed0b5d6580a15e488e2ffd1f243073c0b52228cb513d982`.
Independent parsed comparison confirms every field and the canonical content
digest are identical to the executed fixture; only whitespace changes.
The original564-file contract snapshot remains unchanged; the adapter/fixture
are additional test overlays, compiled in the same isolated shared output/cache.

Seven exporter tests passed, including altered/rehashed observations, missing
steps and source drift during TLC execution. Actual temporary Forge mutations
failed as required: wrong retained parent, missing final receipt and wildcard
proof binding. A root-selected fourth mutation changed only one expected
recovery-origin observation: actual real-call replay failed with
`retained origin L1 block: 12 != 13`. Exact frozen fixture/source hashes were
restored; the unchanged final normal execution passed. These demonstrate
sensitivity of selected comparisons, not complete oracle or protocol coverage.

Adapter repairs included literal per-case length enforcement and snapshotting
actual copied TLC source bytes before execution with drift rejection before
stamping provenance. They are test-infrastructure findings, not production bugs.
Independent full-source/fixture/argv review passed after the drift repair;
root independently regenerated the receipts and checked the fourth real mutation. Strict proof verification
is still mocked, the histories are scripted/same-chain and FI/exclusions/rules
are held fixed. This is finite real-code trace correspondence, not unbounded
refinement, proof-guest validation or live deployment evidence.

## C03 — actual recovery-list and failure replay

Actual M08 actions produced18 complete PublicAttempt receipts: nine curated raw
request kinds, each with None/SecondRegistry failure class. A real model Tick
puts execution at block101/timestamp1001, including positive exact deadline
equality. TLC exhausts164 generated/158 distinct states with queue0/depth19.
Source/config/wrapper/jar provenance is bound to copied inputs and checked for
drift. No Python acceptance rules substitute for M08 execution.

The real new-network Held adapter replays all18 receipts. Selected comparisons
include all three retained landings, two origins, checkpoint/generation/nonce/
start, issued/slot/key/owner/effective/pending/ready/exit/confirmation fields,
lifetime flags, principal custody, three FI records/head/tail/admission fees,
active snapshot and rule/stop schedule. Failed calls compare the selected raw
before/after projection including opaque commitments and checkpoint history;
successful calls check mapped exact writes and unchanged raw metadata/balances.

The separate unconfirmed/unheld method uses4096 real paid public registrations
and a paid replacement. Exclusion of the funded issued/unheld bond preserves its
already earlier exit, replacement slot/bond/root and custody. This is a declared
concrete variant, not full confirmed95 Displaced-profile equivalence.

SecondRegistry uses a reverting mock of the exact second forceExit calldata.
The corresponding case observes a real registry write before the second call
fails, then requires full selected abort equality. This is concrete EVM rollback
under a labeled injected dependency, not a production fault reachability claim.
The late-unissued/default case additionally requires exact UnknownBond rejection.

The independent review found two related adapter omissions: DefaultKey used zero
instead of the actual hash of zero key fields, and readable unissued top-up/
confirmation defaults were not included in its complete-projection assertion.
They were repaired in one coherent wave. An exact UnknownBond check had prevented
the old key mismatch from hiding an unexpected successful unissued exclusion;
nonetheless the repaired calldata now faithfully matches the model's default key.

Final real Forge execution passed both methods, all18 model case identities and
the concrete unheld scenario. A selected Recovered-event assertion additionally
checks indexed generation, Inbox emitter and all checkpoint/context/original-list
data for model-accepted calls. A wrong expected indexed generation is rejected by
the actual event matcher. No all-events or gas-cost conformance is claimed.

Seven exporter tests passed; root independently regenerated all18 exact receipts,
verified every original564-file source entry, both actual real test identities,
all18 case ids and restored final input hashes. Temporary mutations failed for
wrong after-exit, repairing an originally invalid key, wrong dependency target,
and a root-selected change to only the after-state FI timestamp. The latter
failed actual timestamp1198800 versus expected1200000, then the exact fixture
was restored. Independent source/adapter/artifact review passed after
the narrow default-id repair. These are sensitivity tests of selected observers,
not a completeness proof. Raw model
and production sources are unchanged; only new test overlays are compiled.

Principal scales by MIN_STAKE, fees by1gwei and every Unix timestamp by1200;
L1 blocks remain unchanged. This materializes valid public setup/schedule calls,
not physical-time, BFT or cryptographic correctness. Literal confirmed95, Withdrawn
and callback-class correspondence remain GAPs. The wider M09 corrective-upgrade
API is also separate; none is invented by this replay suite.

## C06 — landing frontier and statement responsibilities

The unchanged identity model exports20 scenarios/88 intermediate observations:
EL/Comet/FI/Val × compatible overlap, conflicting frontier, substituted public
origin, recovery-origin reuse/old proof and shared-frontier divergent suffix.
`export_identity.py` retains actual action enabledness and selected raw records;
no Python acceptance implementation supplies the expectations. The actual replay
executes44 land calls (32 accepted,12 rejected) and4 recoveries, comparing full
selected retained records, origins, counters, checkpoint, FI and failed-call equality.

Two final isolated Forge tests pass, including concrete leaf-count/range/off-grid/
missing-origin guards. Twelve exporter tests and fresh actual export comparison
pass. Original564 source entries remain unchanged. Independent full-source and
behavior review passed. Only locked runs after adapter fixes count; preliminary
shared-cache overlap results were discarded. Fixture JSON/setup/assertion work
is outside gas accounting, actual calls are metered, and figures are not a gas
benchmark.

Frontier negatives configure the proof mock to accept the candidate statement.
A root-selected temporary single-source overlay removes only the frontier require;
the replay then observes unexpected acceptance and fails exactly its frontier
assertion. Restoring original source passes both tests. FI mismatch remains within
actual tail bounds, so a later queue guard cannot conceal a missing frontier check.
Separate strict-original-statement mocks test substituted-origin and old-generation
binding. Retained public originVal is compared separately from exported fresh
execution genesis; real guest/STF/cryptography is not executed. These are selected
contract/integration observations, not proof-system or whole-protocol refinement.
