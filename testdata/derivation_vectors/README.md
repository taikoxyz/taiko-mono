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
Both client adapters consume this same file. Framing cases build malformed RLP directly
and use Go source decoding as the reference; the reth engine oracle applies only
to F9 transaction-field cases, not malformed network framing. Only F9 cases record
`engine_decodable`; other families make no engine-decoding claim. Tests exercise forced-source cardinality
separately because it is proposal metadata, not part of the manifest payload.

## Metadata-stage conformance vectors

These written vectors cover the [block-count and default-source rules](../../packages/protocol/docs/Derivation.md#per-source-manifest-extraction) after payload decoding. They are separate from the JSON corpus's decoding expectations: decoding an empty `blocks` list does not by itself apply the metadata-stage fallback.

| Case                          | Setup                                                                                        | Expected after source validation                                                                                    |
| ----------------------------- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Empty proposer source         | A proposal's proposer-supplied source decodes to `blocks = []`                               | Replace that source with one default block and apply inherited metadata; the proposal advances the ending L2 height |
| Empty forced-inclusion source | A forced-inclusion source decodes to `blocks = []`                                           | Replace that source with one default block and apply inherited metadata                                             |
| Source isolation              | One valid single-block forced-inclusion source followed by an empty proposer-supplied source | Preserve the forced-inclusion source and replace only the proposer-supplied source; derive two blocks               |

## Local driver/engine verification

From packages/taiko-client-rs, run:

    bash script/test_derivation_parity.sh

This builds the Go driver and uses the existing Docker harness's two reth nodes.
Both drivers consume the same L1 proposals and sidecars. The test compares pinned
block hashes, ordered transaction bytes and successful anchor receipts, then submits
a subsequent normal proposal. Proposal metadata is generated from the current test
chain before inserting malformed encodings so metadata fallback cannot mask the bug.

The explicitly selected test fails if its Go binary is unavailable. Ordinary Rust
test runs leave it ignored because it additionally needs Go. The script refuses to
reuse running harness containers. TAIKO_GO_DRIVER_BIN and DERIVATION_PARITY_CASES
can select an existing binary and a comma-separated case sequence for failure controls.
The signed control and forced-source counterexample share a nonce-zero transaction.
Run `signed_control` at most once and after every `forced_type2_parity_2` case;
invalid custom ordering is rejected before either driver starts.
Use only local disposable test chains.
