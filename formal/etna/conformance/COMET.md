# Selected stock CometBFT first-block admission

`comet/first_block_test.go` consumes the three committed T01 TLC receipts and
calls the actual exported `state.BlockExecutor.ValidateBlock` in stock CometBFT
v0.40.0, commit `0880b4d378f347ab16e54ec677ff50d803f37d62`. Its module-proxy
origin metadata matches the official tag; all 1,659 module-source files were
independently compared with the official GitHub commit tree using Git blob
identities. `comet-pins.json` and `manifests/comet.json` are separate from the
existing contract/Lean pins. The upstream license is Apache-2.0.

The fixture is a trusted, separately exported actual TLC observation with frozen
byte identity and source provenance. The Go adapter additionally checks literal
raw parent/origin/anchor/generation and both header clocks. It creates genesis
state through upstream `MakeGenesisState`, creates blocks through `State.MakeBlock`
and uses a fresh executor on each validation, avoiding its validated-block cache.

| Exact subtest            | Expected stock behavior                                                                     |
| ------------------------ | ------------------------------------------------------------------------------------------- |
| `equal-times`            | Admit BFT3/EL3                                                                              |
| `parent-dominates`       | Admit BFT3/EL4                                                                              |
| `later-anchor`           | Admit BFT3/EL4                                                                              |
| `wrong-bft-time`         | Reject BFT genesis+1 second and genesis+1 nanosecond with the exact genesis-time error      |
| `wrong-initial-height`   | Reject actual height14 against initial height13 with the intended initial-height diagnostic |
| `retained-last-block-id` | Reject a structurally valid retained block ID against the empty new-instance parent ID      |
| `nonempty-last-commit`   | Reject an absent-vote entry in the first LastCommit with the exact initial-signature error  |

The height test pins the upstream message, whose expected/actual formatting
arguments are reversed, and independently checks actual input14/state13. The
nonempty-commit control has a coherent LastCommitHash and passes upstream basic
validation before reaching the intended first-commit check. The nanosecond
control preserves Unix seconds while exercising exact BFT `time.Time.Equal`.

## Boundaries

This checks selected single-block stock header/time admission. Initial height13,
genesis time3, a seeded application hash and a public-only Ed25519 validator are
premises. The fixed public point is the compressed Edwards25519 basepoint; no
private key, seed, wallet, signing or key derivation is used. This does not
validate Etna committee derivation or its public-key mapping. Empty evidence is
also a premise; a counting pool rejects any nonempty evidence and verifies the
successful executor reached its evidence-check step.

EL/anchor/generation receipt metadata is opaque transaction data whose hash Comet
checks. No Etna EL/STF, anchor authentication, actual recovery history, signatures,
proofs, rounds, locks, weighted consensus, network progress or live node runs.
The two valid EL4/BFT3 receipts demonstrate stock Comet does not require its header
time to equal the opaque EL timestamp; they do not establish EL correctness.

## Reproduction

Use an existing Go toolchain satisfying upstream Go1.25 and the existing shared
module/build caches. Set `GO_ROOT`, `GO_MODULE_CACHE`, `GO_BUILD_CACHE` and
`PYTHON` to their configured locations; the Go path must be the real SDK directory,
not a snap launcher. `$PYTHON` is the configured Python environment. No installation
or second build cache is required. Inspect capacity before dependency preparation.

Dependency preparation is a separate bounded, network-enabled operation against
public Go proxy/sumdb. Run it in a disposable copy of `comet/`, without credentials:

```sh
env -i PATH=/usr/bin:/bin GOENV=off GOTOOLCHAIN=local \
  GOMODCACHE="$GO_MODULE_CACHE" GOCACHE="$GO_BUILD_CACHE" \
  GOPROXY=https://proxy.golang.org GOSUMDB=sum.golang.org \
  timeout 240 "$GO_ROOT/bin/go" list -mod=readonly -deps -test ./...
```

The module/source pin can be read with `go mod download -json` during preparation;
its `Origin.Hash` must equal the exact commit above. Preparation resolves public
modules only; it does not build or run tests. Subsequent execution is offline:

```sh
"$PYTHON" formal/etna/conformance/run_comet.py \
  --source "$GO_MODULE_CACHE/github.com/cometbft/cometbft@v0.40.0" \
  --go-root "$GO_ROOT" --module-cache "$GO_MODULE_CACHE" \
  --build-cache "$GO_BUILD_CACHE" --output "$COMET_OUTPUT"
```

