# Selected stock CometBFT Bootstrap and store readback

`comet_bootstrap/bootstrap_test.go` consumes the five frozen actual M10
checkpoint-import publication receipts, schema `etna-checkpoint-import-replay-1`.
It calls the actual exported `state.Store.Bootstrap`, `Load`, `LoadValidators`
and `LoadConsensusParams` in CometBFT v0.40.0, commit
`0880b4d378f347ab16e54ec677ff50d803f37d62`. The separate existing
`comet-pins.json` and 1,659-entry `manifests/comet.json` remain unchanged.
`comet-bootstrap-pins.json` pins this experiment's exact F03 receipt, exporter,
base parser, model, existing pins and source manifest. Upstream is Apache-2.0.
The separate Go module keeps the original seven first-block tests and their
native discovery unchanged.

The collector reuses F03's strict `load_fixture` external JSON boundary and full
schema/provenance validator before native execution. The native typed JSON
projection verifies the exact frozen byte hash again before decoding. No receipt
is reconstructed from a Python/Go implementation of the import transition.
Independent native literal audits check the actual publication scalars, raw
origin/header/landed pair, every mapper-used symbolic value, app/EL/evidence
markers and the exact three public identity realizations. These precede mapping.
A separately encoded literal field observer then checks both mapped inputs and
actual stock readback, including all priorities and stored proposers; an adapter
and its output cannot establish correspondence merely by agreeing with each other.

| Exact native leaf under `TestCheckpointBootstrap` | Observation                                                                                       |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `origin-base`                                     | Fixed new genesis at height0/InitialHeight3/time100, empty parent and LastValidators              |
| `origin-landed-alternate`                         | Same fixed genesis despite different retained old-generation preimage                             |
| `current-base`                                    | Checkpoint4/time102 and the actual prefix's Last/current/next positions                           |
| `current-first-alternate`                         | Coherent power3/5 current plus its associated next priorities; key order reverses                 |
| `current-second-alternate`                        | Coherent next powers3/4 with the same current/Last as base                                        |
| `last-validator-lookup`                           | Independent historical row4 for each current profile; origin has no row2                          |
| `observer-controls`                               | Wrong field/key/power/priority/order/proposer/version/params/header-app-hash and mapping controls |

Each receipt leaf creates a fresh `cometbft-db` MemDB, invokes actual Bootstrap,
closes the store wrapper, reopens a new wrapper on that same database and calls
Load. It checks complete selected State fields, member order, public key/address,
voting power, priority, stored proposer identity/power/priority, total power,
InitialHeight, AppHash, exact time, BlockID parts, change heights, seeded version
and all consensus parameter fields including Authority. It independently reads
current/next validator and consensus-param rows through exported APIs and decodes
their raw protobuf metadata. Historical Last rows are owned by the dedicated
lookup leaf. State serialization alone does not prove those independent rows exist.

For origin, Bootstrap writes full validator rows3/4 and params row3. For current,
it writes full validator rows4/5/6 and params row5, while State retains
LastHeightValidatorsChanged6. Row LastHeightChanged values4/5/6 are a different
quantity and are checked independently. The origin exception is actual stock
State serialization: LastValidators is omitted at LastBlockHeight0 and loads as
empty; Bootstrap does not manufacture a historical row2.

## Explicit realizations and limits

Symbolic keys1/2/3 map to public Edwards25519 points B/-B/2B. Their compressed
encodings and independently observed addresses are literal in the native test.
-B flips the sign bit of B's compressed public encoding. 2B is public Edwards
curve doubling; no private scalar, seed, wallet, signing or signature API is used.
This realizes symbolic identities for stock storage and is not Etna's actual
secp256k1eth key mapping. The key2 address sorts below key1, as required by the
power3/5 alternate's tie. Membership arrays use actual Comet power/address order;
priorities and stored proposers are assigned and observed by key identity.

The fixed origin has current powers3/2, priorities[-2,2], stored proposer1; next
has priorities[1,-1], stored proposer2. Current checkpoint4 has Last powers3/2,
priorities[1,-1], stored proposer2, the actual earlier-prefix next set. This is an
explicit realization of M10's opaque WindowValidators4 token, not reconstructed
archive history. The selected coherent current/next pairs were independently
derived from fixed genesis and two actual stock state updates during the positive
premise audit; this module does not add another prefix transition engine.
Base next priorities[2,-1] legitimately sum to1 after stock negative floor division.
The first-alternate next stores proposer2 at priority-1 while key3 has priority1.
Neither zero-sum normalization nor choosing the current maximum preserves this state.

Opaque EL and retained Comet/BlockID symbols map to
`SHA256("etna-bootstrap/" || domain || NUL || canonicalJSON(symbol))`, using
separate `el`, `block-id` and `block-parts` domains. Canonical JSON has sorted
record keys, compact separators and exact integers. `mapping_vectors.json`
records independent literal input/digest vectors. Empty genesis fields remain
empty. BlockID parts use Total1 and a separate mapped part hash. These are explicit
trusted mappings, not actual stock block commitments or authenticated history.
Actual validator header commitments come from Comet's mapped-set Merkle Hash,
whose literal vectors are checked; they are not an arbitrary SHA256 of symbolic
VHash. LastResultsHash is actual `state.TxResultsHash` of one fixed ExecTxResult
(Code0, empty Data, GasWanted0, GasUsed0), checked against its literal digest.

