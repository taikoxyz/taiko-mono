# Unzen Derivation Source Max Blocks Design

## Context

Shasta derivation currently limits each derivation source manifest to 192 blocks in both
`taiko-client` and `taiko-client-rs`. Unzen increases this per-source limit to 768 for
proposals whose landed L1 block timestamp is at or after the configured Unzen fork timestamp.

The fork boundary must use the timestamp of the L1 block that emitted the `Proposed` event. It must
not use `blobSlice.timestamp`. On devnet, the existing Unzen timestamp override flags must affect
this feature:

- Go: `--taiko.devnet-unzen-time`
- Rust: `--devnet-unzen-timestamp`

The boundary is inclusive: `proposal_l1_timestamp >= unzen_timestamp` selects the Unzen limit.

## Goals

- Keep pre-Unzen proposal behavior unchanged with a 192-block per-source limit.
- Allow Unzen and later proposals to use a 768-block per-source limit.
- Use one shared helper per client so proposer and driver paths agree.
- Respect existing devnet Unzen timestamp overrides.
- Update protocol derivation documentation to describe the timestamp-selected limit.

## Non-Goals

- Do not change forced-inclusion source semantics. Forced-inclusion manifests still require exactly
  one block.
- Do not add new fork configuration flags.
- Do not change blob payload versioning.
- Do not regenerate generated contract bindings unless implementation discovers that it is strictly
  required.

## Architecture

Each client should define explicit constants for both eras:

- Pre-Unzen: `DERIVATION_SOURCE_MAX_BLOCKS = 192`
- Unzen and later: `UNZEN_DERIVATION_SOURCE_MAX_BLOCKS = 768`

Each client should also expose a small chain/timestamp-aware helper:

- Go: a helper in `pkg/rpc` that returns 768 when `rpc.IsUnzen(chainID, proposalTimestamp)` is
  true, otherwise 192. Keeping the helper outside `bindings/manifest` avoids a package cycle while
  still letting existing proposer and driver call sites share the same policy.
- Rust: a helper backed by `unzen_active_for_chain_timestamp(chain_id, proposal_timestamp)` that
  returns 768 when Unzen is active, otherwise 192.

The helper is the only place that selects the era-specific block limit. Existing Unzen fork lookup
logic already handles devnet timestamp overrides, so using those helpers preserves override
behavior without adding new configuration.

Unknown or unsupported chain IDs should be conservative and must not accidentally enable the
768-block limit. The helper should return the pre-Unzen limit when Unzen cannot be resolved as
active.

## Data Flow And Enforcement

### Go Driver Derivation

The Go event syncer builds Shasta metadata with the landed L1 block timestamp exposed as
`meta.GetTimestamp()`. `DerivationSourceFetcher` should use that timestamp, together with the L2
chain ID, to select the manifest block-count limit.

The current check:

```text
len(derivationSourceManifest.Blocks) > manifest.ProposalMaxBlocks
```

should become a comparison against the dynamic per-source limit selected by
`meta.GetTimestamp()`.

### Go Proposer

The proposer currently rejects transaction-list batches larger than the static 192-block limit.
That check should use the expected proposal L1 timestamp. The proposer already fetches the current
L1 head while preparing a proposal; use that head timestamp as the best available local estimate for
the proposal's landed L1 block timestamp.

There can be a boundary race if a transaction is built just before Unzen and lands in an at/after
Unzen L1 block. This is acceptable for client-side proposal prevalidation because the driver-side
derivation check uses the actual landed L1 block timestamp from the event.

### Rust Driver Derivation

`ProposedEventContext` already carries `l1_timestamp`, and `build_bundle_meta` stores it as
`proposal_timestamp`. Manifest decoding should receive a max-blocks value selected from the L2 chain
ID and this `l1_timestamp`.

The preferred implementation is to add a timestamp-aware decode path, such as:

```text
DerivationSourceManifest::decompress_and_decode_with_max_blocks(bytes, offset, max_blocks)
```

or an equivalent proposal-aware wrapper. The existing static decode behavior can remain for tests
or older callers that do not have proposal context.

### Rust Proposer

The Rust proposer currently requests only one transaction list from the pool, so normal pool mode
cannot hit either limit. The transaction builder still accepts arbitrary `TransactionLists`, so it
should validate the number of lists against the dynamic limit selected by the timestamp that will be
encoded into the manifest:

- Engine mode: `engine_params.timestamp`
- Non-engine mode: the `current_unix_timestamp()` value used for the manifest

This keeps direct builder use and future multi-block proposer behavior aligned with the protocol
limit.

### Documentation

Update `packages/protocol/docs/Derivation.md` so block-count validation says:

- The selected limit is based on the landed L1 block timestamp of the proposal.
- Before Unzen: `DERIVATION_SOURCE_MAX_BLOCKS = 192`
- At/after Unzen: `UNZEN_DERIVATION_SOURCE_MAX_BLOCKS = 768`

The documentation must not say the limit is selected by `blobSlice.timestamp`.

## Testing

### Go

Add focused tests for the dynamic max-block helper:

- timestamp just before Unzen returns 192
- timestamp equal to Unzen returns 768
- timestamp after Unzen returns 768
- devnet override changes the boundary

Update or add source-fetcher tests:

- a 193-block manifest defaults before Unzen
- a 193-block manifest is accepted at/after Unzen
- a 769-block manifest defaults at/after Unzen

Add proposer-side coverage if the existing test scaffolding can provide an L1 head timestamp without
large setup changes.

### Rust

Add protocol helper tests mirroring the Go boundary cases, including devnet override behavior.

Update manifest decode tests:

- pre-Unzen/static limit still rejects 193 blocks
- post-Unzen dynamic limit accepts 768 blocks
- post-Unzen dynamic limit rejects 769 blocks

Add transaction-builder validation tests if implementation adds the direct transaction-list length
check there.

## Edge Cases

- Forced-inclusion source manifests still must contain exactly one block.
- Decode failures and invalid manifest payloads continue to default as they do today.
- Unknown chain IDs stay conservative and do not enable 768.
- The fork boundary is inclusive: `timestamp >= unzen_timestamp`.
- Devnet timestamp overrides are honored through existing Unzen fork-resolution helpers.

## Success Criteria

- Both clients enforce 192 before Unzen and 768 at/after Unzen for proposal derivation.
- Both clients use the landed L1 block timestamp for driver-side validation.
- Devnet override flags affect the selected limit.
- Protocol docs describe the new Unzen limit and the correct timestamp source.
- Existing forced-inclusion and decode-fallback behavior is unchanged.