`COMET_OUTPUT` must be a fresh disposable directory outside source/tool/module
cache trees and disjoint from the persistent build cache. Canonical preflight
resolves symlink aliases and rejects equality or ancestor overlap between the two
writable roots. It also rejects either writable root overlapping the whole formal
source tree or any watched input, including inputs outside that tree. This prevents
private upstream source or the sibling
supervisor from becoming writable through a cache alias. Existing `run_isolated.py` supplies private mount/network/PID
namespaces, read-only inputs, no host home/Git/credentials and dropped capabilities.
Only disposable build temporaries and the existing physical Go build cache are
writable. Go uses `GOENV=off`, `GOTOOLCHAIN=local`, `GOPROXY=off`, `GOSUMDB=off`,
`GOVCS=*:off`, `GOWORK=off`, `CGO_ENABLED=0` and disabled telemetry. The runner does
not download anything. A private modfile points at each read-only source variant.
Keep the normal `formal/etna/` source layout: `conformance/run_comet.py` imports
its sibling `sensitivity/run.py`, whose bytes are included in watched input hashes.
The existing authoritative `execute`/`supervise` owns cancellation, caller-death,
timeout and descendant cleanup; no second supervision implementation is added.
Initialization or cleanup result125 fails closed before any admission verdict.

The campaign first records RED against a private upstream copy with only the
genesis-time equality check removed. Exactly `wrong-bft-time` must fail and the
other six subtests must pass. Normal and restored stock-source trials must each
pass all seven. The original snapshot is never edited. The recorder rejects extra
source files and missing/duplicate/skipped/unexpected/wrong-package test outcomes.
For the mutant it additionally requires both native +1s/+1ns nil-admission
failure diagnostics and one reached evidence check per offset, in exact order.
Go RUN/FAIL frames are distinguished from diagnostic payloads; missing, duplicate,
one-offset, unrelated setup or alternate-header-rejection output is rejected.
A package-only PASS or an unrelated failure under the right test name is insufficient.
Execution schema `etna-comet-first-block-execution-2` retains combined stdout/stderr,
command and supervisor argv, source/input/tool hashes, exact identities, outcomes
and before/after checks. The authoritative supervisor decodes the combined stream
as UTF-8 with replacement; `combined.log` stores that text re-encoded as UTF-8 and
its digest. Metadata explicitly records this transformation and does not claim
separate raw stdout/stderr. Reports are local evidence, not signed attestations.

Recorder regression tests can be run using the existing isolated launcher:

```sh
"$PYTHON" formal/etna/conformance/run_isolated.py \
  --read-bind "$FORMAL_SOURCE=/tmp/etna" \
  --read-bind "$PYTHON_ENV=/tmp/python-env" \
  --cwd /tmp/etna/conformance --timeout 30 -- \
  /tmp/python-env/bin/python -B -m unittest discover -s tests -p test_comet.py
```

Set `PYTHON_ENV` to the root of the existing configured virtual environment.
Its read-only bind exposes that environment at a neutral path; its base interpreter
must also be available through the launcher's read-only system binds. No interpreter
version selection or new environment is required.

The mandatory controller lifecycle lane runs separately from ordinary jailed unit
tests, because a capability-dropped namespace cannot create another child mount
namespace. `FORMAL_SOURCE` is the absolute path to `formal/etna`; `PYTHON` is the
existing configured environment's interpreter. Run its inspected host controller
with a clean environment:

```sh
env -i PATH=/usr/bin:/bin LANG=C.UTF-8 \
  "$PYTHON" -B "$FORMAL_SOURCE/conformance/controller_tests/test_comet_lifecycle.py"
```

This lane drives the actual `run_trial` to the actual isolated launcher. A disposable
sleeping executable is solely a lifecycle fixture; it supplies no Go admission
evidence. Caller TERM, caller-group TERM, INT, SIGKILL/parent-death and timeout each
require all observed owned descendants to disappear, an unrelated sentinel to
survive and no success verdict. Cleanup uses only owned pidfds/PIDs. Unsupported
Linux pidfd/subreaper/namespace capabilities fail as `INCONCLUSIVE`; they are not
silently skipped or counted as passed. The actual pinned Go campaign remains a
separate required gate.
