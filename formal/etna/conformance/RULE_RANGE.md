# Y03 ordinary multi-rule range, version2

`EtnaRuleRange.tla` is a separately versioned current-rule composition. It leaves
the earlier rules/settlement models, configurations, fixtures and native output
unchanged. Its fixed claim is `mixed-rule-landing`. Source selection alone is
NOT_EVALUATED; only a same-run pinned `current_receipt` can attribute a native
result. Actual client/EL/guest execution, proofs, FI singleton execution and
Unzen deployment vectors remain WAITING.

The model makes actual initialized owner schedule writes in the same generation
and ordinary four-block production, an unsupported-rule refusal and retry,
whole-range capture, two per-family results, complete publication and Land. It
uses free bounded calls rather than a scripted transition counter. Finalization,
schedule writes, production, upgrades, proving order and publication can interleave
within the declared bank; advancing past a required offer can leave a safe dead
end. This finite graph is the scope of a safety result, not a completeness claim
about ordinary protocol executions.

## Concrete history and clock

M=1296 and U=4; the integer-second successor is literal, never scaled. All selected
L1 blocks use timestamp=12*number. Hash/root labels are frozen authenticated
identities on one ancestor chain. L1 authentication, execution/committee/FI
validity of the complete retained prefix and proof inputs are explicit premises.
This model does not generate headers, storage proofs, EL blocks or signatures.

