# Etna model-to-code checks

This is the implementation-correspondence lane of the existing Etna formal
project. It supplements bounded TLC models and conditional Lean theorems with
selected executions of pinned real contracts. Passing traces are not an
unbounded refinement proof or proof of the whole protocol.

## C01: current Lean and Registry8

`pins.json` fixes the SPEC, Lean source, contract source, tools and vectors.
The manifests list the exact selected source files: stage those paths from the
pinned GitHub revisions into caller-owned roots, without Git metadata. Existing
SDKs/dependencies may be reused only at their pinned versions. No helper downloads
or installs tools. All output, SDK and cache paths are supplied by the caller;
use a single Lake output and a single Foundry out/cache across increments.

Run helper regression tests with the project's configured Python environment:

```sh
"$PYTHON" -m unittest discover -s formal/etna/conformance/tests
"$PYTHON" formal/etna/conformance/run_baseline.py verify-source \
  --kind lean --root "$LEAN_SOURCE" \
  --manifest formal/etna/conformance/manifests/lean.json
"$PYTHON" formal/etna/conformance/run_baseline.py verify-source \
  --kind contracts --root "$CONTRACT_SOURCE" \
  --manifest formal/etna/conformance/manifests/contracts.json
```

The package at `formal/etna` in the Lean snapshot builds with Lean4.35.0:
`lake --no-cache build`. Regenerate vectors twice, into two fresh output
directories, with `lake exe etna-vectors --write OUTPUT`. The current generator
has no historical `--families`/`--provenance` interface. Its golden vector lives
at the source snapshot's repository-root
`testdata/etna_current_conformance/registry_admission.json`.

Execute inspected repository code through `run_isolated.py` on a Linux host
supporting user/mount/PID/network namespaces. See `--help`: give explicit read
binds for the selected sources/tools/dependencies, explicit write binds for
outputs, a private working directory and allowlisted environment. It exposes no
host home or Git metadata, drops capabilities and disables network access. It
is a reproducibility boundary; independently inspect the source/command before
execution. Do not treat this launcher as a general-purpose hostile-code sandbox.

For Solidity use the original `layer1` profile, Foundry1.4.2 and
Solc0.8.30/Osaka, with the exact lockfile dependency revisions. Keep the original
config location: a configuration outside the protocol root changes Foundry path
resolution. Bind an otherwise identical config with `ffi=false`. Override source,
test, remapping and shared output paths explicitly. The selected original method
is `EtnaCurrentRegistryConformanceTest.test_conformance_currentRegistryAdmission()`.
Use `--match-test test_conformance_currentRegistryAdmission --json -vv`; anchoring
the regex before the `()` signature selects no tests. Empty discovery is failure,
even when Forge exits zero.

Wrap each reviewed command with `run_baseline.py record`, supplying phase,
pinned source commit, source root, manifest, report path and bounded timeout.
For the vector phase give both `--fresh-artifact` paths; they must not exist
before execution. The recorder verifies source bytes before and after, records
stream/artifact digests and kills the process group on timeout. `summarize`
requires the three records, consumes the contract result directly from its
recorded stdout and requires two freshly generated exact vector hashes. See
`--help` for all arguments. Keep reports next to their recorded streams.

These are **trusted local evidence files**, not cryptographically authenticated
attestations. The collector rejects missing/failed phases, missing actual test
results and accidental stale/substituted artifacts. It cannot establish that an
arbitrary caller-supplied argv really executed Lean or Forge; independent review
must verify the actual argv, isolation binds, tool versions and source mapping.
Do not advertise the helper's `PASS` alone as a conformance certificate.

The contract fixture embeds an older `authorityCommit`; the current Lean vector
embeds the current SPEC authority. The only permitted bridge ignores exactly
that metadata field after checking both pinned raw files and both authority
values. Every remaining JSON field, including inputs and expected observations,
must match. Neither fixture nor expected behavior is edited. The report records
this exception explicitly.

Registry8 executes real registration, replacement and exit paths, using a mock
active committee snapshot and valid deterministic PoP/key fixtures. It does not
prove cryptography, reachability of every Lean seed state, committee selection,
whole-contract refinement or live deployment behavior.

## C02: settlement and authorization receipts

