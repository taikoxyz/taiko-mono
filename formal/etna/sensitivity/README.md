# Etna verification sensitivity campaign

This is a reviewed, finite fault inventory, not a completeness claim. Version 1
starts with three known surviving faults. A diagnostic with `SURVIVED` is useful
evidence and deliberately exits nonzero. Historical logs remain external artifacts;
subsequent verification repairs must run a fresh campaign.

Use the configured Python environment, with no additional packages. The current
inventory requires three compatible runtime cohorts; no single Forge selector
can execute the mixed full inventory with the required exact per-item test set.
Select a cohort from [`cohorts.json`](cohorts.json), prepare its matching runtime,
and pass every listed ID explicitly with `--only`:

```sh
# cohort_name is tlc, forge-identity, or forge-rules; runtime_file must match it.
python - "$cohort_name" "$runtime_file" "$evidence_dir" <<'PY'
import json, subprocess, sys
with open("formal/etna/sensitivity/cohorts.json") as source:
    cohorts = json.load(source)["cohorts"]
cohort = next(item for item in cohorts if item["id"] == sys.argv[1])
assert cohort["required_ids"]
only = [arg for identifier in cohort["required_ids"] for arg in ("--only", identifier)]
subprocess.run([sys.executable, "-B", "formal/etna/sensitivity/run.py",
                "--manifest", "formal/etna/sensitivity/mutations.json",
                "--runtime", sys.argv[2], "--output-dir", sys.argv[3], *only], check=True)
PY
python -B -m unittest discover -s formal/etna/sensitivity/tests
```

`--only ID` is repeatable. Omitted inventory entries are `UNASSESSED`, with a
reason. Deliberately unassessed entries carry `unassessed_reason`. The runner's
`ready` flag requires every selected required obligation to be `KILLED`, with
successful normal baseline and restoration. It is a selected-cohort verdict and
does not establish full inventory coverage. Omitting `--only` selects the mixed
inventory and is not a usable full gate with the current one-runtime Forge argv.

| Cohort           | Required IDs | Engine | Exact selected Forge test                                          |
| ---------------- | ------------ | ------ | ------------------------------------------------------------------ |
| `tlc`            | 39           | TLC    | None                                                               |
| `forge-identity` | 3            | Forge  | `EtnaIdentityReplayTest::test_identity_publicHistoryPublication()` |
| `forge-rules`    | 2            | Forge  | `EtnaRulesReplayTest::test_conformance_stopHandoffReplay()`        |

The descriptor lists every exact obligation ID and full test identity. Its
regression checks require the cohorts to partition all assessed required manifest
IDs exactly once and every Forge cohort to have one homogeneous exact test set.
Unknown/unassessed IDs, missing/duplicate coverage and union/substituted Forge
test sets are rejected. The descriptor does not change runtime argv automatically.
The per-item exact Forge classifier is unchanged: selecting both tests together
does not satisfy an item that declares only one.

Full assessed-inventory evidence requires all three campaigns from the same
frozen source/manifest/tools, separately compatible runtime selections and the
same shared physical Foundry lock. Aggregate by obligation ID: verify the exact
44-ID union without duplicates or omissions, all per-ID original/mutant/restored
phases, source/tool hashes, input stability and each campaign's raw log hashes.
Retain each cohort verdict separately. A full aggregate may report complete
assessed coverage only after all these checks; unassessed protocol boundaries
remain outside that verdict.

## Portable manifest: `etna-fault-campaign-1`

Each assessed obligation has a unique `id`, explicit `required` boolean,
`obligation` prose, `engine` (`tlc` or `forge`), `source` (`formal` or `contracts`),
a safe relative `path`, one exact unique `replace: {old, new}`, nonempty unique
`workloads`, and a declared `failure`:

- TLC workloads are config paths relative to the formal root. They must declare
  one existing `MODULE` and one `EXPECT: PASS` or `EXPECT: INVARIANT Name` comment.
  `failure` is `{kind: invariant, name: Name}` or `{kind: property, name: Name}`.
  Existing expected negative-control outcomes are normal successes, not kills.
  Generic temporal violation output counts only for the sole PROPERTY/PROPERTIES
  entry in the actual config, matching the manifest name. Do not combine temporal
  properties when a named failure cannot be identified from TLC's output.
- Forge workloads are exact `path:Contract::test_signature()` identities.
  `failure` is `{kind: forge, failures: {identity: exact_reason}}`. The entire
  selected test set must execute; precisely the declared failures must fail, with
  the exact reasons. A later author must inspect the assertion's actual output
  before finalizing its reason. The initial publication reason is the planned
  observer and is not claimed to exist in the original replay suite.

## External runtime: `etna-fault-runtime-1`

