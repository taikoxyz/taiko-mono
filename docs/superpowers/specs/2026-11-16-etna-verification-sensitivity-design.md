# Etna verification sensitivity and handoff design

The user accepted the adversarial review and authorized implementation. Keep the
existing five-increment cadence: V01–V05, then stop for retrospective. Stop both
lanes on an independently supported actual protocol/spec/production defect;
repair verification/model/adapter defects separately. No sixth increment.

## Goal and evidence

At baseline aed1b861e9dfa9b03f2700837bb8e437be55082c, three deliberately
incorrect implementations survive the selected verification lane: removing M10
peer.el binding leaves40 outcomes unchanged, removing SignalService publication
leaves11 C02–C06 replay tests green, disabling Connect leaves40 outcomes green.
One existing production unit test does detect missing SignalService publication;
this is a verification-lane omission, not a demonstrated production defect.

Deliver observable sensitivity: correctly executed bad changes must be caught
by the intended invariant/assertion/property. Syntax errors, missing tests,
timeouts, drift and unrelated reverts never count as killed mutations. Report
surviving, unassessed and inconclusive obligations explicitly. Test counts do not
measure completeness.

## Authority and limits

SPEC d18357214fab30ea512ae9858a11699806d72ba1, blob649548c58d6629dd85143b33efd3644a3bb71509,
SHA2564d81d5dadcee3eb94ff554ec5a8144a47888dd5a8263ac5852422a0f1d1dd71b.
Actual contracts89f419915de4b73bb57c53bf970f6dea9e8e8c8c, existing564-entry
inventory. Keep all pins. No production-package edits, new SDK/dependencies,
new Rust target/cache, publication, push, merge, deployment or live actions.
Reuse current linked worktree and existing Foundry out/cache. Root owns shared
reports/plan/worklist/commits. Every Forge sequence holds the existing common
cache lock for its entire baseline/mutation/restoration lifetime. Original source
is read-only; mutations are temporary overlays. Inspect launchers before use,
run clean environment with network disabled and no original Git/home/secrets.
Use the configured Python environment, Java17/TLC1.7.4 and Foundry1.4.2/Solc0.8.30.

Preserve existing286 configuration files and19 incomplete archives. Existing
normal/action behavior remains unchanged where adding interfaces is sufficient.
Source hashes may change for reviewed verification repairs; do not hide that as
unchanged provenance. No full protocol/guest/client/refinement claim.

## Approach chosen

The chosen approach repairs the confirmed holes, then adds one narrow interface
interleaving. Repeating the old green suite would not discriminate the faults.
Unrestricted products of all modules are deferred: they are expensive and can
hide an incorrect composition in an oversized model. These are root choices
under the user's delegation; the cost is finite coverage with explicit boundaries.

## V01: repeatable fault campaign

Create formal/etna/coverage/run.py, mutations.json, tests/test_run.py and README.md.
The manifest is a reviewed inventory, not an automatic claim to enumerate all
possible bugs. Each obligation identifies its source/normal workload, exact unique
source replacement and required semantic failure. Unassessed obligations need a
reason. Initially reproduce the three known survivors; this diagnostic campaign
must report SURVIVED, not success. Later tasks update entries after source review.

Runner interfaces: load_manifest(path), classify_tlc(...), classify_forge(...),
run_campaign(manifest, runtime, selected_ids, output_dir). CLI accepts --manifest,
--runtime, --only(repeatable), --output-dir. Runtime tool/source/lock paths live
outside Git, not in portable manifests. No shell command strings. Reuse inspected
run_isolated.py and source verifier for Forge; derive temporary read-only overlays
and current committed test/vector copies. One selected mutation per trial; never
edit originals. Capture baseline/mutated/restored raw output, argv, identities,
hashes and selected test IDs. Baseline and restoration must actually pass.

Statuses: KILLED only for intended named invariant, sole configured temporal
property, or declared exact Forge failure with required test IDs; SURVIVED only
for completed positive execution; INCONCLUSIVE for tool/runtime/timeout/input
drift/wrong failure/empty selection; UNASSESSED for deliberately unrun inventory.
Default readiness requires all selected required entries KILLED and valid normal
restoration. Preserve old survivor evidence. Tests challenge classification,
unique replacements, unsafe paths, wrong test/failure, empty outputs, drift,
timeout cleanup and restoration failure. Do not automatically call a survivor
equivalent; any redundancy argument requires explicit source evidence/review.

## V02: input obligations

Expand M10 raw inputs with discriminatory wrong EL hash and other selected
binding inputs; preserve original0..15 cases. Some checks need coherent bundles
(e.g. bad downloaded state plus matching bad computed state) to avoid masking
by another check. Add focused normal configs rather than silently broadening
old workloads. Inspect SPEC before assigning reject/wait/halt to authenticated
contradictions. Document assumptions and unexercised/redundant conditions.

