# Etna TLA+/TLC validation reports

The first section records the original height/generation model. The
[2026-11-14 extension](#2026-11-14-checkpoint-identity-extension) below records
the composed checkpoint-identity model.

The [latest three-increment gate and retrospective](#three-increment-batch-final-gate-and-retrospective)
records the current accumulated results and their limits.

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