Runtime JSON stays outside Git. It contains positive `timeout` seconds,
`sources: {formal: absolute_source_root, contracts: absolute_pinned_snapshot}`,
`tlc: {java: absolute_executable, jar: absolute_jar, heap_mb: 512}`, and
`forge: {lock: absolute_common_cache_lock, argv: [explicit_arguments]}`.

Forge argv must invoke the existing inspected `conformance/run_isolated.py`
through Python with `-B`, explicit read/write bindings, `--offline` and `--json`.
Its read bindings use `{contracts}` for the temporary copied contracts root and
`{tests}` for the temporary current Solidity/vector overlay; placeholders never
occur in shell commands. The physical common cache lock is held across source
verification and the entire baseline/mutated/restored sequence. Runtime authors
must supply the existing shared Foundry out/cache, pinned tools/dependencies and
config; the runner downloads nothing and introduces no cache or target.

The pinned 564-entry source verifier runs before copying actual contracts. The
runner copies originals, overlays current conformance tests/vectors, mutates one
unique temporary file, then restores and reruns it even after a failed phase.
Originals are never written. Both engines run through the mount/network/PID
namespace launcher with a clean environment; originals and Git/home are not
exposed to test processes. A private Linux subreaper supervisor bounds each command and kills/reaps nested
sessions by pidfd before restoration or lock release, including cancellation.
It requires the existing Linux pidfd/proc interfaces; unavailable cleanup support
refuses execution. The supplied Forge launcher timeout is synchronized to the
runtime timeout. Tool files, JRE and every external read-bound library directory
are fingerprinted and rechecked for drift. Use an output
directory outside both original source roots and a fresh directory per campaign.

## Evidence and interpretation

`campaign.json` and per-obligation `result.json` record the selection, status,
source/mutant hashes, actual argv, exact config/test identities, classified
baseline/mutated/restored phases, runtime/tool identities and stability checks.
Each command and raw log is persisted immediately, with SHA256. Raw output is
stored once; JSON test summaries retain only exact identity, status and reason. `KILLED` requires the intended
semantic failure. Parser errors, unrelated failures, timeouts, missing/skipped or
unexpected tests, input drift, and failed baseline/restoration are
`INCONCLUSIVE`. `SURVIVED` requires completed expected execution of every
workload. A survivor is not automatically equivalent or redundant.

The manifest's original safety workloads intentionally do not establish eventual
connection, adversarial input completeness, real proofs, committee derivation,
or full client/guest refinement. Later entries must state their own premises.

## Positive-stop handoff controls

The original 19 zero-stop handoff profiles survived a source-only complete stop
removal; the original M11 candidate observer killed it. Keep that diagnostic as
the historical boundary. The new three-program scope adds seven exact model
controls: omitted stop, premature stop, missing grid, current cleared schedule,
stopped signing bypass, recovery grid origin and candidate-time substitution.
The intended failures are `HistoricalDerivation` and `StoppedSignatureFence`.
No alternate stop implementation is checked in: faults modify unique operational
source sites only in temporary snapshots.

Two actual Inbox faults target the separate nine-call handoff replay: omitted
recovery stop-time clearing and a wrong event stopGrid shift. Their exact failures
are the existing state/event observers. Probe runs with provisional expected
reasons are inconclusive; only a fresh normal/mutant/restored campaign using the
observed exact reasons establishes kills. The original 38-call replay and shared
physical Foundry lock remain in use. No candidate proof is fabricated, and real
L2 stop execution/signing remains outside the Solidity replay.

For the stop-specific pre-knowledge and historical-preservation witnesses, a
separate reachability-loss experiment suppresses allowed exposures only after
recovery. Normal/restored graphs reach each declared witness; the mutant must
exhaust without reaching either witness. The original weak current-global-state
observers still reach under this fault and are retained as the diagnostic RED.
This experiment records `WITNESS_REACHED` versus `EXHAUSTED_NO_WITNESS` explicitly;
it is not an invariant-violation kill and is not classified by `sensitivity/run.py`.

## Recovery first-candidate controls

Three assessed `handoff-fresh-*` faults target the exact recovery first candidate
in all four recovering handoff programs: candidate time `now+1`, retained-parent
time 2 instead of 1, and parent height 18 instead of checkpoint 12. The wrong
parent time remains below the valid candidate time 3, so the fault cannot pass
silently by disabling `ObserveFresh`. Each fault must fail `FreshIdentity`, whose
independent raw parent and recovery-call/anchor observations do not use the
operational construction helpers. Successful original/restored runs are required.
The 39/3/2 compatible cohorts cover all 44 assessed required IDs; earlier 41-item
campaigns remain historical evidence for their original source head.