An input-to-guard matrix covers Authentic's bindings, Missing and contradiction
classification. For each required nonredundant selected guard, delete only that
guard in temporary source: the existing independent observer must catch the
fault at Check, not only an unrelated later assertion. Retain legal alternate
priorities/proposers and origin exceptions. No second Python acceptance oracle.

## V03: successful cross-contract effects

Add one shared Solidity assertion helper under conformance/solidity and call it
explicitly after every successful actual land in C02–C06, including setup lands.
Compare expected terminal height/EL/stateRoot to SignalService and expected
activeCommitteeSnapshot to actual Inbox storage. Expected values come from the
original mapped call/model, never from post-call getters. Keep existing raw
abort equality and model observations. Cover missing publication, wrong saved
stateRoot, omitted snapshot and other selected settle writes with isolated source
faults. Original production source is unchanged.

Add a dedicated public registry-history probe without modifying frozen JSON:
existing default registration1 is eligible11; public topUp11, activateTopUp21,
then land22 with snapshot21 and terminal12. Keep timestamp/reference/queue bounds
valid. Actual committee derivation/anchor witnesses/proof validity stay explicit
mock premises. The probe must observe snapshot changing; same-value writes do
not establish sensitivity. Initial genesis committee soundness is not claimed.

## V04: progress, separately from safety

Add independent connection enabledness/reachability and a conditional temporal
profile to M10. Existing ImportSpec remains the old safety workload. New nested
progress configs are run through the sensitivity tool; they are not silently
accepted by the old invariant-only classifier. Under fixed correct available
input/current target, no generation change, bounded optional process crash and
fair internal checks/stores/restart/admission/connection, require eventual stable
connection. State the exact environmental/fairness premise, including trusted
normal continuation. No unconditional availability/throughput claim.

Both fully disabled Connect and a Connect action that leaves connected=false
must be caught. Weak fairness on a disabled action is vacuous; independently
require the progress property/positive reachability. Do not make fairness assume
the desired connected result or require scheduling an impossible action.

## V05: held candidate across actual public actions

Add a thin companion module extending EtnaRulesSchedule's unchanged L1 action
engine. Existing Promote supplies unsupported-rule→schedule→support/retry.
Add one raw program HandoffRecovery to its Programs table and NeedsLanding:
seeded c12; scheduleRules(1,2) at1; recover(g0,c12,nonce0,validUntil6,rules2) at3.
Capture candidate t2/parentTime1/parentHeight12 using time1 anchor between calls.
It historically selects unsupported rule1, allowing support and recovery knowledge
to interleave meaningfully. Existing raw programs/actions/schema are unchanged.
This fixture-only source edit changes the producer hash: regenerate C05's original
38-call/23-program export, prove cases/mapping/schema identical, accept only exact
provenance/content digest changes, format before final hashes and verify actual
final replay. Do not claim an unchanged producer digest. Hold one candidate at an
intermediate Ready point, invoke actual remaining public actions, and retry.
Use captured generation, original anchor/history and candidate/parent timestamp.
Do not reuse current-generation ValidCandidate to declare historical data invalid.

Observe three separate boundaries: original historical rule/stop/freshness,
live signing after monotone authenticated recovery knowledge, and current-
generation L1 proof enabledness. Knowledge is a separate action, not instant
omniscience at recover. Signatures exposed before knowledge remain historical;
check knowledge at exposure. No complete HRS/CometBFT engine is copied. If L1
proof behavior is observed, use inherited PrepareProof/Land enabledness rather
than inventing real proof generation from a single candidate; label it explicitly.
Preserve M11 public receipts/history audit and avoid post-recovery relabeling.

Required witnesses include hold before another public call; retry after it;
unsupported rule then support; recovery knowledge before/after support; and old
signing/proof refusal after the respective fence. Controls use latest schedule,
mutable held metadata, stale cached authorization and old proof generation.
No full module product, actual client/guest or liveness theorem is claimed.

## Gates and ownership

Each task carries coherent implementation, actual targeted checks and independent
adversarial review. High-risk semantics additionally receive independently chosen
behavior challenges. Maximum two coherent review/fix waves; original raiser
rechecks. Root owns the single mutations.json integration after V01; later authors
return proposed fragments instead of racing that file. Root serializes campaigns
against source freezes and all Forge operations with the physical shared lock.

Finish one accumulated stable-input TLC regression, temporal/campaign checks,
Python integration checks and selected real source faults, then final independent
review. Format JSON before final hashes/tests; verify committed bytes after hooks.
Update/read back the existing GitHub worklist and preserve local branch/worktree.
Stop after five and report which obligations are still unassessed.
