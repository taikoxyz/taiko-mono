# Stock Bootstrap disk/process restart boundary

G02 exercises pinned stock CometBFT v0.40.0 commit
`0880b4d378f347ab16e54ec677ff50d803f37d62` with actual GoLevelDB. It measures
process termination and reopening on the executing filesystem. Physical
power-loss, multi-store atomicity, concrete Etna importer/App/EL persistence,
valid signatures, committee authentication, WAL and node startup remain premises
or separate obligations.

## Frozen public fixture and observers

The runner validates the actual frozen F03 `checkpoint_import_cases.json` bytes
and provenance through the existing exporter before executing native code.
Selected origin/current base cases use unmodified F04 `bootstrap_test.go` and
`mapping_vectors.json` as recorded private build inputs in the same Go test
package. Their original test parent compiles but is **not executed**. No duplicate
tracked mapper or literal state oracle is introduced. Public points are fixed
public test identities; the experiment has no private keys or signing calls.

| Case         | Selected state                                            | Independent validators rows | Params row | Required absent history |
| ------------ | --------------------------------------------------------- | --------------------------- | ---------- | ----------------------- |
| origin-base  | InitialHeight 3, LastBlockHeight 0, time 100, AppHash EL2 | 3 current, 4 next           | 3          | validators 2            |
| current-base | InitialHeight 3, LastBlockHeight 4, time 102, AppHash EL4 | 4 last, 5 current, 6 next   | 5          | none                    |

The reused literal oracle checks chain/version, height/time, BlockID/parts,
AppHash/results, validator and params change heights, full last/current/next
members, public keys/addresses, order, power, priority, stored proposer and total
power, and consensus params. Each independent validator row is checked through
both stock `LoadValidators` and raw protobuf decoding, including metadata;
params likewise use stock loading and the raw row. Complete state and row
observations appear in each passing native receipt. A public-only frozen
`comet_restart/literal_observations.json` records these complete expected outputs,
initially captured after the reused F04 oracle checked the original disk run.
The collector requires exact complete equality against that fixture too; it
does not accept height-only or row-metadata-only observations. This is output
data, not a second implementation of the F04 mapper or observer.

## Process protocol and exact native identities

`--scenario persistence` selects only `TestCheckpointRestart`:

- `origin-clean-close`, `current-clean-close`: writer calls actual Bootstrap,
  closes the store, acknowledges completion, and exits successfully. A distinct
  reader process opens a new GoLevelDB handle on the same directory.
- `origin-kill-after-ack`, `current-kill-after-ack`: writer acknowledges actual
  Bootstrap returning successfully, closes only the receipt FD, and waits without
  a DB/store Close call. The parent validates the private receipt's process ID,
  case, mode and canonical directory, kills only its owned process handle, and
  requires Wait to report SIGKILL before starting the distinct reader.
- `readiness-no-ack`, `readiness-wrong-child`, `readiness-failed-worker`: actual
  owned children omit the ACK, report a different PID, or exit 23. None permits
  reader startup; all owned children are reaped.
- `observer-controls`: real disk raw-row controls remove state or validator
  history and require the corresponding observer refusal; reused literal field
  observers reject changed initial height and validator priority. Test-only raw
  control seeding does not count as Bootstrap evidence.

Writer and reader communicate through a private inherited FD, independent of
stdout. The worker test helper is selected explicitly in subprocesses; hidden
stdout and exit status are checked exactly. Only outer selected parent/leaves
may appear in the collector's Go JSON stream. All eight leaves, exact frames,
structured receipts and outcomes must occur once. Skips, missing/duplicate
identities, wrong process/path/row values, unrelated diagnostics, extra output,
malformed/duplicate JSON and wrong return codes fail closed.

Database directories live below the explicitly writable `/tmp/output` binding,
so separate processes reopen the same persisted files. They do not depend on
fresh per-invocation namespace `/tmp` contents. Namespace execution, cancellation,
descendant cleanup, canonical input/output layout and the cache lock reuse the
existing `run_comet.py`, `run_isolated.py` and authoritative sensitivity supervisor;
this runner adds no host process-control engine.

