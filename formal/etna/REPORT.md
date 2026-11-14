# Etna TLA+/TLC validation reports

The first section records the original height/generation model. The
[2026-11-14 extension](#2026-11-14-checkpoint-identity-extension) below records
the composed checkpoint-identity model.

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
