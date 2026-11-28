# Etna second five increments: model and code correspondence

The user authorizes five more independently reviewable verification increments,
with Lean/TLA work and real-code replay progressing in parallel. Stop on a
credible independently reproduced protocol or production-implementation issue
and return to the user for confirmation. Model, oracle or adapter defects are
fixed and rechecked separately; they are not protocol findings.

## Baselines and authority

- Existing TLA project/branch starts at local `7acc2507a`; preserve its175 default
  configurations, tools and all historical incomplete experiments.
- SPEC authority: `d18357214fab30ea512ae9858a11699806d72ba1`, Git blob
  `649548c58d6629dd85143b33efd3644a3bb71509`. Refreshed main
  `5ef06b61e8deea716c1002fd53015babfb674f9a` has the same SPEC content.
- Lean source PR22292: `cdbc346b8cee1ee3b332063832c60b88f649eb7b`, SDK4.35.0,
  no external Lake dependencies. Its authorities are pinned to the same SPEC.
- Contract PR22286: `89f419915de4b73bb57c53bf970f6dea9e8e8c8c`, Solc0.8.30,
  Foundry1.4.2. Pin exact dependencies, never substitute a different Solady.
- The existing Lean/current-registry8 case bodies agree with the contract copies;
  authority metadata differs. Any equivalence adapter may ignore exactly the
  declared `authorityCommit` field, only after validating both exact pins and
  proving every other JSON field equal. Do not edit expected decisions by hand.

## Approach and boundaries

Reuse the existing formal project and contract conformance infrastructure. Keep
an explicit source manifest and caller-configured temporary source/build paths;
no machine-specific path enters portable artifacts. Stage pinned sources without
original Git metadata and inspect executable entrypoints before running them.
Use network-disabled, clean-environment execution with private writable outputs;
hide secret-bearing home paths during repository-code execution where supported.

Two model increments add M08 ordinary recovery and M09 verifier rollback. Three
code-facing increments reproduce the current Lean/registry baseline, replay the
TLA settlement/auth projection against real Inbox code, and replay M08 list/failure
cases against actual Inbox/registry/FI state. A mocked proof verifier is an explicit
boundary: bind its expected statement to the original prepared statement, rather
than blindly accepting any public inputs. This checks contract input binding,
not zkVM cryptography or actual STF/QC validity.

The contract grid is6; settlement abstract grid-point q maps to6q consistently
for heights, origins and authorizations. FI per-block claims are not scaled by
this mapping. First settlement traces keep FI/exclusions empty and rules0.
Compare every observable public step: acceptance/revert, checkpoint/generation/
nonce/origin, retained records and changed side effects. Internal staged model
transaction steps collapse to one public atomic contract call, not fictitious
intermediate onchain states.

Continue with a single Lean SDK and a single contract compiler/cache/output set.
Reuse existing Java/TLC and the cached exact Solc. Official temporary Lean SDK
setup is permitted as a prerequisite, with asset digest verification, archive-size
inspection and a reserved build/disk budget; no global package/environment changes.
No Rust build, duplicate target tree, dependency substitution, live deployment,
push, merge or unrelated production fix. Proof results distinguish ordinary Lean
elaboration/build from a separate independent-kernel replay, and CI from local runs.

## Five deliverables and dependencies

1. **C01 Lean/current Registry baseline**: local Lean model/proof build and exact
   vector regeneration; real existing Registry8 replay with version/metadata
   identity checked. Setup alone is not a completed increment.
2. **M08-A recovery transaction**: supplied list ordering/key/id/index checks,
   execution-time state, tentative changes, complete failure rollback and source
   valid successful exclusion/blanking; independent actual pre/post observers.
3. **C02 settlement/auth replay**: TLA-derived bounded attempts and accepted/rejected
   outcomes, read from actual model execution, replayed against real contracts.
   Reject changed model/source pins, missing cases and deliberately wrong outputs.
4. **M09-A verifier rollback**: preserve generation, increment current nonce,
   revalidate confirmations by restored snapshot, revoke empty-proof AND RETRIABLE
   authority, preserve paid-fee/value history, reproof and stranded-origin fence.
5. **C03 recovery replay**: consume M08 public attempt observations and compare real
   contract before/after state, including invalid later list elements and valid
   unheld-id/blank cases. Distinguish real dependency behavior from fault injection.

C01 and M08-A can start together; C02 and M09-A can follow on separate owned files;
C03 consumes the frozen M08 projection. Each ends in independent adversarial review
and behavioral verification. High-signal source counterexamples stop both lines.
At most two coherent review/fix iterations per increment; unresolved material
findings cannot be presented as ready.

M09 corrective upgrade is not necessarily a fixed deployed/API implementation.
If no matching code exists, record a real-code GAP. Do not invent a mock upgrade
and call it conformance. Known verifier-failure limitations do not become newly
found bugs; changed normal invariants must be explicitly qualified.

## Evidence and stop rule

Keep model PASS, Lean build/kernel evidence, vector generation, adapter validation,
real-contract execution, source gaps and incomplete exploration separate. Preserve
counterexample logs and actual pins. Skipped/unavailable runs never count as PASS.
Negative controls must fail the named property, not parse/runtime/build errors.
Final validation preserves the175 regressions, runs added TLC cases, checks runner
and adapter tests and the smallest relevant real/Lean suites. A broader repeated
build is justified only by source changes, failures or unresolved concerns.

A code/spec mismatch is stop-worthy only after independent source/trace checks
exclude adapter mapping, stale metadata, intended unsupported API and mocked
verifier artifacts. Do not fix production behavior before user confirmation.
After five checked deliverables stop for joint retrospective, even if no protocol
or implementation defect is found. Track progress on issue22355 and focused child
issues; code remains local unless publication is separately requested.