## Source fault and restoration

The campaign runs mutant, original and restored phases. The sole private source
fault omits the **entire** final Bootstrap `batch.WriteSync` call, preserving the
subsequent batch Close. Bootstrap consequently returns nil and emits its ACK,
but reopening observes absent state and every expected independent row. Each
of the four persistence leaves must fail with its exact
`missing-bootstrap-batch ... state=absent validators=... params=...` diagnostic;
all four controls must pass. Typed missing-validator results and the exact stock
missing-params error are checked before those diagnostics are emitted. An
unrelated setup error, timeout or arbitrary failure cannot satisfy the mutant.

The same private tree is restored to the actual original bytes and verified
against every entry of the 1659-file source manifest before the restored run.
The original module cache is never edited. Source manifests, Go tool hashes,
frozen fixture/provenance inputs and exact private copied/generated build inputs
are checked before/after execution. The final summary is written only after all
three exact phase results and restoration checks pass.

Replacing `WriteSync` with `Write` would not be a deterministic SIGKILL control:
process death does not remove the OS page cache. This test makes no power-loss
or cross-store durability claim.

## Running

Supply existing inspected tools and caches; the runner never installs or fetches.
Use the one canonical physical build cache and its existing lock. For example,
with paths supplied by the calling environment:

```sh
python -B formal/etna/conformance/run_comet_restart.py \
  --scenario persistence --source "$COMET_SOURCE" --go-root "$GO_SDK" \
  --module-cache "$GO_MODULE_CACHE" --build-cache "$GO_BUILD_CACHE" \
  --build-lock "$GO_BUILD_LOCK" --output "$FRESH_OUTPUT" --timeout 180
python -B -m unittest discover -s formal/etna/conformance/tests -p test_comet_restart.py
```

Go runs offline (`GOPROXY=off`, `GOSUMDB=off`, `GOVCS=*:off`, `-mod=readonly`,
CGO disabled), with read-only source/module/tool bindings and disposable output.
Use the configured Python environment for host collector commands. A clean
campaign emits eight exact outcomes per phase and a source-restoration summary;
its measured paths/hashes belong in the execution record, not this portable
recipe. A scenario map provides an explicit extension seam for G03; this lane
does not infer actual Handshake behavior.

## Actual stock handshake scenario

`--scenario handshake` selects only `TestCheckpointHandshake`. Each leaf runs in
an owned subprocess, bootstraps and closes actual GoLevelDB state, reopens it,
creates/reopens an actual disk blockstore, starts stock local ABCI connections,
and calls exported `consensus.NewHandshaker(...).HandshakeWithContext(...)`.
The explicit local application returns controlled Info/InitChain responses and
records Info, InitChain, FinalizeBlock and Commit calls. It is a mock ABCI boundary;
its responses do not establish real Etna App/EL consistency or durability.

Blocks are unsigned **structural storage fixtures**. Stock `SaveBlock` accepts
complete parts, contiguous heights and matching seen-commit height without
verifying a quorum. No valid history, commit admission or signature claim follows.
The two app-behind controls additionally supply a literal historical validator
row solely for stock CommitInfo construction. They stop at exact controlled
FinalizeBlock/Commit errors rather than claiming a completed real EL replay.