Version and enumerated valid default consensus params are seeded premises;
M10 does not export their contents. Parameter/version field observers enumerate
those premises separately from the adapter's actual defaults. State.MakeBlock
checks selected next-header projection: origin time100, and current time103 from
public unsigned timestamp records supplied solely to MedianTime. No ValidateBlock,
VerifyCommit, signature, commit admission, EL/STF, evidence validation, committee
registry derivation, consensus round, networking or proving claim follows.
MemDB plus a reopened store wrapper checks stock serialization, not process
restart, storage failure or power-loss durability. Model durable/trust markers
remain model observations, not such database guarantees. This is not a concrete
Etna checkpoint importer or full valid archive/history demonstration.

## Source fault, exact evidence and restoration

The collector copies the pinned source privately and removes only Bootstrap's
LastValidators independent-row write in `state/store.go`, using a unique exact
source selector. The original 1,659-entry source snapshot is never edited. Whole
private manifests contain exactly the same paths, with only that target file's
size/SHA256/Git blob entry updated for the mutant. Every original/mutant/restored
phase verifies the entire snapshot before and after execution.

The actual source fault must fail only `last-validator-lookup`; the other six
leaves pass. That leaf continues through the three current cases and emits exactly
three ordered diagnostics. Each requires actual typed ErrNoValSetForHeight4,
a nil returned set, absent raw row4 and independently preserved serialized
State.LastValidators. It has no knowledge of campaign phase. No setup/parser
failure or invented wrapper result earns missing-write credit. The recorder
requires the exact native identity/package/exit outcomes and all three semantic
payloads. The entire mutant output sequence must contain only the fixed Go
RUN/PASS/FAIL/package frames plus those three diagnostic rows, in native order.
Unexpected parent, package or successful-leaf diagnostics also reject the trial:
their existing terminal outcomes cannot expose another error when the parent
and package already fail. Optional OutputType must agree with frame/error
semantics when present; absence does not weaken payload validation. A retained
actual mutant JSON stream in `tests/fixtures/comet-bootstrap-mutant.jsonl` drives
portable regressions for every channel, metadata-free diagnostics and error-typed
framework banners. Omissions, duplicates, reordered/changed diagnostics, extra
frames and wrong source framing reject the record. It fails closed on supervisor
initialization/cleanup result125.

After the mutant, original stock must pass all seven. The collector restores
original bytes into the SAME faulted private source, verifies all1,659 original
entries and re-executes all seven successfully there. Merely running a second
clean copy is not restoration evidence. Native tests use `-count=1`; different
actual source bytes drive the Go build cache key. The existing physical cache is
reused without cleaning or creating another cache.

## Reproduction

Use the existing configured Python/Go SDK/module cache/build cache and the shared
Go build-cache lock. Public dependency preparation, if ever necessary, is separate
from execution; this collector neither downloads nor installs anything. All current
module versions/sums reuse the existing first-block module's prepared dependencies.

```sh
"$PYTHON" formal/etna/conformance/run_comet_bootstrap.py \
  --source "$GO_MODULE_CACHE/github.com/cometbft/cometbft@v0.40.0" \
  --go-root "$GO_ROOT" --module-cache "$GO_MODULE_CACHE" \
  --build-cache "$GO_BUILD_CACHE" --build-lock "$GO_BUILD_LOCK" \
  --output "$BOOTSTRAP_OUTPUT"
```

Output must be fresh and disjoint from all source/tool/module-cache/watched
inputs and the persistent build cache. Existing canonical `validate_layout`
rejects symlink aliases and writable overlaps. The collector uses existing
run_isolated read-only namespace bindings, offline Go environment, no home/Git/
credentials/network and dropped capabilities. Only disposable build/output and
existing build cache bindings are writable. Existing authoritative
`EXECUTION.execute/supervise` owns interruption, caller death, deadline and nested
descendant cleanup; its shared lock helper is reused. No second runner or
supervision framework is introduced, and shared helper bytes are unchanged.

Execution schema `etna-comet-bootstrap-execution-1` records actual command and
supervisor argv, exact source/input/tool/receipt/exporter/module hashes, outcomes,
mutant bytes/manifests and actual restoration. Generated executed modfile/sum
files receive their own read-only binding, disjoint from writable build/output.
Their bytes are recorded before execution and must match afterward before native
outcomes are accepted. As in the existing supervisor,
combined stdout/stderr is decoded with UTF8 replacement and re-encoded into
combined.log; metadata names this transformation rather than claiming raw separate
streams. Default `tests/test_comet_bootstrap.py` uses no JVM or Go execution.
The actual three-phase native lane is the explicit collector command above.
