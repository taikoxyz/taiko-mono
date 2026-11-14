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