| Native leaf                      | State / store base..height / app height | Exact observation                                   | Info / Init / Finalize / Commit |
| -------------------------------- | --------------------------------------- | --------------------------------------------------- | ------------------------------- |
| consistent-no-replay             | 4 / 4..4 / 4                            | success; zero replayed blocks                       | 1 / 0 / 0 / 0                   |
| negative-info-height             | 4 / 4..4 / -1                           | exact negative-height error                         | 1 / 0 / 0 / 0                   |
| nonempty-apphash-mismatch        | 4 / 4..4 / 4                            | exact AppHash mismatch panic                        | 1 / 0 / 0 / 0                   |
| app-ahead                        | 4 / 4..4 / 5                            | app higher than core error                          | 1 / 0 / 0 / 0                   |
| app-below-store-base             | 4 / 4..4 / 2                            | app too far below base error                        | 1 / 0 / 0 / 0                   |
| state-ahead                      | 5 / 4..4 / 4                            | StateBlockHeight > StoreBlockHeight panic           | 1 / 0 / 0 / 0                   |
| store-too-far-ahead              | 4 / 4..6 / 4                            | StoreBlockHeight > StateBlockHeight+1 panic         | 1 / 0 / 0 / 0                   |
| missing-last-response            | 4 / 4..5 / 5                            | exact absent last-response error                    | 1 / 0 / 0 / 0                   |
| wrong-height-last-response       | 4 / 4..5 / 5                            | persisted response4 cannot satisfy expected5        | 1 / 0 / 0 / 0                   |
| empty-store-equal                | 4 / empty / 4                           | success at empty-store shortcut                     | 1 / 0 / 0 / 0                   |
| empty-store-mismatch             | 4 / empty / 4                           | exact AppHash mismatch panic                        | 1 / 0 / 0 / 0                   |
| empty-store-different-app-height | 4 / empty / 5                           | success despite differing height, when hash matches | 1 / 0 / 0 / 0                   |
| nonone-first-block-crash         | 0, initial3 / 3..3 / 0                  | exact known store3 > state+1 panic after InitChain  | 1 / 1 / 0 / 0                   |
| app-behind-finalize-boundary     | 4 / 4..4 / 3                            | controlled FinalizeBlock error reached              | 1 / 0 / 1 / 0                   |
| app-behind-commit-boundary       | 4 / 4..4 / 3                            | controlled Commit error reached after FinalizeBlock | 1 / 0 / 1 / 1                   |

All cases require zero completed replay blocks. Exact panic recovery surrounds
only the exported Handshake call; setup, client lifecycle, store operations and
independent observers are outside recovery. Arbitrary panics and wrong reasons
cannot satisfy a leaf. Full panic text, actual state before/after, logical raw
state/block DB hashes, independently decoded last-response height, actual store
base/height and every observed call count are recorded and bound by the frozen
complete output fixture. `handshake_observations.json` stores four full literal
state profiles and case-specific observations captured after the original native
branch/call assertions passed. Profile references are simple data lookups; the
collector expands them and compares the entire observed state, not just heights
or hashes. Fixture provenance/case identities and exact bytes are pinned.

Stock Handshake wraps replay errors with `%v`, so its returned error does not
preserve the typed height error. The app-ahead and app-below-base leaves separately
invoke actual `ReplayBlocksWithContext` to observe exact typed
`ErrAppBlockHeightTooHigh` / `ErrAppBlockHeightTooLow`, including their fields.
Those two early-refusal probes add no application calls or writes. The exported
Handshake error object itself is checked independently; typed replay observations
are not misattributed to it.

The empty-blockstore shortcut checks AppHash and returns before the ordinary
height constraints. Its matching-hash/different-height success is a bounded stock
capability observation; it does not establish complete importer consistency.
The non1 first-block stop is already explicit in SPEC CONS-3.1-9 and ACCEPTANCE's
Q3.1-8 exception. This lane records its InitChain/state-store effect and expected
stop, with no store wipe, repair procedure or newly discovered protocol defect.

The handshake source campaign omits exactly the entire guard body in actual
`assertAppHashEqualsOneFromState`, in a private pinned source tree. Only
`nonempty-apphash-mismatch` and `empty-store-mismatch` may fail, each with exact
`missing-handshake-apphash-guard ... expected=panic got=success`; every other
receipt/outcome stays exact. The same private tree is restored and all1659 source
entries plus tools and copied/generated inputs are verified before/after as for
persistence. G02's original native source, literal oracle and eight persistence
identities retain their existing meaning and remain regression cases.

The handshake module compiles the full stock consensus package, including
unexecuted private-validator/libp2p imports. If a required public dependency is
absent, the offline compile fails without a semantic result; dependency preparation
is separate from this runner. Compiling those packages does not invoke their
node, network or signing APIs.
