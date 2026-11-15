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
