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
