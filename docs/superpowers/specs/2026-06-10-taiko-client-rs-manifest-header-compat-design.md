# Taiko Client Rs Manifest Header Compatibility Design

## Context

`taiko-client` is already in production and currently decodes Shasta derivation source manifest headers leniently:

- `ExtractVersion` accepts any 32-byte value that fits in `uint64`, then casts it to `uint32`.
- `ExtractSize` calls `big.Int.Uint64()` without checking whether the 32-byte value fits in `uint64`, which uses the low 64 bits in the current Go runtime.

`taiko-client-rs` currently decodes the same 32-byte header words strictly through `U256` conversions:

- version must fit in `u32`.
- size must fit in `u64`.

That creates a client divergence for malformed but production-Go-accepted headers. A blob with `version = 2^32 + SHASTA_PAYLOAD_VERSION`, or with `size = 2^64 + real_size`, can decode to a real manifest in Go while Rust falls back to the default source manifest.

The production compatibility target is Go. Rust canonical output should stay unchanged, but Rust input decoding should match Go for this header edge case.

## Decision

Update only the Rust Shasta manifest header decoder in `packages/taiko-client-rs/crates/protocol/src/shasta/manifest.rs`.

The decoder should:

1. Decode the 32-byte version word as a `U256`.
2. Reject the version only if it does not fit in `uint64`, matching Go's `IsUint64()` check.
3. Truncate the accepted version to `u32` before comparing it with `SHASTA_PAYLOAD_VERSION`.
4. Decode the 32-byte size word as the low 64 bits of the `U256`, matching Go's current `big.Int.Uint64()` behavior.
5. Convert that low-64-bit size to `usize`.
6. Keep the existing payload bounds check before slicing compressed data.
7. Keep all existing fallback behavior: decode failures return the default source manifest through `decompress_and_decode_with_max_blocks`.

Do not change Rust encoding. `encode_manifest_payload` must continue writing canonical zero-extended 32-byte words for both version and size.

## Alternatives Considered

### Keep Rust Strict And Fix Go

This is cleaner protocol behavior, but it does not match the production client today. Because `taiko-client-rs` has not shipped yet, compatibility with production Go is the lower-risk target for this fix.

### Make Both Clients Strict In A Coordinated Change

This may be a future cleanup if the protocol explicitly requires canonical header words. It is not the right immediate fix because it changes production Go semantics.

### Match Go In Rust

This is the chosen approach. It contains the compatibility behavior to a private Rust parser and leaves canonical output untouched.

## Data Flow

The existing flow remains:

1. Blob sidecars are decoded and concatenated.
2. `DerivationSourceManifest::decompress_and_decode_with_max_blocks` calls `decode_manifest_payload`.
3. `decode_manifest_payload` parses the header, extracts compressed bytes, and zlib-decompresses the manifest body.
4. RLP decoding and max-block validation run unchanged.

Only step 3 changes, and only for interpreting the two 32-byte header words.

## Error Handling

The decoder should continue returning an error from `decode_manifest_payload` for:

- payloads shorter than the 64-byte header,
- versions whose full word does not fit in `uint64`,
- unsupported low-32-bit version values,
- sizes whose low 64 bits do not fit in `usize`,
- payloads whose bounded slice is shorter than the decoded low-64-bit size,
- invalid zlib data.

`DerivationSourceManifest::decompress_and_decode_with_max_blocks` should continue catching those errors and returning `DerivationSourceManifest::default()`.

## Tests

Add focused tests in `packages/taiko-client-rs/crates/protocol/src/shasta/manifest.rs`:

- `version = 2^32 + SHASTA_PAYLOAD_VERSION` decodes the real manifest.
- `version > u64::MAX` still returns the default manifest through `decompress_and_decode`.
- `size = 2^64 + real_size` decodes the real manifest.
- Existing strict failure cases still pass, with the oversized-size test updated to reflect low-64-bit truncation behavior instead of rejection.

Verification should include:

- `cargo test -p protocol shasta::manifest`
- `git diff --check`

## Out Of Scope

- Changing Go behavior.
- Changing the protocol docs.
- Changing Rust manifest encoding.
- Adding a public compatibility flag.