`EtnaSettlementReplay.tla` extends the unchanged settlement model. Eight finite
scripts execute its actual actions and use TLC `ENABLED` for success/rejection;
Python does not duplicate the guards. Regenerate or verify the frozen receipts:

```sh
"$PYTHON" formal/etna/conformance/export_settlement.py \
  --java "$JAVA" --jar "$TLA2TOOLS_JAR" --check
```

The exporter pins the TLC jar and exact copied source/config bytes, rejects
input drift and requires every expected receipt. `settlement_cases.json` contains
45 observations including8 initial states. The schema carries each action,
actual outcome, scalar public state, five retained landing records and three
generation origins. Fixtures and provenance are validated before replay.

Stage `solidity/EtnaSettlementReplay.t.sol` as an additional file in the pinned
contract snapshot's `test/layer1/etna/conformance/` directory, and the generated
JSON in that directory's `vectors/`. Preserve every original manifested file.
Use the C01 isolated compiler/dependency settings and the same out/cache;
select `EtnaSettlementReplayTest.test_conformance_settlementReplay()`.
The Solidity adapter also checks exact per-case receipt counts, so an omitted
last step cannot silently shorten a successful run.

The adapter scales normalized L2 grid heights by6. Model time maps monotonically
to L1 block `11+time` and timestamp `1000+12*time`; it is not physical finality.
Queue/exclusions stay empty and recovery rules remain0. Proof verification is a
strict original-statement mock: preparing a proof captures its immutable calldata
and full public statement. Submission sets that original expected statement;
it never regenerates the expectation from the new recovery domain. Both old-domain
proof scenarios additionally require the mock's exact `ProofRejected` selector,
so an unrelated precondition rejection does not substitute for that check.
Compatible fork/EL history, proof validity and initialization/owner authority
remain premises; actual cryptography and arbitrary contract executions are not
covered by these selected traces.

## C03: recovery lists and failed calls

`export_recovery.py` executes the unchanged M08 module and exports its complete
versioned PublicAttempt. Its Python layer parses TLC values and checks provenance
and completeness; it contains no acceptance predicates. Verify the frozen18
Held attempts with:

```sh
"$PYTHON" formal/etna/conformance/export_recovery.py \
  --java "$JAVA" --jar "$TLA2TOOLS_JAR" --check
```

Stage `solidity/EtnaRecoveryReplay.t.sol` and `recovery_cases.json` like C02,
preserving original manifested files and using the same compiler/cache. Run both
`EtnaRecoveryReplayTest` and `EtnaRecoveryUnheldReplayTest`. The first method checks
all18 original public attempts (nine curated kinds times two dependency classes);
the second exercises a separate public-registration/displacement/unconfirmed-unheld
variant, not an additional claimed exact M08 Displaced-profile replay.

Mapping is explicit: new-network S=0, gridq to6q, principal unit to1000 ether
(the fixture MIN_STAKE), fee unit to1 gwei, finite no-exit10000 to the actual
uint48 sentinel. Model Unix timestamp t maps to1200*t for *every\* timestamp,
including deadline, origins, queue and schedules; L1 blocks/nonces are unchanged.
This satisfies the actual minimum maxAnchorAge1152 while retaining comparison
order and inclusive equality. Symbolic keys map to real registered key fixtures;
DefaultKey maps to the actual hash of zero consensus-key fields. This mapping
covers the selected L1 transitions, not elapsed physical time or BFT membership.

The Held setup uses actual paid registrations, top-up, initialization, FI enqueue,
strict statement-bound landing and rule/stop scheduling. A second-forceExit
failure is a separately labeled Vm dependency injection: the first real registry
write is observed and complete selected raw state is compared after revert.
Mocked fault deployment/reachability and abstract callbacks are not established.

The literal confirmed95 Displaced fixture, Withdrawn profile and callback class
are explicit GAPs. A switching-network initialization can give the original
model's confirmation/start chronology a legitimate prehistory; this new-network
adapter instead tests an actual unconfirmed/unheld variant. It never plants the
missing confirmation or active snapshot in storage. Actual gas metering is paused
for the aggregate fixture as in Registry8; no transaction/block gas feasibility
or cost benchmark is implied. Proof cryptography remains mocked.

For accepted model attempts the adapter also expects the selected Recovered event:
indexed generation, Inbox emitter and complete checkpoint/L1 context/original
array payloads. A wrong expected indexed generation fails actual replay. Other
registry events and failed-call log payloads are outside this selected event check.