The generation0/S0 fixed origin and Inbox initialization/start are L1 block25,
time300. GenesisCutoff is the strictly earlier block24. The explicit initial
committee premise is a valid nonempty authenticated registry checkpoint24 whose
positive activation delays have already elapsed. Registry execution, selection
and proof authentication remain outside this composition; these concrete labels
leave room for a valid registry prehistory and do not substitute a contradiction
with an authentication assumption. Epoch length L=16 puts the first ordinary
switch at S(1)=15 and activation H(1)=17, beyond all retained/produced heights1..10.
Every checkpoint and job therefore reports committee0's actual snapshot24.
The public `resolve_blocks` interface enforces that fixed generation0/origin25/
time300 on every row, derives first only for height1, and binds the genesis
predecessor to time0/anchor25/empty LastBlockID. It applies the same contract to
standalone ranges. Caller-supplied first/carry/origin flags cannot jointly relax
it. This is an ordinary fixed-origin interface, not a general recovery resolver.
The [prefix-repair gate](../REPORT.md#y-prefix-final-review-repairs) independently
executed5 literal positives and76 negatives, including the correlated height8
forgery, per-row/singleton changes and exact bool/float aliases. The model's fixed
offer bank had hidden that API omission; its source is unchanged by this repair.
`ProtocolInitialCompatibility` and the observer independently require strict
cutoff/origin separation, first BFT300 and parentAnchor25, zero-rule history at25,
the no-rotation horizon and snapshot/dependency/statement-word20 consistency.

The initial settled checkpoint4 landed at L1 block191/time2292 with reference190.
Its retained complete prefix1..4 has anchor190/time2280 and checkpoint0. The
first block's BFT is origin time300, its parent anchor is origin25 and its
projected EL timestamp is2280. Checkpoint0's Comet hash is0 per the Etna-start
record. That component is used only in a height-only anchor/back-pressure view;
normalizing its earlier unused label does not change any cut at1..10, captured
range6..10, parent link, statement or settlement behavior. Block4
has EL2302, which can run ahead of the landing's L1 timestamp withinM; `land`
has no independent terminal-EL-time <= L1-time check. The finite prefix is
authenticated valid history, not evidence about deployed validator clocks.

The first actual write is at192/time2304: scheduleRules(1,3600), writing slot293
(0,1,3600,0). Prefix blocks5/6 have EL3597/3598, anchor192/time2304 and checkpoint4;
parent6's age is1294. Parent6 BFT3597 and parent5EL3597 make EL3598 follow the
literal successor. Their actual landing is block299/time3588/reference298/time3576.
It occurs after historical anchor288/time3456; that anchor therefore still proves
checkpoint4. Historical checkpoint or schedule data is never injected retroactively.

| New block | EL time | BFT time | Own anchor number/time | Anchor checkpoint | Rule | Witness |
| --- | --- | --- | --- | --- | --- | --- |
| 7 | 3599 | 3599 | 288/3456 | 4 | 0 | carry |
| 8 | 3600 | 3600 | 288/3456 | 4 | 1 | inherit |
| 9 | 3601 | 3600 | 300/3600 | 6 | 1 | carry |
| 10 | 5184 | 5184 | 432/5184 | 6 | 2 | carry |

Thus the first two gaps are3/4 and the last two3/4. Parent6 is non-genesis and
previously settled. Anchor288 is locally finalized before fresh preparation of7.
The same anchor is inherited by8. Preparation retains the complete block8 proposal;
the abstract deterministic `admit` call with software0 refuses it without changing
any live field. This refusal is scoped to the abstract admission interface and
does not conflate PrepareProposal, ProcessProposal and FinalizeBlock. Upgrade1 is
offered for the paused retained block; retry uses its unchanged anchor/witness
and candidate bytes. Advancing finality alone never reinterprets that candidate.
In the literal positive fixture, the software upgrade is the only state change
between refusal and successful retry; other offered calls have their own frames.

Block9 preserves max(parent3600+1,BFT3600,anchor3600)=3601. The second actual owner
write at324/time3888 first promotes previous next1 to active1, then proposes next2
at5184, writing (1,2,5184,0). Slot293 at288/300 remains (0,1,3600,0), while432
has (1,2,5184,0). Block10 requires software2. No recovery or stop substitutes for
these two ordinary activations.

## Same original range and proof-family premises

Capture retains exactly (6,10], its four ordered blob hashes, five continuous cuts
and three interior leaves. Reference433/time5196/hash933 is after every selected
anchor/root on the frozen ancestor chain; Land434/time5208 is strictly later.
The statement retains the existing21-word ABI projection, with active snapshot
and job dependency concretely24 (statement word20). The ordered vector
(0,1,1,2) is observer data, not an added statement field. Python replays the
actual capture/Land through `current_settlement`, including its ABI hashing,
three interior cut leaves, full original blobs and reference-number/hash binding.

Families1 and2 must independently bind that same complete original statement;
family2 is ZK. Each declared adjacent image implements either(0,1) or(1,2).
`aggregateAvailable[family]` separately premises that this family can aggregate
its adjacent-image segments into a proof of the complete ordered range. A flat
capability union alone supplies no such premise; capabilities across different
families never substitute for each family's full coverage. No three-fork ELF or
real proof generation is assumed. Registering/aggregating actual images remains
outside this offline composition.

The alternative endpoint plan contains images(0) and(2). It misses interior1;
the ordinary `FamilyCovers` guard refuses that family's completion even when the
other family covers the whole range. The source control changes this actual guard
only for family1, permits the endpoint result, and requires the other family's
normal complete result before `BackendRulesBound` fails. Exact source restoration
must reproduce ordinary whole-range progress. Independently changing capture's
`RuleVector` to use the latest slot violates `HistoricalRulesBound`, which derives
its oracle separately from immutable write history and each block's own anchor.

## Observer and execution boundary

`resolve_blocks(blocks, authenticated_views)` accepts immutable tuples of closed
block/view records, checks exact int/bool identity, own anchor root/hash, historical
schedule, witness carry/inherit, parent continuity, freshness, back-pressure,
planned stop and the literal timestamp, then returns all ordered selected rules.
`audit(text,case)` parses complete Init and every actual adjacent frame, validates
the closed receipt schema and bounded actual argument bank, replays each accepted
or refused call, and compares every live post-state field. It rejects latest-slot
reinterpretation, lossy pause, incomplete family coverage, suffix-only publication,
missing cuts and ABI additions. All three native producers call the shared
`require_healthy_native` guard before classifying outcomes, rejecting fatal Java
exception/error/stack, panic, traceback and runtime-crash diagnostics while
preserving expected TLC invariant-error lines. Native collectors and source-control
paths must call the same guard before outcome attribution.

Genuine trusted same-run collection is a caller precondition. These record bytes
cannot attest their own provenance: synthetic complete execution records can
exercise healthy parser acceptance. Such fixtures confer no native execution
evidence. Parser regressions stub only final scope classification for portable
historical/current checkouts; separate current-workspace controls and genuine
archive readbacks exercise the complete unstubbed attribution APIs.

Profiles: safety checks Bounds/HistoricalRulesBound/BackendRulesBound/RangeBound/
Settled over the exact finite offered graph; smoke/pause/progress use named
NoSmoke/NoPause/NoProgress invariant witnesses. Native0+Finished+queue0 establishes
only exhaustion of that graph; native12 for a named endpoint establishes existence.
Timeouts, setup failures, unexpected diagnostics, missing targets or skips are
INCONCLUSIVE. No engine run or passing result is implied by this guide.

Execute only after a separate reviewed packet pins the actual source, config,
tools, modes and argv. Stage clean tracked source plus explicit owned helpers;
exclude bytecode/untracked caches and preserve all original caches/artifacts.
Use managed Python, reviewed isolation, literal signal-reset entrypoints, RO
source/tools and disposable RW output. Native budgets remain at most1GiB/300s;
there is no automatic retry or budget expansion.
