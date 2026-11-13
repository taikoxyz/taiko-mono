# Manifest decoding vectors

Run from the repository root: `GOTOOLCHAIN=go1.26.0 go run ./testdata/derivation_vectors/generate.go`.

The generator enforces Go 1.26.0 (the CI toolchain) because zlib output changes
between Go versions even when decompressed bytes are identical.

The corpus contains deterministic source payload bytes and expected source RLP before
metadata inheritance. A rejected source normalizes to one zero-valued block without
transactions. Acceptance is explicit in the generator; it never calls the validator.

F9 also records the original Go-encoded execution transaction list and whether reth
can decode its grammar. Signer recovery and execution validity are separate:
a decodable transaction may still be skipped by the execution engine.

All integers in hex fields are encoded in canonical RLP; hex strings omit 0x.
Framing cases build malformed RLP directly and use Go source decoding as the reference.
Only F9 cases record `engine_decodable`; other families make no engine-decoding claim.
Tests exercise forced-source cardinality separately because it is proposal metadata, not
part of the manifest payload.

## Shared Unzen boundary conformance

[`boundary_cases.json`](boundary_cases.json) adds 151 independently authored cases that Lean
and Go consume. The original 136 decoding cases remain unchanged. The named matrix
in [`boundary_coverage.json`](boundary_coverage.json) is checked against the corpus, so dropping
a named boundary or adding an unlisted case fails the fixture checks.

Each case supplies chain ID, proposal, parent header fields, and ordered sources with blob
payload bytes. Outputs include **extracted manifests before metadata validation**, per-source
block counts, ordered derived blocks and candidates, header plans, and the next parent.
Checking extraction separately prevents a later metadata fallback from hiding decoder drift.
Failed extraction normalizes to a one-zero-block manifest; an ordinary empty manifest remains
empty at extraction and defaults during metadata validation.

| Category               | Cases | Boundaries                                                                                                      |
| ---------------------- | ----: | --------------------------------------------------------------------------------------------------------------- |
| Extraction control     |     1 | Valid manifest                                                                                                  |
| Version                |     8 | 0/1/2, uint32 boundary, low-word alias, uint64 maximum and overflow                                             |
| Size and framing       |    13 | High-word aliases, size ±1, zero, uint64 maximum, truncated header                                              |
| Offset                 |     5 | Nonzero, `BLOB_BYTES - 64` ±1, exact maximum, uint24 maximum                                                    |
| Blob presence/encoding |     2 | No blobs; invalid decoded blob bytes                                                                            |
| Cardinality            |     9 | Ordinary 0/1/767/768/769; forced 0/1/2/768                                                                      |
| RLP fields             |    12 | uint64 metadata overflow, address width, extra/missing fields, leading-zero integer, root shape, trailing bytes |
| Timestamp              |    19 | Lower/upper ±1, chain-specific offset ±1, repeated/descending later block, exhausted window                     |
| Anchor                 |    26 | Parent/origin/lag ±1, stagnant proposer, forced stale/future parent, small-origin subtraction, later regression |
| Fork selection         |     4 | Mainnet/Hoodi L1 activation time with 193 Shasta blocks or mixed Shasta/Unzen blocks                            |
| Gas                    |    28 | Lower/upper ±1, 10M/45M clamps, non-divisible rounding, later failure, genesis reserve, invalid initial bounds  |
| Inheritance            |     3 | Forced metadata overwrite; default-looking proposer and forced manifests                                        |
| Source sequence        |    10 | Empty activation, empty/default/forced/valid combinations, late corruption, prefix isolation, repeated fallback |
| Header                 |    11 | Distinct ordered candidates, uint48 proposal-ID byte boundaries/maximum, sharing byte 0/100/255                 |

The Unzen model's existing scope still applies: the proposal L1 time selects the 768-block
cap; each derived block's own time selects its execution fork. Early Shasta parent-anchor
recovery and the pre-Unzen 192-block cap are not exercised here. The source offset fits its
real uint24 ABI; proposal IDs fit uint48. Negative initial-bound fixtures do not assert that
such parents occur on a valid chain. Machine-integer overflow and non-genesis parent gas
below the anchor reserve remain outside cross-client equivalence.

`inbox_forced_valid_bad_proposer` and `inbox_forced_then_late_bad_proposer` use reachable
Inbox ordering: forced sources followed by one proposer source. Other sequence cases include
abstract model inputs (such as multiple proposer sources or no final proposer) to exercise the
model's general append/isolation claims; they do not assert that the Inbox emits those shapes.