## C04: literal lifecycle recovery profiles

`export_recovery_lifecycle.py` executes the unchanged frozen M08 model and
exports eight Displaced/Withdrawn × Mixed/Unheld × None/SecondRegistry receipts
to `recovery_lifecycle_cases.json`. `EtnaRecoveryLifecycleReplay.t.sol` constructs
the actual public switching history and compares selected complete public states.

Old bond registration87 uses3 MIN_STAKE; topUp92 adds1 (ready97); requestExit
records93.4095 fillers have5 units each, and a paid5-unit replacement at93
displaces the unique4-unit minimum. Switching init95/cutoff94,50% forfeit and
confirm95 leave effective1/pending1; origin97 uses S=6. Withdrawn calls actual
withdraw98, clears owner/confirmation/pending and preserves lifetime metadata.
H(q)=6+6q, timestamps1200t, literal L1/exit/confirmation/ready coordinates and
bond IDs0/4096/4097 are explicit mappings. Only inventoried filler reserve is
removed from projected custody; raw filler/replacement/custody stays checked.

Three actual tests pass, including all eight receipts and exact UnknownBond
atomicity;11 exporter regressions and fresh export comparison pass. An AFTER
confirmation95→96 mutation fails the actual observer after recover. Independent
source/replay review passed. This closes C03's two literal lifecycle profile gaps,
not its callback gap. Unheld first forceExit is a no-op; no tentative-write
rollback claim follows from its second-call failure. Legacy finalization and
full-statement-bound proof mocks remain explicit imported premises.

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

## C05: actual rule and stop scheduling

`export_rules.py` consumes the frozen M11 public projection:23 programs and38
original calls. `EtnaRulesReplay.t.sol` replays real scheduleRules/scheduleStop/
recover calls with T(t)=100000+1152t, separate stored-zero/MAX sentinels, S=6,
optional public first landing12 and actual switching setup. It compares raw
slot293, all five fields, event word, counters/current origin, retained records
and failed-state equality. Two labeled concrete tests supplement uint48/ABI edges.

All three final tests pass,13 exporter regressions pass and fresh export matches.
Changing only the actual pending-rule lock from < to <= makes RulesLock/2 fail
actual acceptance at exact1152-second equality. Changing only the event stopGrid
shift192→191 fails its raw event assertion. Original-source restoration passes
all three tests. Independent source/replay review passed. Fixture/setup/assert
work is unmetered; actual selected calls are metered, not a production benchmark.

Actual L2 ruleset support/stop execution remains model-only. Legacy finalization
and seeded-landing proof mocks are explicit premises; no real STF/cryptographic
proof or registry callback-lock conformance is claimed. Sources and dependencies
are read-only in a network-disabled runner. One shared filesystem lock serializes
all actual Forge jobs; overlapping diagnostic runs were excluded from evidence.

## V03 — successful cross-contract publication

All actual successful land/setup paths in C02–C06 now call one shared
EtnaReplayTestBase observer. It compares original mapped call height/EL/stateRoot
to SignalService and original activeCommitteeSnapshot to Inbox state. No expected
value is derived from a post-call getter; prior model/abort assertions remain.

A dedicated public-history probe performs topUp at11, activateTopUp at21 and
land at22 with snapshot21/terminal12. Actual snapshot changes1→21; the initial
committee, anchor and proof remain explicit adapter/guest premises. This tests
publication wiring under real registry history, not full guest/STF correctness.

The actual full original11 tests plus this probe pass (12), and restored full12
pass. Three isolated source faults are killed by the intended new observer:
missing saveCheckpoint, wrong nonzero stateRoot312→313, and omitted active snapshot
(write leaves1 versus expected21). Zero stateRoot was rejected as an invalid
discriminator because SignalService already rejects it; the tested nonzero fault
passes the callee and fails the post-success root comparison. The minimal final
campaign uses only the dedicated probe for each mutation; full12 normal/restored
gates remain separate evidence. Missing publication additionally fails existing
Settlement replay, which previously survived it.

Independent review verifies all six files, every successful path, exact12 IDs,
three exact failure reasons/raw hashes and original564 source entries. No
production defect identified; source remains pinned/read-only. Early empty-test
selection was INCONCLUSIVE, not a kill, and was corrected before final evidence.
