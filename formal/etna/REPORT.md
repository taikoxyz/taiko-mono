# Etna TLA+/TLC validation reports

The first section records the original height/generation model. The
[2026-11-14 extension](#2026-11-14-checkpoint-identity-extension) below records
the composed checkpoint-identity model.

The [completed F01-F05 gate and retrospective](#five-increment-batch-final-gate-and-retrospective)
records that batch's369-config/65-obligation gate and its independent audits.
The [coverage-closure CI increment](#coverage-closure-batch--g01-exact-outcome-ci)
records subsequent current-byte CI validation; the new five-item batch remains
in progress under the [remaining-work index](WORKLIST.md).
Earlier sections preserve historical inputs and explicitly corrected claims;
their intermediate counts and positive tuples are not the current result.

Date: 2026-11-13. Source specification:
`d18357214fab30ea512ae9858a11699806d72ba1`.

## Result and scope

The 12 checked configurations produced their expected outcomes: two completed
baseline explorations, four deliberately broken guard configurations and six
reachability witnesses. No safety-invariant violation was found with all normative
guards enabled in these finite configurations.

This is evidence about the abstract model, not an unbounded proof, contract-code
verification, CometBFT verification, or a deployment-readiness claim. No actual
Etna defect is reported by the deliberately broken configurations. See
[README.md](README.md) for assumptions and source-to-model correspondence.

## Reproduction

Use Python 3 (standard library only), Java 17+ and the official TLA+ tools
release 1.7.4. Its CLI banner is `TLC2 Version 2.19 of 08 August 2024`.
The recorded Java runtime is Temurin 17.0.21+9. Tool downloads are not included
in the repository and are not performed by the runner.

Official `tla2tools.jar` SHA-256:
`936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88`.

Checked `EtnaSettlement.tla` SHA-256:
`3fd57284128ea5a19966c2684161f909155a4730310972fee87d50eed009b84a`.

```sh
python3 -m unittest discover -s formal/etna/tests -v
python3 formal/etna/check.py \
  --java java \
  --tlc-jar "$TLA2TOOLS_JAR" \
  --output-dir "$TLC_OUTPUT_DIR"
```

The suite uses one worker, seed 1, a 512 MiB heap and a 45-second timeout per
configuration. Deadlock checking is disabled: bounds introduce terminal states
and this scope makes no liveness claim. Every run gets a unique output directory
with full text counterexamples and `results.json`; state databases are removed
after execution. A negative control passes the runner only for exit code 12 and
the exact expected invariant violation. Timeout, parse failure, runtime exception
or a different violated invariant fail the suite. A baseline also requires a
completion message and an empty remaining-state queue.

## Observed checks

The small configuration bounds are `(MaxHeight, MaxGeneration, MaxNonce,
MaxTime) = (2,1,2,1)`; extended bounds are `(3,2,3,1)`. Heights are normalized
grid points, `S=0` and `K=1`, not production parameter values. Controls and
witnesses use the small bounds.

| Configuration            | Observed outcome                | Generated states | Distinct states |
| ------------------------ | ------------------------------- | ---------------: | --------------: |
| baseline                 | Complete, queue 0               |            8,709 |           2,538 |
| baseline-extended        | Complete, queue 0               |          131,607 |          38,651 |
| missing-checkpoint       | NoStaleCheckpointRecovery       |              120 |              58 |
| missing-nonce            | NoStaleNonceRecovery            |              142 |              70 |
| missing-deadline         | NoExpiredRecovery               |              151 |              72 |
| missing-proof-generation | NoOldGenerationLanding          |              515 |             177 |
| reach-recovery           | RecoveryNotReached              |               20 |              14 |
| reach-overlap            | OverlapNotReached               |              247 |             113 |
| reach-invalidation       | InvalidationNotReached          |               21 |              15 |
| reach-expiry             | ExpiryNotReached                |               22 |              16 |
| reach-deadline-equality  | DeadlineEqualityNotReached      |              209 |              96 |
| reach-old-proof          | OldProofAfterRecoveryNotReached |               96 |              48 |

Counterexample/witness searches stop at the target state; only baseline runs
exhaust their entire reachable state graph. Reachability witnesses establish
that a path exists, not that every execution eventually follows it.

Representative missing-checkpoint counterexample:

1. Authorize recovery at generation 0, checkpoint 0 and nonce 0.
2. A competing landing moves checkpoint 0 to 1.
3. With only the expected-checkpoint check disabled, the old authorization
   executes recovery from checkpoint 1. `NoStaleCheckpointRecovery` fails.

Representative overlap witness:

1. Prepare a proof for `(0,2]`.
2. A competitor lands `(0,1]`, moving actual checkpoint `c` to 1.
3. Submit the delayed proof and settle `(1,2]`; record parent 1, not proof origin 0. Matching history and cuts are assumptions of this first model.

The proof-generation control retains a generation-0 proof across recovery at
checkpoint 0 and then accepts it in generation 1 only when the current-generation
public-input check is deliberately disabled. This also exercises reuse of the
origin's older landing record. The deadline-equality witness advances time to 1
and successfully recovers with deadline 1; it does not rely on time remaining 0.

## Independent validation and limits

An independent reviewer inspected the module, configurations, runner and pinned
source correspondence and ran the full suite. A separate tester ran a stronger
time configuration `(2,2,3,2)` with all guards enabled: 78,061 generated states,
19,740 distinct states, queue 0 and search depth 12. The module hash matched the
recorded candidate. The tester also inspected the negative-control and witness
traces. Both independent passes found no material unresolved findings within
the stated scope. A separate temporary mutation recording the proof origin
instead of actual execution-time `c` was caught by `ActualLandingParent`
(exit 12, 247 generated states and 113 distinct states).

The runner's 11 unit tests pass, including rejection of incomplete searches,
unexpected invariants, parse failures and runtime exceptions. The existing Etna
rule checker passes for 640 live rule references; no normative rule was changed.

The model deliberately excludes L1 reorgs and per-node RPC views, signer crash
recovery, committees, FI/hash/cut integrity, proof generation and verifier
failure/rollback. In particular, it neither proves complete prefix integrity nor
fork-safe overlap. Future composition must revisit these abstractions and rerun
the existing small configurations as regressions.

## 2026-11-14: checkpoint identity extension

The same project now composes `EtnaCheckpointIdentity` with the original
`EtnaSettlement` actions. Source main was rechecked and remains
`d18357214fab30ea512ae9858a11699806d72ba1`. The original module and all 12 original
configurations remain byte-identical to local commit `dba626a9b`.

Final identity-module SHA-256:
`2181cec211890aa67ca7281c5c6606803cca32b195e3abe8a42dc4dedf0da927`.
The base-module hash and tool versions are unchanged from the first report.

### What changed in the abstraction

The first model assumed all proofs had compatible cuts. This extension instead
allows two candidate cut histories, separately supplied leaves, and public-input
origins that do not necessarily match the retained record. It checks the full
five-word identity interface: height, EL hash, Comet hash, FI cursor and
validator-state hash. Normal proof binding remains an assumption about the
underlying verifier implementation; its boundary conditions are now explicit
model transitions and can be individually weakened for negative controls.

The two histories are a conservative abstraction of boundary metadata, not two
demonstrated EVM/Comet executions. Component-isolation cases deliberately permit
one metadata field to vary without reconstructing the other fields' preimages.
Hash collision resistance, execution correctness, valid QCs, queue eligibility
and available proofs are not established here. The current FI head is identified
with the retained checkpoint cursor; separate-storage consistency and queue-tail
checks are outside this increment.

Current-generation origin reuse follows PROOF-6.2-41a: the public input retains
the old record's validator-state hash, while execution begins with independently
authenticated new genesis validator state. The successful origin-reuse witness
requires the two values to differ at a nonzero checkpoint. Interior checkpoints
still require full equality with their retained records.

### Final measured suite

All **31 configurations** returned their expected outcomes: 12 unchanged legacy
cases plus 19 identity cases. Seven normal configurations exhausted their graphs;
12 negative controls and 12 existential witnesses stopped at their exact named
invariant violations. Every run's source/configuration/tool hashes remained
unchanged. The runner recorded which TLA+ module actually ran.

Normal identity bounds are height 2, generation 1, nonce 2, time 1 and fork height `1`. Shared-prefix cases use height 3 and fork height 2. All original deadline,
time and invalidation actions remain in the composed `IdentityNext`; none was
removed to reduce exploration. Runtime bounds remain one worker, seed 1,
512 MiB heap and 45 seconds per case. Only safety and reachability are checked.

| Configuration                           | Observed outcome                  | Generated states | Distinct states |
| --------------------------------------- | --------------------------------- | ---------------: | --------------: |
| identity-baseline-comet                 | Complete, queue 0                 |          198,501 |          32,292 |
| identity-baseline-el                    | Complete, queue 0                 |          198,501 |          32,292 |
| identity-baseline-fi                    | Complete, queue 0                 |          193,293 |          30,807 |
| identity-baseline-shared-prefix         | Complete, queue 0                 |        1,005,219 |         152,427 |
| identity-baseline-val                   | Complete, queue 0                 |          198,501 |          32,292 |
| identity-el-only-comet                  | OverlapCheckpointBound            |            2,185 |             568 |
| identity-el-only-fi                     | OverlapCheckpointBound            |            2,771 |             691 |
| identity-el-only-val                    | OverlapCheckpointBound            |            2,185 |             568 |
| identity-landing-record-rewrite         | RetainedRecordsMatchSettledPrefix |               20 |              20 |
| identity-missing-boundary               | OverlapCheckpointBound            |            2,185 |             568 |
| identity-missing-cut-binding            | ExecutionCutsBound                |               32 |              23 |
| identity-missing-origin                 | OriginIdentityBound               |               44 |              24 |
| identity-reach-conflicting-overlap      | ConflictingOverlapNotReached      |              156 |              80 |
| identity-reach-recovery-origin          | RecoveryOriginReuseNotReached     |           14,678 |           3,268 |
| identity-reach-recovery                 | IdentityRecoveryNotReached        |            3,659 |             896 |
| identity-reach-same-history-overlap     | CompatibleOverlapNotReached       |            2,165 |             558 |
| identity-reach-shared-prefix-divergence | DivergentSuffixNotReached         |            4,927 |           1,007 |
| identity-reach-substituted-leaves       | SubstitutedLeavesNotReached       |                7 |               7 |
| identity-recovery-rewrite               | RecoveryIdentityPreserved         |               64 |              46 |

The shared-prefix baseline explored 152,427 distinct states and completed with
an empty queue in about 21 seconds. State counts describe these bounded models,
not production scale or an unbounded protocol proof.

### Representative explored paths

**Missing checkpoint binding.** Prepare a proof covering `(0,2]`; a competing
history lands height 1; submit the old proof. When the full overlap-boundary
check is disabled, TLC accepts the conflicting suffix and reports
`OverlapCheckpointBound`. Merely comparing EL hashes has the same problem in
the Comet/FI/validator-state isolation configurations.

**Substituted leaves.** A proof's execution history and supplied interior leaves
can differ. With cut binding removed, TLC reports `ExecutionCutsBound`, including
a fresh landing with no competing transaction. A matching caller-provided leaf
does not authenticate what the proof executed.

**Valid divergence after the boundary.** The shared-prefix witness prepares a
proof, lets a competitor settle their common checkpoint, and successfully lands
the remaining suffix where the candidates diverge only after that checkpoint.
This guards against a model that incorrectly rejects every competing history.

**Recovery-origin reuse.** Settle a nonzero checkpoint, authorize and execute
recovery, then land in the new generation from that retained older origin record.
Its public validator-state hash stays unchanged while execution uses the new
genesis state. The positive witness is reachable.

### Independent finding and fix in the model

Independent review found a missing assertion: stored `recordCuts[h]` could be
corrupted while the observer's `prefixCuts[h]` stayed correct. An independent
temporary mutation reproduced the gap: the pre-fix model still passed its EL
baseline, exploring 18,924 distinct states with an empty queue.

The fix adds `RetainedRecordsMatchSettledPrefix`, comparing every present landing
record with the independently observed settled prefix. The new record-only
rewrite control now fails this invariant immediately after a landing (20 distinct
states, depth 2). This was a **verification-model coverage gap**, not a discovered
Etna implementation or protocol defect. It demonstrates why named mutation
controls alone do not establish complete verification coverage.

A separate independent check disabled the boundary guard and retained only type,
record-link and global history properties, omitting the local audit invariants.
`SettledHistoryCompatible` still found the hybrid prefix (568 distinct states,
depth 4). Thus the global state property detects incompatibility independently
of the audit flags that restate individual binding requirements.

### Independent verification and runner evidence

An independent tester reran all 12 legacy cases and all 14 new adversarial/witness
cases and inspected their actual traces. A stronger validator-state baseline
used height 2, generation 1, nonce 2 and **time 2**: 527,006 generated states,
78,438 distinct states, queue 0, depth 10. It used the final identity-module hash.
Independent source review checked the origin exception, all composed actions,
field mappings and the record-consistency fix. Additional temporary `ENABLED`
witnesses showed that conflicting/substituted queued proofs had base `Land`
enabled, but the correctly guarded composed `IdentityLand` disabled. The
permanent queued-input witnesses establish input availability; they do not
themselves execute an EVM revert.

The runner's **20 unit tests** pass. It validates optional `MODULE` selection
without falling back on malformed, duplicate, missing or unsafe declarations.
It snapshots all selected configurations, local TLA+ modules and the TLC jar;
edits or removal invalidate the result and stop the suite. Independent end-to-end
tests confirmed invalid module declarations fail before execution, and that a
checker which changes its selected model cannot pass even if it prints a
success message and exits 0. Output includes pre-run source/config hashes.

Use the same command in the reproduction section; add
`--case identity-baseline-el` for one normal identity check. No production build,
guest execution, deployment or actual-client correspondence check was performed.

### Workflow established and next boundary

For each increment, pin source rules, make environment/proof assumptions explicit,
reuse existing transitions, add structural properties, reach valid and invalid
inputs, weaken one obligation at a time, and independently challenge the
assertions themselves. Freeze and hash inputs before recording results, and
retain the small cases as regressions.

The next boundary remains outside these results: per-node L1 observations,
signer persistence/trust, committee transitions, actual cryptography and real
client/contract equivalence. Concrete trace replay against implementations or a
refinement proof is still needed to connect this formal model to running code.

## Per-node L1 trust increment (2026-11-14)

Source remains Etna SPEC at `d18357214fab30ea512ae9858a11699806d72ba1`.
The source pin was rechecked against GitHub main. The new model investigates
M02 startup/session trust and sign/serve gates using a finite L1 snapshot trace:
initial generation 0, its first landing, recovery at that checkpoint, and a
new-generation landing. Inclusion, finality, provider visibility and authenticated
targets are distinct. This snapshot trace is an interface abstraction of
settlement/recovery, not a formal product with the earlier modules.

[Model mapping and reproduction](L1_TRUST.md) records exact source obligations,
bounds and assumptions. Original TLA+ modules, all 31 older configurations and
the outcome-checking runner remain unchanged.

### Specification question kept distinct from a protocol finding

RECOV-8-16 says startup/session generation mismatch safety-halts, while
RECOV-8-5/SYNC-9-2 classify own-L1 lag as a retry. RECOV-8.2-4 does not explicitly
order the checks for a node configured in a new generation whose own L1 view
still predates recovery R. Existing review question Q8.2-3 also identifies this
ordering. The new-generation profiles start at or after R and therefore do not
resolve this case. Checking the authenticated origin floor first is a possible
interpretation, not a rule adopted by this model. This is a source ambiguity,
not a demonstrated protocol defect.

No unconditional progress, L1 finality-failure, full anchor processing,
crash/HRS durability, cryptographic correctness or client refinement claim is
made. Own-L1 RPC timeout and app-trust-confirmation timeout are separate;
previously legitimate signatures are judged using their event-time evidence,
not a generation observed later.

### Frozen results

The complete actual-worktree suite produced **63/63 expected outcomes**: 31
unchanged regressions and 32 L1-trust cases (4 complete normal searches, 20
negative controls and 8 existential witnesses). All recorded input hashes stayed
unchanged. Every normal run exhausted its queue; a witness/control passed only
when TLC reported the exact declared invariant violation.

L1-trust module SHA-256:
`b27df113c00068ededba461b3063a960f75b9c60c77dc7e1523fa9b24ce653cc`.

Tools and reproduction command are unchanged: official TLA+ tools 1.7.4
(TLC 2.19), Temurin 17.0.21+9, one worker, seed 1, 512 MiB heap, 45 seconds per
configuration. Run the README command without `--case` to reproduce all cases.

| New normal profile             | Generated | Distinct | Queue |
| ------------------------------ | --------: | -------: | ----: |
| l1-trust-baseline-recovery     |   122,820 |    6,165 |     0 |
| l1-trust-baseline-startup      |   112,212 |    5,701 |     0 |
| l1-trust-baseline-supersession |   143,580 |   10,166 |     0 |
| l1-trust-baseline-two-nodes    | 1,992,073 |  106,608 |     0 |

Positive witnesses include two trusted nodes with different authenticated
checkpoints, signing while global recovery is not yet locally known, signing
after an unrelated own-L1 timeout, missing-then-retry trust, and the retained
origin validator-state exception. These are existence traces, not liveness.

The finality control exposes a genuine included-but-unfinalized input: include
snapshot 1 while finalized remains 0; expose it through the provider; load local
evidence; authenticate with the finality guard removed; grant trust. The stored
certificate records that finality was not authenticated, and
`TrustedTargetFinalized` fails. No L1 finality violation is assumed.

### Independent assertion challenges

An isolated write-only mutation replaced the actual certificate with an internally
valid canonical certificate for another snapshot. Earlier normal invariants still
passed (5,701 distinct states); adding an independent target relation caught it
at depth 7. The repair adds `TrustedCertificateFromTarget` and
`TrustedCertificateFromLocal`, with separate wrong-target and expected-instead-
of-observed write controls.

A separate mutation let logical `BeginSession` clear a safety halt. Earlier normal
invariants still passed; an independent temporal absorption check rejected it
at depth 5. The repair adds an observation-only `haltHistory` and
`SafetyHaltSticky`; the permanent unsafe-session control now fails that property.

Certificate assertions also evaluate the fixed-origin validator exception
independently of the acceptance helper. Importantly, selected existing negative
controls rejected broad certificate rewrites, broad origin-helper changes
and a contradiction-classification mutation through unexpected PASS outcomes.
The baseline-only experiments show weak direct assertions, not demonstrated
whole-suite escapes. The old full control matrix was not rerun for the halt
mutation, so no whole-suite-escape claim is made for it either. These are model
assertion improvements, not discovered runtime protocol defects.

### Independent verification and next scope

An independent stronger single-node profile crossed recovery with all eight
local evidence kinds and all selected read-error actions enabled:
`SessionGeneration=0`, `MaxSnapshot=2`, `NodeCount=1`, all normative guards on.
It completed 1,702,918 generated states, **61,824 distinct**, queue 0, depth 21,
using the final module hash. The tester also independently reran all 28 new
negative controls/reachability cases with exact expected outcomes. Extra isolated
witnesses confirmed that a later-generation non-origin wrong validator value
halts, a wrong Comet hash still halts at the recovery origin, and missing
validator material at a non-origin checkpoint pauses without halting.
Independent source review rechecked the actual complete increment and repaired assertions; source claims remain bounded as
listed above. The unchanged runner's 20 tests passed, and the Etna rule-reference
checker passed its 640 live references (migration-purity check not requested).

The next increment is M03: signer and ABCI/EL crash recovery. It must introduce
physical persistence and process boundaries rather than infer crash safety from
the continuous-process session latch. Implementation trace replay remains
pending; none of these results establishes real-client conformance.

## M03 crash recovery increment (2026-11-14)

The actual frozen-worktree focused suite completed **25/25 expected outcomes**:
4 normal exhaustive searches, 12 negative controls and 9 existential witnesses.
Prior models, 63 configurations and the shared runner remain byte-identical.
Full accumulated regression is scheduled at the five-task/discovered-problem
stopping boundary. Source remains Etna SPEC `d18357214`; upstream CometBFT
v0.40.0 resolves to `0880b4d378f347ab16e54ec677ff50d803f37d62`.

| New normal profile                 | Generated | Distinct | Queue |
| ---------------------------------- | --------: | -------: | ----: |
| app-crash-baseline-height-one      |     2,789 |      680 |     0 |
| app-crash-baseline-recovery-height |     2,538 |      636 |     0 |
| signer-crash-baseline-domains      | 1,497,462 |  218,335 |     0 |
| signer-crash-baseline-small        |   140,014 |   23,817 |     0 |

Final signer SHA-256:
`c948786960d3dd5af381c653f3c0c28795291b19d3b96e660efa8825f6d93c4a`.
Final app SHA-256:
`f54c6458954b8ee33f6a0765eab766ffd45c59f027704c0c0dc3c8a0798aafa0`.

An independent verifier performed 18 checks, including both signer profiles,
both app profiles, actual pre-return crash/replay, request substitution and
the derived real-Commit/mock-replay boundary. With the local Info bound removed,
wrong Info still made `CometNeverAheadOfApp` fail: EL and saved response reached
block 1, the app had not committed, but mock replay advanced Comet to 1. An
additional temporary history observer independently required actual commit
receipts for Comet/Ready and caught the same error at depth 12.

Independent review exposed three model issues: a replay witness could use an
unrelated earlier crash; an observational generation variable enabled an action;
and computed signatures were not linked to actual caller requests. These were
repaired with a captured pre-crash record, operational floor gating and independent
request identity. Before repair, a write-only A-to-B request substitution passed
the normal small baseline and all five existing negative controls; an independent
request observer caught it at depth 4. This is a model-assertion finding, not a
source-permitted protocol defect. No entire old positive-witness matrix escape
is claimed beyond the controls actually rerun.

**Incomplete coverage retained:** two slots with two signature variants, for
both two and three payloads, did not complete in 45 seconds. Last printed progress
was about 3 seconds into each run, not final counts. The exact parameters and
progress evidence remain in `experiments/`; both wider products are explicitly
INCONCLUSIVE. The successful profiles separate HRS-depth from payload/signature
breadth and do not prove that wider product.

[Crash mapping and reproduction](CRASH_RECOVERY.md) records process-only durable
storage, serialized signer ownership, the explicit durable completed-recovery
authentication interface, aggregate app/EL/Comet volatile crash abstraction and
missing full composition/refinement. The already documented first-block-above-1
Comet handshake stop is reachable and remains a known limitation. No unmutated
new protocol counterexample was established in this bounded M03 scope.

## M04 committee increment (2026-11-14)

The frozen actual-worktree focused suite completed **20/20 expected outcomes**:
2 complete normal searches, 13 negative controls, 5 existential witnesses.
Earlier models, 88 default configurations, runner and incomplete signer
experiments remain unchanged. The full accumulated suite is deferred to the
five-task/discovered-problem boundary. Source remains Etna SPEC `d18357214`.

| Normal profile                 | Generated | Distinct | Queue |
| ------------------------------ | --------: | -------: | ----: |
| committee-baseline-members     |    41,272 |   12,917 |     0 |
| committee-baseline-replacement |    41,272 |   12,917 |     0 |

Module SHA-256:
`d34ffcc6cbdab5d3a2804556419243e894699eaf1beb9a8c7606dbb02d023467`.

Independent verification also exhausted the two-member/VPUnit2 cross-profile:
41,272 generated / 12,917 distinct / queue0, depth20. Targeted tests checked
snapshot/header writes, stale-pending effects without the local generation
audit, the fixed recovery-floor boundary and actual authentication-root provenance.

### Model-oracle findings and repairs

A narrow mutation skipped pending update and derivation only for generation0,
switch height2, candidate anchor2. **All18 original configurations still produced
their exact expected outcomes**, including the existential positive witnesses.
Because the oracle followed only the logged switches, it could agree with the
wrong implementation. An independent literal calendar assertion rejected the
mutant at depth6/29 distinct states. The repair adds complete/exclusive switch
calendar correspondence for every committed generation/height pair and a
permanent narrow omission control. This was a real verification-model gap, not
a source-permitted protocol bug.

A separate mutation changed both proofRoot and its self-described switchAnchor
to the selection snapshot. A normal profile stayed green and the old wrong-root
control still failed as expected. Its entire original matrix was not rerun, so
no full-suite escape is claimed for that mutation. The repair binds captured
D/switch/origin inputs to immutable generation-keyed actual committed anchors,
canonical parent identity and origin history. The first recovered switch links
to the retained old-generation parent at c, not an uninitialized new-domain record.

The repaired positive witness lands c1 under generation0 anchor0, recovers at R2
without changing L1 active snapshot0, then commits the first generation1 block2
with anchor2. Its raw parent is generation0/height1, D anchor0 is below origin2,
selection is floored to2, and the update becomes effective at height4. Other
witnesses cover recovery at/after a switch, complete replacement and unchanged
members with changed power. Header current/next sets are checked separately.

[Source mapping and reproduction](COMMITTEE.md) defines the finite fixture and
scope: three keys, immutable snapshots0..2, L3/heights0..7, at most one recovery.
Committee identity is projected to snapshot/members/powers, not full targetEpoch,
record/hash encoding, MPT/secp or proposer-priority arithmetic. L1 slot284 changes
only on an actual landing, not merely on recovery or pending selection. There
is no registry-transition product, client refinement or availability/liveness
proof. No new unmutated protocol counterexample was established.

## M05 registry increment (2026-11-14)

The frozen actual-worktree focused suite completed **26/26 expected outcomes**:
5 complete normal searches, 15 negative controls and 6 existential witnesses.
Earlier models, 108 default configurations, runner and incomplete experiments
remain unchanged. Source remains Etna SPEC `d18357214`; the full accumulated
suite is deferred to the five-task/discovered-problem boundary.

| Normal profile         | Generated | Distinct | Queue |
| ---------------------- | --------: | -------: | ----: |
| registry-workflow      |   236,666 |   44,110 |     0 |
| registry-two-slot      |   934,608 |   82,391 |     0 |
| registry-repeat-topup  |     3,534 |    1,084 |     0 |
| registry-split-pending |     2,554 |      788 |     0 |
| registry-all-forfeit   |     1,955 |      595 |     0 |

Module SHA-256:
`0a659bb1deafa2dff19bbde70dfa057dd650daa36328871ef0084a3080cc3b44`.

### Model gaps repaired

Independent review and behavioral challenges exposed shared snapshot/member
oracles, missing independent forfeiture rounding/allocation checks, insufficient
admission/displacement receipts, and a withdrawal receipt that described the
computed slot write rather than actual primed storage. Repairs use literal raw
snapshot observations, separate expected eligibility/powers, actual pre/post
registration/withdrawal receipts, independent ceiling inequalities and per-bond
principal conservation. Numeric profiles make effective-first pending deduction,
full pending cleanup and repeated activation reachable. The lifecycle witness
now withdraws a bond that really belonged to the initialized active set, after
replacement, new landed selection and the full confirmation delay.

A second narrow challenge marked a funded displaced nonmember as withdrawn
only during a rejected registration, without paying it or changing balances.
The prior normal workflow still exhausted 48,394 distinct states. An independent
actual pre/post rejection observer failed at depth11/328 distinct states. This
was a genuine assertion gap, not a protocol source defect; the entire prior
25-case matrix was not tested against that mutation. The repair observes
actual rejected-call `r' != r` and independently requires withdrawn records to be
issued, hold no slot, and have zero principal/owner/confirmation/readiness. A
permanent shadow-write control detects the rejected mutation. Correct-source
registry operations are unchanged by this observation-only repair.

### Checked workloads and limits

[REGISTRY.md](REGISTRY.md) records the exact executed setup prefixes and finite
external-call budgets. The one-slot workflow reaches genuine active-member
retirement with pending principal and preserves its replacement's slot. The
two-slot/three-id profile checks admission, minimum-slot tie breaking and
accounting; it cannot finish a fresh withdrawal after its prepared prefix.
Small raw-storage profiles cover two top-up cycles and normalized 50%/100%
forfeiture. They do not replace arbitrary workload timing or full production
integer arithmetic. Valid cryptographic/DAO inputs, atomic token effects and
normal landed selection are premises; nonzero slash-bounty routing, M04 product
composition and actual contract refinement remain outside this scope.

Four larger registry experiments exceeded the 45-second case limit. Their
exact old sources/configurations and progress remain under `experiments/` as
**INCONCLUSIVE**, alongside the earlier signer experiments. No complete
queue-zero claim is made for these wider products. No new unmutated protocol
counterexample was established in the exhausted M05 scopes.

Independent source/diff review and behavioral verification completed on this
frozen source. The verifier reproduced the original shadow mutation with and
without the new latch assertion: the structural withdrawn-state assertion still
rejected it; with both new assertions omitted, a separate actual pre/post
rejection observer rejected it. The correct workflow with that external observer
exhausted 44,110 distinct states, queue0, depth22. The original rejected-key
control retained its exact earlier violation. Root and implementer each ran all
26 exact outcomes against unchanged inputs; the complete project gate remains
scheduled for the end of this five-task batch.

## M06 forced-inclusion increment (2026-11-14)

The focused final suite has **20 expected outcomes**: three exhaustive normal
workloads, eleven negative controls and six existential witnesses. The model
extends the actual `EtnaSettlement` actions with FI-aware wrappers; it does not
copy or bypass their generation, authorization, nonce, expiry and checkpoint
guards. Source remains Etna SPEC `d18357214`.

| Normal profile  | Generated | Distinct | Queue |
| --------------- | --------: | -------: | ----: |
| fi-empty-revert |    18,054 |    5,395 |     0 |
| fi-fee-lag      |   184,181 |   58,270 |     0 |
| fi-mixed        |     2,928 |    1,151 |     0 |

Module SHA-256:
`5f3e91f14e137449d04333174c1bf684001650273f5b41baa9f47aac629a8718`.

### Independent challenges and model repairs

A real-action five-state scenario first enqueued Empty then B and closed the
anchor. A narrow model mutation chose index 1 for the first produced block,
consuming B with locally consistent before=1/after=2 and cuts. All prior normal
assertions passed on that scenario. An independent predecessor/origin cursor
observer failed on the same five states. The repair binds actual pre-action
cursor, stored block and predecessor/origin cursor; a permanent shifted-before
control now fails the exact production-rule invariant. No full prior matrix
escape is claimed.

A separate five-state scenario forged only the closed anchor's transaction A
hash into Bad. The live queue remained intact, but the former oracle followed
the same forged anchor and accepted its skip. An independent pre-Tick queue
observer failed at closure, after three states. The repair independently captures
literal queue/head/tail before closing each L1 block and compares historical
anchors exactly. A permanent forged-anchor control detects this gap.

The unmutated earlier abstraction also cleared a pruned-parent halt during
recovery at unchanged c/frontier. A six-state real-action model scenario passed
its previous assertions but failed an independent availability observer. Recovery
now preserves the halt, actual pre/post halt is observed, and produced blocks
must not start halted. Explicit restoration/manual restart is a separate resource
interface. This is a conservative projection across recovery, not a proof of
historical-state availability.

Blanked entries always supply the known empty raw bytes, regardless of an
internal candidate-mode label. Their old transaction may still appear as ordinary
body content alongside a legal due skip. The stale-hash negative control uses a
raw workload and actually advances before due: entry timestamp 10, anchor time 10,
due time 12, blank hash and empty raw, body A. It does not reject a legal due blank
skip on a diagnostic reason label. The wrong-parent control uses a uniform tuple
identity and must reach its named invariant; its earlier heterogeneous-type
runtime error was rejected as failed verification and corrected.

### Bounded workload and incomplete products

All normal profiles use two entries, height 2, time 0..2, one recovery, nonce 0..2
and an explicit external budget of two total production calls across generations.
Each executed setup state is checked. MixedReady and EmptyReady enqueue twice at0,
close blocks0/1, and perform a real first block at time 2. The latter first observes
Transient then Complete and legally skips the eligible empty singleton. All
selected actions remain exposed afterward, but time is exhausted: a later recovery
cannot obtain a new closed root within these two workloads. FeeLag instead
includes A early, then admits B while L2 cursor 1 and L1 head 0. It checks the higher
second admission charge and permits earlier recovery/new-generation interleavings.
These are distinct finite workloads, not an arbitrary transaction workload.

For state-space control, operational build cache/acceptance remains intact while
unused per-block build observations become EmptyBuild. The capture criterion is
literal visibility/due/eligibility/body0 matching, independent of optional decision
switches; eligible singleton-skip decisions retain their actual context. The
transient observer keeps the latest context only, used for an existential retry
witness and never to enable protocol actions. Wider earlier candidate products
that exceeded 45 seconds remain **INCONCLUSIVE**, with exact source/config/base
inputs retained under `experiments/`; narrowed workloads do not establish their
completion.

[FORCED_INCLUSION.md](FORCED_INCLUSION.md) records exact source mapping, fixture
execution table, prefixes and reproduction. Cryptographic storage proofs,
canonical transaction decoding, actual EL/zk execution, full checkpoint identity,
L1 finality and client refinement are interfaces/exclusions. No unconditional
FI service deadline or throughput result follows. Earlier 134 default inputs remain
regressions; the complete accumulated suite is still reserved for the batch end.
No new source-permitted protocol counterexample was established.

Independent source/diff review and behavioral verification completed on the frozen
source. Sixteen final independent checks include all three original gap probes,
missing pre-due witness, proper typed wrong-parent violation and both internal
body modes producing the same legal due-blank progress. An advancing overlapping
landing was inspected: delayed proof 0..2 lands after c=1/head=1, advances to head=2,
and applies each queue index exactly once. Independent normal searches exhausted
58,270 and 5,395 distinct states, both queue 0. Root and implementer each completed
all 20 exact outcomes with stable current inputs; all 153 prior tracked formal
source/config/runner files remain byte-identical to the previous commit.

## M07 proving and DA progress increment (2026-11-14)

The frozen actual-worktree focused suite completed **21/21 expected outcomes**:
three exhaustive normal workloads, twelve negative controls and six existential
witnesses. This is a separate bounded pipeline interface, not a formal product
with the earlier settlement/trust/FI models. Source remains SPEC `d18357214`.

| Normal profile          | Generated | Distinct | Queue |
| ----------------------- | --------: | -------: | ----: |
| progress-pipeline       |   172,176 |   10,381 |     0 |
| progress-small-capacity |    87,088 |    5,261 |     0 |
| progress-ancestry       |     1,133 |      133 |     0 |

Module SHA-256:
`4a102d5e465b7c943b8564994a320fb4b2af13fbe5348c=0f095aa75016fa0105`.

### Pipeline and progress boundary

Produced head, selected parent/candidate anchor, L1-included checkpoint,
finalized source block/checkpoint and actual candidate adoption remain separate.
Private history, each backend's availability/result and complete original-range
payloads are separate resources. Captured jobs and requests bind the original
generation, retained origin/terminal, reference, dependency, data, cuts and
statement. An overlapping old-p job can settle only the suffix after actual c;
its full original-range publication and both statements remain unchanged.
A cached proof or mere inclusion cannot give a candidate production credit.

Conditional assertions use independent captured originals/events to determine
ready prerequisites, then evaluate `ENABLED Land` or `ENABLED Produce`. A valid
landing does not require another L2 block while production is at U. The next
candidate can itself adopt an actually finalized anchor; it need not first
produce a block under its old paused parent anchor. The source timestamp rule
`max(parent+1, BFT time, anchor timestamp)` permits this adoption. Existence and
enabledness establish neither eventual resource arrival nor sustained throughput.

### Clock-model findings and repairs

Three actual small scenarios exposed weaknesses in the first prototype:

- A same-block reference landing passed its previous normal assertions across
  ten states. An independent literal `inclusion > captured reference` observer
  rejected that trace. Current-reference lookup is not source-permitted.
- Removing only the ordinary finalizer's past-inclusion guard passed the old
  assertions across eleven states. A separate actual inclusion/finalization
  chronology observer rejected it. A self-written finalization event alone was
  not an independent finality oracle.
- Two jobs landed checkpoints 1/2 in the same block; the prototype then finalized
  intermediate checkpoint 1. All former assertions passed on that eighteen-state
  scenario, while an independent block-end checkpoint observer rejected it.
  A finalized L1 root exposes the block's final state.

These are scenario-level model/oracle findings, not full-matrix escape claims or
protocol defects. The repair uses strict past references in both guard and
independent receipt/oracle. Ordinary finalization chooses a source block strictly
before observation, derives that block's last included checkpoint, and is checked
against raw actual landing events. Anchor identity uses that finalized source
block, not the later observation time. Genesis and trusted completed recovery
have distinct provenance. Three permanent negative controls independently detect
current references, current-block finalization and a lower positive intermediate
checkpoint when two checkpoints really share the finalized block.

The recovery interface explicitly executes at R=old time+1 and is observed after
finalization/bootstrap at old time+2. It preserves missing history/backend
resources. This is not a transaction-level recovery/finality product. With default
time bound 2 it can run only at old time 0; strict-past normal landing cannot yet
have happened there, so default M07 recovery covers c=0 only. Earlier modules
cover nonzero recovery origins separately. The old-generation negative uses a
reference window of 2 so its old reference remains live across the macro, making
the intended generation-binding violation observable.

### Finite resources and limitations

Bounds are K=1/U=2, head at most 3, three total production calls across generations,
two immutable job ids and clock 0..2. The pipeline and smaller-capacity profiles
execute real productions, capture jobs (0,1] and (0,2], then actual history/backend
availability, completion and payload-preparation events before exploring all
selected remaining actions. This is a declared ready-resource workload, not an
assumption that every execution eventually becomes ready. The separate OneJob
absent-resource workload forbids history/backend availability and can stay paused;
it leaves a job id for the fresh-reference/old-dependency case. Job/head/workload
exhaustion is a finite scope limit, not a protocol deadlock.

Payload capacity 1/2 is a symbolic resource fixture. It checks that a smaller
prefix may fit while a larger job does not; it is not a production Ethereum
six-blob, encoding, compression or byte-capacity proof. Reference and ancestry
budgets are symbolic. Refreshing a reference does not erase the old dependency;
long-pause recovery needs are known source limits, not new protocol findings.

All three broader first-prototype resource/timing products exceeded 45 seconds.
Exact historical inputs remain **INCONCLUSIVE**, with their earlier clock-model
limitations intact; they are not substituted for current source or counted as
passing default cases. [PROVING_PROGRESS.md](PROVING_PROGRESS.md) records the
source mapping, workload/provenance interfaces and reproduction. Cryptography,
actual EL/STF, consensus, blobs, L1 finality mechanics, detailed governance
recovery and implementation refinement remain premises/exclusions. No new
source-permitted protocol counterexample was established.

Independent source/diff review and behavioral verification checked the frozen
source. Seventeen final independent checks include the original clock repairs,
an independent candidate-enabledness assertion with the built-in property
omitted, actual pause/landing/finalized adoption, and unchanged old-p advancing
overlap. The concrete path lands prefix 1 at block 1 with head 2 still paused,
observes block 1 finality at 2, then produces block 3 using checkpoint 1/block 1 in
that same candidate. Two same-block landings instead finalize checkpoint 2 with
both application counts exactly once. A separate `MaxTime=3` scenario starts
`head=c=2`, produces the next block, captures fresh reference 2, and at 3 still cannot
complete with dependency 0 despite available history/backend/data. This is an
additional declared scenario beyond the default time 2 scope, not a complete
larger search. Independent ready and permanently-absent normal searches exhausted
10,381 and 133 distinct states, both queue 0.

## Five-task batch stopping boundary (2026-11-14)

All five authorized increments M03 through M07 are checked and locally saved in
the same project. No new independently supported, source-permitted protocol
counterexample was established. Stop after this batch for retrospective; model
repairs and wider incomplete searches are not evidence of protocol perfection.

| Increment                          | Focused cases | Normal searches | Negative controls | Existential witnesses |
| ---------------------------------- | ------------: | --------------: | ----------------: | --------------------: |
| M03 signer/application crash       |            25 |               4 |                12 |                     9 |
| M04 committee selection/activation |            20 |               2 |                13 |                     5 |
| M05 registry lifecycle             |            26 |               5 |                15 |                     6 |
| M06 forced inclusion/settlement    |            20 |               3 |                11 |                     6 |
| M07 proving/DA/back-pressure       |            21 |               3 |                12 |                     6 |
| New batch total                    |           112 |              17 |                63 |                    32 |

The final **single accumulated run completed 175/175 exact expected outcomes**
against frozen inputs: 28 normal configurations exhausted with queue 0; 147
negative-control or negated-witness configurations produced their exact declared
invariant violation. None passed because of a parse/runtime error, timeout or
changed input. Earlier 63 cases and the 112 new cases are all included.

Using caller-supplied existing Java 17/TLC release 1.7.4 and the shared runner:

```sh
python3 formal/etna/check.py \
  --java "$JAVA" --tlc-jar "$TLA2TOOLS_JAR" \
  --output-dir "$TLC_OUTPUT_DIR"
```

The actual run used 45 seconds per case, 512 MiB heap, one worker, seed 1 and explicit
deadlock disablement for finite workload terminal states. Jar SHA-256 remains
`936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88`.
The manifest was independently compared to every current module/configuration;
all 175 inputs stayed unchanged throughout. All 188 previously tracked formal
source/config/runner files remained byte-identical before M07 integration.

| Checked command                                            | Observed result                                                                                                |
| ---------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `formal/etna/check.py` without case selection              | 175/175 exact outcomes; 28 exhaustive normal searches                                                          |
| `python3 -m unittest discover -s formal/etna/tests -q`     | 20 tests passed during the batch; runner/tests remained unchanged afterward                                    |
| `python3 packages/protocol/docs/etna/rules/tools/check.py` | 640 live rule references/index/assets/links passed; migration-purity check explicitly skipped without `--base` |

Independent adversarial source review and independent behavioral verification
completed for every increment, with original findings rechecked after repair.
No production target was compiled. Normative SPEC and production code were not
changed. This establishes bounded symbolic-model evidence, not implementation
refinement or a full product of all nine top-level models.

Eighteen larger historical experiment configurations remain **INCONCLUSIVE**:
two signer, four registry, nine FI and three pipeline prototypes. Their exact
inputs/progress and known earlier-model limitations are retained under
`experiments/`, outside the passing default suite. Smaller executed workloads
are not claimed equivalent to those products. Data/proofs/resources can remain
missing; conditional enabledness and existential witnesses imply no unconditional
liveness, proving throughput or settlement-latency guarantee. Actual-code replay,
full interface composition, publication/CI and broader coverage remain separate
worklist items.

## M08-A — ordinary recovery transaction (2026-11-15)

The second authorized batch adds a frozen public recovery-attempt projection.
`EtnaRecoveryTransaction.tla` SHA256
`4d33545dbeffa396b40864620788ab688ceb51c9d323d85b46acb29a75c046a2`
and18 new configurations passed all exact expectations in both implementer and
independent owner runs:3 exhaustive normal searches,9 deliberate mutant controls
and6 existential boundary witnesses. Normal distinct-state counts are10010
(held),3242 (displaced),3242 (withdrawn), all final queues0. Tool/budget are the
same TLC1.7.4/Java17,45s,512MiB,one worker,seed1 as the earlier batch.

Independent adversarial review read the complete source/config/doc and checked
actual hashes/results. Owner behavior verification additionally supplied two
**distinct issued ids in reverse order** directly to raw `Begin`; the real model
rejected the call and kept its entire canonical projection unchanged. A separate
temporary mutation reported a callback rejected while actually writing workspace
state; `NestedCallsRejected` caught the write. Neither probe modified the frozen
model. No actual protocol/implementation issue was established.

List domain, single-attempt bound, normalized fixtures and private ordering limits
are detailed in [RECOVERY_TRANSACTION.md](RECOVERY_TRANSACTION.md). In particular,
private prevalidation is not the real per-call `forceExit` instruction order;
public atomic acceptance/effects are the proposed correspondence boundary. The
callback abstraction is one representative write class, not a concrete reentrancy
proof. Actual-code correspondence is deferred to C03, separately reported.

Earlier175 cases remain unchanged. This increment brings the default selection
to193; its final accumulated run is pending M09 freeze, so18 focused passes are
not presented as an already completed193-case run.

## C01 — local Lean and real Registry8 (2026-11-15)

[Conformance evidence](conformance/REPORT.md) records a successful local
Lean4.35.0 build of the pinned current model/proof targets, two actual fresh
vector generations with exact golden hashes, and the original real Solidity
Registry8 consumer: one selected method/eight cases. No production source,
fixture expectation or authority metadata was patched. The vector bridge permits
only the two explicitly pinned authority metadata values; every other field is
identical. This is selected real-code correspondence, not full refinement.

Independent adversarial source/argv/artifact review passed after one helper
false-positive fix (duplicate output paths). Root separately verified both exact
source manifests and actual logs/outputs; dedicated tester executed the real
contract. Sixteen recorder/vector tests and five namespace-launcher tests passed.
Cold Lean build332.919s, actual two-directory generator3.646s and final recorded
real-contract run20.084s. Full independent Lean kernel replay, cryptography,
whole-registry reachability, deployment behavior and further replay scopes remain
separate obligations. No actual protocol/implementation issue was established.

## C02 — settlement and authorization implementation traces

The unchanged base model generated8 scripts/45 receipts using actual TLC action
enabledness (90 distinct states, queue0). Independently regenerated bytes were
identical. The new adapter replayed all45 observations against pinned real Inbox
contracts, with original full-statement proof mocks and exact old-domain proof
rejection selectors. It compares all five bounded landing records, three origins,
current checkpoint/generation/nonce and failed/offchain public-state equality.

Seven focused exporter tests, four actual negative mutations and final normal
real-contract execution passed their expected outcomes. Missing-step enforcement
and source-drift provenance were repaired in the adapter. Independent source/
artifact review passed; a root-selected origin-time mutation independently
confirmed the actual getter assertions and exact fixture restoration. No actual
protocol/implementation discrepancy was found. [Detailed evidence and limits](conformance/REPORT.md)
separately state same-chain scripted workloads, proof mocks and empty FI/exclusions.

## M09-A — corrective rollback and derived authority

Frozen module SHA256
`9de72dfbc6149d07c0add856d11c71a9e113b3a80c26e1a0893cef2f3d48c832`
passed19/19 focused exact outcomes in implementer and independent owner runs.
Three normal graphs exhaust1314/4448/8858 distinct states with queues0;
ten deliberate controls and six existential witnesses produce their exact named
invariant violations. Actual checkpoint reads, accepted/rejected proof attempts,
cached/retry authorization and value/fee/stake transfers are observed. Latest
corrected start and already-paid external cash are imported interface premises.

Independent root mutation found a model-oracle gap: retaining all later base
landing records still passed the original normal profile. Repair adds actual
full base-record pre/post observations, full prefix preservation, absence above
the trusted target and the existing NoFutureLandingRecords invariant. The exact
original root mutant now fails BaseLandingRollbackCorrect; an independent reviewer
also corrupted only retained h0.parent and observed the same failure. Complete
source/config/doc/archive review passed after that single coherent repair wave.
This is a repaired **model assertion omission**, not a production defect.

One wider unrestricted-runtime prototype timed out45s, with last progress34626
states/19607 queued. Exact source/config/dependency and its older assertion set
remain INCONCLUSIVE under experiments/m09-wide-runtime. The smaller prepared
workloads do not establish that product. [Module mapping and limits](VERIFIER_ROLLBACK.md)
explicitly exclude concrete proxy/storage migration, real bridge cryptography,
failed corrective-upgrade atomicity and node reconciliation. Those remain GAPs;
this module is normative-interface verification, not actual upgrade code replay.

The earlier193 default cases remain unchanged;19 new cases bring the selection
to212. The final accumulated run completed successfully, reported at batch end.

## C03 — actual recovery attempts and public unheld identity

Frozen M08 public actions generate18 complete Held receipts (158 distinct states,
queue0), including positive exact deadline equality. The pinned real Inbox/
Registry/FI adapter passes all18, plus a separate genuine public4096-registration/
paid-replacement unconfirmed-unheld scenario. Recovered-event indexed generation,
emitter and complete data are compared for model-accepted calls. It checks exact
mapped canonical effects, full selected abort equality and preserved raw metadata.
Second-call failure is labeled dependency injection; real first-call registry
writes are observed before rollback. Actual UnknownBond validates the unissued
case. The earlier exit12 remains12 when the unheld exclusion executes at13.

Independent review repaired DefaultKey's zero-record hash mapping and readable
unissued-default observations, then rechecked actual final tests and negative
mutations. Root separately regenerated the18 receipts, verified564 original source
files unchanged, actual case/test identities, final source/fixture hashes and its
chosen FI-timestamp mutation. Seven exporter tests pass. [Detailed mappings and
limits](conformance/README.md) document timestamp1200 scaling, token/fee units,
proof mocks and unmatched confirmed95/Withdrawn/callback profiles. No production
implementation issue was established; the model-to-code claims remain scoped.

## Second five-increment batch: stop and retrospective (2026-11-15)

All five authorized increments C01, M08-A, C02, M09-A and C03 have completed local
review/verification gates. **Stop here; no sixth increment is started.** No new
independently supported protocol/specification/production implementation defect
was established on the pinned revisions. Model assertion omissions and test
adapter defects were found, repaired and rechecked separately.

| Increment | Completed evidence                                                                                 | Important boundary                                                                                                                              |
| --------- | -------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| C01       | Existing current Lean targets built locally; two exact vector generations; original real Registry8 | Existing encoded theorems/seeded opening; explicit authority-only bridge; no new Solidity equivalence theorem or full independent-kernel replay |
| M08-A     | 18 exact TLC outcomes; raw-request/revert/effect and callback-write sensitivity                    | Three normalized one-attempt fixtures; curated lists, not arbitrary histories                                                                   |
| C02       | 8 real-model scripts/45 real-Inbox observations; strict original statement and mutation checks     | Same-chain proof mocks; empty FI/exclusions/rules0                                                                                              |
| M09-A     | 19 exact TLC outcomes; current nonce, complete landing prefix, confirmations, cache/retry and cash | Imported prepared interfaces and normative upgrade; concrete corrective API/migration GAP; wider runtime incomplete                             |
| C03       | 18 real Held recoveries plus genuine public unheld variant; selected event and failure sensitivity | Confirmed95 Displaced/Withdrawn/callback GAPs; labeled dependency injection; selected state projection                                          |

Final accumulated `check.py` execution completed **212/212 exact expected
outcomes** with frozen inputs:34 normal searches ended queue0;178 controls or
negated-witness searches violated only their declared invariant. No timeout,
parser/runtime error or input drift counted as success. Source/config hashes
were independently recomputed against every result. All214 previously tracked
formal code/configuration files from the prior batch remained byte-identical;
production-package diff is empty.

Final focused infrastructure checks:20 existing runner tests and35 conformance
Python tests passed. Rule markers/index/assets/links checked640 live rules;
migration purity was explicitly skipped because no migration-base argument was
supplied. Real contract tests used Foundry1.4.2/Solc0.8.30/Osaka in one shared
isolated output/cache, and existing Lean4.35.0 used one shared Lake output.
Independent adversarial review and independently selected behavioral mutations
completed at every gate. All local commands use pinned source/tool inputs.

### What the green results do and do not tell us

The controls demonstrate that selected errors produce observable failures. In
particular, removing base landing invalidation initially remained green: the
model's assertions observed only SignalService state. Adding raw full base
records and prefix equality made that exact mutant fail; independent corruption
of an older retained record also fails. This is direct evidence that checking
more assertions found a prior verification blind spot.

The current protocol conclusion is limited by the chosen interfaces/workloads.
L1 has a canonical serialized state; actual RPC forks, client/CometBFT/EL restart
interleavings and weighted consensus have not been replayed here. Settlement
proofs are represented by validity/strict-statement mocks. New commitment values
are not all independently recomputed from a separate hash implementation. The
corrective rollback is still a normative interface without a concrete upgrade
implementation under test. C03 explicitly leaves three unmatched profile classes.
Those boundaries can hide real bugs even though every selected run is green.

The broader M09 product remains INCONCLUSIVE;19 larger historical experiment
configurations now exist (previous18 plus this one). Their smaller successful
counterparts are not claimed equivalent. The next discussion should compare
those uncovered boundaries with actual implementation risks and choose further
scopes; this batch does not start them automatically. Artifacts/commits remain
local and the GitHub worklist tracks their unpublished status.

## Third batch in progress (2026-11-16)

The user explicitly authorized the next exactly five increments M10-A/C04/M11-A/
C05/C06. The prior five-increment stopping boundary was respected. SPEC remains
d18357214fab30ea512ae9858a11699806d72ba1 (main content refreshed identical);
real contracts remain89f419915de4b73bb57c53bf970f6dea9e8e8c8c. No production
implementation changes or new protocol defect have been established.

### M10-A — import installation and admission

Forty exact outcomes passed both author and root executions: three exhaustive
normal profiles,27 named mutation controls and10 reachability witnesses. The
normal profiles explore3361/3448/10963 distinct states with empty queues. The
model compares independently captured raw authenticated inputs, complete durable
EL/app/Comet/evidence contents and publication receipts, including origin/genesis
installation, pending/current sets, priorities/proposers, FI and signer fencing.
An independently selected mutation changes only Comet paramsChanged from s+1
to s; TLC reports exactly PublishedStoresAligned, exit12.

Independent full-source/config/document review passed. The model is a thin
standalone interface, not formal composition with M02/M03. The latest target is
fixed per profile; Continue assumes normally validated post-import execution.
Required evidence/ancestor sets are fixed; actual importer, full window/index
implementation, cryptography, power-loss behavior and stock consensus remain
outside scope. See CHECKPOINT_IMPORT.md for mappings and exact controls.

### C04 — literal displaced and withdrawn recovery

Two exhausted frozen M08 profiles generate eight original PublicAttempt
receipts: Displaced/Withdrawn × Mixed/Unheld × None/SecondRegistry. Real public
registration/topUp/requestExit/displacement/forfeit/confirmExit/setOrigin/withdraw
history preserves literal exits93, confirmation95, ready/origin97 and withdrawal98.
Exact50% forfeiture on4 MIN_STAKE units avoids scaling/rounding assumptions.
The adapter checks full selected before/after state, retained identities, FI,
custody, events and independently inventoried filler preservation.

All three actual final Forge tests pass (eight receipts, public-history probe
and genuine UnknownBond recovery), plus11 exporter regressions. Fresh export
comparison and564-entry original-source readback pass. An independently selected
AFTER confirmation95→96 mutation with valid rehashed fixture fails at the real
observer (95 != 96); the fixture is restored byte-for-byte. Independent complete
source/replay review passed.

This closes only the earlier literal Displaced/Withdrawn gaps. The unheld first
forceExit is a no-op; its later failure does not demonstrate tentative-write
rollback (Held C03 already does). Unheld/SecondRegistry succeeds because there
is no second call. Legacy Unzen finalization and landing-proof validity are
explicit test premises; callbacks, real STF/cryptography and full refinement
remain unchecked. All artifacts stay local.

### M11-A — L1 scheduling and historical-anchor observations

The model extends actual EtnaSettlement.Recover with schedule-specific guards/
writes and23 raw programs (38 public calls). Two normal searches exhaust217 and
13680 distinct states, queue0;22 exact mutation controls and10 reachability
witnesses bring the owned selection to34. It separates L1 time/current storage,
valid historical anchor state, candidate L2 timestamp and parent metadata. It
checks strict notice equality, cancellation, failed promotion atomicity, rules0/
next+1 recovery, unknown-rules wait/retry and original-S parent-boundary stop.

Independent review found one model assertion gap: replacing historical schedules
with zero still passed normal CandidateCorrect/AnchorAgreement because both
used the same corrupted history. This is not a protocol defect and does not mean
all earlier controls/witnesses missed that broad mutant. Observer-only raw history
audit now binds every appended and retained record, length/current state and
candidate prefix to actual executed writes. The reviewer rechecked and withdrew
the finding. Root's direct write and older-retained-entry mutants both report
exactly HistoryProvenance, exit12. All34 owned outcomes pass after one fix wave.

The model is finite fixed programs, resolved/authenticated anchor inputs and one
selected candidate/retry per trace; it does not implement real clients/guests,
anchor envelope validation or structural K upgrades. Event data is represented
as five48-bit limbs plus reserved16; C05 independently packs concrete words and
maps normalized notice1 to actual1152 seconds. See RULES_SCHEDULE.md.

### Provenance integrity repair

A final cross-check found the existing top-level pins.json SPEC SHA256 was wrong.
Pinned commit d18357214fab30ea512ae9858a11699806d72ba1 and blob649548c58d6629dd85143b33efd3644a3bb71509
remain unchanged; both previously validated source manifests already contained
the correct digest4d81d5dadcee3eb94ff554ec5a8144a47888dd5a8263ac5852422a0f1d1dd71b.
Only that redundant digest is corrected. A focused regression fails before the
repair and passes after, checking both raw manifest pins, their SPEC SHA/blob and
local SPEC bytes/blob. All17 baseline-helper tests pass; independent review and
root564-entry source verification pass. No source repin or vector regeneration.

### C06 — landing frontier and statement responsibilities

Twenty actual frozen-model scenarios/88 observations replay44 real land attempts
(32accepted/12rejected) and4recoveries. Full selected retained identities and
failed-call equality pass. Two locked actual tests,12 exporter regressions and
fresh model export comparison pass; original564 sources remain unchanged.
Independent full-source/behavior review passed. The root-selected omission of
only FrontierLeafMismatch's require makes the candidate-valid proof mock accept
the bad frontier; the exact frontier assertion fails, and source restoration
passes. Origin/old-generation proof binding is separately labeled under strict
statement mocks. Historical originVal versus fresh execution-genesis distinction
is preserved; real STF/guest/cryptography remains outside this replay. Detailed
normalization, adapter resource repairs and exclusions are in conformance/README.md.

### Stable accumulated model regression

The final accumulated runner completed286/286 exact outcomes with no input drift:
39 normal searches exhausted with empty queues;247 named controls/witnesses
produced only their declared violations. Every current model/config hash was
recomputed against the actual results. All255 baseline TLA/config files remain
byte-identical, including the19 archived incomplete experiments. Original564
contract entries and corrected SPEC digest/blob match. Production-package diff
is empty. Twenty runner tests and640 live rule checks pass; migration purity
is explicitly skipped without a migration-base argument. The final C05 gate is recorded below; the five-increment stopping boundary
has now been reached.

### C05 — concrete rule scheduling correspondence

The frozen M11 PublicAttempt schema yields38 original calls in23 programs. Real
Inbox scheduleRules/scheduleStop/recover execution matches acceptance, full
five-field slot293 and event payload, current origin/counters, retained state
and failed-call equality. Exact normalization uses1152 seconds per notice unit;
stored zero, present origin time0 and cancellation MAX remain distinct.

Three final isolated Forge tests,13 exporter regressions and fresh model export
comparison pass. The root-selected strict <→<= lock mutant is accepted exactly
at RulesLock/2 and fails actual acceptance; the independent event-only stopGrid
shift mutant fails raw RulesScheduleUpdated payload. Restored original source
passes all three tests. Independent complete-source/evidence review passed.
Actual L2 rules/stop behavior, callback locks and real proof execution remain
outside this selected contract projection. Concrete uint48/ABI cases are labeled
supplements, not tiny-model-derived proofs.

## Third five-increment batch: stop and retrospective (2026-11-16)

All five authorized increments M10-A, C04, M11-A, C05 and C06 completed their
local independent-review/behavior gates. **Stop here: no sixth task starts.**
No independently supported protocol/SPEC/production implementation defect was
established on the pinned revisions. No production code was changed.

| Increment | Completed evidence                                                                           | Principal remaining boundary                                                                                      |
| --------- | -------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| M10-A     | 40 exact outcomes; full durable-store/publication checks; root pure-write mutant             | Thin standalone interface; fixed latest target; actual importer/window/index and normal continuation not executed |
| C04       | 8 actual lifecycle receipts,3 actual tests and observer sensitivity                          | Callback gap; imported legacy finalization/proof premise                                                          |
| M11-A     | 34 exact outcomes;23programs/38calls; independent historical-store oracle                    | Resolved authenticated anchors, finite programs and one candidate/retry; actual client/guest not executed         |
| C05       | 38 actual public calls,3 actual tests, strict-lock/event mutants and restoration             | L1 selected projection/list-free recovery; L2 selection and full cryptography not replayed                        |
| C06       | 20scenarios/88observations,2 actual tests; frontier-guard omission causes unexpected success | Strict statement mocks, symbolic execution/genesis and selected bounded records                                   |

The final accumulated TLC run passes286/286 exact expected outcomes:39 normal
searches exhaust with empty queues and247 controls/witnesses violate exactly
the declared invariant. Current source/config hashes match every result. All255
baseline TLA/config files, including19 incomplete historical experiments, remain
byte-identical. Integrated Python checks pass72 conformance+20 runner tests;
640 live rule references/index/assets/links pass, with migration purity explicitly
skipped. All8 selected new actual Forge tests pass against pinned sources in one
existing cache. No duplicate Rust target, new SDK, publication or deployment.

### Why this still does not establish a perfect protocol

Independent mutation exposed a genuine verification blind spot: historical
snapshots initially served as both data and oracle. Normal exploration passed
even when those schedules were written as zero. A separate raw history audit
now catches both new-write and older-record corruption. Existing witnesses could
already detect some broad mutations; the claim is specifically about the missing
normal invariant. The wrong redundant SPEC digest was also repaired while its
commit/blob and both source manifests remained correct. Test-adapter type/blob/
gas-accounting issues were repaired separately, and overlapping-cache diagnostics
were excluded from the evidence. None was a production protocol finding.

The selected real public calls agree with the finite model workloads, and
intentional guard/write omissions are observable. Broader protocol bugs can
still hide in omitted interleavings, concurrent changing targets, actual RPC/L1
views, client/CometBFT/EL persistence, untested callbacks, actual guest execution
and proof soundness or unavailable importer/migration APIs. The models are not a
fully composed product and the adapters are not universal refinement proofs.
Those explicit boundaries, rather than a claim of perfection, explain why this
batch can be green. No further scope is started before the user's retrospective.

Artifacts and commits remain local on codex/etna-tla-settlement; the existing
GitHub worklist records exact pins, bounded completion evidence and limits.

## Fourth batch in progress: verify the verification (2026-11-16)

Baseline aed1b861e; same SPECd18357214fab30ea512ae9858a11699806d72ba1 and
contract89f419915de4b73bb57c53bf970f6dea9e8e8c8c. The user authorized exactly
V01fault campaign, V02inputs, V03success publication, V04progress, V05handoff.
Stop on confirmed actual protocol/source problems; repair verification defects
separately and stop after five. No production-package change or publication.

### V01 — reproducible fault campaign

`sensitivity/run.py` implements versioned manifests/external runtimes, temporary
exact source replacements, complete baseline/mutated/restored execution, full
Forge test identities, sole-property temporal identification and raw-log hashes.
Only intended semantic failures count as KILLED. Empty/skipped tests, parser or
runtime errors, unrelated failures, timeouts, input/dependency drift or failed
restoration are INCONCLUSIVE. Surviving faults and unassessed obligations remain
explicit; default readiness requires the selected required obligations killed.

The actual initial EL-binding and disabled-Connect faults each preserve all40
original expected outcomes in baseline/mutated/restored phases. The source-only
SignalService-publication omission preserves all11 selected C02–C06 tests in all
three phases. All three correctly report SURVIVED, ready=false and nonzero CLI
status. Corrected-runner focused TLC and real Forge11×3 readbacks confirm the
classification. These diagnostic results do not claim the holes are repaired.

Fifteen focused runner tests and independent review pass. Two independent P2
runner defects were fixed in one wave: separately-sessioned descendants could
survive timeout, and changed dependency directories could remain reported stable.
The reviewer reran both concrete probes; descendants now stop promptly without
killing an unrelated process, and dependency drift invalidates readiness. Raw
logs/argv persist promptly and compact JSON avoids duplicated full Forge traces.
Code/tests/manifest were relocated byte-identically from ignored generated
coverage directory to tracked sensitivity source; new-path tests/actual TLC
readback pass. The pinned564 source inventory remains unchanged.

This is a finite reviewed inventory/tool, not a claim that all faults have been
enumerated. V02–V05 remain pending at this point; no sixth task is started.

### V02 — discriminatory import inputs

Raw16–24 add wrong downloaded EL, coherent wrong state/recomputed root, unbound
entries/window, legal alternate second-set metadata, an isolated next-set
contradiction and missing-finality/package/header-auth contradiction qualifiers.
Original0..15, all operational/observer definitions after Raw, and40 original
import configs are byte-identical. Five focused normal configurations supplement
the original workloads; no production change or hash/crypto implementation.

The root's actual sensitivity campaign runs19 selected guard/prerequisite
deletions on the published model. All57 phases complete: each original/restored
workload passes and each mutant fails exactly ClassificationCorrect at Classified
depth2, before publication. Inputs remain stable and the selected campaign is
ready. The independent reviewer verified all seven files, SPEC classifications,
exact raw-log hashes and the stage of every failure. No material finding.

This fixes both missing inputs and guard masking: old next-set contradiction
also violated derived membership; a coherent changed preimage/entry input now
exercises the header-next mismatch alone. Finality/package/header-auth prerequisites
and the origin exemption also have separate false-halt discriminators. Authenticated
chain/height corner cases remain explicitly unassessed; the matrix is finite, not
a proof that all input combinations/classification premises are complete. Full
accumulated regression remains a final-batch gate.

### V03 — successful cross-contract publication

A shared original-input observer now checks SignalService(height,EL,stateRoot)
and Inbox active snapshot after every successful selected land/setup. Prior
model and abort comparisons remain. A real public topUp11/activate21/land22
probe changes snapshot1→21. Full12 normal/restored tests pass. Three source-only
faults fail exactly at the intended publication assertion: omitted checkpoint,
nonzero wrong root312→313 and omitted snapshot. Minimal one-test mutation scope
is explicit; the full12-test gates and existing Settlement missing-write failure
are recorded separately. Original564 source entries and six owned hashes match;
independent source/behavior review passed with no material findings. Initial
committee/guest/anchor/proof validity remain mock premises. See conformance docs.

### V04 — connection capability and conditional progress

M10 gains only eight observer lines; all actual actions/default specification and
45 existing import configurations remain unchanged. A thin EtnaImportProgress
companion adds typed action labels for TLC fairness evaluation. Labels do not
enter old guards/data; every genuine internal action changes a typed projection
field, and weak fairness still refers to the actual action. This avoids TLC
heterogeneous Empty/record equality failures without changing old state encoding.

Enabledness/positive witnesses detect disabled Connect. The stronger sole
ConditionalStableConnection property requires eventual stable connection under
fixed correct/available input, fixed target/generation, fair internal checks and
stores/restart/admission/connection, and optional at most one existing crash.
Latest4→4 and older4→6 normal temporal searches pass. Disabled and no-effect
Connect mutations fail the intended invariant or temporal property; no-effect
Connect deliberately remains ENABLED, so enabledness alone cannot certify progress.
Three selected campaign obligations and nine focused safety/witness checks pass.
The independent reviewer inspected actual lassos and independently disabled only
ReadTarget: the older profile reaches a fair disconnected suffix and violates
the sole property. That extra obligation is included in the final inventory.

Independent semantics/fairness review passed. Trusted normal continuation,
resource availability and a stable generation remain explicit premises. There is
no actual client/CometBFT/EL progress, perpetual-crash recovery or unconditional
network/throughput theorem. Temporal tool/setup errors were INCONCLUSIVE, never
counted as kills. The final integrated published-source campaign below passed.

### V05 — held-candidate schedule/recovery handoff

Two bounded normal programs, six exact negative controls and eleven existence
witnesses pass. Six direct source mutations fail their declared historical
derivation, identity, at-exposure signing or proof-generation invariant, with
normal/restored inputs passing. Independent review inspected support before
recovery, after recovery before knowledge, knowledge before support, and a valid
pre-knowledge signature retained after authentication. Historical validity is
separate from current signing authorization and current L1 proof acceptance.

The companion calls the actual existing M11 Setup/PrepareCall/Invoke actions.
Only a HandoffRecovery raw fixture and NeedsLanding entry are added to M11. C05
retains identical 23 programs/38 payload calls; its model SHA/content hash alone
are refreshed. The signature oracle captures knowledge at exposure; comparing
old signatures to later knowledge would create a false finding. The proof is an
otherwise-valid opaque queued-proof premise, not generated from the candidate.

Both selected programs use stopTime=0. Positive stop and stop-clear/recovery
composition is explicitly UNASSESSED; existing independent M11 stop tests cannot
stand in for that composition. No actual protocol/production defect was found.
Independent per-task review passed; integrated campaign/replay evidence follows.

## Fourth-batch final verification and retrospective — 2026-11-16

Exactly five increments V01–V05 are implemented locally. No sixth increment is
started. Baseline is `aed1b861e9dfa9b03f2700837bb8e437be55082c`; the reviewed
implementation head is `0343ddd99` on `codex/etna-tla-settlement`, not pushed.
Final documentation-only commit is recorded in the GitHub worklist #22355.
SPEC and concrete contract pins stated above remain unchanged. No production
package was modified. Independent per-task and whole-batch reviews apply to
these bounded verification changes, not to the complete protocol.

### Fresh accumulated gates

- `check.py` with the pinned Java/TLC: **314/314** exact expected outcomes;
  48 normal searches exhaust with queue0, 266 controls/existence witnesses fail
  only their declared invariant. All recorded source/config hashes match current
  files. Original286 default configs and all43 archived experiment files are
  byte-identical to the batch baseline;19 historical incomplete profiles remain
  incomplete, not reclassified by the green default suite.
- `sensitivity/run.py` with the full checked-in inventory: **32 required faults
  KILLED**, all normal/restored phases accepted, all inputs stable. All105
  executed workload logs were independently rehashed. Four inventory entries
  remain explicitly UNASSESSED. The ready flag applies only to this selected
  required inventory and is not protocol-wide readiness. Temporal latest/older
  baseline/restoration searches are included; disabled/no-effect Connect and
  disabled ReadTarget violate the sole declared stable-connection property.
- Full real-contract isolated replay: **12/12 selected test identities pass**,
  using the single existing physically locked Foundry out/cache. This includes
  current C05, all38 calls, and the genuine public checkpoint21/snapshot switch.
  The564-entry source inventory and original/copy/formal inputs remain stable.
- Fresh `export_rules.py --check`:38 actual calls/23 programs reproduce the
  current fixture. Only model provenance and content digest differ from the
  previous fixture; C05 SHA256 is
  `ef6fe8ada1fe11b35497bc746ff3de1e6a7d149acaf8c190b56fae2d229fc0ae`.
- Python unittest discovery:20 runner +72 conformance +15 sensitivity =**107
  passing tests**. Rule checker:640 live markers/index/assets/links pass;
  migration-purity explicitly SKIPPED without a migration base.

Run the three Python suites with `python -B -m unittest discover -s` followed
by `formal/etna/tests`, `formal/etna/conformance/tests`, or
`formal/etna/sensitivity/tests`. Use `check.py --java <pinned-java> --tlc-jar
<pinned-jar> --output-dir <evidence>/default`; then `sensitivity/run.py
--manifest formal/etna/sensitivity/mutations.json --runtime <external-runtime>
--output-dir <evidence>/campaign`. The runtime supplies local source/tool/cache
paths rather than embedding machine paths in tracked files. Full replay uses
the inspected `conformance/run_isolated.py` read-bind argv, current adapters
and vectors, exact12 expected test IDs, offline pinned Forge/Solc and the common
physical cache lock. Raw result JSON, argv sidecars and logs are retained in the
author's local evidence directory; worklist updates identify the final local
commit without pretending it is a published GitHub commit.

### Why previous green results missed faults

1. **Inputs were insufficiently discriminatory.** The old40 import checks lacked
   a wrong downloaded EL hash and coherent contradictory bundles. New raw inputs
   distinguish rejection/wait/halt and kill19 selected guard/prerequisite faults.
2. **Success was incompletely observed.** Existing replay assertions allowed a
   missing SignalService publication. Shared observers now compare its complete
   tuple and Inbox active snapshot against original input after successful land.
   Missing publication, nonzero wrong root and missing snapshot all fail exactly
   the new success observer. The existing upstream unit already caught missing
   publication; this was a conformance-lane gap, not a newly discovered bug.
3. **Safety did not establish progress.** Disabled Connect preserved every old
   invariant. Enabledness/existence and conditional temporal progress are now
   distinct. An enabled action that does nothing still fails eventual stable
   connection; fairness is not used to assume successful connection.

V01 independent review also found and repaired two verification-tool defects:
nested isolation sessions survived timeout/cancellation, and read-bound
dependency directories were absent from drift checks. Original repros were
rerun independently after the fix. Parser/runtime/setup errors, empty selections
and wrong assertion failures remain INCONCLUSIVE, never semantic kills. A root
metadata-schema typo and temporary replay-driver missing path were corrected
before semantic execution; neither counts as a successful test or protocol finding.

### What remains outside the result

No independently supported protocol/SPEC/production defect was found. A green
finite selected mutation inventory does not show model completeness, unbounded
safety or implementation equivalence. Four explicit unassessed categories are:
remaining protocol obligations; individually discriminating wrong trusted
chain/height bindings; branch-specific contradiction authentication removals;
and positive-stop/stop-clear candidate-handoff composition. Both handoff
programs here use stopTime0.

Actual client/importer/CometBFT/EL crash and network behavior, weighted consensus,
real proof/STF/guest and committee/genesis validity, concrete corrective-upgrade
migration and broader products remain separate obligations. Trusted normal
continuation and fixed correct available inputs underpin the temporal result.
Source replay uses statement-bound verifier mocks and selected concrete traces,
not a universal refinement theorem. The next discussion should prioritize those
assumption boundaries and missing compositions; no next task starts automatically.

## Verification takeover — positive-stop composition, 2026-11-16

The user authorized continued verification after the previous five-task stop,
then requested a published branch without a PR. Baseline `2fbe8b366` was pushed
to `codex/etna-tla-settlement`; this increment continues that branch. Earlier
local-only and stop-after-five statements above describe the previous batch.
SPEC and actual-contract pins remain unchanged. Production code, normative
documents and the GitHub worklist were not edited in this increment.

### Confirmed blind spot and bounded repair

An independent takeover experiment disabled historical stop decisions. All 19
previous handoff outcomes still matched, while the original M11 observation
workload detected the same fault. This independently confirms the declared
positive-stop coverage gap; it is not an actual protocol defect.

Three new raw Stop/Rules/Recover programs reuse the existing public action engine.
With S6/K6/c12 and stopGrid12, due/future parents are unlanded parent18/time2;
off-grid uses parent13/time2. Future stopTime3 equals candidate time3 but is after
parent time2. These choices distinguish original-start grid alignment and
parent-time stop semantics without retimestamping the landed checkpoint12.
Support, recovery and authenticated generation knowledge can occur separately.
The retained candidate keeps its historical identity and stop decision after
recovery clears the live stop. Stopped candidates cannot sign; an earlier legal
exposure stays historical after knowledge advances. The original opaque queued
proof experiment remains separate: no proof of a stopped candidate is fabricated.

There are 25 new configurations: three normal searches, 21 existence witnesses
and one public-receipt export. A separate exporter profile produces nine real
public calls from three programs. One additional Solidity replay test invokes
the actual pinned Inbox methods using the existing state/event/abort observers.
All 314 previous configs, 43 archived experiment files and original 38 C05
semantic payloads remain unchanged; model provenance/content digests are refreshed.

### Integrated evidence

- Fresh accumulated `check.py`: **339/339 exact expected outcomes**. All 52 normal
  searches exhaust with queue0; the remaining 287 controls and existence witnesses
  match their declared outcomes. New due/future/off-grid normal
  searches exhaust 1,922/584/584 distinct states. Root independently rehashed
  every recorded model/config input against the final files.
- Complete assessed fault inventory: **41/41 required faults KILLED**, executed
  as compatible TLC36 /Forge Identity3 /Forge Rules2 cohorts. The selected IDs
  cover the assessed required inventory exactly once; all 44 workload executions
  per phase pass normally and after restoration, and fail at their declared
  semantic targets when mutated. Source/tool/input identities and every raw log
  hash are stable. Aggregate SHA256:
  `2a2050493e404ff75884b0774f0290d39cf6d285109f9e01c7e268436f36e5af`.
  This assesses the selected inventory only; the four explicitly unassessed
  inventory entries retain their documented limits.
- Full isolated real-contract replay: **13/13 exact selected test identities**
  pass, including the original 12 and new nine-call stop-handoff replay. Original
  564 source entries and copied/formal inputs are stable; one existing physically
  locked Foundry cache is reused. Fresh original 38-call and new nine-call exports
  reproduce the fixtures exactly.
- Final Python discovery: **20 runner +78 conformance +20 sensitivity =118 tests
  pass**. Rule checker:640 live markers, index, assets, links and tables pass;
  migration-purity is explicitly skipped without a migration base.
- Independent behavioral checks detect an operational held-parent-time corruption
  while the raw audit remains unchanged, and an actual Inbox recovery fault that
  clears stopTime but leaves stopGrid. Original/restored phases succeed. These
  checks supplement, rather than replace, the declared fault inventory.

### Independent review and repairs

Two material findings concerned verification machinery. Both are distinct from
protocol/SPEC defects.

1. The initial pre-knowledge witness could be satisfied by an exposure made before
   recovery and retained afterward. Two new stop-specific observers now bind the
   exposure's own generation1/floor0, with a separate later-knowledge preservation
   check. The original reviewer independently denies every allowed post-recovery
   exposure: normal/restored executions reach the exact intended witnesses, while
   both faulty searches exhaust 584 states without those witnesses. This explicit
   reachability-loss regression is not mislabeled an invariant-failure kill.
2. Existing Identity and new Rules fault entries require disjoint exact Forge
   test sets, so one fixed runtime cannot execute the full mixed manifest. The
   portable cohort descriptor partitions every assessed required obligation into
   compatible TLC/Identity/Rules groups. Five focused regressions reject missing,
   duplicate, unassessed and incompatible selections. Execution must supply an
   explicit compatible runtime and `--only` IDs for each group; exact test-set
   validation remains strict and a subset-ready flag is not full-inventory success.
   The original reviewer independently verified all 132 raw phase logs, exact
   semantic/test identities, source/tool hashes, mutant replacements and full
   aggregate; no material finding remains. Reproduce the grouped procedure in
   [sensitivity/README.md](sensitivity/README.md) using the checked-in descriptor
   and external runtimes; do not reuse the earlier single-runtime full command
   for the current mixed manifest.

Separate harness attempts were inconclusive, not semantic evidence. A disposable
namespace driver inherited ignored SIGINT/SIGTERM dispositions; restoring normal
dispositions only in that driver makes the unchanged cancellation tests pass.
A rule-check attempt initially omitted the referenced sibling Derivation document;
mounting the complete existing docs read-only resolves that setup error. No test
assertions or repository launchers were weakened. Earlier interrupted/superseded
and parser/selector/setup failures are not counted as passing gates or fault kills.

### Remaining limits

No independently confirmed protocol/SPEC/production defect was found. This closes
positive-stop composition for three finite programs, not all stop/recovery products.
The historical unassessed inventory entry retains that distinction. The 19 archived
incomplete profiles remain incomplete. Actual client/importer/CometBFT/EL behavior,
real STF/guest/proving, weighted consensus, initialization validity, structural K
upgrades and unbounded refinement remain outside the result. Authenticated anchors,
valid parent metadata, statement-bound verifier mocks and trusted normal continuation
remain explicit premises. No deployment, merge, PR or Notion/worklist write occurred.

## PR22387 feedback repair — fresh recovery fixture, 2026-11-16

External review of baseline `4c8b96c93` exposed a concrete violation of an assumed
fixture premise. The old `ObserveFresh` constructs parent12/time3 with candidate
time4 after recovery origin12/time3. Independent reproduction on all four
recovering normal profiles confirms that the old invariants pass and the actual
fresh receipt is accepted; a separately supplied raw parent/first-block oracle
rejects each profile with the intended invariant failure.

**Correction to the earlier interpretation:** the prior314/339 numerical expected
outcome counts remain historical execution facts, but their fresh-recovery witness
does not establish a valid protocol continuation. That conclusion is withdrawn
for the old fixture. L1 method replay does not execute CometBFT's first-block
validation and cannot fill this gap. Calling complete block validity an environment
premise cannot justify an input that contradicts that premise.

The missing checks were concrete: FreshIdentity checked generation and anchor,
but omitted first-block time and the retained parent's original timestamp;
ValidCandidate checked parent-before-child and anchor age, but omitted this
genesis boundary. The earlier fault inventory did not mutate these inputs.
Independent review used the same abstraction boundary and missed the contradiction.
Repeating those checks unchanged would still pass.

Pinned RECOV-8.4-7/10 fixes the first block's BFT time to R.timestamp. CONS-3.2-3
separately fixes EL time to max(parent+1, BFT time, anchor time). Under the explicit
retained parent12/time1, recovery3 and anchor3 fixture, both times are3. Recovery
must not retimestamp the retained parent. The repair constructs that exact bounded
candidate and adds a separate raw-input audit binding parent, time, generation,
origin and exact recovery anchor. Three source faults target candidate time4,
parent time2 (still below the candidate time), and wrong parent18. Validation and
publication evidence for the repaired source follows.

### Repaired-source evidence

- Author oracle-first RED rejects the unchanged old constructor in all four
  recovering normals, exactly at FreshIdentity. After repair, all43 existing
  handoff configs match their declared outcomes, including fresh positive
  witnesses. All339 config files remain byte-identical to the reviewed baseline.
- Root's fresh full regression: **339/339 exact expected outcomes**, with52
  exhausted normal searches and287 named controls/existence witnesses. Every
  recorded model/config hash matches the repaired files. Root's118 Python tests
  and640 rule-reference checks pass; migration-purity remains explicitly skipped.
- Complete compatible fault campaign: **44/44 assessed required faults KILLED**,
  selected exactly once across39TLC/3Identity/2Rules cohorts. There are56 workloads
  per phase: all originals/restorations pass and all mutants fail at their exact
  declared semantic targets. All168 raw logs and source/tool/input hashes are
  checked independently. Aggregate SHA256:
  `c4bc74b554293388c5eefafdbf09601d9126343da0660d7e03266108992b7298`.
- Independent behavior verification runs20 trials across the four recovering
  profiles. All12 normal/restored trials exhaust and emit actual candidate3,
  parent12/time1, generation1, origin12/time3 and the correct anchor. An external
  checker uses raw recovery args/context and historyAudit, not freshAudit, to
  check these values. All8 separate time/parent-time mutants fail FreshIdentity;
  parentTime2 stays below candidate3, so the fault does not merely disable the
  witness. A new independent reviewer additionally detects wrong generation,
  copied origin block and copied anchor origin, and checks that disabling the
  fresh action loses the required witness and is rejected by exact classification.
- All32 existing conformance inputs and their actual replay/exporter code remain
  byte-identical. The earlier13-test real-contract and38/9-call export evidence
  is retained for those same inputs; those unchanged gates were not rerun or
  relabeled as fresh executions. The fault cohorts still execute their selected
  actual contract tests and verify all564 original contract entries before/after.

Frozen repaired model SHA256:
`6421a398dfa10efb2f6b9ee066c83e239bf44a42d22d18b7461047e21f0f3487`.
The453-file execution manifest SHA256 is
`4bb7afc0ddc612d5c67bdb4d888b2e3d8450d7873025c443114cf970efd8c853`;
later REPORT integration is a reviewed prose-only delta. The original external
feedback is addressed by this scoped repair; historical counts are not erased
and no whole-protocol or actual-client proof is claimed. No production/SPEC,
deployment or merge change is included. The PR stays draft for continued review.

## Three-increment batch after review repair — T01

R0 was published at `d1206bb07` before this new batch. T01 makes first-block BFT
time and EL timestamp distinct in a small deterministic companion. At fixed
origin12/R103/time3/generation1, the three literal cases produce:

| Retained parent time | Anchor number/time | First BFT time | EL timestamp |
| -------------------- | ------------------ | -------------- | ------------ |
| 1                    | 103/3              | 3              | 3            |
| 3                    | 103/3              | 3              | 4            |
| 1                    | 104/4              | 3              | 4            |

These cases satisfy the selected RECOV-8.4 and CONS-3.2-3 timestamp premises.
They do not execute parent/origin authentication or an STF history. The audit is
a separately written literal table, never the constructor or its maximum helper.
It binds complete raw input and observed header metadata. Enabledness, three
required existence witnesses and three actual exported receipts prevent safety
from passing solely because nothing was constructed. Preparation is observation
staging, not a protocol action or fairness assumption.

- All6 new configs match their exact declared outcomes. Independently collapsing
  EL to BFT fails on both valid EL4 cases. The339 old configs and28 old TLA files
  remain byte-identical; the full accumulated batch regression is still a final
  gate, not inferred from these focused runs.
- All5 new selected source faults are KILLED, with6 workloads per phase and18
  original/mutant/restored logs checked. Original/restored outcomes succeed;
  mutants fail only their exact ObservationExact or ConstructionEnabled targets.
  Existing44 assessed IDs/selectors are preserved. The shared manifest now has49
  assessed required IDs; a full49-item campaign is not claimed at this point.
- Fresh TLC export reproduces exactly3 receipts. Eight new exporter tests cover
  missing/duplicate/unexpected records, source/provenance drift and rehashed
  altered raw/clock fields against fresh output. Root's126 Python tests
  (20runner/86conformance/20sensitivity) and640 rule-reference checks pass.
  Migration-purity remains skipped without a migration base.
- Independent behavior verification freshly exports and literally audits all raw
  and header fields, checks all3 positive witnesses, and changes constructed
  origin metadata while leaving clocks intact: ObservationExact fails. Disabling
  preparation leaves safety vacuously green but loses all3 required witnesses and
  receipts; those exact gates reject it. Restored runs reproduce the same data.
  Independent review also challenges raw parent binding, constructed parent
  binding, disabled construction and both collapsed-clock cases. No finding.

Final model SHA256:
`7a963ec9d4c5c5394763e59f4918dec9ce90afa387db0c1c2968b8a9376681b6`;
fixture SHA256:
`ac047ee026a0e97f8db54a514a52d6638a3660bcaeba6e2265e9a405bfd07735`.
The final5-fault campaign SHA256 is
`5c980ecdd6918bea9f39932c3dccefb40cc77027a35fca3dd29e01a7cac4f439`.
Final formatting changed only inventory whitespace and Markdown table alignment;
parsed inventory, models, configs, exporter and fixture stay unchanged. The
selected campaign and20 sensitivity tests were rerun on those final bytes.
Initial unsupported initial-state-failure formatting and a namespace SPEC-path
omission were inconclusive setup attempts, not semantic kills. A read-only file
mode copied into a private mutation target was also an inconclusive preparation
error; a byte-identical writable staging source with read-only execution binds
resolved it without changing the shared runner or sealed snapshot.

T01 covers finite integer-second construction and export with explicit input
premises. Actual CometBFT admission is T02; actual EL execution, fractional-time
behavior, cryptography and unbounded consensus/progress are not established.
T02/T03 and the final three-item retrospective remain pending here.

## Three-increment batch — T02 stock CometBFT boundary

T02 consumes the exact T01 receipts in a separate Go adapter and calls stock
CometBFT v0.40.0 `BlockExecutor.ValidateBlock`, commit
`0880b4d378f347ab16e54ec677ff50d803f37d62`. All1,659 source files match the
official commit tree by Git blob identity, size and SHA256. Source/license,
module origin and tool requirements were inspected; public dependencies were
prepared separately, followed by offline execution using the existing SDK and
shared caches. Original module sources remain read-only. Separate Comet pins
preserve the existing contract/Lean pins.

- Seven exact native subtests pass in both normal and actually restored source:
  the three BFT3/EL3 or BFT3/EL4 receipts, wrong BFT time, wrong initial height,
  retained block ID and nonempty first commit. Each validation uses a fresh
  upstream executor to avoid its validated-block cache. Negative controls reach
  their intended upstream errors; BFT time tests both +1 second and +1 nanosecond.
- Removing only the actual upstream initial genesis-time equality check in a
  private copy makes exactly wrong-bft-time fail, with both offsets admitted and
  the evidence check reached. The six other tests pass. Normal/restored trials
  each return0; the mutant returns1. Source restoration changes the same private
  copy back and verifies all1,659 original entries before running it again.
- Independent verification reproduces the native campaign and changes the
  adapter to use EL time as BFT time: exactly the two EL4 cases fail at the
  genesis-time check. All other native cases pass. This challenges the adapter
  wiring independently of the TLC construction.

Two material review repairs strengthened the new controller before publication.
The first recorder checked test identities/statuses but could count an unrelated
failure as the intended mutation kill. It now requires both ordered native time
diagnostics and evidence-check observations; six altered actual logs and focused
regressions reject missing, duplicate, single-offset and unrelated failures.
The second repair reuses the existing authoritative sensitivity supervisor:
caller cancellation previously could leave the independently sessioned namespace
workload alive. Five controller cases now check TERM, group TERM, INT, caller
SIGKILL and timeout, with every owned descendant gone and an unrelated sentinel
alive. An independent actual-Go TestMain probe passes the same five modes. Root
rechecked the committed controller suite against the original failure path.

The final preflight also resolves physical aliases, rejects cache/output nesting
or equality, and protects the whole formal source tree and every watched input
from writable aliases. The canonical campaign layout was already disjoint; the
guard closes unsupported CLI layouts. Seventeen core tests and the five separate
host-controller tests pass on the final bytes. Independent source review and
unmocked entrypoint probes confirm rejection before execution preparation. The
reused supervisor and Go adapter remain unchanged by this last layout repair.

Execution schema2 stores combined stdout/stderr as UTF-8 replacement-decoded,
re-encoded text, with its digest and exact supervisor command. It does not claim
separate raw streams. Initialization/cleanup result125 fails closed. The final
campaign checks watched input, tool and source identities before/after and
records log digests, independently read back. Reproduction and the mandatory
separate controller lane are documented in
[`conformance/COMET.md`](conformance/COMET.md).

This is selected stock single-block header/time admission. Seeded application
state, a public-only validator point and empty evidence are explicit premises.
EL/anchor/generation metadata is opaque transaction data. No actual Etna EL/STF,
committee derivation, key mapping, authenticated recovery history, signatures,
proofs, consensus rounds/locks or network progress is established. No protocol
defect was confirmed. T03 and the final accumulated three-item gate remain.

## Three-increment batch — T03 contradiction authentication

T03 adds three raw negative inputs and five focused M10 configurations without
changing `Authentic`, `ProvenContradiction`, `Decision`, `ObservedClass` or any
action. Raw0..24, all345 prior configs and49 prior assessed fault entries remain
unchanged. The five new required faults join the existing TLC cohort; the
inventory now partitions54 assessed IDs as49TLC/3Identity/2Rules. An old aggregate
unassessed entry retains its identity/flag and clarifies the remaining concrete
authentication, cryptography and window-reconstruction boundary.

Raw25 changes the first validator preimage and matching peer entries without
rebinding any L1 commitment. Raw26 changes only the second preimage set. Raw27
combines bound conflicting entries with an unbound peer window. These corrupt
candidate inputs must be rejected; none establishes an authenticated conflict
or a valid STF history. Healthy raw0 accompanies each negative input.

- Pre-edit diagnostics showed envelope/registry guard omissions already fail
  on old inputs, while both preimage omissions and the window omission survive
  the complete old raw0..24 union. These are verification-input gaps.
- All5 new source faults are KILLED by the shared campaign:15 actual phases,
  successful normal/restored searches, and only `ClassificationCorrect` failures
  for mutants, each at the two-state Check-to-Classified false-Halt boundary.
  All source/config/tool and execution-log identities are checked.
- Independent behavior verification runs56 small boundary trials: normal and
  restored singleton inputs, explicit classification reachability and a five
  fault by six input matrix. Only the intended corrupt input fails under each
  fault; healthy0 and every off-target input pass. Literal audits check the
  actual raw preimage/entry/window fields and L1 commitments independently.
  Separate old-domain trials reproduce the three survivors; three authenticated
  contradiction inputs still reach Halt as intended negative-classifier witnesses.
- Independent review verifies the complete old raw and operational/oracle byte
  preservation, exact unique fault sites, cohort coverage and SPEC classification
  correspondence. Its separate literal classifier run exhausts with raw0
  Verified and raw2/18/25/26/27 Reject; healthy raw0 can reach trusted admission.

The focused campaign uses immutable v1 inputs. Final v2 changes only a stale
documentation row that still called these finite guard omissions unassessed;
all execution inputs remain byte-identical. An initial Python cleanup-test run
inherited ignored SIGINT/SIGTERM and was inconclusive; restoring the standard
signal dispositions in the disposable entrypoint yields20/20 passing unchanged
tests. No runtime helper was modified to make them pass.

No concrete importer, crypto or proof validity is established. The symbolic
hash constructors and fixed trusted chain/height/window domain remain explicit
premises. This completes the third technical increment; accumulated final gates
and the three-item retrospective are reported separately below when complete.

## Three-increment batch final gate and retrospective

Date: 2026-11-16. Exactly T01, T02 and T03 complete this batch after the R0 review
repair. The final accumulated executions use one stable478-file snapshot; later
differences are reviewed prose only in REPORT, CHECKPOINT_IMPORT and the current
sensitivity cohort-count table. No execution model, config, runner, receipt,
source pin or tool changed after the freeze.

| Gate                         | Measured outcome                                                                                       |
| ---------------------------- | ------------------------------------------------------------------------------------------------------ |
| Default TLC suite            | 350/350 exact outcomes:58 exhausted normal searches,292 named controls/witnesses                       |
| Shared source-fault campaign | 54/54 assessed required IDs KILLED, partitioned49TLC/3Identity/2Rules                                  |
| Shared phase evidence        | 67 workloads per phase,201 checked original/mutant/restored execution logs                             |
| Ordinary Python suites       | 20runner+103conformance+20sensitivity=143 passing tests                                                |
| Separate controller lane     | Five cancellation/timeout cases pass; independent actual-Go five-mode probe also passes                |
| Rule references              | 640 live markers; index/assets/links/tables pass; migration purity explicitly skipped                  |
| Recovery-time export         | Three fresh actual TLC observations match the committed fixture exactly                                |
| Stock CometBFT boundary      | Seven exact tests pass normal/restored; the private source fault loses only both wrong-time rejections |

Root reclassifies all350 default logs and checks model/config/source identities,
not just the runner success flag. An independent stdlib-only artifact audit
separately checks every default outcome and all201 shared phase logs, exact
semantic/test failure identities, reconstructed single-site mutant bytes,
cohort coverage, tools and input stability. A fresh whole-batch reviewer inspects
the complete three-commit implementation diff, actual upstream Comet sources,
focused receipts/counterexamples and accumulated evidence. No material finding
remains; a stale top-level cohort table was corrected during final prose review.

Execution snapshot manifest SHA256:
`24136dbe42acdf98934a76635d46c2e839afa3159d9d5db1e537bbb6d4e06925`.
Default results SHA256:
`39957003e8fae9003655ca44a2b17db0e1a82a7dd59110cdadb16f8b0aaf2347`.
Shared cohort aggregate SHA256:
`cf2a3001bd18b2a3dfa8bf7fa01d51cd0ed2eb04885fd6803e8fb392f7de6235`.
T02 final native campaign SHA256:
`0413ab38dafa05e319e9a333a214858c818fd0e10d00615779a55b1c48a8fe96`.
Existing unchanged13-test Solidity and38/9-call export evidence is retained as
historical, with exact consumed input identity; those complete gates were not
rerun or described as fresh. The two selected real-contract test identities do
execute normally, under fault and after restoration in the current shared cohort
campaign. Original564 contract source entries remain unchanged.

The original self-check failure was a shared omission: the constructor, fixture
assumptions and assertions agreed with one another without checking every
successful witness against the normative clauses. A missing genesis/retained
parent relation escaped that loop. This batch also exposes input masking:
three removed import-authentication guards survived the old input domain. The
recorder and process-lifecycle repairs show why the verification tools need
their own wrong-reason, cancellation and input-alias controls. Repeating the
same green suite would not have found a property it never checked.

The resulting evidence is stronger at these selected boundaries. It still does
not establish full Etna App/EL/importer integration, authenticated STF history,
actual proof generation or proving latency/backpressure, weighted consensus,
network progress or whole-protocol refinement. The19 archived incomplete
profiles remain incomplete. BFT/EL clocks, finite negative classification and
stock header admission are explicit scopes, not substitutes for those gaps.
No confirmed production/SPEC defect was found. This batch stops at three for
retrospective; the authorized hourly PR-feedback monitor continues without
starting a fourth increment. The PR remains draft.

## Five-increment boundary batch — F01 positive import premises

The user authorized five further increments after56fc86d48. F01 starts by
reproducing two invalid positive M10 premises, rather than expanding green counts.
The non-origin height4 header had time40 although generation1's first height3
must use genesis time100 and later stock block times increase. The origin fixture
also reused landed `First.proposer=2` as genesis proposer. Pinned stock
`MakeGenesisState` instead stores proposer1 with priorities[-2,2], then proposer2
with[1,-1] for its next set. A bounded offline Go probe with public B/-B points,
no signing material, confirms those selected fields; manifest checks verify
all1,659 pinned source files remain unchanged.

Independent appended checks fail on the actual old Published boundary for each
defect, while the prior normal and successful-trust witness still pass. The old
M10 results remain historical conditional transition checks; they did not
establish these usable initialization/chronology premises. Those stronger
successful-fixture claims are withdrawn and corrected here.

F01 sets the selected non-origin time to102 and corrects only the origin genesis
first proposer to1. Origin's retained old-generation header remains time20 and
the non-origin landed proposer remains2. A separately written literal
`PositiveImportPremises` audits raw origin/header fields and actual selected
Comet/app publication fields without calling constructor or store-oracle helpers.
The old350 config bytes, old54 assessed fault entries, four unassessed entries,
other models and existing conformance payloads/pins remain unchanged.

- All61 affected import configs match their exact outcomes:18 exhausted normal
  searches and43 named controls/witnesses, including seven new focused configs.
- Both exact new source faults, canonical time40 and origin first proposer2,
  fail only `PositiveImportPremises` in their declared audit workloads; original
  and actual restored source exhaust successfully. The full healthy profiles
  preserve the existing invariants; the chronology fault's focused workload
  isolates this audit from the older literal store comparison.
- Disabling Publish leaves three safety profiles green but loses all four
  required publication/trust witnesses. Missing progress receives no success
  credit. Five cohort-partition tests pass; the inventory now has56 assessed
  required IDs,51TLC/3Identity/2Rules. A full56-item campaign is a final batch gate.
- Independent behavioral verification executes30 additional trials: old-premise
  reproductions, per-input repaired publication/trust, two faults/restorations
  and missing-publication challenges. Independent review reclassifies all61
  default outcomes, both fault triples and the seven disabled-publication logs,
  checks source/config/mutant/log identities and verifies the full old config set.

Executed model SHA256:
`b62d824a6d64bb86457bf23116f79b8120f8b778a78e5c103ac78f208019b165`.
Final v3 differs from executed v2 only in sensitivity README current counts and
wrapping; all execution inputs remain identical. These are selected necessary
premises and bounded reachability checks, not valid STF history, full window
reconstruction or a concrete importer. No actual protocol defect was established.
F02–F05 and the final five-item accumulated gate remain pending.

## Five-increment boundary batch — F02 chain and height discrimination

The old Raw0..27 input domain never independently corrupted the non-origin
header chain or height. Removing either `Authentic` equality therefore survives
the complete old domain: each normal/mutated/restored search exhausts with
13,220 generated and4,512 distinct states. Those diagnostic survivors are
evidence of missing input discrimination, not production guard omissions.

F02 appends Raw28/29, changing only the peer header's chain or height to99 and
rebinding its symbolic L1 Comet commitment. Other input fields remain unchanged.
Neither input establishes an existing authenticated-contradiction branch;
both require Reject. They are intentionally invalid classifier tuples, not
proof-valid landings or positive STF/history witnesses. Healthy Raw0 accompanies
each new focused configuration.

- Both required one-site guard faults are KILLED exactly at Check/Classified:
  the omitted equality causes false Verified and `ClassificationCorrect` fails.
  Normal and actual restored searches pass, each with3,273 generated and1,101
  distinct states and an empty queue. Six focused phase logs and six old-domain
  diagnostic phase logs retain exact config/source/mutant/tool/output identities.
- Independent behavioral verification executes38 additional TLC trials, with
  literal raw-field/binding checks, per-input classification reachability,
  selective two-by-three fault matrix, healthy trust, authenticated Halt/Wait/
  corrupt-candidate controls, old-domain survival and actual source restoration.
  Healthy and off-target inputs do not supply fault-kill credit.
- Independent source review inspects all eight owned files and verifies Raw0..27
  and the entire operational/observer/audit suffix unchanged, all357 previous configs,
  other old files/payloads/pins and all56 prior required selectors preserved.
  All20 sensitivity/cohort/classifier/lifecycle Python tests pass.

The inventory now partitions58 assessed required IDs as53TLC/3Identity/2Rules.
The four unassessed categories retain their IDs/flags; the chain/height category
clarifies that concrete authentication, cryptography and full extended-history
classification remain outside the finite guard checks. The full359-config and
58-fault accumulated gates remain pending until the five-item batch ends.

Executed model SHA256:
`2ca92b8b685112444444dfcbdf5df4ab8294dfaa0af40f084919806207d63782`.
Focused campaign SHA256:
`ea1dc13a48f12c33f2b3d8d70ca7e4c439f200bb6ad644c736bf0a242da102c3`.
Initial namespace/JMX setup errors were inconclusive; the same inspected offline
launch passed with the required local capability. No operational protocol guard
or normative document changed. F03–F05 remain.

## F01 supplement before export — necessary priority bounds

Before F03 froze positive import receipts, source review found two further
impossible M10 positive tuples: Raw11's first priorities[7,-7] at powers3/2,
and Raw20's second priorities[6,-6] at powers2/4. Both committed future stock
validator sets have passed at least one proposer-priority increment, including
committee-update heights. For two members, normalization bounds the pre-step
difference by2V; adding powers and decrementing the selected winner bounds the
post-step absolute difference by V+|power1-power2|. Ties give difference+V or-V,
and further increments retain the bound. Thus these selected bounds are6 and8,
while the old differences were14 and12. Arbitrary valid prior committees cannot
rescue those positive premises. This is a necessary condition, not a complete
history characterization or a requirement to recompute history during import.

Independent actual Go probes confirm source-generated alternatives: first
[-1,1]/stored proposer1 on the third increment for3/2, and second[-2,2]/proposer2
on the second for2/4. Baseline first[-2,2]/proposer2 remains unchanged and passes
the necessary condition; no complete prehistory is inferred for it. The baseline
second's stored proposer tie imposes a public-address ordering on any claimed
local concrete realization; F04 must respect that mapping or limit its claim.
The independent TLC verifier read back the existing Go probe artifact; it did
not rerun the Go probe as part of its27 fresh TLC trials.

F01 was reopened within this five-item batch to correct only Raw11/20's priority
tuples and add independent literal power/difference checks over actual published
Comet fields. All other raw cases, actions, authentication/store/classification
observers,359 prior config bytes and old payloads/pins stay unchanged. The prior
strong positive-preimage premise is withdrawn; older results remain identified
with their original source. This is an explicit exception to Raw11/20 byte
preservation before the F03 export, not another technical increment.

- Each original tuple still passed its old normal search and reached trust;
  an independently appended necessary-bound invariant fails after Published.
- All63 affected import configs match their exact outcomes on the repaired
  model. Six selected F01/F02 source faults, including restoration of each old
  priority tuple, are KILLED at their exact targets; originals and actual restored
  sources pass with stable inputs. Existing20 sensitivity tests pass.
- Singleton repaired Raw11/20 checks bind raw and actual Comet/app fields and
  reach separate publication/trust witnesses. Fresh independent verification
  adds27 TLC trials:15 exhausted passes and12 intended counterexamples, including
  old-premise reproductions, target-only two-by-three fault matrix and byte-exact
  source restoration. Independent review checks the complete six-file diff,
  source proof,63 raw outcomes, six fault triples and all provenance hashes.
- Two required faults join the preserved58, giving60 assessed IDs partitioned
  55TLC/3Identity/2Rules. Main configs remain359; the complete accumulated gate
  remains pending. Concurrent unfinished F03 files were excluded from the frozen
  execution snapshot and from this increment's commit.

Executed M10 SHA256:
`37af404f24845ca3f805b914222934a7af3a13fd51635276915e93996fa47e37`.
The scalar bound applies to these two-member positive-power fixtures; it does
not prove complete STF/window validity, full importer correctness, generalized
weighted consensus or unbounded protocol behavior. No protocol defect was found.

## F01 final supplement — coherent committed pairs before export

The preceding individual-set alternatives are withdrawn as complete positive
pair premises. The remaining shared assumption was that independently reachable
current and next sets could be combined. Actual pinned `updateState` copies the
same previous NextValidators into current and into the updated/incremented next;
the pair must agree with one chronological program. The old base pair cannot
arise from those update rules, and its current set also disagrees with the
specified fixed-genesis, two-block prefix.

A private single delegating bridge exposed the original unexported function
without copying or editing it. Actual genesis plus two updates produced the
three pairs documented in
[CHECKPOINT_IMPORT.md](CHECKPOINT_IMPORT.md#f01-final-correction-jointly-committed-validator-pairs).
All1659 original source entries and exactly one added private bridge were
verified before and after execution. An independent verifier reran the isolated
public-only Go probe and compared the complete raw output, then audited fields
by public-key identity. The source arithmetic and output agree, including base
next priorities[2,-1] and first-alternate next's stored proposer2 despite key3's
higher current priority. These values must not be renormalized or chosen by
current-priority maximum.

The final fixture repair couples both sets, powers and commitments, keeps fixed
genesis entirely literal, and retargets corrupt proposer fixtures that would
otherwise become no-ops. An independently literal actual-publication pair table
detects a new individually bounded but incoherent pair fault. Existing opaque
window tokens and all359 main config bytes remain unchanged. This is the second
and final material F01 fix wave within the authorized five increments.

These selected programs establish stock validator-state arithmetic and pair
correspondence. They do not establish app-selected updates follow the L1
committee schedule, signed/valid commits, complete authenticated history,
EL/STF execution or proof soundness. Unsigned timestamp records construct the
selected headers; post-commit AppHash is separately seeded after stock returns
nil, and an explicit unchanged-parameter response selects marker5. Those inputs
remain disclosed premises. A store accepting supplied state alone would not
have exposed this pair-validity defect.

The final affected gate passes all63 import configurations:20 exhausted normals
and43 named controls/witnesses. All35 affected M10 source faults are KILLED at
their intended invariant or temporal property, with successful original and
actual-restored searches;38 workloads per phase produce114 checked raw logs.
Existing20 sensitivity tests pass. The five selected singleton profiles also
pass literal Comet/app-record audits and reach publication and trust separately.
The bounded wrong-pair mutant still passes old store alignment and local bounds
and reaches publication/trust when the new literal audit is omitted.

Independent behavioral verification contributes40 accepted TLC executions over
38 distinct checks, separately from the author's suite, plus the fresh actual
Go replay described above. It includes bound-only controls, correct Raw4/12
classifications, permanent WrongPriority/WrongProposer controls, byte-exact
restoration and a real disabled-Publish temporal counterexample. Rejected setup
and temporary harness/parser diagnostics are retained and excluded from credit.
Independent source review finds the full six-file change compliant and of
acceptable quality, with all359 config bytes, old pins and engines preserved.
Root separately reclassifies all63 main and114 fault-phase raw logs and their
hashes. Inventory is61 assessed IDs:56TLC/3Identity/2Rules; the full accumulated
five-item gate is still pending, and unfinished F03 files remain excluded.

Executed M10 SHA256:
`4091cee2e355b553db60986d99ff8e29b7d4fe4285fd457c6a320dc5c0111258`.
The35-fault campaign SHA256 is
`ed5bcd5a12f74c1af12165653f6c0c87c29bcbf14c03a34f62b58cb485fde2b7`;
the evidence-summary SHA256 is
`62065d5ec958c2267bfb21d38ab73e505908d31a7da845f809c2667e48179d7c`.

## F03 — actual checkpoint-import publication receipts

The new [exporter](conformance/export_checkpoint_import.py) runs five singleton
temporary wrappers over the final reviewed M10 source. Each wrapper calls the
unchanged Init, Check, Stage, Flush and Publish actions and records ten actual
enabled steps. The [fixture](conformance/checkpoint_import_cases.json) contains
the complete selected raw inputs, classification/publication observations,
actual EL/app/Comet/evidence stores, durability markers and publication metadata.
It stops with trust and connection false and signer HRS preserved. Python parses
observations; it does not reconstruct the import transition or choose a verdict
from the case ID. The five IDs cover fixed-genesis origin import and all three
coherent current pairs.

The local parser extends the unchanged old parser with signed integers and
bounded sets/ranges. Sets and ranges share canonical JSON ordering, while
sequence order remains intact. Exact scalar types prevent bool/int aliases.
Source, parser, pins/SPEC, wrapper, singleton configs and TLC jar are recorded;
fresh `--check` executes TLC and compares complete canonical observations.

Independent review and behavioral fault injection found two additional checker
defects before publication. First, plain JSON loading discarded conflicting
duplicate object fields before exact comparison. The reusable `load_fixture`
now rejects duplicates at every nesting level, with actual CLI-path regression
coverage. Second, hashing original files did not establish which temporary
model/wrapper/config bytes actually executed. A temporary Java launcher changed
each executed copy before invoking the real pinned TLC; all five cases still
succeeded with the wrong provenance. The exporter now compares those copies to
their expected bytes before and after every run, before accepting observations.
Each final fixture was generated again from actual execution after the exporter
changed; earlier versions remain historical.

Final author checks pass: five fresh exported publications/50 enabled actions,
five fresh `--check` observations,11 focused regressions and114 ordinary
conformance tests. Three actual controls distinguish missing progress from green
safety: disabled Publish with safety only exhausts but yields no receipt and is
rejected; retaining enablement fails exactly RequiredStepEnabled; removing Print
also exhausts without a receipt and is rejected. Independent source review
rechecks both fixes and the complete four-file change. Independent behavioral
verification separately reruns fresh export/check and a complete literal oracle
for all five raw/store observations and50 before/after action records. Both
conflicting duplicate fields fail through main's fixture-loading path with
generation mocked; a separate actual CLI `--check` executes all five cases before
rejecting malformed duplicate input. All three original executed-copy drift
reproductions now fail at the exact copy-integrity guard after real TLC execution.

The final exporter SHA256 is
`2bee3e3fc5feb16c7c529777d97d0eb56c8219b94ef9e7fb710580aec22ec151`;
the141767-byte formatted fixture SHA256 is
`ffb50b92a5b22220b6a1e44821e2731c1b29466cdabbea12211ca4866b71bea6`.
M10 remains `4091cee2e355b553db60986d99ff8e29b7d4fe4285fd457c6a320dc5c0111258`;
the old parser and all old conformance payloads/pins remain byte-identical.
These are actual model publication observations with symbolic commitments and
durability markers, not concrete importer execution, authenticated archive/STF
history, signed commits, proof soundness or database power-loss durability.
F04/F05 and the accumulated five-item gate remain pending.

## F04 — selected stock Bootstrap and independent history rows

The new [Bootstrap experiment](conformance/COMET_BOOTSTRAP.md) consumes the
reviewed F03 fixture in a separate Go module and collector. It calls actual
pinned Store.Bootstrap, Load, LoadValidators and LoadConsensusParams, with fresh
MemDBs and reopened Store wrappers. Five receipt leaves compare actual state,
current/next rows, raw row metadata, parameters and selected MakeBlock headers.
A separate historical-lookup leaf checks origin's absent row2 and current row4;
observer-controls checks deliberately wrong fields. Literal key/priority/proposer,
sorting, total-power, state and mapping observers are independent of the adapter.
LastResultsHash uses actual TxResultsHash of the single fixed ExecTxResult.

The private source fault removes only Bootstrap's historical LastValidators
write. All seven original tests pass. The actual mutant fails only the historical
lookup, with three ordered observations of typed ErrNoValSetForHeight4, nil set,
absent raw row and preserved serialized State.LastValidators. Original bytes are
then restored into that same private tree, all1659 entries verified and all seven
tests rerun successfully. This separates complete-State serialization from the
independent historical validator rows. There is no phase flag in native code.

The collector reuses existing source verification, canonical layout checks,
shared physical cache/lock, authoritative supervisor and isolation launcher.
Generated modfile/sum inputs are separately bound read-only and checked before
and after execution; author self-review reproduced this generated-input gap and
fixed it before peer freeze. F03 JSON uses its strict loader and frozen byte hash;
native receipt decoding also checks that hash. Fourteen shared/F03/old-native
files remain byte-identical, so the conditional unchanged old-lane rerun was not
reopened or claimed as fresh evidence.

Independent review found a further wrong-reason admission: correct leaf statuses
and the three expected messages could conceal an additional parent cleanup
error, because parent/package failure was already expected. Independent
verification reproduced the same gap in parent, package and other-leaf outputs.
The final collector validates the entire fixed mutant output sequence, allowing
only its framework frames and three required diagnostics. It rejects unexpected
diagnostics in every channel, with or without optional OutputType, and rejects
error-typed framework banners. A byte-for-byte retained real output fixture
drives portable regression tests.

Author final17 focused tests and a fresh actual three-phase campaign pass, with seven
native outcomes per phase, exact mutant semantics, stable inputs/tools and
original/restored1659-entry source manifests. Independent behavioral verification
ran its own actual three phases, checked public vectors and nine focused
controls, and demonstrated actual rejection of a wrong-AppHash adapter. After
the publication hook reformatted the embedded mapping JSON, both author and
independent verifier reran actual native phases on the final formatted bytes;
the independent wrong-AppHash probe was also rerun. Canonical JSON values/types
remain identical, and the final byte manifest matches the publication format.
The recorder fix was independently checked against six genuine author/tester
phase streams and15 error-channel controls; that evidence remains valid for the
unchanged collector bytes. The post-format independent run classifies its three
new phase streams and repeats six channel controls, with restored manifests
verified. The raiser independently rechecks the original finding
and final scoped diff; both source-review verdicts and behavioral verdict pass.

Final collector SHA256:
`7d50ef1091ff5702c450a05176acad0e3c23448ffd9e7bc45ec5842437570999`.
Final actual campaign summary SHA256:
`def625ba7d762b7879ecf6416d6a5a2454c63048aa62787edc0f4a7783661362`.
The independent current-byte campaign summary SHA256 is
`1cc5b6beeeacb008bbaeb581cf3a6450980c771c91b0463c25268efbb0b463b0`.
The source fault changes state/store.go from
`32aa1743ae14e624569c9c20824a3a476330d4d00cf899a3b76d3c6f8605c63e`
to `965437e88750a27f2e136f05b78dc32032729bcab38f3f46dce5a46771f58ee1`;
actual restoration returns the entire private tree to the original manifest.

These are selected stock serialization/readback and header-construction results.
The public B/-B/2B identity realization is not Etna's secp256k1eth mapping;
version/parameters, unsigned timestamp records and opaque hash/BlockID mappings
are explicit premises. The selected Last set realizes the earlier actual prefix,
not a complete authenticated archive. MemDB plus reopened wrappers does not prove
power-loss durability. No concrete Etna importer, non-genesis block admission,
valid signed commits, EL/STF execution, committee derivation or live consensus
is established. F05 and the accumulated five-item gate remain pending.

## F05 — nonzero recovery and proving-resource scenarios

The [new companion](EtnaProvingRecovery.tla) runs three explicit bounded scripts
over unchanged M07 actions. They produce an unsettled suffix, actually land and
ordinarily finalize checkpoint1, then invoke the existing trusted completed
recovery macro at execution3/observation4. Recovery retains records, jobs, proofs,
publication and resource state while resetting the production origin to1.
New-generation Produce explicitly replaces the old unsettled height2 identity.

FreshPresent captures the unused job1 with generation1/parent1/terminal2/ref4/
dependency3 and lands at5. FreshAbsent preserves missing resources through
recovery and capture/publication, observes two actually disabled completions,
then uses explicit history/provider arrivals before completing and landing.
OldOutstanding retains its already captured old-generation job and attempts
actual Land at4: its reference, ancestry, frontier cut, full data, both proofs
and head remain live, isolating generation rejection. No job ID is recycled.
Each receipt contains actual enabledness/execution and complete raw pre/post
state. Expected outcomes audit the execution; they do not decide whether to run
an enabled action. Terminal predicates require raw state, receipts and counts.

Author verification covers all ten new configurations with exact outcomes: seven exhausted normal/
focused searches and three named terminal witnesses. Four new scoped source
faults are KILLED exactly at RecoveryOriginAudit, RecoveryResourceAudit,
RecoveryGenerationAudit or RecoveryEnabledAudit; original and actual-restored
sources pass with stable inputs. The generation mutant actually executes the
old landing, advances included1 to2 and is caught by the actual-receipt audit.
Disabling the real Recover action loses the required complete terminal witness;
restoring the same source makes it reachable again. Green safety exhaustion
alone therefore earns no progress credit.

Independent source review checks the complete16-file diff and actual M07/SPEC.
Independent behavioral verification separately executes ten cases, four fault
triples and the witness-loss/restoration control, using its own general raw TLA
value parser and literal audits of all terminal receipts. Both verdicts pass
without a material fix wave. All359 old config bytes and65 old inventory objects
remain unchanged. The new total is369 main configs and65 assessed obligations
(60TLC/3Identity/2Rules), with four unassessed boundaries retained. These are four
new scoped verification obligations, not four discovered protocol bugs.

The author's existing20 sensitivity tests pass after resetting inherited ignored signals
in the disposable jailed launcher. The initial three lifecycle timeouts were
reproduced as parent/child SIG_IGN launch context; no helper or test was changed,
and the failed launch is retained without semantic pass credit. Project formatting
was applied and checked before the final source/inventory freeze.

Companion SHA256:
`7f7b3014f81dc450e5926bda559400648fd38c79bf492a79f20b9fea82e962e6`.
M07 remains
`4a102d5e465b7c943b8564994a320fb4b2af13fbe5348c0f095aa75016fa0105`.
The four-fault campaign SHA256 is
`a4b27678de9d499ea07c3dc87ddecfe2839bc7b743ced3019109a87ea086e492`;
the independent behavioral report SHA256 is
`3bbb671062b71472b55e9e2543099671c77e31a8a77c0f83c9685aa727afb5d5`.
External finality/authentication and physical restoration remain assumptions of
the trusted recovery macro. These selected executions do not implement recovery,
real proving, resource fairness, latency guarantees or universal liveness. The
stable accumulated five-item gate and final whole-batch review remain pending.

## Five-increment batch: final gate and retrospective

All five authorized increments are complete. The stable execution snapshot is
implementation head `d9c1c4d43dd747167f065b6433bdaba131c5b0be`, containing511
tracked formal files. Every frozen byte was independently matched to that Git
tree. Subsequent closing edits affect this report and the plan only; executable,
model, config, fixture, inventory and consumed tool inputs remain unchanged.

| Gate                              | Final measured result                                                                                                                                                                                                                                                                       |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Default TLC                       | 369/369 exact outcomes:70 exhausted normal searches and299 named controls/reachability witnesses across17 top-level models.                                                                                                                                                                 |
| Compatible shared cohorts         | 65/65 assessed obligations KILLED, exactly once:60TLC/3Forge Identity/2Forge Rules. All234 phase/workload logs checked;78 workloads per original/mutant/restored phase.                                                                                                                     |
| Ordinary Python                   | 20 runner +131 conformance +20 sensitivity =171 tests, all passing.                                                                                                                                                                                                                         |
| Separate controller lane          | Five mandatory host-controller lifecycle tests pass with stable shared inputs; their sleeping process fixture supplies no Go admission evidence.                                                                                                                                            |
| Rules                             | 640 live markers,640 live/28 retired index, assets, links and tables pass. All106 mounted doc/tool inputs stable. Migration purity remains explicitly skipped without a base.                                                                                                               |
| Fresh model exports               | Three clock observations and five complete import publications compare to the committed fixtures; all50 import action records independently checked.                                                                                                                                        |
| Current-byte stock store evidence | Two independently executed seven-leaf, three-phase campaigns match the final formatted inputs; exact historical-row source fault, actual same-copy restoration and wrong-AppHash rejection verified. These earlier-in-batch executions were audited, not relabeled as a new final Go rerun. |

Default TLC completes in538.934s; the complete compatible shared campaign in
387.724s. Python/rules and fresh exports complete in4.274s and6.276s respectively.
Every required lane exits0. Raw shared failures comprise57 declared invariant
obligations, three single-property temporal obligations and five exact Forge
failure obligations; setup, parsing, timeout and wrong-reason errors earn no
credit. Both selected actual contract test identities execute under their own
compatible cohorts. All564 original contract entries and the complete568-entry
runtime snapshot are independently checked, including the original symlinks.

A fresh whole-batch source reviewer inspects the complete eight-commit,
43-file implementation diff and relevant legacy interfaces; specification
compliance and code quality both pass without a requested fix. A separate
stdlib-only artifact audit imports no production classifiers or validators.
It independently checks every default result, all65 obligations/234 raw phase
logs, exact model/config/tool/mutation hashes, original/restored records,
actual exporter values, native identities/diagnostics and source preservation.
Both final verdicts are READY for this bounded draft-review scope, not merge or
production approval.

The shared executor removes its temporary TLC/Forge phase trees. The independent
audit therefore verifies full original hash maps, exact single-site mutation
reconstruction, identical private bindings, recorded stable restoration and
actual raw behavior; it cannot walk deleted phase trees afterward. F04 retains
its actual mutant bytes and restored private tree, and both original/restored
1659-file manifests were independently walked. These are distinct evidence
strengths and are not conflated.

All350 pre-batch configs remain byte-identical. F05 also preserves all359
preceding configs and65 inventory objects. The old first-block seven-native
gate, full13-test contract replay and38/9-call exports remain historical evidence
for verified byte-identical consumed inputs; those whole gates were not rerun
or called fresh. Nineteen archived incomplete profiles remain incomplete and
four unassessed boundaries stay outside the65-obligation denominator.

The concrete self-check blind spots were shared positive premises, incomplete
input domains, progress inferred from green safety, and incomplete failure or
execution-input attribution. Constructors and observers could agree on time40
before genesis100 or an impossible validator pair. Removing a guard could survive
when no input distinguished it. An expected failed child could conceal another
parent error. Original-file hashes could remain correct while executed copies
changed, and JSON loading could discard conflicting fields. More repetitions of
the same checks would not add those missing properties. The completed work adds
independent literal/source premises, required actual receipts, raw state audits,
exact error-channel classification and current-byte upstream execution controls.

The scope decisions remain explicit: selected stock two-update prefixes prove
local validator arithmetic, not Etna committee derivation or complete signed
history; symbolic proving and trusted completed recovery do not establish real
proofs, external authentication/finality, resource fairness or universal progress;
MemDB serialization does not establish physical durability or importer atomicity.
Full App/EL/STF/archive reconstruction, actual secp256k1eth mapping, non-genesis
commit admission, network voting and sustained throughput remain unverified.
These limits explain why finite green results cannot establish protocol
completeness. No independently supported production/SPEC defect was found in
the inspected scope; the confirmed repairs concern fixtures and verification.

Exact final evidence SHA256:

| Artifact                              | SHA256                                                             |
| ------------------------------------- | ------------------------------------------------------------------ |
| Frozen511-file manifest               | `20287a33baa37ef71d0548480485d8030bfad46cb7441e0a39d16f525a4e2e80` |
| Default369 results                    | `9c500810e59f327533d0b201a8a767b9a177c4e69a8fb332829fa5c4177560b3` |
| Shared65 aggregate                    | `de28136237d54ba2a2c78d58908f196cb5fd4204e3333c43888797197526886b` |
| Independent whole-batch source review | `12d2fe55d907e152d9e92e80bdaa87c1b7c7b7b29418ab208051c0a15cf4673c` |
| Independent artifact report           | `7a9788d8cf4364def4f0ae6a1d4b66bef1fc53030c9842f1d5635d56038b6482` |
| Independent per-result evidence       | `bfc6dfa729462314dda4e4ffdbb6184aca50263845a0ddadcacb419ba2aeac4d` |

The existing PR stays draft, production/normative sources and Notion remain
untouched, and this batch stops after five increments. Hourly feedback checks
continue under the existing authorization; they do not start a sixth increment.

## Coverage-closure batch — G01 exact-outcome CI

The user authorized a new five-item batch after organizing remaining tasks.
The [worklist](WORKLIST.md) now records acceptance/dependencies and the required
composition matrix, with19 archived searches grouped by their missing obligation.
Independent review added explicit shared encoding/key/signature vectors and
unified zk-gas semantic equivalence; these remain implementation dependencies,
not extra completed work or new protocol findings. Issue22355 links this index,
states the published draft status and preserves all older body text as history.

G01 adds `ci.py` and a draft-enabled TLC/Python workflow. The existing runner
still classifies TLC outcomes; the gate audits exact discovered identities,
current model/config/tool hashes and raw logs, refuses stale output directories,
and requires positive discovered/run counts with no skipped mandatory tests.
Tool preparation downloads only the checksum-pinned jar before offline execution.
The workflow and local validation use the same explicit signal-reset entry so
namespace PID1's inherited ignored signals do not invalidate lifecycle checks.

Two material fix waves closed verification defects before publication: empty or
partially skipped unittest discovery could return success; and sorting config
filenames but comparing sorted stems falsely rejected the complete prefix-named
case set. Independent actual CLI controls reproduce the former and reject it
after repair. Prefix-name regression and an audit of the preserved genuine369
results verify the latter. Setup-denied Java sockets, superseded runs, cancelled
runs and wrong signal-context failures remain excluded from final success.

The final canonical isolated execution exits0 in511.857s: **369/369** exact TLC
outcomes (70 exhausted normals,299 named invariant controls/witnesses), **189**
Python tests (38 runner/CI,131 conformance,20 sensitivity), all discovered and
run with zero skips/errors/failures, and rule-reference checking exit0. Migration
purity remains explicitly skipped without a base. Root separately audits all369
raw logs and source/config hashes without importing the production classifier.
Independent source/spec/quality review and independent behavioral verification
pass on the final three owned code hashes. Actual tiny TLC cases, empty/mixed
skip controls, missing/duplicate/forged results and nested-session cleanup are
independently checked. The369 old configs and operational models are unchanged.

Final results SHA256:
`f86df8bbe79a4972b0aa23116fc9016aa9c03de2cbb3fadfed3126f480e64c99`;
gate summary SHA256:
`c5d168b63f1756fc438c71e17af4738f7c50965c46bc1b8babb640a8088e3b50`.
The source review SHA256 is
`4e926e177a07dd2b3e5f9e9fbf1fe247b76335cd8c1c5def0e3a22e07c3f5eaa`.

This is local current-byte gate evidence. Hosted Actions provisioning/execution
and artifact upload require separate readback after publication. The CI job
does not execute native Go, contracts, real proving, mandatory host-controller
tests or shared source-fault campaigns; their earlier results remain historical
for unchanged consumed inputs until an explicitly affected gate is rerun.
G02-G05 and the final accumulated batch review remain pending.

### G01 hosted launch and artifact ownership repair

The first hosted run43998140485 at87464de50 fails before TLC starts: Python
cannot open the prepared launcher under `sudo` (Errno13). Pinned tool preparation
succeeds; this is not a model counterexample or a GitHub authentication failure.
Independent review also identifies the later ownership consequence: a sudo
launcher would create host-root-owned0700 TLC directories, which the ordinary
artifact uploader could not traverse. The first run stops too early to observe
that later artifact failure.

The workflow now launches the same namespace helper as the ordinary runner UID,
matching the successful local execution model. Namespace isolation, read-only
source/dependencies and the signal-reset entry remain intact. A disposable
committed-source-only profile executes three genuine TLC cases and63 selected
Python checks (38/5/20) with all required child statuses0. The normal caller owns
the0700 results directory, reads all13 output files, and archives the results
plus all three raw logs. This profile is launcher/readability evidence, not a
new full369-case or189-test run. The unchanged gate/model bytes retain the prior
canonical full execution above. Paused G02 untracked files are excluded.

Hosted execution and complete artifact readback of the repaired workflow remain
required. G02 is paused at a coherent draft boundary until this earlier CI
integration issue is repaired and verified.

### G01 supported Docker runtime and final binding boundary

Hosted retry44000312830 atb8437f27c confirms a separate platform refusal:
`unshare` cannot write `uid_map`. CI now uses the installed Docker runtime;
native local lanes keep the existing namespace supervisor. A tiny locally
assembled empty-base image needs no registry pull, package or SDK installation.
The caller's numeric UID, read-only root/system/source/tools, private PID/tmp,
no network/capabilities, no-new-privileges and explicit writable output preserve
the required isolation. Private tmpfs permits executable fixtures as the old
namespace backend did. Default Docker policies remain enabled.

The adapter records a private unmounted ownership nonce and rechecks actual
daemon labels/IDs before cleanup. It never removes caller-provided names,
overwrites image tags or prunes global resources. Actual success, unrelated
name collision, mandatory-child failure, timeout, SIGTERM/SIGINT and accepted
import/create with a lost reply verify cleanup and unrelated-resource retention.
The always-run reconciliation step covers interrupted execution.

Review identifies and repairs a binding-policy gap: only the source had been
checked against HOME/Git, leaving other configured mounts unchecked. All four
configured bindings now reuse the authoritative parser before any Docker or
runtime creation. Executable Java and an existing outer output directory are
required. Disposable mocked-home/Git/symlink controls prove rejection without
submitting any real sensitive directory or file; no Docker call occurs.

The frozen pre-validation adapter executes **369/369** exact TLC outcomes and
**195** Python tests in520.374s, with reconciliation0 and no owned resources.
An independent raw audit checks all369 logs and source hashes, and the normal
caller archives/reopens all381 output files byte-for-byte. This is explicitly
pre-binding-fix host-adapter evidence. The final validator leaves the388 child
inputs (369 configs,17 models, gate and checker), valid mounts/runtime and rootfs
tar bytes unchanged. Its current **197** Python/rules preflight, genuine
three-case TLC integration, all-binding controls and real failure/timeout
cleanup controls pass. Independent source/spec/quality review and behavioral
verification close the binding finding on the final bytes.

The unchanged model search is retained with its original adapter attribution;
it is not relabeled as a final-validator full run. The current hosted full
369/current-Python gate and complete raw artifact readback remain required
before closing G01 or resuming G02. G02-G05 and the final batch gate remain open.

### G01 host output publication and artifact boundary repair

Hosted run44008626733 at acb7e5c400 passed all gate, reconciliation and upload
steps. The downloaded381-file artifact was read without extraction: all369
case logs match their exact outcomes (70 exhausted searches,299 named invariant
failures), current model/configuration hashes match, and197 Python tests have
no skips or failures. Its ZIP SHA-256 is
`f0311b2c49d8fcd3d9c524299931e02185099de46051422e1959381825e1a665`.
This execution predates the following output-boundary repair.

Review then found two related host-consumer defects. The parent opened log/status
destinations in child-writable output and could follow a planted link. The pinned
artifact action also follows links when reading that output. Disposable sentinel
controls reproduced the parent overwrite; inspection of the exact pinned action
confirmed its consumer path. No real sensitive paths or unsafe remote uploads
were used.

The parent now retains canonical diagnostics in its unmounted private runtime
and publishes separate inodes using atomic replacement; directory collisions and
cross-device renames fail without a copy-through fallback. After reconciliation,
an independent output check freshly confirms owned daemon resources are absent
and uses no-follow metadata reads throughout the tree, rejecting links and
special files. Raw upload requires both reconciliation and output-check success.
The always-run diagnostics upload names only the two private canonical files.

The current adapter passes208 Python tests (57 gate/adapter,131 conformance,
20 model/sensitivity), rule markers and actual Docker controls. Outside disposable
sentinels stay unchanged; planted metadata links are replaced with regular files;
extra file/directory links and a FIFO are rejected; directory collisions and an
actual cross-device publication fail safely with cleanup. Normal prior381-file
artifact layout passes the new checker. These controls do not relabel the older
full run as execution of the repaired adapter. Independent source and actual
behavior rechecks pass at the frozen current adapter/workflow/test hashes. A
new hosted full run with complete artifact readback is required before G01
closes and G02 resumes.

Final repaired execution: [hosted run44014380640](https://github.com/taikoxyz/taiko-mono/actions/runs/44014380640)
at9798a68fa83490835e519720c454505bf9bfa75d succeeds, including reconciliation,
quiescent output checking and both uploads. Downloaded artifact14298780801 has
381 files and SHA-256
`939acf27300a1e1567100d8d4ca1ac7508b41c597c0cd0ba6792d8cba460d58d`.
An independent raw read of all369 case logs confirms70 exhausted searches and299
exact named failures, all current configuration/model hashes,208 tests
(57+131+20, zero skips/errors/failures), all five children0 and backend cleanup0.
The separate two-file diagnostic artifact14298656593 has SHA-256
`a70ec19ba145c6862c4a2c978a5936d48686f028c095ddb929aae44d3195a68c`;
both canonical files match their public copies byte for byte. The TLC results
file SHA-256 is
`6c0f4b32d13bf03cb0d255f0cdaf938da5d43449df016fe774821392a333eee5`.
G01 is complete for its TLC/Python CI scope; G02 resumes. Native, contract,
real proving and complete protocol acceptance remain separate work.

A final independent ACCEPTANCE-to-worklist audit also found two remaining-plan
omissions, repaired without expanding G01-G05: O01 now owns actual launch capital,
concentration, finalized-R quorum/revaluation and funded operations; C01 explicitly
owns concrete timed refusal, trusted-session reconnect and automatic supervisor/
WAL retry without resetting HRS or restarting safety halts/old generations. L01
now explicitly names production signer/HSM/KMS pins and maximum-committee
signature-tail measurements. The raiser rechecked all fixes. The current index
has29 obligations and10 required composition families; bounded completion is
still distinguished from whole-module closure.

## Coverage-closure batch — G02 stock disk/process restart

The [new native lane](conformance/COMET_RESTART.md) uses actual GoLevelDB with
pinned stock CometBFT0880b4d378f347ab16e54ec677ff50d803f37d62. It reuses the
unmodified F04 mapper/literal observers and frozen F03 public receipt. The old
F04 test parent compiles but is not executed. Each origin/current case runs both
clean close and abrupt death after completed Bootstrap: an independently checked
private ACK binds the writer PID, case, mode and canonical disk directory; only
the owned process handle is killed, SIGKILL is confirmed by Wait, and a different
reader process reopens that same directory.

The reader checks complete state and independent raw/getter validator/parameter
rows: origin rows3/4 and params3, with validators2 absent; current rows4/5/6 and
params5. Collector receipts must also equal the full frozen public observations,
including members, priorities and stored proposers. Actual no-ACK, wrong-child
and failed-worker controls prevent reader startup; observer controls distinguish
missing history and changed fields.

The sole private source fault omits the entire final Bootstrap batch.WriteSync
call. All four persistence leaves then acknowledge success but reopening reports
exactly absent state and expected rows; four independent controls still pass.
Normal and actual same-copy restored execution pass all eight leaves. Every
entry of the1659-file source manifest, copied F04/native files, both module-file
locations, tool bytes and provenance inputs is checked before and after execution.

| Phase    | Native return | Required result                                  | Raw combined-log SHA-256                                           |
| -------- | ------------- | ------------------------------------------------ | ------------------------------------------------------------------ |
| mutant   | 1             | Four exact missing-batch failures, four controls | `62b22407ec835f5dfb456f81191d6720c87b855449a7a8bd371f94400efebf74` |
| normal   | 0             | Eight pass                                       | `fac777531fefd1ef13faf7f965cc5339b79790445ab7918fce65e2083df956d8` |
| restored | 0             | Eight pass                                       | `92ae39194faf82ef920f43e82ad0fbb445b804f19d09957f5bf8fe05823ec128` |

The final formatted-byte author campaign takes1.158/1.207/0.957s respectively.
Its summary SHA-256 is
`d4413c6c9a8a7679a077a0e73f656ac72c4b7f6184d0ae6006f980b73b84daa4`;
native source SHA-256
`41438dc029fb86a576dab75ce05c4bed83f0753ad4dff57872382d8f444e6b71`;
collector SHA-256
`acd807bbc2678e6b488eb829e857a48458f19ab52a4fbd6ba2740d067f751e6e`.
Fourteen focused tests,145 complete conformance tests and five separate actual
host-controller tests pass. Independent source/spec/quality review passes at all
nine frozen hashes. A second actual native campaign independently reproduces the
three phases, then reopens all12 resulting databases read-only and compares
literal full state, raw/getter history and parameters without changing DB bytes.
Independent actual-stream and source-drift controls also reject their intended
errors. No material review finding remains; G02 is complete for this boundary.

Self-checks first exposed a missing private module-root file, incomplete collector
observation acceptance and timeout metadata acceptance. Red regressions preceded
the fixes; setup failures were never counted as semantic outcomes. Missing/skipped/
duplicate identities, all unrelated diagnostics, wrong reason/return codes and
generated-input drift fail closed.

This establishes selected completed-write process restart on the executing
filesystem. SIGKILL does not simulate loss of the OS page cache: physical power
loss, multi-store atomicity, actual Etna importer/App/EL, signing, WAL/consensus
restart and authenticated complete history remain separate obligations. The
existing shared cache, lock, offline namespaces and authoritative supervisor are
reused; no dependency fetch, installation or production source change is needed.

## Coverage-closure batch — G03 stock handshake matrix

The [handshake scenario](conformance/COMET_RESTART.md#actual-stock-handshake-scenario)
calls actual exported HandshakeWithContext over disk state/block stores and an
explicit controlled ABCI application. Fifteen selected inputs cover no-replay
success; negative/app-ahead/app-too-far-behind heights; state/store divergence;
missing/wrong-height last responses; empty-store equal/mismatched AppHash and
matching-hash/different-height behavior; the known non1 first-block stop; and
controlled FinalizeBlock/Commit error boundaries. Every leaf runs in an owned
subprocess, with exact return/panic/call counts, full state observations and
logical raw-store before/after hashes. Setup and lifecycle failures cannot count
as the expected panic. Blocks remain unsigned structural storage fixtures.

Two observations constrain what this evidence means. Empty blockstore accepts a
matching AppHash before ordinary height checks, including the selected app5/
state4 input; stock success therefore does not establish complete importer
consistency. InitialHeight3/state0/store3/app0 reaches InitChain then the already
documented CONS-3.1-9/Q3.1-8 stop. Its exact state-store effect is checked, but no
wipe or repair procedure is accepted here. Handshake's replay-error wrapping
also loses typed height errors; separate actual ReplayBlocks calls verify those
types without attributing them to the exported Handshake return.

The private fault removes only the actual assertAppHashEqualsOneFromState body.
Only the two AppHash-mismatch leaves may then report unexpected success; thirteen
other leaves must pass. Original and actual same-copy restored execution pass
all15. All1659 source entries, tool bytes and copied/generated inputs verify
before/after every phase.

| Phase    | Native return | Required result                         | Raw combined-log SHA-256                                           |
| -------- | ------------- | --------------------------------------- | ------------------------------------------------------------------ |
| mutant   | 1             | Two exact guard failures, thirteen pass | `787ab8394bdac380960c78438eb1b8fb6e81b15badec4cbeaee4b8321070b0d7` |
| normal   | 0             | Fifteen pass                            | `72270c2e847ec85eee5a04f24e9b77c133bbd894a938a66917ba997cabf674ad` |
| restored | 0             | Fifteen pass                            | `6fff68d35c2c2f7dd5025a1d51668d59b2919d38565dfe755df53a81d314b28b` |

The formatted-byte author phases take2.711/1.759/1.759s. Summary SHA-256 is
`8711cf4beaebfff2b21a034bc257dd2e00899a00b79f03a5cc3f3473d543c279`;
native source SHA-256
`d976cd16371b16a9e7e027c4368106ffdb60419394806066ff4597f27e9a0f70`;
collector SHA-256
`d5ef8c43f97c3ea0d82931386da0a0858b8a4082532a5af0d2d94d1e9ecb60e5`.
Current-code G02 regression separately passes all eight identities in each
phase, with its four intended missing-write failures only in the mutant. Its
summary SHA-256 is
`ed0c8d1940322b55663c5ddc412e0380e29451cb308981b860da6e8624057078`.
Nineteen focused and150 full conformance tests pass with no skips. Independent
source/spec/quality review passes at all eight frozen hashes. A second actual
handshake campaign and current-code persistence campaign independently reproduce
both exact three-phase contracts. Thirty-three changes to fresh actual streams
and a real CLI source-drift check reject their intended errors; independent
branch/state oracles and all source/copy/tool audits pass. No material finding
remains; G03 is complete for its selected stock API scope.

Actual offline discovery first exposed absent transitive dependencies from
stock consensus/privval/libp2p imports. The accepted separate preparation step
downloaded32 exact public source modules into the existing cache, verifying both
module and go.mod sums against pinned primary sources; no SDK/system package was
installed. Offline discovery then reports825 packages and zero missing inputs.
Relevant new initialization hooks were inspected before execution. All native
builds/runs retain read-only sources/modules/tools and disabled network; setup/
dependency-list output is never semantic evidence. The complete observation
fixture was captured after independent native branch/call assertions, then pinned
and checked in full by the collector.

This closes selected stock API behavior only. Actual Etna App/EL, authenticated
history, valid commits, node/P2P/WAL startup, physical power loss, multi-store
publication and the known first-block stop's concrete handler remain open.

The preceding G02 commit also passes hosted run44018110081:369 exact TLC outcomes,
222 Python tests (57+145+20), reconciliation, output checking and both uploads.
All381 raw files and both private diagnostic files were checksum-verified and
read back at514371270. This ordinary CI evidence is separate from both actual
native scenarios above.

## Coverage-closure batch — G04 positive-stop old-proof handoff

The additive [stop/proof wrapper](STOP_PROOF_HANDOFF.md) invokes unchanged
CandidateHandoff/RulesSchedule/Settlement actions. Due, future and off-grid
positive-stop programs now queue an immutable generation0 proof for parent1/
terminal2 before actual public recovery at checkpoint1. Actual Land is enabled
before recovery; afterward the same proof's actual attempted landing is refused
under generation1/origin1, with the retained prefix unchanged. The stopped held
candidate is not claimed to have produced this independent opaque proof.

All10 new configurations pass: three normal profiles and a focused generation
audit exhaust their queues; six complete terminal witnesses cover both support
and knowledge orders for all three programs. Due explores418 distinct states;
future/off-grid each192. Raw terminals require all three accepted public calls,
immutable proof/held history, a real attempted refusal, cleared current stop,
knowledge, support, and a fresh generation1 candidate. All43 original handoff
outcomes and all30 existing TLA/390 configuration bytes remain preserved.

Root review found that the initial wrapper unnecessarily deferred InstallSupport
until after recovery, blocking legitimate G05 pre-recovery work. Restoring the
base action's availability fixes this seam. A red old-wrapper check loses the
new support-first witness; all three repaired support-first terminals record
supportAt.index2/floor0, and knowledge-first terminals record index3/floor1.
An earlier Setup framing error was also caught before semantic acceptance.

The actual shared source fault removes only Settlement's generation conjunct.
Baseline/restored exhaust663 generated/418 distinct states with queue0; the
mutant violates exactly StopProofGenerationAudit and executes actual Land from
checkpoint1 to2 with proof generation0/current generation1, preserving live
parent1 and recording audit.oldProof. Original Settlement SHA-256 is
`3fd57284128ea5a19966c2684161f909155a4730310972fee87d50eed009b84a`;
mutant SHA-256 is
`795218170ebae50896522cc1facf7c473a1639e881f21e7e8505ac8564818a2f`.
Actual same-copy restoration and source maps verify. Missing queue and attempt
controls instead exhaust safely with the required terminal absent, then regain
the witness after restoration; they are not counted as safety kills.

Independent adversarial source review and independent actual execution/raw-state
audits pass at all14 frozen model/config/catalog hashes. The tester independently
repeats new10/old43, the selected generation campaign and both omission controls,
and checks all six full terminals plus G05's eligible pre-recovery Future seam.
The shared inventory now has66 assessed obligations (61 TLC,5 Forge); four
aggregate unassessed categories remain unchanged. Deleted temporary shared phase
trees are not claimed to have been walked post hoc; raw/hash/restoration evidence
retains its actual attribution.

The wrapper SHA-256 is
`d03354cf46164ba71aef62bd3076793cc68e1006382135982d536914fe7202ee`.
G04 is complete for this finite opaque-proof product. The inherited proof has no
age field: availability of the proof/reference remains a fixed environment
premise, not measured retention, an M07 produced job, real ZK/STF execution or
complete authenticated history. G05 actual signer composition remains next.

## Coverage-closure batch — G05 actual signer composition

The additive [signer wrapper](HANDOFF_SIGNER.md) extends G04 and invokes a
namespaced INSTANCE of unchanged EtnaSignerCrash with21 distinct signer
variables. Three Future/support-first profiles retain computed, persisted or
already-exposed-and-retried generation0 work before public recovery. Actual
handoff and signer AuthenticateRecovery adopt floor1 together; immediate and
post-restart stale requests/exposures are attempted through actual enabledness.
Already-sent old packets may be delivered afterward. Fresh-domain trust/connect,
two persist/expose pairs and a second crash/restart precede a refused rollback/
conflict attempt. Old inherited session trust remains revoked throughout.

All eight new configurations pass. Five normal/focused audits exhaust10,623
states generated/5,356 distinct with queue0; three full terminal witnesses reach
only SignerTerminalNotReached at10,468/5,285/119. Each requires the full inherited
G04 terminal and all32 actual signer steps, not a cursor-only end marker.
Independent raw parsing matches all96 before/after receipts to actual signer
globals and independently derives application replies from historical Outcome.
The tester also repeats all10 G04 and13 original signer profiles. All31 old TLA
and379 default configuration bytes remain unchanged.

Two actual shared source faults add precise exposure obligations. Omitting only
AuthenticateRecovery's durable floor write permits restart to restore floor0,
then actual StaleExpose at step15 under independent handoff learnedFloor1. The
returned/network sets are unchanged because this is an idempotent re-exposure;
SignerFloorExposureAudit observes the action event and catches it. Dropping
actual Crash HRS preservation permits second restart followed by actual
Request/Persist/Expose of domain1 slot1/B, despite retained returns slot1/A and
slot2/B. SignerHRSExposureAudit catches this actual rollback/conflict at step32.
Both fresh shared campaigns are KILLED for exactly those named audits; baseline
and same-copy restored phases exhaust cleanly. Source maps and mutation hashes
verify attribution. Shared temporary phase trees are deleted by the engine;
raw/hash/reconstruction and recorded restoration are audited, not a posthoc walk
of those deleted trees.

Six actual component-action omissions (Request, Persist, Expose, recovery
AuthenticateRecovery, Crash, Restart) lose the required terminal witness while
safely exhausting; same-copy restoration regains it. These36 authored TLC runs
are missing-progress controls, not assessed safety kills. The tester independently
repeats Request and Restart omissions in12 runs. The shared inventory is now68
assessed obligations:63 TLC and5 Forge; the four aggregate unassessed rows remain
unchanged. This increment executes only its two new shared IDs; the final gate
separately reruns all required cohorts.

Independent adversarial source review and independent behavioral verification
pass at all12 frozen semantic file hashes. Wrapper SHA-256 is
`56a2ed7c081eabd1250b222637f34f3d5edfea56a129f8645c7c15a081a23043`.
The scope is three selected scripts, two domains and two abstract HRS ranks,
symbolic signature records and authenticated input premises. It does not
establish concrete L1/session authentication, FilePV/key/crypto behavior, node/
WAL/power loss, exhaustive interleavings, real proving/STF or full liveness.
Proof/reference availability remains G04's fixed premise. All five authorized
increments are implemented; final accumulated verification/review remain pending.

## Coverage-closure batch — final gate and retrospective

All five authorized increments G01–G05 are complete. Stop here; no sixth
increment starts. The existing PR remains draft. No independently supported
protocol/SPEC/production defect was established on the pinned revisions, and no
production, normative SPEC or Notion source was changed.

| Increment | Established selected evidence                                                                                                                  | Principal remaining boundary                                                                                    |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| G01       | Draft-enabled exact TLC/Python CI, actual hosted execution, owned-resource cleanup and complete artifact readback                              | Native/contract/proving acceptance remains separate                                                             |
| G02       | Actual GoLevelDB completed-write ACK, owned SIGKILL, different-process same-directory reopen, full literal rows and intended whole-write fault | Power loss and actual multi-store importer/App/EL not exercised                                                 |
| G03       | Actual stock15-branch handshake matrix, exact AppHash-guard fault, empty-store shortcut and documented first-block stop                        | Mock ABCI; real application/history admission and known-stop handler remain open                                |
| G04       | Three positive-stop programs with actual queued/attempted old proof, six full terminals and observed bad landing on generation omission        | Opaque proof/reference availability is fixed; no producer/retention/real proof claim                            |
| G05       | Actual signer actions in three prework profiles,96 raw receipts, crash/restart/fresh progress and two observed bad-exposure faults             | Authenticated inputs, two abstract HRS ranks and selected scripts; no native signer or exhaustive interleavings |

### Stable accumulated execution

The immutable candidate snapshot was formed from ef65f26a6 plus the exact12
reviewed G05 semantic files. Every model, config, runner, native input and catalog
byte matches implementation head43fe46187fdf0eb5791ac75f840b1a15a49b2e56; the
snapshot's older README/REPORT/WORKLIST prose is explicitly excluded from claims
about closing documentation. All655 snapshot file hashes remained stable.

The actual Docker gate passes387/387 exact outcomes:79 normal searches exhaust
with empty queues and308 controls/witnesses violate only their declared
invariants. All current config/model hashes match raw logs/results. Mandatory
Python discovery/execution passes227 tests (57 gate/container,150 conformance,
20 sensitivity), with zero skips/errors/failures. The separate host-controller
lane passes all five real lifecycle tests. Rule checks verify640 live markers,
index/assets/links; migration purity is explicitly skipped without a base.
Docker reconciliation and quiescent no-follow output checking pass.

Actual hosted [run44030752309](https://github.com/taikoxyz/taiko-mono/actions/runs/44030752309)
at exact implementation head43fe46187 also passes every job step, the same387
outcomes/227 Python tests, resource reconciliation, quiescent output check and
both artifact uploads. Both API artifact digests bind the exact run/head. The
complete399-file raw archive and separate two-file private diagnostics have been
read back, with config/model hashes and every named outcome checked. Raw archive
SHA-256 is
`913679a53b43c55f16f8c22ce448734eed08171c48b160f0d40c20acc0c814bf`.
The closing documentation head triggers its own CI; implementation-head success
is not mislabeled as that later execution.

All68 assessed obligations run freshly in the required63 TLC/3 Forge identity/
2 Forge rules partitions. Every intended mutation is KILLED with successful
original and actual same-copy restored execution:243 raw phase logs in total.
The four aggregate unassessed categories remain unchanged and outside this
passing denominator. Temporary shared phase trees were deleted by the engine;
raw logs, hashes, reconstructed sole replacements and recorded restoration are
verified, without claiming a posthoc filesystem walk of deleted trees.

Current frozen-byte native persistence and handshake campaigns also rerun.
Original/restored phases pass8 and15 leaves respectively; the whole Bootstrap
write omission gives exactly four intended failures, and the AppHash guard
omission exactly two. Full1659-file pinned source maps, retained original/
restored copies, generated fixtures and tool hashes verify. Native execution is
offline and uses the existing canonical cache/lock. It does not imply signed
history, consensus startup, real EL durability or physical power-loss testing.

Independent complete-batch source review and independent raw-artifact audit
are READY for the selected diagnostic draft, with no material finding. Source report SHA-256: 408e160e5f43b98b0881af187cfe781db1a5b059838a0d03140c2e110df63ae0.
Raw-artifact report SHA-256: 83de53cc542283e80b02aa97e881e54bcce16a40e94f6888f46a37db979c234b. Per-task gates and final gates
are separate evidence. The closing commit changes reporting/checklist prose
only; executed semantic inputs remain identical to the reviewed implementation.

### What self-checking missed and what changed

The previous green scopes could not establish the omitted paths. This batch
found missing acceptance obligations in the work index, false-green empty or
skipped test handling and ordering assumptions in the new gate, hosted isolation
incompatibility, and unsafe parent-output/artifact link handling. All confirmed
in-scope defects were repaired and independently rechecked. The G04 wrapper
initially blocked legitimate pre-recovery support; the corrected seam has exact
raw support-first terminals. Setup/parser/receipt defects were corrected before
counting semantic outcomes. These are verification/tool/abstraction defects,
not new production protocol findings.

The improvement is to require independently observed raw writes/actions, complete
positive terminals, actual missing-action controls and exact real-source faults,
then audit original/restored bytes. An assertion sharing its acceptance data or
a safe no-progress run can still be green while omitting the important path.
Counts and independent review reduce those blind spots; they do not exhaust
unmodeled behavior or validate implementation interfaces that do not yet exist.

### Remaining work and decisions

[WORKLIST.md](WORKLIST.md) retains29 obligations and10 required composition
families. V02 and the selected C03/U01/U02 scopes are complete; wider C01/C02,
weighted consensus/committee derivation, changing authenticated targets, actual
multi-store import, shared encoding/key vectors, zk-gas semantics, real proving/
DA, runtime budgets and funded launch/operations remain OPEN or WAITING with
explicit acceptance. The19 incomplete historical profiles map to their missing
properties, not a fabricated requirement to rerun obsolete model versions.
M01–M12 parent checkboxes stay partial until their broader acceptance is met.

Root decisions made during this batch, with the cost if wrong:

- Use the Git worklist as the current index and preserve the older issue body as
  history; old local/unpushed counts must not be mistaken for current status.
- Choose these five bounded available checks while real App/EL/importer/proving
  dependencies remain WAITING; a green batch cannot close whole modules.
- Compose actual EtnaSignerCrash rather than repeat only local trust booleans;
  concrete L1/session certificate authentication remains unverified.
- Keep pre-fix host-adapter evidence attributed to its own bytes after pre-mount/
  output repairs, and require the final hosted full run/artifact audit before G02;
  otherwise old execution could be mislabeled as new runtime verification. That
  required final hosted gate passed at9798a68fa.
- Rebut the speculative Go finalizer concern from exact pinned LevelDB receiver/
  goroutine lifetime rather than add KeepAlive without evidence. If that source
  judgment were wrong, an automatic Close could weaken the abrupt-death claim;
  the independent source reviewer checked and agreed with the lifetime evidence.

The hosted Docker backend is the documented response to actual uid_map refusal;
no global policy change, privileged fallback or unsandboxed execution was used.
Authentication and proof availability remain stated premises. Historical issue
content, raw evidence, plan workspace and linked worktree are preserved while
PR22387 stays open. The hourly monitor returns to feedback-only mode; another
batch requires direct user authorization.

### Root disposition of final-review boundaries

The final source reviewer reported no material finding and listed16 considered
extensions. Root checked each against the accepted task and actual evidence:

| Review item                                           | Root disposition and consequence                                                                                |
| ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| 1 production importer/App/EL/real prover              | Keep WAITING dependencies; no concrete recovery/proof acceptance claim.                                         |
| 2 power loss or WriteSync-to-Write                    | Keep actual process-death/whole-write control; OS page cache survival does not establish power-loss durability. |
| 3 complete real handshake replay/history              | Keep selected stock API observations; complete replay and signed-history admission remain open.                 |
| 4 empty-store/error typing/non1 stop repair           | Preserve observed upstream behavior and documented stop; concrete handler remains C02 work.                     |
| 5 stock Ed25519/parameter fixtures                    | Keep stock-only attribution; exact Etna encodings/signatures/resources remain E01/L01.                          |
| 6 proof age/producer attribution                      | Keep fixed opaque proof/reference premise; no M07 or real-proof result.                                         |
| 7 forced Due signer acceptance                        | Use genuinely accepted Future prework; Due/OffGrid remain separately checked G04 paths.                         |
| 8 concrete L1/FilePV or alternate L1Trust             | Keep actual SignerCrash deliverable and explicit authentication premise; T01/C01 remain open.                   |
| 9 wider/unbounded/fairness/nil-vote products          | Keep finite bounds; these green scripts do not establish wider coverage.                                        |
| 10 omission controls as safety kills                  | Preserve reachability-loss classification and assessed denominator.                                             |
| 11 mock tests as native/hosted evidence               | Keep actual lanes separate; final runtime claims come from fresh raw executions and archives.                   |
| 12 golden fixture as sufficient/automatically invalid | Retain independent native branch/state/row oracles; hashes alone are insufficient.                              |
| 13 arbitrary host/daemon-loss cleanup                 | Keep owned-resource reconciliation/fail-closed publication; host-loss guarantees remain unproved.               |
| 14 unknown future Go output                           | Keep strict pinned event contract; a changed SDK needs revalidation.                                            |
| 15 cache/tool provenance as refinement                | Keep bounded provenance claim; no runtime-equivalence certification.                                            |
| 16 cosmetic collector/fixture rewrite                 | Leave unchanged without a demonstrated defect; retain current reviewed behavior and avoid unrelated scope.      |

These affirm existing explicit bounds rather than park a correctness finding.
If a later implementation relies on any excluded behavior, its owning worklist
obligation must be executed before these results can be reused for that claim.

## Adversarial-coverage batch — scope and attribution preflight

H01–H05 starts at18fb38a39 under new direct authorization for five increments
and frequent reflection. No implementation result is claimed yet. Read-only
source-first reconnaissance identified two actual-source boundaries (public-PoP
Registry lifecycle and unsigned weighted multi-height stock transitions) and
three omitted model chronologies (proof recapture, FI replacement after partial
settlement/recovery, and irreversible pre-correction payments).

A concrete attribution gap was found before execution: existing Registry8 and
recovery lifecycle helpers call Foundry test-key creation/signing. Their earlier
actual-source test results remain valid under that test setup, but they are not
public-signature-vector-only runs, and a blanket statement that no local test
signing occurred is incorrect. No live key, wallet or transaction is implicated
by this setup observation. H01 must instead consume published PoP bytes at their
bound domain from a fresh minimal base, with all transitive hooks inspected.
Existing unchanged legacy Forge results remain historical rather than counted
as newly executed under the no-signing scope. This correction concerns execution
provenance, not an established protocol flaw or retrospective claim of public
fixture correctness.

The new plan requires an omitted legal history, independent raw observation,
complete positive terminal and intended-failure discrimination per increment.
More green counts alone are insufficient. Concrete authenticated histories,
STF/proof execution, full consensus and corrective storage migration remain
separate obligations; independently supported actual protocol defects stop work
for discussion. Original sources/configs and prior evidence remain preserved.

## Adversarial-coverage batch — H01 public-input Registry lifecycle

H01 completes the selected actual held-slot lifecycle, not all R01. A fresh
Vm-only minimal fixture uses the actual Registry constructor, proxy dispatch and
initialization at the published chain1/address2222 domain. It checks all12
published digests before actual PoP registration across6 keys/2 owners. No
EtnaTestKeys/CommonTest/base setup runs; no new key/signature is generated.
Public code placement, actor impersonation, exact-transfer token and supplied
initialized/unlocked Inbox snapshots are explicit test premises.

Five actual tests cover two six-PoP same-block cohorts and later activation,
repeated top-ups/activation, mature-but-unactivated liability, and full forfeiture/
public zero withdrawal. Literal histories require effective12 after two activations;
forfeit8 from principal16 (effective4 then pending4), leaving effective0/pending8/
custody8/sink8; first confirmation16 survives repeat17; withdrawal17 refuses and
18 pays8. The zero-principal path emits no token zero-transfer. Complete raw
packed bond/entry/principal/custody/lifetime identity, exact ordered events and
independently constructed canonical roots/frozen checkpoints are checked. Every
failed call has exact revert bytes, no logs and full selected raw equality,
including all8192 admission-index cells. This is a bounded footprint, not all
possible EVM/transient storage or semantic admission-index verification.

The author actual-source fault omits only pending-principal deduction. Its
mutant reaches raw pending12 with custody8 and fails exactly the liability test's
`public ledger: pending principal`; the other4 pass. Both original and actual
same-copy restored phases pass all5. The integrated authoritative manifest's
fresh `registry-public-pending-deduction` campaign separately passes with
ready=true/inputs_stable=true and only that obligation selected. Inventory total
is69 assessed (63 TLC/6 Forge), but this increment freshly executes only its one
new shared obligation; the five legacy Forge obligations retain historical
test-key execution evidence. Four aggregate unassessed rows remain unchanged.

An independent tester chooses a different real source fault: omitting the
first-confirmation early return. Repeating confirmation then writes17 over16;
only the liability leaf fails the direct raw assertion
`public confirmation: first block preserved`, while the other4 pass. Actual
original/restored phases pass all5. The tester independently audits the authored
pending fault rather than redundantly rerunning it. Both mutation effects and
all exact case/command/log/source identities are checked from raw Forge JSON.
No parser/setup/skip/timeout/wrong-reason failure is credited. Temporary phase
trees are removed by the existing runner; evidence is raw execution, same-copy
commands/hash maps, exact source replacement and recorded restored execution,
not a posthoc walk of deleted phase trees.

The independently re-extracted public Git blob is
`e069e2930143cbaf126d46532a96179764ec0ab6`, SHA256
`85d9df59bbc1709950be8cd8b248a3871523229afabd3d4e65b8027d6e4529de`;
all allowlisted12 row/6 key fields equal the published fixture. Only public fields
were retained. All564 pinned source entries and568 full staged snapshot records
verify, with symlink records checked by target, plus all30 reachable import/tool/
dependency identities. The source snapshot and extra staging metadata counts
serve different purposes. Sources/dependencies stay read-only and offline; the
existing physical cache/lock, launcher and classifier remain authoritative.

An initial observer resource-exhaustion run and incomplete Solady import-audit
attempt remain INCONCLUSIVE, not semantic evidence. The audit was completed
before accepted runs. All8192 cells remain checked; gas metering pauses only
around expensive observer sweeps and resumes before every actual public call.
No protocol/EVM limit was raised, and this establishes no gas/latency budget.

Independent source/spec/quality review and independently selected actual behavior
challenge pass with no material finding. Frozen test SHA256 is
`a44ac6d6ae69afdffd6cb9c1bed303a4d4ce16dd2c4565fa4febfb1f9ae75ae9`.
The public JSON extract SHA256 remains
`e441ece5cd83e70c2008da00b144f3411a1009dda3e18ce8cda9a4bebb208cdf`.
All old32 TLA/387 default cfg and other original executable inputs remain intact.
No actual protocol defect was established. Six keys and these histories do not
cover real governance/landing/proving, token callbacks,4096 displacement/capacity,
concurrency, double-sign admission or arbitrary failure storage. R01 remains OPEN.

Reflection: the concrete improvement is tracing setup to remove hidden local
signing and replacing same-write getter/root agreement with literal raw state,
independent roots/history and cash amounts. The separate confirmation fault
challenges a second real write; neither fault proves all Registry behavior.
H02 weighted state evolution remains next, with its own unsigned-only boundary.

### H01 pre-push integration — exact SPEC correspondence

Before H01 publication, hosted planning run44037594044 failed one conformance
check. Its actual checkout was mergef0d9028c17a95365fcf3e69972ef198f36948a9d:
planning headaae79c38c into updated mainb796b007c31a00e687238011dec38534a5b21d08.
The earlier reported base ref was stale; the checkout log and actual SPEC bytes
control this attribution. All387 TLC outcomes,57 gate tests,20 sensitivity tests
and149 other conformance tests passed. The single failure correctly detected
workspace SPEC SHA53877 versus canonical source4d81, not a Registry result.
H01 was kept local while the version change was reviewed.

Independent complete old/current SPEC review maps all11 token changes to their
existing governing rules: registry versus active-committee checkpoint terminology,
FI head/cursor wording, sub-proof spelling and back-pressure pause terminology.
No changed validity condition, bound, encoding, storage layout, rule ID or H01–H05
assumption was identified for this exact pair. Unrelated base test changes were
not approved by that source review. Normative files were never edited here.

The new [correspondence ledger](conformance/spec_correspondence.json) preserves
historical authority d18357214fab30ea512ae9858a11699806d72ba1 / blob
649548c58d6629dd85143b33efd3644a3bb71509 / SHA256
4d81d5dadcee3eb94ff554ec5a8144a47888dd5a8263ac5852422a0f1d1dd71b,
and records ONLY the reviewed workspace revision b796b007 / blob
07912c040eea8a925f9cb4ab2579bed1a105a3c7 / SHA256
53877d1f29ce90aac0b2f41620c6c79c2229eab154fa4630e5b187450be6ffc1.
The small separate spec_authority helper requires a closed metadata shape,
fixed source path, exact historical authority and both raw SHA256/Git-blob values.
Duplicate keys, malformed/unknown metadata and any unknown future document fail
closed. There is no runtime text normalization or automatic semantic classifier.
The ledger is reviewed source metadata, not an ancestry or semantic proof.

Both original historical manifests/pins and run_baseline.py remain byte-identical.
Their source consistency check is retained; a separate workspace test checks
exact reviewed correspondence. The actual original test over the new SPEC first
failed at the precise53877/4d81 assertion. Corrected actual original/reviewed
SPECs each pass all26 baseline and159 full conformance tests. A real reviewed
SPEC plus one newline still fails through the actual workspace entrypoint.
The independent tester repeats26/26 on both exact documents,159/159 over the
reviewed document and seven separate actual-body adversarial controls, checking
unique IDs, zero skips/errors/failures and stable554-record original/copied inputs.
The separate unknown-document rejection produces the required single ValueError
and exit1. An initial independent harness import
error remains inconclusive and is excluded from successful evidence.

Independent repair source/spec/quality review and independent behavioral
verification both pass with no material finding. This is necessary integration
repair before advancing the five-task batch, not another increment. H01 Registry
Solidity/public JSON bytes and its actual-source results remain unchanged; its
guide was only table-aligned by the normal formatting hook (current guide SHA
0e59c4ced4a479e25b809485ff8b29a3d36d46d644f064f395932e48155fc1ca;
pre-format2459ea57 is historical documentation only). Only the old baseline test
is adjusted for the separated gate; original model engines/configs are intact.
Latest-head hosted CI must be read back separately after publication; earlier
CI or these local actual-byte tests are not mislabeled as a later hosted run.

### H01 public-vector CI false positives

Hosted check44045299768 reports18 generic-api-key findings in the unchanged
public registration fixture:12 compressed public-key rows and6 public entry-key
digests. Independent extraction from pinned published blob
e069e2930143cbaf126d46532a96179764ec0ab6 already verified every field; no
credential is among these exact findings. The fixture SHA256 remains
e441ece5cd83e70c2008da00b144f3411a1009dda3e18ce8cda9a4bebb208cdf.
The repository-root .gitleaksignore records only those18 original
7a550c1c3 commit/file/rule/line fingerprints, without path/value wildcards.
Existing workflow and rule configuration are unchanged. No scanner was invoked
locally; a later hosted result must verify this integration separately.

## Adversarial-coverage batch — H02 actual unsigned weighted handovers

The [new native lane](conformance/COMET_HANDOVER.md) adds five six-transition
programs over actual stock CometBFT v0.40.0 /
0880b4d378f347ab16e54ec677ff50d803f37d62. Public A=B/B=-B/C=2B identities
are fixed; MakeGenesisState at InitialHeight11 starts A3/B1, and actual returned
State feeds each updateState call through height16. Programs cover no change,
unequal powers, removal/addition, full replacement and a second update at12
before the first update at11 becomes current at13. A byte-pinned bridge only
forwards the private operation; an external module imports production packages
without compiling upstream test-package key-generation globals.

Before native execution, source-independent literal arithmetic and protobuf/
Merkle encoding were frozen: literals SHA256
d8b9e9a2059cf7ef2a2a3d5b5f1b1a1ba668f85c7d1512fe891c485971f20f09;
derivation4b85ada31a77633a54a16ab9e117ad2d41a20eea50b7cbfb2380404d3402b5e8.
The independent reviewer checks all105 normal/two-fault state rows and210 hash
projections; the behavioral verifier separately derives35 normal rows/70 hashes.
Expectations do not call the actual transition, ValidatorSet constructor,
GetProposer or Hash as their oracle. The complete stored proposer object matters:
it need not equal the member with greatest final priority. Signed negative-floor
centering can preserve a nonzero priority sum; the expected table retains it.

Author execution has five phases: normal, omitted actual priority increment,
actual restoration, premature current-set activation and actual restoration.
All25 exact leaves,150 transitions and175 full state observations match their
predeclared normal/fault results, including actual MakeBlock current/next hashes.
A compiler/setup failure or arbitrary diagnostic never qualifies as sensitivity.
The independent tester chooses the different actual LastHeightValidatorsChanged
H+1 versus H+2 fault: unchanged remains green, all4 update programs produce only
the exact predeclared change-height differences; normal/restored5/5 pass.
Complete raw receipts and positive terminals remain mandatory.

All1659 original upstream entries and the one generated bridge are audited
before/after execution. Native module/fixture/generated modfile and selected Go
tools are guarded, with the existing offline namespace/supervisor and the same
canonical cache/lock. Actual source restores on the same private tree, followed
by actual normal reruns. No new dependency, signing, live operation or production
source change is involved. Prior serialized State.Bytes and update/header/ABCI
inputs are checked unchanged; private unexported caches are outside that claim.
The guide's serialized-state scope was clarified before author execution;
only table formatting happened afterward. All code, literals and pins stay exact,
and independent native execution uses the final guide bytes. Historical author
input records retain the pre-format guide hash.

Six collector regression tests and the full165-test conformance suite pass.
Independent source/spec/quality review and independent behavioral/source/raw
verification pass. Existing shared mutation inventory remains69; the native
source faults are separate evidence, not newly added shared obligations.
Exact final whole-batch Python/TLC counts and hosted CI remain later gates.

### H01–H02 cross-task reflection

The prior false-green risk was testing coherent prepared objects or two getters
backed by the same write. H01 replaces that agreement with public registration
history, literal principal/cash/history observations and a separately chosen
confirmation write omission. H02 replaces independently seeded validator states
with actual consecutive stock updates and checks every intermediate result.
An independent change-height fault demonstrates a field that could be wrong
while all member hashes remain coherent. These are substantive coverage changes,
not evidence that the remaining protocol is correct. No natural protocol defect
is established by the selected executions.

The strongest remaining shared premise is the boundary input itself: H01's
initialized/mock Inbox snapshot and exact-transfer token; H02's unsigned genesis/
ABCI updates and empty structural commit. Neither authenticates the real
node/EL/guest/L1 interface or proves commit admission. H02 selected powers do not
exercise rescaling, clipping or overflow. R01 and K02 therefore remain OPEN.
Next H03 must compose actual proof expiry, resource loss, fresh recapture and
resumption, rather than infer progress from a refused stale proof alone.

## Adversarial-coverage batch — H03 proof recapture and resumption

The [new wrapper](PROOF_RECAPTURE.md) calls unchanged EtnaProvingProgress
actions from its original Init, with two selected36-attempt resource orders.
History and backend arrival/loss include isolated missing-history and
missing-backend completion attempts. The wrapper attempts each real action when
enabled and records complete raw before/after state, execution and production
count; it never suppresses a bad Land merely because a control expects refusal.

Both complete histories produce old blocks1/2, capture task0/reference0, retain
its genuine completed results through resource loss and refuse its expired
Land at time2. A distinct task1/reference2 first carries A's old reference0
statement and B's fresh reference2 statement; the real Land refuses at time3.
Actual fresh A completion then enables Land at3. At observation4, Finalize(3)
produces finalized checkpoint2/L1block3; PublishAnchor publishes reference3, and
the final actual Produce adopts that anchor and reaches head3/production count3.
Job0 remains immutable, the accepted prefix applies blocks1/2 exactly once, and
no recovery/generation reset is used to manufacture progress.

Author exact regression checks cover21 EtnaProvingProgress,10
EtnaProvingRecovery and10 new EtnaProofRecapture configurations, all41 matching
their declared outcomes. The new10 comprise one complete normal profile, two
dedicated raw audits, five deliberate absence controls and two full terminal
witnesses. The absence controls' PASS means the complete terminal was not
reached; it supplies no positive-progress or broad safety claim. Discovered
default count is now397; the later whole-batch gate must execute that complete
then-current set before claiming a fresh accumulated result.

Two exact private M07 source omissions are assessed: remove the reference-age
conjunct, or remove backend-statement equality. Independent raw traces confirm
actual bad Land0@2 or Land1@3 with ARef0/BRef2, followed by only the intended
RecaptureExpiryAudit or RecaptureBindingAudit failure. Original/restored phases
pass and same-copy source restoration is actually rerun. The unchanged M07
engine SHA256 is4a102d5e465b7c943b8564994a320fb4b2af13fbe5348c0f095aa75016fa0105.
Shared catalog/cohort adds only those exact two entries: current inventory71
(65TLC+6Forge), with4 unassessed categories and all prior records preserved.
This inventory is distinct from the newly executed two obligations.

Independent source/spec/quality review passes the complete14-file model/config/
guide/catalog change. The independent verifier checks both author37-state full
traces against its source-derived36-call/literal-job oracle, all41 exact raw
results and both bad-Land original/mutated/restored campaigns. Its own14 selected
TLC cases include two original full witnesses, the distinct actual wrong-parent-
credit fault, actual same-copy restoration, and missing PublishAnchor/Produce
controls. Ten complete37-state diagnostic/witness traces preserve every36-call
receipt. Wrong parent credit retains genuinely landed/finalized checkpoint2 and
its new anchor, but the last Produce is disabled and head remains2: this is
complete-witness loss, not a generic safety kill. Restoration recovers both full
witnesses. Source, tools, generated observers and all32 old models/387 old
configurations remain exact. The20 shared sensitivity/cohort regression tests
also pass against the integrated catalog.

An initial independent TLC attempt was inconclusive before state generation
because the managed sandbox blocked Java's local worker socket. The same
inspected isolated/offline invocation then ran with the required outer permission;
no external-network or alternate-runtime fallback was used. Author fault source
snapshots predate guide creation, so no later guide hash is attributed to them.
Independent execution includes its then-frozen guide; subsequent prose changes
format tables, replace ambiguous module numbering with exact module names, or
remove the stale editorial qualifier after the scoped source update.
All executable model/config bytes remain the actually tested versions.

Reflection: refusing stale or mixed proof alone could leave an apparently safe
but permanently stalled chain. Complete real recapture, accepted landing,
finality, anchor adoption and another Produce are now required, and a distinct
real credit omission loses that exact terminal. The selected bounded schedules
do not establish latency guarantees, arbitrary asynchronous liveness, private
history availability, real proving/STF/DA correctness or a long-outage policy.
RefWindow still jointly reduces proof-reference age and anchor age as in M07;
no protocol parameter change is inferred. P01 remains OPEN. No natural protocol
defect is established by these intentionally faulty executions.

### H03 pre-push integration — scoped SPEC correspondence

Fresh PR inspection before H03 publication found H02 headf22df335d hosted
run44049560621 failed one test. Actual checkout470fb21af29bcaf12891ee1eb1653cf39fe1e48a
merged it into newmain991e06f6d94842b2f57c67a4a8ba254b3c5a8830, parentb796b007.
All387 TLC expectations,57 gate tests,20 sensitivity tests and164 other
conformance outcomes pass. The sole error correctly rejects unknown workspace
SPEC bytes. Both399-file raw and2-file diagnostic archives were checksum-bound
to their GitHub metadata before error/root-cause readback. This is normative
source drift, not a failed H02 transition or a reason to weaken an unknown guard.

Exact current SPEC blobaf8c32cc1e8af7eade999040747d074d429df2bc / SHA256
753d3188055cfef7cd7868e6abe954fbffd5115babca96b74602b54603bcfc32 changes
START-10-5. Independent primary review also reads its five adjacent document
deltas. Shared same-code SignalService deployment now separates immutable root
provider, write syncer and optional legacy syncer; adjacent requirements include
full provider uint64 lookup, uncached failure/zero/missing-return rejection
without local fallback, no L2 Inbox read, atomic Anchor/provider cross-check
and retry, plus VERSION/cache/checkpoint continuity. These are normative changes,
not editorial synonyms. Historical89 contracts have the older constructor and
separate L2 override, and no selected replay executes the new provider/upgrade
path. That new implementation/deployment acceptance remains D01 WAITING.

Independent scope review finds the consumed registry initialization clause, old
bounded L1 checkpoint save/get, selected model rules/encodings/layouts and
H01–H05 chronologies unchanged. This permits continuing only those explicitly
historical/bounded programs under their stated premises. It supplies no whole-
SPEC equivalence or new deployment conformance. Current tracking adds D01 and
one required composition family, totaling30 records/11 families; earlier29/10
counts stay historical. Tracking is not an extra executed increment.

The small three-file gate update keeps the same closed schema, fixed source path,
exact historical authority, duplicate-key rejection and both raw SHA256/Git-blob
checks. The reviewed-scoped-correspondence class and reviewed-scoped result
replace the editorial taxonomy, and sole current753d tuple replaces53877. Canonical4d81
remains accepted; earlier53877 is no longer an implicit runtime exception.
All historical pins/manifests, run_baseline and original models/configs remain
exact. No normalization, automatic classification or future revision acceptance
is introduced; metadata records independent review rather than proving it.

Actual unchanged-helper/new-body rejection was reproduced first. Corrected actual
canonical/current documents each pass27 targeted and166 full conformance tests;
previous53877 and current753d plus newline each fail through the real workspace
entrypoint with the precise no-reviewed-correspondence ValueError. An added
replacement regression and old-editorial-class rejection preserve one admitted
current identity. Independent repair source/code review and actual behavioral
verification pass separately; the latter retains exact raw identities, expected
refusals and source/tool guards. Whole-batch accumulated checks and latest-head
hosted CI remain separate final gates.

All18 H03 files and561 tracked formal files outside the three-file repair were
protected through authored repair execution; final independent guards likewise preserve actual model/code
inputs. Only afterward are D01/closing prose and the guide's stale editorial
wording updated. No earlier run is relabeled as consuming that later prose.
No production, normative source, deployment or live operation changed here.

## Adversarial-coverage batch — H04 FI suffix recovery and replacement

The [new additive companion](FI_SUFFIX_RECOVERY.md) starts at the unchanged
FIInit and calls actual EtnaForcedInclusion/EtnaSettlement actions, preserving
the original outer production guard/increment. MaxHeight2 and MaxProduces3
permit old1, discarded old2 and replacement2; stage remains0. Two selected
15-attempt histories differ only in hash blanking versus retention. Every
enabled real action executes, even a deliberately bad source operation; raw
audits never schedule that operation away.

A is admitted at block0/timestamp10/fee1 and old1 consumes it locally. B is
admitted at block1/timestamp12/fee2 while local cursor1 has advanced but the
L1 landed head is still0. After old2 exists, Prepare2 retains its queued proof
and a fresh landing settles only checkpoint1. Actual recovery at3 retains
parent(0,1), rewinds the raw local cursor2->1, advances generation/nonce and
only blanks B's hash in the Blank case. Timestamp12/enqueueBlock1, A's entry,
fee admissions and cash/revenue3 persist. The inherited journal oldCursor is
settled1 and cannot independently attest actual pre-recovery local2.

The old prepared proof is actually refused after recovery; generation, parent/
origin and cut conditions all reject it, so this supplies no isolated generation-
guard sensitivity claim. At block4 the replacement adopts closed anchor3,
produces distinct(1,2) with retained parent(0,1), then actually lands checkpoint2.
Complete terminals require three actual productions, one recovery, two executed
landings, final cursors/head/tail2, unchanged queue timestamps and fee totals,
and the independent L1 applied-index event sequence[0,1] exactly once. B is
a symbolic inclusion body; no Completed/ObserveBuild or real EVM revert/STF
is executed or inferred.

Author final39 exact outcomes cover20 original EtnaForcedInclusion and19 new
configs. The new19 are one complete normal, two focused raw recovery audits,
14 deliberate omission/terminal-absence regressions and two positive terminal
witnesses. Each positive trace has16 states/15 raw receipts. Absence PASS is
not a successful-progress or broad safety claim. Initial missing-Sequences and
unbound primed-stage diagnostics were confined to the companion, corrected and
retained without behavioral credit; final39 uses the corrected frozen code.
The formatted guide existed before the final checker/source campaigns and its
consumed bytes match the published guide. Discovered default count is now416;
the whole-batch final gate remains separate.

Two actual private FIRecover write faults are assessed: retain old local cursor2
instead of landedCut1, or omit B's hash-only blanking. Each really executes
recovery11 and violates only the matching SuffixCursorAudit or SuffixHashAudit.
Original/restored phases pass with actual same-copy restoration/rerun and stable
source/input/tool records. Shared inventory now73 (67TLC+6Forge); only these two
new catalog obligations are freshly executed here. All previous71 assessed
records and4 unassessed categories remain unchanged. The20 catalog/sensitivity
Python regressions also pass.

Independent source/spec/quality review passes the complete23-file change.
Independent behavior uses a different actual FIRecover revenue-reset fault: it
executes genuine recovery while revenue3->0 and cashPaid/admissions remain3.
Literal raw accounting rejects it immediately, and original/same-copy-restored
Blank/Retain full witnesses pass. Missing old2 is especially discriminating:
the program can still end with settlement head/cursor2 and revenue3, but has
only two productions and no discarded old2. Missing final landing instead
retains only the first L1 applied index. Full partial-terminal traces expose
these differences; no final-scalar snapshot substitutes for the required history.
The verifier also independently checks author39 raw results, both actual bad
Recover writes, original/restored source and tool identities.

### H03–H04 cross-task reflection

H03 required actual fresh proof completion through finality, anchor adoption and
another Produce, beyond a refusal or enabled predicate. H04 requires an actual
old suffix and replacement landing beyond apparently correct final height,
cursor and cash. Its missing-old2 control demonstrates how the same terminal
scalar state can hide omitted coverage. Raw local cursor2 is also distinct
from the recovery journal's settled1; agreement with that journal alone would
miss a wrong rewind. These checks strengthen specific observers and histories
without implying that the whole protocol has been verified.

Remaining shared premises include authenticated canonical anchors, atomic
authorized recovery, symbolic FI bodies/fees, valid chain/STF and abstract proof
interfaces. These are finite schedules with selected bounds, not arbitrary
interleaving/fairness, actual EL/guest/client/prover/resource execution, real
fee currency or gas/zk budgets. F01/P01/Q01 and new D01 deployment acceptance
remain OPEN/WAITING. No natural protocol defect is established. H05 next tests
actual modeled payments before correction and preservation afterward; broader
corrective implementation remains Q02 WAITING.

## Adversarial-coverage batch — H05 pre-correction payments and fresh retry

The [final additive companion](ROLLBACK_PAYMENTS.md) invokes unchanged
EtnaVerifierRollback/EtnaSettlement actions from RollbackInit/setup0. Its Core
program has23 actual attempt receipts; NonceBefore and HeightReuse have24each.
All include the16 original transaction/progress calls plus explicit checkpoint,
cache, stale-authorization and invalid-proof probes. No concrete corrective
implementation API or payment history is invented by a state setter.

Imported valuePaid1/stakePaid1 are labeled baseline, not transfers. Actual
Withdraw1 before containment adds one stake payment, and RetryForged actually
pays one value before PauseBoth/Upgrade. At correction, raw valuePaid2/stake2/
fees1each, Forged escrow0/completedTRUE and bond1 principal0/withdrawnTRUE must
persist. Both old message caches are100, equal to firstBadBlock100, so even
the earlier Legit cache is revoked; genuine ReproveLegit is necessary. It then
pays its remaining escrow1 once with fee0, and the real repeat makes no transfer.
Final valuePaid3/stake2 therefore separate actual[2,1] from imported[1,1];
only the two SeedMessage actions contribute the two fee payments. Confirmed1
was already cleared by withdrawal, so its zero at correction is not credited
as confirmation-invalidation sensitivity.

NonceBefore executes OwnerInvalidate before containment, requiring Upgrade to
advance the current nonce1->2 even though stored authorization.nonce remains0.
HeightReuse executes actual FreshGood2 after unpause; generation stays0 and
Good2 snapshot is20, not block101. The newly honest identity at numeric height2
can serve a fresh legitimate proof; height2 is not permanently forbidden. These
are selected atomic-model behaviors, not full node/consensus recovery evidence.

Raw observers inspect complete actual before/after state and every value/stake/
per-message fee delta. Independent totals alone would telescope, so literal
allowed amounts are also checked by actual action/payee and every other call
must transfer0. The old one-slot message journal can be overwritten; Upgrade's
afterCash is unprimed and its payment-preservation property omits completed.
Neither substitutes for actual raw cash' and completed preservation.

Author26 exact outcomes comprise19 original M09 configs and7 additive configs:
one normal, two focused preservation audits, three complete witnesses and one
grouped omission control. That control exhausts50 applicable profile/call
histories; these are structural nonreachability regressions, not50 new safety
claims. All3 full raw histories and each actual transfer were checked. Initial
Init-parenthesis parse diagnostics were confined to the companion, fixed and
excluded; final26 uses the corrected frozen code. Guide formatting occurred
before final execution and its consumed bytes remain exact. Current discovered
default count is423; whole-batch freshness remains the final gate.

Two actual private Upgrade faults are assessed. Resetting valuePaid to imported1
really executes correction with raw2->1 while the inherited journal still says2;
PaymentUpgradeCashAudit catches the negative change. Resetting already-paid
Forged.completed toFALSE really changes that flag while escrow remains0;
PaymentUpgradeCompletedAudit catches the preservation failure. It is not a
demonstrated duplicate cash drain. Removing the completed guard alone is not
discriminated by merely retrying again because retry isFALSE; even re-arming
would have escrow0. Original/restored phases pass, with actual same-copy source
restoration and stable source/copy/tool records. Inventory75 (69TLC+6Forge)
adds only these two obligations; earlier73 and4 unassessed records persist.
The20 shared catalog/sensitivity Python regressions pass as well.

Independent source/spec/quality review passes all11 source/config/catalog files.
Independent behavior uses a different real Upgrade nonce-source fault: stale
authorization.nonce+1 yields1->1 only in NonceBefore, rather than correct1->2.
Core/HeightReuse remain ordinary full-witness controls; their unchanged output
is not counted as another kill. All3 original/restored positives regain full
history after actual same-copy restoration. Missing the first PayLegit can still
finish valuePaid3/stake2 because RepeatLegit then pays1; there was no preceding
successful retry followed by a zero-value repeat. All3 raw partial histories
therefore lose the required complete witness despite matching final balances.

The independent audit checks author26, both bad Upgrade source triples and its
own13 exact executions/12 traces. In total17 independently parsed histories
contain385states/368raw receipts, with literal action/payee/authority/accounting
checks. All34 old models and416 old default configs remain byte-identical to
published b907a4108; original M09 SHA remains
9de72dfbc6149d07c0add856d11c71a9e113b3a80c26e1a0893cef2f3d48c832.
No source/jar/tool/generated-input drift or setup failure receives result credit.
Only later root closing prose is outside those execution snapshots.

Reflection: previous setup could assume already-paid amounts and correct only
before any real cash movement; final balances or a journal could then hide a
missing history or an actual field reset. This increment requires the actual
pre-correction payments, observes unchanged raw irreversible effects and then
executes a fresh-authority payout and genuine zero-transfer repeat. Those
selected observations leave injected verifier failure, valid root labels,
abstract fee/principal units and an already-correct atomic correction interface
as premises. Real proxy/storage migration, partial-failure atomicity, actual
SignalService/Bridge/Registry/guest/client authentication, real tokens/fees,
node reconciliation and new D01 deployment are unverified. Q02 remains WAITING.
No natural protocol counterexample is established. All five selected increments
are now implemented; final accumulated execution/review and retrospective remain.
No sixth increment is authorized.

## Adversarial-coverage batch — final gate and retrospective

The authorized H01–H05 implementation head is
`3bc4d53ff675ecf60a1e6c9c1846ff0af706d872`. All five selected increments have
separate nonauthor source/spec/quality review and behavioral verification.
The final accumulated snapshot contains35 recursive TLA sources and423 default
configurations. All32 original recursive TLA sources and387 original default
configurations remain byte-identical to the preceding completed G batch. Of480
original Python/Solidity/model/config records, only the approved source-correspondence
regressions in `conformance/tests/test_baseline.py` changed; original model and
runner implementations were not weakened to make the new histories pass.

### Fresh accumulated evidence and precise attribution

- The local isolated run checks423 exact TLC outcomes:108 EXPECT:PASS and315
  intended named controls/witnesses. PASS includes deliberate terminal-absence
  controls;108 is not a count of successful progress programs or independent
  protocol properties. Its ordinary Python suites pass57 gate,166 conformance
  and20 sensitivity tests, with zero skipped/error/failing tests.
- That local overall gate initially **fails**, despite those successful children:
  root prepared only the Etna docs subtree, omitting the external `Derivation.md`
  link target. The unchanged rule checker correctly rejects the incomplete
  snapshot. The authoritative hosted workflow copies the entire docs directory.
  Original failure/status/logs and its686-record snapshot remain retained. A
  separate offline focused rerun with the complete106-record docs snapshot passes
  all640 live markers, index/assets/links/tables. All original Etna doc bytes
  remain exact. This focused result does not relabel the failed overall run.
- Exact implementation-head [hosted run44068685817](https://github.com/taikoxyz/taiko-mono/actions/runs/44068685817)
  succeeds end to end, including all423 outcomes,243 ordinary Python tests,
  rules, resource reconciliation, quiescent output checks and both uploads.
  Its actual checkout is merge5d63416 of3bc4d53ff into reviewed991e06f6.
  The local SPEC is historical canonical4d81; that merge uses exact reviewed
  current753d/blobaf8. The executable/model/config inputs match3bc, while the
  separate strict scoped-correspondence gate checks the two distinct SPEC bodies.
  Both API archive digests match;435 raw files contain all423 case logs and
  exact config/model hashes, and the two separately uploaded private diagnostic
  files match their raw-archive copies. Native/Forge/controller work is separate
  from that hosted TLC/Python job.
- Only the **seven newly added shared obligations** are freshly rerun in the
  final campaign: six TLC actual-source faults and one public-input Registry
  fault. Each has successful original and actual-restored phases with its
  precise intended mutant failure. The public Registry phase runs five exact
  tests. The75-record assessed inventory is69TLC+6Forge; previous68 obligations,
  including five legacy test-key Forge lanes, retain their explicitly historical
  evidence. Neither75 fresh executions nor public-only legacy runs are claimed.
- The actual unsigned Comet handover lane freshly executes all five consecutive
  six-height programs through original, omitted-priority fault, restoration,
  premature-activation fault and restoration. Source/generated overlays, frozen
  literal observations, tools and1659 original source entries are guarded.
  Separately, all five real controller termination/timeout lifecycle tests pass.
  Independent per-increment extra faults and missing-action controls remain
  separately attributed rather than silently added to shared inventory totals.

Source snapshots, commands, raw receipts, exact mutation/restoration records,
tool hashes and independent audits are retained for this open draft. Migration
purity is explicitly skipped without a pre-marker base, as in the unchanged
checker; it is not a passing invariant. Four aggregate unassessed categories
and19 archived incomplete profiles remain outside the passing denominator.

### Why earlier self-checks could stay green

The useful outcome is that concrete blind spots were demonstrated and removed,
not that a protocol bug quota was met. H01 traced setup far enough to discover
historical indirect test-key signing, then built a genuinely public-input lane.
H02 checked independent literal priority/proposer/change-height histories rather
than deriving the expected validator set with the operation being tested. H03
required real fresh completion, landing, finality, anchor adoption and resumed
production instead of treating refusal or enabledness as sufficient progress.

H04's missing-old2 control reaches the same final height/cursor/revenue while
never constructing the discarded suffix; requiring all three Produce actions
exposes that gap. H05's missing-first-legitimate-payout control likewise reaches
the same final balances because the nominal repeat becomes the first payment;
only the full paid-then-zero-repeat history distinguishes it. Raw actual fields
also differ from journals: FI recovery's oldCursor records settled1 rather than
the actual local2, and correction's afterCash is unprimed. Independent allowed
amounts per action/payee prevent mere telescoping totals from passing as an
accounting oracle. These are reproducible reasons not to trust final snapshots,
shared expected-value code or green counts alone.

Fault injection establishes that selected observers discriminate selected
defects; it does not show that our fault selection spans unknown protocol
failures. Scripted full histories also do not exhaust asynchronous schedules.
Valid STF/authenticated L1 and an atomic correct correction interface exclude
important failure classes by premise. More runs over those same abstractions
cannot substitute for the concrete client/EL/provider/upgrade obligations.

Two SPEC movements were also treated as evidence requiring review. The initial
exact editorial correspondence is historical. The later991e06f6 shared
SignalService/provider changes are normative: current753d admission asserts only
independently reviewed correspondence for selected historical/bounded consumers,
not whole-SPEC equivalence or conformance to the new deployment. Canonical pins
remain unchanged; unknown future and superseded53877 bytes fail closed. New D01
deployment/provider/upgrade acceptance remains WAITING in the30-obligation,
11-composition worklist. This tracking and gate maintenance is not a sixth task.

### Scope decisions and their costs

1. Execute the directly authorized five without another approval pause. The
   chosen bounded APIs may require rework; this grants no protocol/production
   change authority.
2. Retain old five Forge lanes as historical test-key evidence and rerun the
   new public-only lane. Cost: those older lanes are not fresh in this batch.
3. Check unsigned weighted Comet state arithmetic. Cost: signed commit admission,
   rounds/locks, network behavior and registry derivation cannot be inferred;
   broader K02 remains open.
4. Check selected real-action chronologies in H03–H05. Cost: arbitrary asynchronous
   interleavings, real STF/proving and concrete correction remain P01/F01/Q02.
5. Pause gas only for complete raw observer/index sweeps and resume before actual
   Registry calls. Cost if the boundary were wrong: gas-dependent behavior could
   be distorted; these results establish no gas/capacity budget.
6. Preserve canonical pins and admit only the independently reviewed exact
   editorial pair during the first repair. Cost of misclassification: overstated
   relevance; unknown bytes must be rejected and exact source deltas reviewed.
7. Replace that superseded pair with the one independently reviewed current
   scoped normative correspondence and D01 tracking. Cost of missed consumed-rule
   impact: overstated relevance; this remains a reviewed finite-scope assertion,
   with no automatic future admission or new deployment guarantee.

No independently supported natural protocol/source counterexample has been
established within these bounds. Real App/EL/guest/STF/history/proving, weighted
network consensus, full registry lifecycle/capacity, concrete correction,
partial-failure atomicity and new shared SignalService deployment remain open
or waiting. The reason for no finding is still an open hypothesis about our
coverage, not evidence that the protocol is complete. Stop after these five;
the existing draft and hourly feedback-only monitoring continue.

The complete-batch nonauthor source review is READY for this selected draft
scope (report SHA256
`085a58e10f537039a96d851dbc1d2f6471dde5c7b3a6e063302d558f7cb6f1df`).
The independent accumulated local audit preserves the failed overall rule
snapshot attribution (SHA256
`8d1a7b15ded0d719caad931c488e9b0a4b06567464fb9bd946bfef3db24feff2`);
its separate exact-head hosted audit is READY (SHA256
`1c91172544a1f3ff90039c26b323a5c23ab4d0144aef0c173d452a05f9d10f90`).
The latter independently reads all seven full positive H03–H05 witnesses in
addition to every exact case result, unique Python test identity and archive
digest. Final source review did not substitute passing tests for code judgment.

Root retains all seven review boundaries above: authorization stays at five;
legacy Forge is historical; unsigned arithmetic is not consensus; selected
chronologies are not complete concrete refinement; observer gas is not a gas
budget; old correspondence is not future permission; scoped current
correspondence is not deployment acceptance. Additional arithmetic rescale,
clipping/overflow and private-cache internals remain broader K02 work. Final
execution/publication judgments were not delegated to the source reviewer;
independent raw audit and narrow closing-prose review address those separately.
No material finding was silently parked or counted as fixed by a setup failure.

The closing commit changes only README/REPORT/WORKLIST/plan prose. Executable,
model, configuration, fixture and pin bytes remain exactly the independently
verified3bc implementation; closing-head hosted status is read separately.
PR #22387 remains draft; worktree, ledger and raw evidence are retained.

## Interleaving-boundaries batch — J01 repeated recovery identity

The new companion executes13 actual modeled attempts: land1, recover at1,
prepare1→3, competing land2, overlapping land3, prepare3→4, recover again at3,
refuse the queued old proof and land fresh4. Full witnesses require both actual
recoveries, four actual landings, immutable prepared inputs, retained records,
actual parents0/1/2/3 and settled-prefix generations0/1/1/2. The final scalar
checkpoint4/generation2 alone is insufficient. All35 prior recursive models and
423 default configurations remain byte-identical; the nine additive profiles
bring discovered default configurations to432, not a newly run full432 gate.

Author35 exact executions comprise19 affected old identity profiles, nine new
profiles, two private raw omission endpoints, one real generation source-fault
execution and four same-copy-restored controls. The generation fault writes1→1
only at the second real Recover and immediately fails the dedicated raw audit.
The separate shared sensitivity campaign independently executes baseline,
mutated and restored phases on the same private copy; its one new obligation is
KILLED. Assessed inventory becomes76 (70TLC/sixForge), with old75 historical and
four aggregate unassessed entries retained. No new Forge/native execution or
natural protocol defect is implied.

Independent behavioral verification executes a different real Recover nonce
saturation fault. Its second recovery writes nonce1→1 while generation correctly
becomes2; the dedicated raw nonce observer catches that actual write. Original
and same-copy-restored full histories pass. A private missing-Prepare4 control
still reaches checkpoint4/generation2, two recoveries and four landings, but its
queued statement remains terminal3/parent1 instead of terminal4/parent3. The
complete witness disappears. Independent parsing reads every original variable
and raw state from actual TLC output, separately from author summary/oracles.

Omitting recovery2 allows the old proof's landing to execute and disables the
fresh final call. Omitting the overlap can retain the same checkpoint/generation
headline while changing startHeight, settled prefix and actual landing history;
its prepopulated unlanded record3 is not settled evidence. Every subsequently
enabled call executes. Absence PASS controls establish witness loss, not progress.

One pre-execution source-review finding corrected attribution: the stale proof's
execution-origin check uses proof.generation1 and therefore Genesis1, separately
from base Land rejecting proof1/current2. Fresh generation2 uses Genesis2. The
source reviewer rechecked the correction before any engine run. A separate root
launch initially produced three cleanup-test errors in20 catalog regressions.
A retained paired probe established inherited ignored INT/TERM dispositions;
the unchanged repository CI ENTRY resets them. Re-running only that suite with
the exact existing ENTRY yields20 tests OK/no skips. The original failed log
remains failed; no tool source, test or timeout was weakened.

Independent source/spec/quality integration and actual behavioral/raw-evidence
gates are READY. Source, executed-copy, configuration and pinned-tool hashes
remain stable through actual restoration. Reflection: earlier bounds stopped at
generation1, so saturation at1 was observationally indistinguishable from a
correct increment. This history exposes the second transition and checks retained
identity across both competing windows. It still assumes injective symbolic
identities, otherwise-valid proof/cut inputs and atomic authorized recovery on a
finite grid. Full S01/Q01 and concrete client/EL/guest comparison remain WAITING;
this closes only the selected modeled sub-obligation. J02–J05 and accumulated
final gates remain unfinished; no sixth is authorized.

## Interleaving-boundaries batch — J02 selective two-node supersession

The companion executes both41-attempt node-order mirrors across authenticated
snapshot1 and finalized recovery snapshot2. Both nodes really sign and serve
first; the first node then learns generation1 and loses only its own trust.
The lagging node actually signs Retained and serves using provider1/known0.
The first node's Block/Nil/Retained requests, service and old-target re-admission
refuse after knowledge1. Actual logical sessions retain that knowledge, and
new-target authentication produces the sticky mismatch halt on each node.
This is modeled service followed by containment, not generation1 installation
or fresh-generation admission/liveness.

Author26 exact outcomes comprise10 affected original configurations, nine new,
two actual revoke-all faults and five restored controls. The two fault mirrors
execute the real first finalized observation21, changing the other node's trust
TRUE→FALSE while the correct observing-node effects still occur. Only the
dedicated immediate raw noninterference audit fails. Both actual-restored full
41-receipt histories equal their original histories, with all16 original fields
and all12 node-owned fields retained. The original19 baseline and later
mutant/restored copy paths are separately attributed; the root shared campaign
supplies a true same-copy baseline/mutant/restored triple for the one new assessed
obligation. Catalog regressions20 also pass using the existing CI signal entry.
Inventory is77 (71TLC/sixForge); this step freshly executes one shared obligation,
with earlier76 not rerun here and four unassessed entries retained. The nine new
defaults imply441 discovered, not a freshly executed whole441 gate.

Skipping the first finalized observation really enables subsequent old Sign,
Serve and GrantTrust. Later new-target authentication then refuses while the node
is trusted, and a nominally halted-session attempt instead executes. The actual
41-receipt partial witnesses check those changed branches and the complete raw
endpoint. The mode-qualified absence PASS alone is structural/vacuous and gets
no containment or progress credit.

Independent behavioral verification uses a different actual source fault:
removing only ObserveGeneration's finalized-provider guard. In both mirrors,
attempt19 then really learns generation1 and revokes trust at included2/finalized1;
the focused raw finality observer fails immediately after that write. Actual
same-copy original/restored complete mirrored witnesses pass. A private missing-
GrantTrust14 control remains in normal mode and reaches exactly the same all16
original terminal fields, while B's initial and lagging Sign/Serve never execute.
Full intermediate raw histories distinguish that loss from complete availability.

Independent execution9 plus author26 plus shared3 give38 exact TLC executions,
separately attributed. The independent parser audits17 actual raw traces,
610states/593receipts, every16original field at each state and all12node fields
at every history prefix. Whole628formal and generated-private/source/tool/copy
hash guards hold. No setup/type/parse/timeout or wrong-error result is credited.

Independent source/spec/quality and literal/dispatch review checked the complete
implementation before any execution; a separate scoped review checked the one
catalog row and cohort link. All previously published model/config/code inputs
remain unchanged, and current source/copy/tool guards and real restoration pass.
No natural protocol/source defect or additional production implementation is
claimed. Current canonical/scoped SPEC correspondence and D01 WAITING remain.

Reflection: earlier two-node bounds never reached the recovery snapshot, and
earlier supersession bounds had only one node. Conservative signing safety alone
could therefore miss excessive revocation and lost valid service. This selected
cross-product checks actual intermediate availability as well as local refusal.
It still assumes authenticated fixed L1/evidence tokens and constant session0;
physical importer/signer restart, HRS/supervisor behavior, cryptography, changing
sync targets and full T01/C01/K01 remain OPEN/WAITING. J01–J02 are the first two
selected increments; J03–J05 and accumulated final gates remain unfinished.

After J02 publication, the existing CI check flagged the fixed receipt label
`EvidenceB1Exact` beside `AuthenticateB1` as a generic API key at commit1d399f051,
line14. Source readback confirms these are literal schedule names, not credentials.
The existing root ignore file receives only that exact historical commit/file/
rule/line fingerprint; earlier entries and detection rules remain unchanged.
The failed run44108940026 remains failed. No model/configuration or production
source is changed, and no local scan/new security capability is invoked. The
ordinary configured CI result on the repair head is read back separately.

## Interleaving-boundaries batch — J03 pending-funded admission and retirement

All six21-attempt schedules execute the actual unchanged Registry actions.
Both occupied slots have effective1/pending2 when amount2 registration really
executes and rejects against total3; amount4 then accepts at tied lowest slot0.
Displaced bond0 retains principal and identity, activation refuses after exit,
and every Activate1/Recover0/Forfeit0 permutation executes before historical
Slash0generation0. Full raw histories require the effective-first2 then pending1
sinks, generation1, closed immutable snapshots, confirmation5 and an actual
public zero withdrawal6 that preserves replacement bond2's slot0. Snapshot4
selects only1/power3, while snapshot5 selects1/2 with powers3/4. Cash is actual
deposited10/sunk3/paid0/vault7, supplemented by every normal operational r prefix;
ENABLED registration is never equated with acceptance or a sticky journal flag.

The first execution exposed a new-wrapper evaluation-order defect: primed raw
receipts read setup before TLC bound its unchanged next value. The original
Registry/protocol source was unchanged. Initial12 new author cases failed with
that setup error; two old logs completed separately and a broader two-slot case
was interrupted without a complete batch results file. Root's first shared
three phases were INCONCLUSIVE75, catalog tests were not run, and independent
actual execution was zero. All failures and old snapshots remain retained and
receive no successful-witness/fault-kill credit.

Fix1 moves only the existing unchanged setup/program frame before the primed
receipt, preserving the mathematical transition relation, dispatch, expected
literals, all twelve configs and original Registry. Independent static readback
preceded renewed execution; independent final scoped review marks the finding
ADDRESSED after actual current-byte commands/results and restoration. The
pinned release1.7.4 JAR has runtime TLC banner2.19; its exact required SHA remains
unchanged. No alternative tool or production/SPEC change was introduced.

Fresh corrected author30 outcomes comprise twelve new/two focused old profiles,
a true same-copy prebaseline, one real occupied-slot-balance fault and restored
normal/six full witnesses/admission audit. That fault actually accepts amount2
at attempt9, transfers2, consumes key/id2 and displaces old0, then fails precisely
RegistryRawAdmissionAudit before attempt10. All six restored full receipt
histories equal their originals. The broader original two-slot profile is not
claimed freshly rerun here; accumulated default coverage remains a final gate.

Independent actual25 cases use a different real Forfeit pending-first write.
Each of six orders really leaves effective1/pending0/ready0 after penalty2,
instead of effective0/pending1/ready4; the immediate raw split observer detects
it at that order's actual Forfeit position. Source inspection shows later Slash could converge to identical operational r
and total cash; mutant runs stop at the first bad Forfeit, so no observed full
mutant endpoint is claimed. Final-state equality alone would hide that error.
All six original/restored full positives pass. Six normal-mode missing-Forfeit
endpoint histories plus combined absence show that Slash can instead take3 and
leave the same10/3/7 totals without the actual2+1 sink sequence or lifetime
forfeit flag. Original/restored/fault/private-input/copy/tool guards hold.

The new shared obligation separately executes true same-copy baseline/mutant/
restored phases and20 catalog regressions with the existing CI signal entry.
Current successful totals are58 exact TLC invocations (author30/independent25/
shared3), plus catalog20. Independent parsing audits46 actual raw traces,
940states/894receipts, every original r/audit/event/setup value and actual
execution mask. Whole642formal and generated-private/source/tool guards hold.
Inventory becomes78 (72TLC/sixForge); this step newly executes one shared
obligation while earlier77 are not rerun here and four unassessed remain.
The twelve new defaults imply453 discovered, not a fresh whole453 result.

Missing replacement permits previously disabled Activate0 to execute; forfeiture
then takes effective stake, and zero withdrawal clears old0's still-owned slot.
Its vault3/no-bond2/only-member1 endpoint is an actual partial history. Missing
withdrawal retains owner1/confirmed5/unwithdrawn despite zero principal and
maturity. Author retains one printed partial history per combined-six witness,
not six raw paths from each such run. Mode-qualified absence alone is structural/
vacuous and gets no progress credit; positive partial/raw evidence is separate.

Reflection: spare identity/key capacity and pending-funded minima remove masked
admission premises, while actual intermediate principal splits, historical cash
movements and slot lifetime prevent equal totals or cached committees from
supplying an absent history. The wrapper failure also shows why static logical
review needs actual first-transition execution; later lanes start with a planned
finite smoke case before parallel fault products. These six normalized schedules
still assume valid evidence/authorization/token behavior and do not establish
concrete4096-slot indexing/storage/gas/callbacks or unrestricted lifecycle
refinement. Full R01 remains OPEN; D01 WAITING and all canonical/source pins
remain unchanged. J01–J03 selected increments are complete; J04/J05 and accumulated
final gates remain unfinished, with no sixth authorized.

## Interleaving-boundaries batch — J04 Nil replay and delayed delivery

Eight finite histories cross Computed/Written crash cuts, two initial signature
salts and Early/Late delivery. Every original21-field state is recorded around
actual inherited calls. Written retries retain the saved Nil bytes despite the
opposite caller salt; Computed retries have no saved write and lawfully compute
the opposite salt. Written's extra Persist refuses; Computed's retry Persist executes.
The Idle conflicting-payload request refuses in both. Two slots and a fresh domain exercise actual writes/exposures; recovery
persists floor1, a second crash loses volatile knowledge and Restart restores it.
Old Nil may legally arrive after fresh domain1 exposure: Deliver uses the actual
saved record, without adding a new returned/network signature. Consumer admission
and cryptographic signature validity are outside this symbolic interface.

The first planned singleton smoke failed before exploration: TLC cfg grammar
rejects direct tuple-set constant literals. This retained rc255 setup failure has
zero states/witness/kill credit; independent/shared/catalog execution was zero.
Two separately retained tiny syntax diagnostics are not protocol cases. Fix1 adds
eight pure literal singleton operators and substitutes only the22 constant
bindings. Original signer, dispatch, observations, literal expectations and shared
metadata stay unchanged. Independent mapping/source review preceded a corrected
single full26-attempt smoke; its raw trace was read before parallel campaigns.
Final scoped actual-evidence review marks the representation defect ADDRESSED.

Corrected author55 exact TLC executions comprise22 unique new and four focused
old configurations, plus explicit same-copy prebaseline, actual mutation, positive
controls and restoration. Four Written histories detect the unique actual Request
fault at RetryNil receipt10: pending uses the wrong caller salt while saved
durable bytes remain unchanged, before Expose. Four Computed mutant histories
remain identical to baseline and are positive controls, not kills. Eight initial,
same-copy prebaseline and same-copy restored complete receipt histories agree.
Eight actual missing-DeliverOld partial histories preserve floors, durable,
writes, returned and network while losing old delivery; fresh A is delivered.
Mode-qualified absence alone is structural/vacuous and receives no progress credit.

Independent29 exact executions challenge a different actual Restart write that
restores knownFloor0 instead of persistent1 at the second restart. Every profile
fails the immediate dedicated raw audit at its actual second-restart position.
Original/restored full histories succeed. Four Written omission endpoints skip
the first Persist: they lawfully become before-write crashes, compute the opposite
salt on retry and actually execute the now-enabled retry Persist. They are not
corrupted cached replays. An aggregate absence check is separately attributed.
The new shared obligation executes its own same-copy three phases; catalog20
regressions pass with the existing CI signal entry.

Independent cross-lane parsing derives87 current exact TLC executions (author55,
independent29, shared3), catalog20 separately, and69 raw traces/1699 states/
1630 receipts. All original21 fields, typed records/sets, actual captured Deliver
arguments and execution masks are checked. All666 formal inputs, private copy
and tool guards hold. Inventory79 comprises73 TLC/six Forge; only the one new
shared obligation is freshly replayed here. Four unassessed entries persist.
The22 new defaults imply475 discovered, not a fresh complete475-suite result.
The pinned JAR release1.7.4 and actual runtime banner2.19 remain distinguished.

Reflection: durable replay identity, volatile floor recovery and legal network
redelivery need separate oracles; final floor/record equality hides lost delivery
or a lawful before-write history. Static logical review cannot establish cfg
parser compatibility, so one planned finite smoke precedes parallel products.
No independently supported natural signer/protocol defect was found. Broader C01
remains OPEN: no FilePV/HSM/WAL/power-loss/concurrent-key-owner/authentication/
actual-signature refinement is established. Canonical/current source pins stay
unchanged and D01 WAITING. J01–J04 selected increments are complete; J05 and
accumulated final gates remain unfinished, with no sixth authorized.

## Interleaving-boundaries batch — J05 proof arrivals and overlapping landings

Twelve finite programs cross six H/A/B resource-arrival permutations with
Early/Late long-A completion. Actual inherited calls retain all original r/seen/
stage/count before and after; complete typed raw parsing checks17 operational r
and9 seen fields plus stage/count. Literal short completion masks distinguish
partial resources, while enabled repeated completions execute idempotently.
Both immutable jobs keep parent0/reference0/dependency0. Short Land at now1
accepts cached proofs while B is unavailable; a new long-B completion refuses.
After B returns, matching long results still cannot land one-payload suffix
publication. Full original two-payload publication then lands at the same now1
with actual parent1, retaining record1 and applying height2 exactly once.
Finalize1 at now2 selects block-end checkpoint2, publishes reference1 anchor2,
and actual third production uses that selected anchor.

The first planned singleton smoke failed lexical parsing before exploration:
24 adjacent equality/tuple tokens require separating whitespace. Retained rc150
has no states or witness/kill credit; independent/shared/catalog execution then
zero. Fix1 changes only24 whitespace separators and two local LET indentation
lines. The latter was an unconfirmed static layout suspicion, not another
observed bug. An exact inverse reconstructs the failed original bytes; other21
integrated files and all old source/config inputs stay unchanged. Independent
static mapping gates preceded one corrected full31-receipt smoke. Actual35
generated/32 distinct/0 queued are separate counters; no equality is assumed.
All18 new configurations later execute, and final scoped review marks the
lexical defect ADDRESSED with no new fix breakage.

Author51 exact TLC outcomes comprise18 unique new/six focused old configurations
and explicit same-copy prebaseline, actual source mutation and restoration.
All twelve original/prebaseline/restored full receipt histories agree. The
unique actual Land r-prime fault preserves genesis on first landing but deletes
record1 on the second. Its selected actual HAB/Late25-receipt prefix fails only
OverlapRetainedPrefixAudit: record1 is erased while record2 has parent1 and
seen.expectedRecords is unchanged. Actual338 generated/302 distinct/11 queued
are retained as an early invariant stop, not exhaustion. Same private source
bytes are restored before all twelve full witnesses plus normal/audit succeed.

Independent51 exact TLC outcomes challenge actual Finalize's block-end selector.
All twelve mutants select intermediate checkpoint1 instead of2 at the real
Finalize call (Early29/Late27), failing the immediate IndependentBlockEndAudit;
all twelve original/restored positives pass. Twelve normal-mode missing-short-
Land endpoints execute the now-legal suffix Land0→2 and later refuse settled
FullLand. Head3/included2/finalized2 and applied1/1 then hide one absent landing,
missing record1 and parent0 record2. Two missing-full-publication probes first
retain the scheduled unavailable anchor2 refusal, then actually Produce with
existing anchor1: head/count3 while included/finalized1. Missing full publication
therefore does not universally stop production. Author's two emitted omission
traces are HAB/Early singletons; aggregate12 audits do not emit twelve traces.
Mode-qualified absence PASS alone remains structural and gets no progress credit.

The new shared obligation separately executes actual same-copy three phases and
catalog20 regressions. Independent cross-lane audit derives105 current matching
TLC outcomes (author51/independent51/shared3),90 raw histories/2760 states/
2670 receipts, all original fields and actual execution masks. Whole686
formal/private/source/tool guards hold. Initial failed parser call and two
separately retained data-only auditor failures (generated==distinct assumption,
old-log routing) receive no successful credit; fixing those temporary readers
reran no engine. Pinned JAR release1.7.4/runtime banner2.19 remain distinguished.
Inventory80 comprises74 TLC/six Forge with four unassessed; only one new shared
obligation is freshly run here. Earlier79 are not rerun in this step. Discovered
default493 is not yet a fresh accumulated complete493 result.

Reflection: immutable original publication, actual settlement parent, retained
interior record, block-end finality and candidate-specific production require
separate intermediate observations. Equal head or settled counters cannot
supply missing accepted-call histories. The finite product adds meaningful
arrival/order variation but no fairness, latency, throughput, real proving,
concrete STF/client/EL/upgrade or unrestricted asynchronous equivalence result.
Proof and producer anchor ages still share RefWindow. No independently supported
natural protocol/source defect was found; broader P01/P02 remain OPEN and D01
WAITING. All five selected increments are complete; accumulated final gates and
retrospective remain unfinished. No sixth is authorized.

## Interleaving-boundaries batch — final gate and retrospective

All five selected increments and final independent source/behavior gates are
complete at implementation34c797bb53a5b7faedd4ddd46585900af0cc5801. This closing
change updates four prose files only. All35 original recursive models,423 old
default configurations and529 old code inputs remain byte-identical. The current
493 defaults comprise the original423 plus70 additive configs; source discovery
includes40 recursive TLA and514 recursive configs. Broader30 obligations and11
composition families retain their existing acceptance boundaries.

Fresh accumulated verification uses the unchanged checker/gate in the existing
offline container, with a read-only792-input snapshot containing686 formal files
and106 complete protocol documents, including Derivation.md. The locally
assembled runtime uses repository ci_container.py's documented Python runtime;
outer drivers and the separate controller use the managed Python. Exact pinned
Java17/JAR and canonical signal-reset entry remain unchanged. No download,
replacement engine, host-network fallback, real signing or live operation is
part of this verification. Wall time is a validation resource measurement.

Actual results:493 exact default outcomes, split133 PASS (including absence
controls) and360 named controls/witnesses;243 ordinary Python tests with zero
skips/failures;5 separately counted controller tests; all640 rule markers resolve.
The5 newly added shared TLC source faults independently rerun true same-copy
baseline/mutant/restored phases,15 actual executions, with the precise immediate
named audit and exact restoration. Inventory80 is74 TLC/six Forge; prior75
shared obligations, native transitions and Forge execution remain historical,
and four unassessed entries remain. No fresh native/Forge result is claimed.

Independent whole-batch source review inspected the complete base2f863ad77 to
implementation34c797bb5 diff, all70 new config mappings, actual inherited action
calls, literal observations, five unique actual-source mutation selectors,
old79-row catalog preservation and all529 original inputs. Independent final
artifact review checks actual command/isolation/cleanup, complete discovered
coverage, exact config/module/source/tool binding, raw outcomes and test counts,
including the fresh mutated raw effects and mandatory controller lane. It
retains the separate meaning of safety PASS, named reachability, fault detection,
omission witness loss and restoration. Source and artifact verdicts are READY.

The exact implementation-head configured CI is SUCCESS/SKIPPED at17:25:29Z;
this is status readback, distinct from the independent local raw-artifact audit.
Its two Check links jobs initially failed only GitHub503/504 on links already
present before this batch. Full failed logs were retained; one failed-only retry
per existing link workflow passed at the same head. No URL exclusion/checker
weakening or source change followed. Earlier failed parser/setup calls and
pure data-reader errors remain failed/zero-credit with their original inputs;
none is silently counted as a protocol fault or additional successful coverage.
The final artifact reader also retains its overly strict end-of-log and single-
line unittest assumptions; the canonical count trailer and exact existing split
output are explicitly validated without repeating any engine execution. The pinned artifact release1.7.4/runtime TLC banner2.19 remain distinguished.

Reflection: the useful result is discriminating intermediate histories. A
second recovery exposes generation/nonce saturation hidden at max1. Local node
service separates over-revocation from safe halting. Registry admission and
intermediate effective/pending splits expose errors hidden by final cash. Nil
saved-byte identity differs from lawful unsaved computation and network delivery.
Overlapping proof settlement needs full original publication, a real current
parent, retained interior records and block-end finality; a missing first Land
can keep headline counters unchanged. Missing full publication can leave an
existing anchor that still permits production. Expected masks observe actual
calls and never suppress a newly legal action.

Checks also exposed their own weaknesses: a proof-origin oracle needed the
prepared proof's actual generation; a new wrapper needed primed frame binding
before observation; cfg tuple bindings and tuple-equality spacing needed valid
parser representations; temporary readers over-assumed graph-count equality
and misrouted old logs. The first planned finite smoke now precedes parallel
products. Exact named-fault controls, actual same-copy restoration, independent
literal fixtures and complete raw histories reduce these blind spots. No
independently supported natural protocol/source defect was found. This supplies
neither an absence-of-defects argument nor an exhaustive oracle-completeness claim.

Six recorded scope decisions and their costs:

1. Continue the established next-five method from direct authorization: selected
   topics may need bounded rework; no extra production or external authority.
2. Improve model/check effectiveness before concrete comparison: client/EL/guest/
   upgrade mismatches remain uncovered by these histories.
3. Use fixed histories and finite6/8/12 products: omitted asynchronous
   interleavings remain possible; no unrestricted equivalence or fairness claim.
4. Keep prior75 shared/native/Forge execution historical: no new concrete-code
   assurance for those unchanged lanes is supplied by this group.
5. Run immutable author/tester copies concurrently after coherent freeze:
   contention may delay or inconclusively time out a run; failure stays retained,
   and execution wall time does not become protocol performance evidence.
6. Exclude one confirmed historical literal-label false positive by exact existing
   commit/file/rule/line fingerprint: that one historical finding is excluded;
   future commits, paths, lines and rules remain checked. Detector rules and
   shared history are unchanged.

Canonical SPEC and reviewed current753d/af8c32cc bytes remain fixed, with scoped
correspondence only; the live main SPEC blob was rechecked unchanged at17:25Z.
Normative START10-5 provider/deployment behavior remains D01 WAITING. Unlimited
interleavings/fairness/latency, concrete client/EL/guest/ABCI/importer/signer
refinement, cryptography/physical durability/concurrent key owners, Registry
production-scale storage/gas/token/DAO behavior and exhaustive fault coverage
remain explicitly outside this completed finite batch. Broader S01/T01/C01/R01/
P01/P02/Q01/Q02 and D01 retain OPEN/WAITING status. No unavailable interface was
invented to close them. Draft/worktree/ledger/raw artifacts are preserved for
review; hourly monitoring returns to feedback-only after final readbacks.
No sixth increment, merge/ready, production/SPEC/Notion or live action is authorized.

## N01 public signed-consumer gate

The authorized next-five public-consumer batch is in progress. N01 is complete
for its selected stock signed-vote API boundary at implementation
`feaecb47dfa4e039e0426e37fbb8941c94e8d6ed` plus reviewed repair
`d7bfe629ceda37ce580afceeff38ef59c0a42b91`. N02–N05 remain pending. See the
[five-task plan](../../docs/superpowers/plans/2026-11-18-etna-public-consumer-conformance.md)
and [scope, inputs and invocation](conformance/COMET_SIGNED.md).

Actual pinned stock CometBFT verifies all 23 unchanged public signatures and
matches all 23 published canonical byte strings. Structural validation accepts 21
and refuses exactly the two incomplete BlockIDs. The 45 native cases include
strict 2/3 refusal, 3/4 acceptance, below-threshold and nonzero-index controls,
valid nil verification with zero nonnil-commit power, duplicate/conflict policy,
domain/address/index/step refusals and genuine round 1/2 POL. One public signer
with synthetic weighted/absent profiles tests these APIs; it is not an Etna
launch committee, full consensus execution or a latency benchmark.

The author's same-copy source fault changes the final single-verifier quorum
comparison. Fresh normal and restored phases each pass 45; exactly the intended
threshold leaf fails under mutation. A separately chosen independent source
fault incorrectly counts valid nil signatures toward the nonnil target: again
45/44+one intended failure/45, with all other literal receipts unchanged.
Both faults retain raw execution, full 1659-file guards, positive controls and
restoration. These controls are separate from the historical shared 80 inventory.

Independent review found two verification defects after native behavior passed:
missing required Go event classifications and oversized receipt fragments could
qualify as exact evidence, and two recoverable I/O paths could skip restoration
of the disposable private fault copy. The repair enforces actual event-kind
presence and the pinned 1024-byte framing, validates elapsed metadata, and
protects mutation before its first write while restoring original bytes and
mode even after partial writes or failed readback. Real-file I/O probes and
eight changes to actual raw streams independently validate these corrections.
The first real run also exposed legitimate 1024+286-byte POL log fragmentation;
the failed adapter run remains retained rather than counted as a full campaign.

The corrected head passed nonauthor source review and independent behavioral
verification, including the actual distinct nil fault. The managed-Python
ordinary cohorts passed 67+166+20=253 tests, zero skips/errors/failures. No model
or baseline executable input changed; the 493 default model outcomes and shared 80
mutation results remain previous evidence until separately refreshed.

| Retained artifact identity                           | SHA256                                                             |
| ---------------------------------------------------- | ------------------------------------------------------------------ |
| Public projection                                    | `34932f8ddf991ae41eb1be94c873e99524f51cf96d427faed4a1bfc443dc960e` |
| Corrected author campaign summary                    | `97349715780130ca0cc361bf73a1847cd45c6a904a5daffbddb04b112eb5cb06` |
| Independent nil campaign summary                     | `2bcc30fae51febde58b62654e2b4ec2371c504660e0335c6b4d38c980ed4ae05` |
| Independent correction audit                         | `454f4eca284968fffb180a1a1ef492bdc249adee084fa25e72c6e3e99a4a9c92` |
| Source review and scoped recheck                     | `224fed5380b5208ccf267b243d39911fa96bc81ed781b7368d38e0ff02dc6f5c` |
| Independent behavioral report and correction recheck | `808950dbac7c7dcbb2907ded301ac3351411a896b67fd14ce8a28d489c303614` |

Common published-fixture provenance and the configured offline dependency cache
remain premises. Selected Go executables/VERSION and actual Comet/input bytes
are pinned; this is not a full SDK/cache content audit. Authenticated committees,
proposals, locks, finalization, P2P and missing actual client/EL/guest consumers
remain K02/E01 and their related OPEN/WAITING obligations. No natural protocol
defect was established by this selected gate.

## N02 actual signed evidence and input binding

N02's selected actual-contract gate is complete at implementation
`3d453ec859dcf6e4f148dd465308d6f15087abe6` plus reviewed input-binding repair
`ca8e4315fe010ef5ce966a0cd8020681cf6d3134`. This completes two of the five
authorized increments. N03–N05 and the accumulated final gate remain pending.
The [shared fixture and invocation](conformance/REGISTRY_CASES.md) use the same
published public inputs as N01 and the original pinned 564-file contract source.

All 42 actual Forge leaves pass original and restored execution: five domains,
23 canonical encodings and 14 fresh double-sign pairs. Each full phase adds
23 comparisons against the accepted actual Go outputs. The pair outcomes are
six slashes, six NotDoubleSign refusals, one FutureGeneration and one
InvalidSignature. Valid slashes debit all eight units, including four pending,
pay reporter two and sink six, and preserve the expected lifetime identity,
roots and checkpoint history. Exact evidence replay refuses NothingToSlash,
with no second payout. Both attempts of each refusal retain the selected raw
state, cash and history. Mock Inbox state and exact-transfer token behavior are
explicit fixture premises.

The actual same-BlockID guard omission causes exactly the intended wrong
slashing failure, with the attempted checkpoint/two transfers/slash event;
41 other leaves pass. A separately chosen production arithmetic change makes
the six lawful slashes pay one/seven instead of two/six. Independent execution
observes those six exact failures and 36 unchanged controls, then all 42 pass
after restoring the same private source copy. Original source bytes and modes
remain unchanged. These controls are separate from the historical shared 80.

Independent review found that correct result words could alias different pair
inputs: ordinary/backdated and round/height-mismatch evidence produced identical
old receipts. The repair binds each case name and both actual delegate-frame
calls to independently encoded, named public vote tuples. Each call contains
996 canonical ABI bytes, including both signatures, timestamp bits, generation,
order and bond ID. Native token-emitter checks now use an independently derived
CREATE identity. The independent verifier reconstructs all 14 named pairs
(13 distinct calldata values; historical/current contexts legitimately share
one pair), five domains, selectors, PoP digest and both entry roots.

A separate real fixture experiment keeps the backdated name but submits ordinary
A/B. Forge still passes the numerical checks; the corrected collector rejects
the actual wrong inputs and accepts the restored fixture. Seventeen independent
changes to actual raw rows/calldata/retries/emitter are rejected. Nonauthor
source review and behavioral rechecks pass. Ordinary Python cohorts pass
80+166+20=266, with zero skips/errors/failures. Setup, discovery and observer
failures remain retained with no acceptance credit.

| Retained artifact identity              | SHA256                                                             |
| --------------------------------------- | ------------------------------------------------------------------ |
| Corrected author campaign summary       | `b835d8a704a249947a7d11d3a41c1203161d60a63c020e8291b885774d5ecaf5` |
| Corrected source restoration            | `cf866e57ea4f6d21e8da1f7d2a3064981167978e24629378acf2f553814efd6b` |
| Independent ABI/input audit             | `2d8c05957d52f1e3f76cbc16973dcf26888649abcba61ca07290077f8161b82e` |
| Independent source review and recheck   | `a68059ddb8644abee22e0e7ce4feecf3603fc3cb2e213265f3d96335b247f050` |
| Independent behavior report and recheck | `85eb7289cb464a30590d5899b41ccf2198d66db7898b68591751c27efb575dc8` |

One bounded private Forge cache is reused within each three-phase run; the
existing physical lock serializes execution. The old written cache is preserved
outside the mounts, at the cost of a small cold compile per run. Restoration
covers handled exceptions and completed or cooperatively supervised phases.
Abrupt termination between phases can retain an unfinished private snapshot
without a PASS summary; canonical source stays untouched. Local execution logs
are not chain transaction receipts. Full capacity, real Inbox recovery,
production token/deployment and the other actual E01 consumers remain open.
No natural protocol defect was established. The unchanged model/default and
shared inventory evidence remain separately attributed; hosted N01 job
44213808947 at 6aa1cab2a completed successfully with exact-head/job-step readback,
without a deep audit of its hosted archives in this check.

## N01 feedback repair: bind actual native inputs

External review of `b9240431` found that the N01 wrong-generation and wrong-Inbox
refusals had identical outcome-only receipts. H/R/type refusals also omitted
the attempted fields, and replay observed the second BlockID without identifying
its submitted signature. The earlier actual-source faults established sensitivity
to changed consumer logic but did not establish sensitivity to changed inputs
with equal outcomes. The input-binding lesson from N02 had not been propagated
back to N01 before publication. This is a verification defect, with no production
or normative protocol change.

Repair `894279273e3e69a82e2bc17734de0edff3c4afc9` binds the actual API inputs:
verification chain, submitted height/round/type/index/address, SHA256 of canonical
sign bytes and exact signature. Original and matching VoteSets, both replay
operands, the occupied commit signature slot and verifier target, and the POL
submissions retain distinct observations. The 23 wire cases retain full public
bytes and gain actual metadata. All 45 original outcomes remain unchanged.
Expected fields were frozen independently from named public vectors and a
separate protobuf encoder before execution; both independent gates reproduced
all 23 public byte strings and every new field across the other 22 leaves.

Fresh original/threshold-fault/restored execution produces 45 passes, exactly
44 passes plus the intended threshold failure, then 45 passes. The author's
private harness changes the generation case to exercise the Inbox domain: all
45 native leaves pass, while the collector rejects the exact mislabeled case.
A separate independent harness changes the height refusal's submitted value
from 1001 to 1002. All 45 native leaves still pass, but the collector rejects
`vote-height`; the other 44 receipts remain identical. Ten independent actual-log
substitutions, including second signature/digest replacements on the same-block
replay, are refused. The 11 focused and 59 legacy Python regressions pass.
Source review and independent behavior verification pass with no open findings.
The original 1,659-file source, private restoration and physical lock are verified.

| Retained artifact               | SHA256                                                             |
| ------------------------------- | ------------------------------------------------------------------ |
| Corrected full campaign summary | `469aba5feda8a778e4ed70573df6d2ddc77e6a1f5ff6627aa6eca3032112a5f4` |
| Independent height-alias raw    | `d900c7efdc6fc115d267e55532aff951f04a810723c5e02ca379d509e1c9fc4c` |
| Independent identity/raw audit  | `ea35fb7fe35dcf840fe62da978decd8cf1ceba565b09b6da4157a1153c5763dc` |
| Independent source review       | `3728b2f19e092a57aa482265110c96c077df9bde145344243ea7a6c086ec63c0` |
| Independent behavior report     | `7accd06470fd47f4373ac443040cb04e6af8a3c46feb268b384904d943a96a8e` |

This repairs the selected N01 evidence. It adds no sixth increment and leaves
N03–N05 plus final accumulated gates unfinished. Prior native logs are retained
under their original, narrower attribution. Existing synthetic-validator and
offline-cache premises and full consensus/client/EL/proving limits remain.
Hosted run 44224189515 passed every job/step at the earlier `b9240431` head;
that status is not evidence for this later repair until its own CI is read back.

## N03 actual exit, withdrawal and slot reuse

Implementation `00c5a1f30a9e1e96ac75dbeb8d2a03245199211f` completes the selected
actual Registry two-cycle lifecycle gate. Three of the five authorized increments
are complete; N04/N05 and final accumulated gates remain. This is the same pinned
564-file contract source, public registration projection, initialized/unlocked
Inbox fixture and exact-transfer token used by N02.

The 16-step journal binds each actual caller, EVM block number, active snapshot,
checked delegated calldata, result and selected state/history/ledger commitment.
Two h10 deposits are followed by h12 pending principal, h13 exit and h14 mature
activation refusal. Snapshot 14 refuses confirmation; exact snapshot 15 confirms
at h16. Identical withdrawal bytes refuse at 17 and pay 8 at 18. The retired key's
valid alternate-owner PoP reaches KeyAlreadyUsed. At 20, new bond 2 reuses slot 0
while bond 1 stays in slot 1 and entryCount stays 2. The second exit/confirmation/
withdrawal at 23/26/28 pays 4. Total deposits 16, payout 12, custody 4. Six historical
checkpoints retain their exact packed words and roots. The empty slot 0 is its
canonical hashed zero-field entry alongside live slot 1, with count 2; it is not a
padding leaf, empty Registry or zero root.

Original and restored native runs pass the same complete journal and 23 ordered
action logs. Removing the actual activateTopUp exit guard produces the intended
h14 semantic failure, with its independently predicted checkpoint/activation
trace and no final receipt. An independent actual cleanup change uses bondID
where slotID is required. Its first withdrawal is unchanged; its second still
pays 4 and emits the same 23 logs, but slot 0 retains occupancy 3. The native test
returns success and the external collector rejects the final withdraw_reused
state exactly. Independent calculation predicts the changed 75-word commitment;
all first 15 steps and other final fields are unchanged. Restoring the same copy
recovers the original journal and source bytes/mode.

The N01 feedback repair changed its metadata pin, leaving the published 05ab head
with a stale N02 dependency. The producer-only checks before that push missed
this integration failure. This commit precisely updates the consumer reference
to reviewed 56ea3af metadata; public 34932f bytes and consumer semantics stay fixed.
Corrected N01 normal evidence is accepted and old outcome-only evidence refuses.
Fresh affected N02 original/fault/restored passes 42, has exactly the intended
one failure, then passes 42; each phase matches all 23 Go wire rows. The 05ab head
itself is not credited as a passing N02 head.

Independent source and behavior review pass. Both independently reconstruct the
16 contexts, selected state and history, ABI/results and exact token ledger.
Raw context/state substitutions and trace/padding changes are rejected.
All 272 ordinary Python regressions pass 86/166/20 with zero skipped/errors/failures.
One nonblocking CLI-test output issue is retained for N04: capture expected
argparse stderr and assert its specific missing --go-normal reason.

| Retained artifact                 | SHA256                                                             |
| --------------------------------- | ------------------------------------------------------------------ |
| Author lifecycle campaign summary | `3e49bf8acdfd25d13fbeddf206473f5a50bccc2762aed9acd06bcc8ef57721ed` |
| Affected N02 campaign summary     | `1565829d1e2f79e408371f0b9815d302f6aab6def2f5039ef286add56b343fa8` |
| Independent wrong-ID native raw   | `281665d0d274f3de58c3b68b76fd6196c58b81504c44069f214eb64397590e92` |
| Independent source report         | `0717a33175393746d0bff52d7be2ed9a8f5e340fab5a5c84d4a5eaaa1e7f7142` |
| Independent behavioral report     | `9d35e977aa934d0ffeed236200f95f2715e7a252b803d315a3ad5c88c67a2fa0` |

These are selected real-consumer traces and source controls, separate from 493
model/default outcomes and the historical 80 shared mutation inventory. Full 4096
capacity, arbitrary lifecycle combinations, real Inbox/token/deployment and
client/EL/guest consumers remain open. Restoration has the documented handled/
cooperative boundary; abrupt between-phase termination may retain an unfinished
private copy with no PASS. No natural protocol defect was established.

## N04 actual late token failures and identical retries

Implementation `7c845ea39a45672b37c172cb2507b022d0c2c0a7` completes the selected
actual Registry atomicity/retry gate. Four authorized increments are complete;
N05 and final accumulated gates remain. The actual source, public inputs and
shared fixture are unchanged. The two new native leaves bind seven actual
Registry/external calls and their before/after commitments. The bounded raw
projection includes all 8192 admission cells, fixture bond/key/owner/pending/
confirmation/forfeiture state, entry and checkpoint storage, seven token actors,
transfer count, proxy pointer and inherited persistent slots. It does not claim
the entire unbounded storage domain or transient state.

At h11/snapshot 7, valid public registration reaches token allowance 3 against
amount 4. The exact nested transferFrom and bubbled Error("token allowance")
refuse, and full selected raw/cash/history state remains identical. Calibration
establishes that Forge retains emit-then-revert trace entries: the failed
registration includes an attempted checkpoint. Owner B externally approves 4;
identical actual Registry/token calldata at the same height/snapshot succeeds
once, issues contiguous bond 1 after bond 0 and pays 4 into custody. The retry's
ordered trace is CheckpointWritten/Transfer/Registered.

At h12/snapshot 9, topUp has allowance 4 and balance 0. It reaches the real token
balance error after one attempted allowance 4→0 write; all selected state,
including allowance and admission cells, rolls back. The driver mints 4 externally
and the identical call succeeds once. Pending 4/ready 14 and admission value 8
change while effective 4, prior checkpoint/root and the neighboring bond stay
fixed. Actual h14 activation consumes pending and records effective 8 while
preserving the old checkpoint. Final vault 12 and transfer count 3 match the
independent ledger. Token call/actor/calldata/revert/write observations and the
pinned SafeERC20/Address bubbling path establish this fixture's failure origin;
AccountAccess has no per-frame returndata, and the exact bytes come from the
outer proxy call. Logs here are execution traces, not committed chain receipts.

Original and restored two-leaf runs pass. Removing the actual topUp token
transfer causes exactly the intended unexpected-success diagnostic and deposit
trace; the registration control still passes. A distinct independent source
change overwrites admission parent 2048 with leaf 0 rather than the smaller
sibling. The genuine balance refusal still fully rolls back, and funded retry
still transfers normally, with the same allowance observations, logs, entries,
leaf values and native Success. Only the independently predicted full state
commitments expose the incorrect minimum. The stock collector rejects topup_retry;
activation retains the predicted bad parent, and restoring the same private
source recovers both complete positive journals. All 564 files and original
mode 0664 restore exactly.

Independent source and behavior gates pass without open findings. The carried
N03 CLI-test issue now captures stderr and checks the specific missing flag.
Fresh affected N03 retains 16 steps/23 logs and its exact source-control phases;
N02 retains 42 leaves/23 Go-byte comparisons in each phase. All 277 ordinary Python
checks pass 91/166/20 with zero skipped/errors/failures. No shared consumer pin
is stale. Published prior 87aafa47f hosted run 44231458235 completed successfully
with all 10 steps read back; current-head CI is separately tracked.

| Retained artifact             | SHA256                                                             |
| ----------------------------- | ------------------------------------------------------------------ |
| Author two-leaf full campaign | `5dd7d16f536f689482989f546c5a55768e969804503b1835e69fe4af863498cb` |
| Affected N03 campaign         | `c672c4e696de2de979c223196ce17c60a7a73c3ac2e037020ac49195c3bc645c` |
| Affected N02 campaign         | `10c5c6dfaa318344b0be265ea920c15305cf782c1b7ef6db0ed3a9e96fd5fccf` |
| Independent parent-error raw  | `9cb2dc3b7ce20ffa1b92df26975969eb9bbaff00be330ff58cba4d4140234301` |
| Independent source report     | `f4e869d936a195126bb810167d127b9585400885d4c41a4203420ea3d5a7c743` |
| Independent behavior report   | `ba2b78e544a3618ecf8047b905ffd42312e2c26711031511f8207328a5c9fb95` |

The original snapshot, public-only read mounts, existing physical cache lock,
offline tool/dependency pins and documented cooperative restoration boundary
remain. This is selected EVM-call retry evidence with an exact-transfer fixture;
it does not establish arbitrary token callbacks, real transaction deployment,
withdrawal custody, full-capacity admission, gas or proving behavior. R01 and
full cross-consumer E01 remain open. No natural protocol defect was established;
source controls are separately attributed from the historical 80 inventory.

## N05 exact archived-disposition acceptance

Implementation `c90220a1e4af4148674d9954b37f1dc9f82607c9` completes the
selected X01 disposition audit after two independent review/fix rounds. The
[semantic guide](ARCHIVED_DISPOSITION.md) and [manifest](archived_disposition.json)
bind all 19 archived configurations, 13 local model paths and their 32 byte
identities. The checker discovers the actual archive inventory, verifies family
layout and the guide's exact membership, and checks immutable historical notes,
source paths, current evidence links and outstanding obligation status. It also
runs on a Git-free source export. No archived config, model or observation file
changes, and none of these 19 incomplete searches is rerun or credited as PASS.

The audit distinguishes missing products from source-version hazards. FI Budget
already preserves the prune halt across recovery; Projected adds explicit halt
observations, canonical blank bytes and a narrower build projection. Current,
FI-archive and rollback-archive EtnaSettlement bases have the same byte digest;
the wrapper and observer differences are the relevant historical differences.
The signer progress note attests an unavailable predecessor digest, while the
available parameterized source has its own verified digest. Three configurations
without historical config-digest attestations have explicit retained-cohort pins;
these identify audited files and do not authenticate missing predecessor inputs.
The other 16 identities are corroborated by their exact immutable notes.

Independent checks exposed defects in the first disposition checker: coordinated
path/digest edits could redefine the intended cohort, note substring checks could
misattribute historical source roles or per-profile outcomes, and a compound
WAITING-COMPLETE token could masquerade as an open obligation. The first repair
bound the audited notes, missing config identities, exact layout and full status
tokens. The second removed a residual Registry filename/stem alias: a renamed
`.cfg.cfg` file with synchronized manifest and guide cannot reuse the original
note's filename. Family-specific historical labels preserve the real cohort.
Focused regressions demonstrate these refusals while the unmodified archive and
future mutable REPORT/WORKLIST/README publication remain accepted.

All 31 focused tests and the standalone checker pass. Independent source review
reads all 19 config/source associations; independent behavior checks challenge
missing, added, duplicated, stale, rebound and mislabeled inputs in source
exports. Root publication is separately checked after updating X01 and links.
C01, R01 and P01 remain OPEN; F01 and Q02 remain WAITING. X01 closes only the
disposition acceptance, not graph exhaustion, broad interleaving reductions,
actual STF/proving/rollback implementation, consensus or client correspondence.
No natural protocol defect is established by this audit. The retained notes,
32 config/model pins and provenance distinctions are enumerated in the guide
and manifest; immutable local review reports remain alongside the plan ledger.

## N01–N05 accumulated final gate and retrospective

All five selected increments and the independent accumulated source/raw gates
are complete. The final consolidated correction is `033f4b6eee19afecd2e0857733797069251849bc`; it was read back
at the existing OPEN/DRAFT PR before this closing record. No additional increment,
merge, readiness change or production/SPEC/Notion/live action is authorized.

The most-capable independent whole-batch review found two further P2 defects
in evidence acceptance. First, both Go smoke admission and the Solidity runner's
stock evidence consumer checked the original staged files but did not require
the two effective module files used by `-modfile`. Correct pre/post records
were present in all genuine runs; the readback boundary also admitted mutually
consistent missing or wrong effective inputs. The repair uses one authoritative
exact six-entry map, including the pinned module plus its exact replacement,
for receipt generation and both readback paths. Missing, added and changed map entries
fail independently of the raw Go verdicts.

Second, N02's native pair collector filtered the full log list to three topics.
That discarded setup events and could hide an extra Registry event, including
on the actual same-block source-fault path before the Solidity complete-log
assertion. The correction validates the entire nine-event native setup prefix
and exact zero/four-event action suffix. Only after validation does it retain
the established selected summary. Extra, missing and reordered formerly ignored
events are rejected in normal and fault records. Legitimate existing native
receipts retain their outcomes; N03/N04 already compare complete arrays.

Independent RED probes reproduced both gaps at the previous head and distinct
negative/positive readbacks verify the repair. The same source reviewer rechecked
the consolidated correction; the independent behavioral auditor rechecked the
actual retained original/fault/restored records and corrective regressions.
All important findings are addressed. One nonblocking P3 remains explicitly deferred: the new shared test helper
imports under documented unittest discovery, while the conventional dotted
`-m unittest formal.etna.tests.test_registry_cases` invocation fails at import.
The predecessor's dotted invocation passed; the documented Registry/Comet
discovery commands and local CI test suites pass. This is a test invocation convenience regression,
with no runtime or evidence effect. It is retained for follow-up after the sole
final correction wave, and no second wave starts automatically.

The bounded abrupt-between-phases private
snapshot cleanup limitation remains documented: no PASS or canonical-source
mutation follows from interruption, and an unfinished output cannot be reused.

Fresh root ordinary Python is **313** tests (127/166/20),
zero failures/errors/skips. The exact archive checker and focused publication
checks pass after X01 status and link updates. The separately retained hosted
run 44235324891 at N04 publication 48718f504 passed all 10 job steps. Its downloaded
artifact SHA-256 is `a996d04fbf74fa998b01cf676b08610c1e7256e07f1488898fa8ef30162e4c4f`.
The independent auditor read all 493 actual TLC logs: 133 completed positive
searches and 360 exact named invariant traces, with positive counters and
terminal completion. All 493 configs, 27 current models and pinned jar match
this batch's unchanged executable authority. These are re-audited hosted results,
not a new local 493 run or a fresh execution of the historical 80 source-control
inventory. Current publication CI is separately read back and never inferred
from an older successful head. Rules markers 640/live index 640/retired 28,
assets, links and tables pass; migration purity remains an optional separate
check, distinct from the zero Python skips.

All 682 baseline files outside the four shared Markdown records are byte-identical,
including 636 executable/data/module inputs and every archive config, model and
historical note. Public projections and source/tool pins remain unchanged.
The native evidence is separately attributed: N01's 45 leaves/23 genuine public
wire checks; N02's 42 leaves/23 Go-byte comparisons; N03's 16 actions/23 logs; and
N04's two leaves/seven actions with all 8192 admission cells. Original, actual
source-control and restored results remain individually identified in the prior
reports and raw audit. Changed receipt validation is freshly verified against
these real records; it does not claim another execution of their native programs.
All 19 archived searches remain INCONCLUSIVE. X01 is COMPLETE for disposition
only; C01/R01/P01 remain OPEN and F01/Q02 remain WAITING.

| Independent final record                             | SHA-256                                                            |
| ---------------------------------------------------- | ------------------------------------------------------------------ |
| Whole-batch source review before correction          | `fcdec841670d5253c08d643410e608ddcfa40a87ceba2c43c4618b5211a045bc` |
| Scoped consolidated correction review                | `e62b097b073a36d65c95c57d11a5e87efc8939c79cd4461ba0857697b3eec189` |
| Behavioral/raw artifact audit and correction recheck | `2291e114dfc47eff86540eb0b9f7f4b3e910dc0538471aaeb495b128c11a8048` |

Self-checks missed these defects because accepting genuine positive runs did not
exercise incorrect but internally consistent input records, and selected-event
projection erased evidence before comparison. Earlier N01/N02 input aliases and
N05 provenance rebinding had the same shared-assumption weakness. The missed
N01-to-N02 pin dependency also showed that a coherent local component is not a
complete integration check. Independent source inspection, altered real records,
whole-array comparisons and affected consumer checks now cover the specific
failures; they do not prove the remaining protocol or checker has no defects.
No independently confirmed natural protocol defect is established in this batch.

The overall estimate remains about 50 percent engineering progress, not measured
test coverage. The 30 unequal remaining-obligation rows now comprise 5 COMPLETE,
7 OPEN and 18 WAITING. Full client/EL/guest/provider correspondence, complete
consensus/committee operation, real proving/backpressure measurement, recovery,
deployment and broader interleavings remain substantial. Prior read-only
infra PR51 context only establishes merged multi-GPU test configuration changes;
it contains no measured proving latency result and closes no P02 acceptance.

The five-increment batch stops here. Preserve the existing draft, worktree and
raw ledger. Hourly checks continue in feedback-only mode; another group needs
direct user authorization.

## N04 feedback: pre-token Registry write observations

[Review 4609790258](https://github.com/taikoxyz/taiko-mono/pull/22387#discussion_r4609790258)
identified a coverage gap in the published N04 evidence. The failed token call,
reverted allowance write and equal Registry pre/post commitment could also
occur if the token call ran before the Registry writes. Source inspection
established the pinned implementation's ordering, but the original receipt did
not independently record those attempts. Implementation
`7e9d84af2b394325b0909bfe3d722d0e80eff6e5` repairs the existing N04 witness.
This is one scoped feedback repair; completed N01–N05 remains complete.

The version-2 atomicity receipt records every write to four selected slot keys
across the ordered action, with the actual enclosing frame, frame/storage
ordinals, storage account, previous/new value and revert flag. Raw before and
restored words are read outside the recorder. The collector requires the four
observations in the proxy's delegated execution before the unique nested token
call. The producer does not discard wrong-context, duplicate or late writes.
The complete selected rollback digest and original token/refusal/retry checks
remain. No production contract or normative SPEC is changed.

| Selected word         | Before | Attempted | Restored |
| --------------------- | -----: | --------: | -------: |
| Bond 0 pending        |      0 |         4 |        0 |
| Bond 0 ready          |      0 |        14 |        0 |
| Admission leaf 4096   |  16384 |     32768 |    16384 |
| Admission parent 2048 |  16384 |     16385 |    16384 |

The four slot/value predictions were derived before execution. Native
calibration observed DelegateCall frame 2, Resume frame 4 and token Call frame 5,
with selected storage ordinals 9/11/15/18. The frame code account is the
implementation; its inherited accessor is owner A and its storage account is
the Registry proxy. Frame/depth/ordinal constants are limited to this pinned
Forge 1.4.2/solc0.8.30 fixture; independent context and ordering relations are also
checked. Node 1024's existing empty-slot minimum does not change. These are four
selected writes, while the existing full selected observer covers all 8192
admission cells and the other bounded fixture state.

The ordinary author gate passes the actual two leaves through original,
omitted-transfer fault and restored phases at native return 0/1/0. Register
remains a successful control; the fault preserves its designated top-up
unexpected-success diagnostic before any missing-witness check. Original and
restored complete outcomes match and include all four reverted writes.

The independent verifier then ran old producer plus old collector at e7bd3d91b
and new producer plus new collector at 7e9d84af on identical private source edits
moving only the genuine transfer before those writes. Both revisions produced
two native Success leaves in each original/early/restored phase, return 0/0/0.
The old collector accepted the edited execution. The new raw witness retained
the genuine token refusal and rollback but contained zero selected writes; the
unchanged corrected collector refused it with the exact Registry-write-witness
diagnostic. The control's labeled collectorRejection is an expected negative,
not normal scenario acceptance. Both complete legacy journals and every event
matched byte-for-byte across all six phases after stripping only the new schema
and witness. The early-transfer variant is a coverage counterfactual; no natural
protocol defect is inferred from it.

Independent source review reports no findings. Independent ABI decoding verifies
four writes in normal/restored traces and zero in the early control. All 17
altered-witness checks refuse. Fresh managed-Python discovery passes 317 tests
(131/166/20), zero errors/failures/skips; the focused Registry suite passes 30.
Retained N02/N03 results are exactly preserved without relaunching their native
programs. Old N04 receipts remain historical and fail the new schema, which is
separate from actual early-transfer discrimination. The configured omission
control and the independent ordering control retain exact source restoration,
all 564 manifest entries, mode 0664, pinned tools/dependencies/public projections
and the original physical serial lock. No optional native branch ran.

| Retained record                     | SHA-256                                                            |
| ----------------------------------- | ------------------------------------------------------------------ |
| Author full campaign summary        | `85708686b296866a15a3022c32152888bccf91995e6f0e280d8198992d33f3d1` |
| Independent old early-control audit | `f88acb708dec8c13b4ebb376f9e8e0c4a4032b2cd133398fcef2cbf011a0cf85` |
| Independent new early-control audit | `2757d5b7432ffab00926d409b0189b68c0f8e8b8a5b8ab2b637f16371b4f626d` |
| Independent source review           | `c2b1cc683d142e3613296aa6eb3d129607fd37e4430a6b3285194d501493d3cb` |
| Independent behavior verification   | `88c251e6b1028308be91db912858d58950c20e038944f9e57311604e76a3734c` |

[The single repair plan](../../docs/superpowers/plans/2026-11-18-etna-topup-rollback-observations.md)
and [current runtime scope](conformance/REGISTRY_CASES.md#late-token-refusal-and-identical-calldata-retry)
retain the bounded token, proxy/Inbox and storage premises. The prior qualified
unittest-import convenience issue remains deferred. The previous 493 TLC input
set is unchanged and was not rerun locally for this repair. Publication CI is
tracked at its own exact head. Review 5951543725 externally confirms the earlier
N01 correction, without implying PR approval or resolution of the new thread.
The existing draft and raw evidence remain; monitoring returns to feedback-only
after publication, with no new batch.

## O01: public FilePV disk handoff and cached replay

Implementation `57c6c41633999a2698056476b0b215f7b26d5cd1` completes the
first selected increment in the
[durability/composition plan](../../docs/superpowers/plans/2026-11-18-etna-durability-compositions.md).
The [public FilePV lane](conformance/COMET_FILEPV.md) exercises pinned stock
CometBFT source through two separately supervised processes. The writer injects
an existing public signature at actual `saveSigned`. After writer exit the host
reads and checks the actual ordered stock JSON and mode `0600`. The later reader
opens those same bytes, uses the stock decoder and constructs fresh FilePV state
with a nil private key. It binds the actual attempted request before mutation,
response, complete selected HRS/bytes and actual disk-buffer identity.

The public seeds are nil precommit H1000/R0/step3 and A prevote H1000/R1/step2.
Their literal disk artifacts are 319/487 bytes, respectively, SHA-256
`4e9095589653586cf29a7c84c61c247561981e2f8ef5d74e1113342f67183215`
and `6b1560e11d90e0670101afc0351568cdacab9dbc478e7774ecd411b5dd8037aa`.
The 11 reader leaves cover three genuine cached replies, A/B conflict and wrong
chain, H/R/step regressions, two explicit incomplete-memory cases and advancing
CheckHRS eligibility. Only the designated CheckHRS call catches its documented
incomplete-state panic. No advancing SignVote or non-nil precommit extension
signing is attempted. The writer supplies public bytes rather than producing a
new signature, and the reader does not call the private-key loader.

| Exact committed-byte phase |       Writer leaves | Reader leaves |
| -------------------------- | ------------------: | ------------: |
| Smoke                      |              1 pass |        1 pass |
| Original                   |              2 pass |       11 pass |
| Omit actual Save call      | 2 intended failures |             0 |
| Restored                   |              2 pass |       11 pass |

The omission still updates every selected in-memory field, but both fresh paths
are absent and both named missing-state diagnostics occur. No reader starts on
that failed handoff. The full same-private-copy tree is restored to all 1,659
manifest entries, with actual file bytes and mode `0444`. Original/restored raw
results match their frozen public-derived oracles. Each invocation binds the
actual same-directory named source and adapter, all seven staged/effective Go
inputs, reviewed offline mounts/tools and the original physical build lock.
The formatted artifacts supersede the separately retained pre-format runs.

Independent behavioral verification ran eight scoped invocations against the
exact committed export. Suppressing only stock timestamp restoration yields an
actual 124→124 reply with the cached signature and failed public verification,
while exact replay remains valid. It reaches the exact cached-time diagnostic;
the unchanged ordinary receipt oracle also refuses its raw observation.
Restoring the same source restores genuine 124→123 replay. A separate adapter
control makes the actual request at 125 but still receives the same verified 123
reply: native leaves pass and the ordinary oracle refuses the changed attempt.
A hard link to the actual writer file preserves its bytes/mode but gives two
links; the production ownership guard refuses before reader invocation. After
unlinking it, normal replay passes on that same writer artifact. Negative-control
expectations are explicitly labeled and do not change the production collector.

Two preparation attempts remain separately failed with zero detection credit:
an outer sandbox mount refusal before Go, and an independent observer that
incorrectly compared access time after one stock writer. The observer was fixed
to compare content and stable descriptor/path identity, excluding read-updated
atime, before the final approved run. Those are setup/observer failures, not
natural protocol findings. The final independent run has zero timeouts/skips.

Fresh final-byte ordinary checks pass 322 tests (136/166/20), with no
errors/failures/skips. Both package-qualified and discovery Registry unittest
invocations pass 30; the previously deferred sibling-import issue is fixed by a
package-aware import without masking dependency errors. It is a prerequisite
repair, not an extra increment. Independent source review reports no findings;
the behavioral gate independently reads actual source/staging/raw/disk artifacts.

| Retained record                | SHA-256                                                            |
| ------------------------------ | ------------------------------------------------------------------ |
| Committed-byte smoke summary   | `b95caeb21ade6d62e447cdc08d7501bc151c4bf8dad6c97ed13877ad82c0729d` |
| Committed-byte full summary    | `f1f916018965baf708888224d78eb1e80a5b83bdf386d815b9c7fc27be28cf12` |
| Independent behavioral summary | `16da155bb3d379eb0b481ffbb341456b56c8f3f9a5c5e36df3fa52f11f420637` |
| Independent source review      | `a881444c41a1d5fe778393f7b19263e5ecdb9da978ace642e9eeed5b64fe1816` |
| Independent behavioral report  | `9141693aad13c05293dae226f98aafc2981e4fa9098741eb76bf0adb50db25a9` |

C01 remains OPEN. These are selected public-signature storage/replay boundaries,
not production key loading, new-sign-before-persist/expose ordering, consensus
WAL/supervisor/session behavior, abrupt-write crashes, power loss or failover.
The prior 493 default TLC configurations and operational models are unchanged
and were not rerun locally for O01; exact publication CI is recorded separately.
All 19 archived searches and other OPEN/WAITING obligations retain their status.
The existing five-increment batch continues with O02; no external-review wait,
new batch, production/SPEC/Notion edit or merge is implied.