The Go adapter calls the actual blob fetch/decode and metadata functions plus header helpers
also used in production. Its anchor input is substituted at the RPC/signing boundary. Lean calls
the executable model. Signed-anchor equality, engine execution, authenticated parent reads,
and the Anchor contract's execution are not compared. Header candidates preserve order; the
signed first anchor is represented by its target and position. Rebuilt Anchor state retains
the model's trusted running-maximum assumption.

The Go forced tag records the event's source classification; it is not an independently
produced runtime field or a claim about persisted `L1Origin`. Forced behavior is tested through
the actual prepared metadata and retained/defaulted candidates. The Go adapter tests
pre-execution source/plan order; it projects parent headers instead of executing the production
engine-application loop.
Runtime insertion scheduling, L1 origin writes and authenticated parent fetching require
separate integration evidence.

Each adapter has negative controls that deliberately corrupt expected metadata, candidate
order, header gas/extraData/anchor and next-parent outputs. A comparison that stops observing
those fields fails its own controls. This is executable conformance evidence, not a proof of
whole-client equivalence or exhaustive coverage of every possible byte string.

Regenerate deterministically, then verify (Python 3.11+, no third-party packages):

```bash
python3 testdata/derivation_vectors/generate_boundaries.py
python3 testdata/derivation_vectors/generate_boundaries.py --check
python3 -m unittest discover -s testdata/derivation_vectors -p 'test_boundary_vectors.py' -v
```

The generator uses stored DEFLATE blocks to avoid compressor-version drift. Each source's
accept/default outcome and extraction rejection are explicit fixture choices; it never calls
one of the implementations being tested to obtain expected results.

Run Go from the repository root:

```bash
go test ./packages/taiko-client/driver/chain_syncer/event/derivation -run '^TestManifestVectors' -count=1
go test ./packages/taiko-client/driver/chain_syncer/event/blocks_inserter -count=1
go test ./packages/taiko-client/driver/chain_syncer/event -run '^TestProcessProposalSkipsActivationProposal$' -count=1
```

Run Lean and fixture checks from `formal/derivation` with `bash scripts/gate.sh`.
The formal workflow runs the Lean and Go adapters on draft PRs and watches Go client code and
dependency changes as well as the model, specification and corpora. These native conformance
jobs need no Docker or live chains.

### Both sides of the fork selector

[`fork_selection_cases.json`](fork_selection_cases.json) supplies 12 additional **Go-only**
extraction cases. Mainnet and Hoodi each have paired proposals at Unzen−1, Unzen and Unzen+1:
192 blocks are accepted before activation, 193 are rejected before but accepted at/after it,
and 768/769 exercise the new cap at activation. All candidate timestamps remain pre-Unzen,
so selecting the cap from a candidate's timestamp instead of the L1 proposal timestamp fails.
An always-768 selector also fails the pre-Unzen cases. The Lean model's 151-case corpus remains
Unzen-only; these client extraction checks do not extend its theorem scope.

`generate_boundaries.py --check` reproduces both generated corpora.

## Metadata-stage conformance vectors

These written vectors cover the [block-count and default-source rules](../../packages/protocol/docs/Derivation.md#per-source-manifest-extraction) after payload decoding. They are separate from the JSON corpus's decoding expectations: decoding an empty `blocks` list does not by itself apply the metadata-stage fallback. Default blocks receive the metadata specified in [Default Source Manifest](../../packages/protocol/docs/Derivation.md#default-source-manifest).

| Case                          | Setup                                                                                        | Expected after source validation                                                                                        |
| ----------------------------- | -------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Empty proposer source         | A proposal's proposer-supplied source decodes to `blocks = []`                               | Replace that source with one default block and apply inherited metadata; the proposal advances its last L2 block height |
| Empty forced-inclusion source | A forced-inclusion source decodes to `blocks = []`                                           | Replace that source with one default block and apply inherited metadata                                                 |
| Source isolation              | One valid single-block forced-inclusion source followed by an empty proposer-supplied source | Preserve the forced-inclusion source and replace only the proposer-supplied source; derive two blocks                   |

## Consumers

The Go unit-test suite and the Lean `vectors` runner read `manifest_cases.json`; neither needs
Docker nor a running node. The Go suite is
`packages/taiko-client/driver/chain_syncer/event/derivation/source_manifest_vectors_test.go`.
From `packages/taiko-client`, run
`go test ./driver/chain_syncer/event/derivation -run TestManifestVectors`.

The Rust client no longer reads any of these corpora. Its Shasta manifest decoder was removed
together with `f9_engine_encoding_oracle`, the only check of the F9 `engine_decodable` claims
against alethia-reth's transaction-list decoder, and its boundary and fork-selection adapter
went with the Unzen driver. No end-to-end driver/engine parity run remains either: the script
that compared the Go and Rust drivers over the Docker harness was removed together with the
Rust client's Shasta paths.
