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

## Consumers

Two unit-test suites read `manifest_cases.json`; neither needs Docker or a running node:

- Go: `packages/taiko-client/driver/chain_syncer/event/derivation/source_manifest_vectors_test.go`.
  From `packages/taiko-client`, run
  `go test ./driver/chain_syncer/event/derivation -run TestManifestVectors`.
- Rust: `packages/taiko-client-rs/crates/protocol/src/shasta/manifest_vectors.rs`, whose
  `f9_engine_encoding_oracle` checks each F9 `engine_decodable` claim against alethia-reth's
  transaction-list decoder. From `packages/taiko-client-rs`, run
  `cargo nextest run -p protocol manifest_vectors` (also part of `just unit`).

No end-to-end driver/engine parity run remains: the script that compared the Go and Rust
drivers over the Docker harness was removed together with the Rust client's Shasta paths.
