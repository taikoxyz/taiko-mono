# Etna verification sensitivity campaign

This is a reviewed, finite fault inventory, not a completeness claim. Version 1
starts with three known surviving faults. A diagnostic with `SURVIVED` is useful
evidence and deliberately exits nonzero. Historical logs remain external artifacts;
subsequent verification repairs must run a fresh campaign.

Use the configured Python environment, with no additional packages:

```sh
python -B formal/etna/sensitivity/run.py --manifest formal/etna/sensitivity/mutations.json \
  --runtime "$runtime_file" --output-dir "$evidence_dir"
python -B -m unittest discover -s formal/etna/sensitivity/tests
```

`--only ID` is repeatable. Omitted inventory entries are `UNASSESSED`, with a
reason. Deliberately unassessed entries carry `unassessed_reason`. The default
readiness gate requires every selected required obligation to be `KILLED`, with
successful normal baseline and restoration. It does not assert anything about
unselected or unassessed inventory.

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
