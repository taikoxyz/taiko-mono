# Alethia-Reth Uzen Alignment Design

## Summary

`taiko-client-rs` is pinned to `alethia-reth` commit `432362e14ee69d6b1affb5ba3108cd62e2b2e7dd`, while the latest upstream `main` inspected for this design is local commit `b3f4ee9` from April 11, 2026. The newer upstream range introduces Uzen-aware chainspec behavior, engine-side handling for hash-relevant header fields omitted by `ExecutionPayloadV1`, stricter transaction validation, and new parent beacon block root normalization behavior.

This design updates `taiko-client-rs` to align with that upstream behavior and adds explicit Uzen fork-time constants for the Taiko L2s already modeled locally: `devnet`, `masaya`, `hoodi`, and `mainnet`.

## Goal

Make `taiko-client-rs` compatible with latest `alethia-reth` `main`, while explicitly modeling Uzen activation per supported Taiko L2 and preserving all existing event-sync and preconfirmation safety invariants.

## Non-Goals

- No changes to preconfirmation stale-boundary semantics.
- No changes to confirmed-sync ingress gating.
- No unrelated refactors of Shasta derivation, event sync, or P2P envelope structure.
- No expansion of supported chains beyond the Taiko L2s already modeled in the repository.

## Current State

- Workspace `Cargo.toml` pins `alethia-reth-consensus`, `alethia-reth-primitives`, and `alethia-reth-rpc-types` to `432362e14ee69d6b1affb5ba3108cd62e2b2e7dd`.
- Local Shasta activation policy is centralized in [crates/protocol/src/shasta/constants.rs](/Users/davidcai/taiko/taiko-mono/packages/taiko-client-rs/crates/protocol/src/shasta/constants.rs), but Uzen activation policy is not modeled there.
- Multiple execution payload submission paths construct `TaikoExecutionDataSidecar` values without the new upstream `header_difficulty` field.
- Several tests assume pre-Uzen behavior such as zero difficulty, absent parent beacon block root, and no Uzen-era header normalization.

## Upstream Changes Driving This Work

The upstream `alethia-reth` range from `432362e` to `b3f4ee9` introduces the compatibility surface relevant to this repository:

- `crates/chainspec` adds `TaikoHardfork::Uzen`, helper methods such as `is_uzen_active`, and shared Ethereum hardfork activation derived from Uzen.
- `crates/primitives` adds `TaikoExecutionDataSidecar.header_difficulty`.
- `crates/rpc` caches and hydrates header difficulty for built payloads and validates Uzen payloads with restored hash-relevant fields.
- `crates/block` and `crates/consensus` normalize parent beacon block root under Uzen/Cancun-era execution rules and reject blob transactions.

These are not only compile-time API changes. They also alter how payload submission and validation behave once Uzen is active.

## Requirements

### Dependency Alignment

- Update all `alethia-reth` git dependencies in the workspace to commit `b3f4ee9`.
- Keep the dependency set limited to the crates already consumed by this workspace unless a new upstream crate becomes required by compilation.

### Fork-Time Modeling

- Continue to model Shasta activation centrally.
- Add explicit Uzen fork-time constants for:
  - Taiko Devnet
  - Taiko Masaya
  - Taiko Hoodi
  - Taiko Mainnet
- Provide helper functions parallel to the existing Shasta helpers so call sites can resolve Uzen activation from chain ID rather than hard-coding conditions.
- Use concrete constants for the supported Taiko L2s in this repository, including devnet and the same already-modeled networks as Shasta.

### Runtime Compatibility

- Every local engine submission path that constructs or forwards a `TaikoExecutionDataSidecar` must be reviewed against upstream Uzen behavior.
- If a path submits a fully built payload or checkpoint block into `engine_newPayloadV2`, it must populate `header_difficulty` when the source block/header is available.
- If a path only builds `TaikoPayloadAttributes` for the engine to build locally, it should not fabricate downstream-only sidecar fields.
- Parent beacon block root handling must not rely on old assumptions that the field is always absent once Uzen is active.

### Test Behavior

- Tests must reflect that Uzen can be active from genesis in test chainspecs and devnet-style fixtures.
- Assertions that hard-code pre-Uzen expectations must be updated where the active fork now changes the correct result.

## Design

### 1. Centralized Fork Configuration

The fork configuration source of truth remains [crates/protocol/src/shasta/constants.rs](/Users/davidcai/taiko/taiko-mono/packages/taiko-client-rs/crates/protocol/src/shasta/constants.rs). That file already owns chain IDs, Shasta activation constants, and chain-aware helper functions used by derivation, proposer, and preconfirmation code.

This design extends that file rather than creating a parallel Uzen config module. The local policy layer should answer two questions for any supported chain ID:

- when Shasta activates
- when Uzen activates

Expected additions:

- Uzen activation constants per supported Taiko L2
- `uzen_fork_condition_for_chain(chain_id) -> Option<ForkCondition>`
- `uzen_fork_timestamp_for_chain(chain_id) -> ForkConfigResult<u64>`

If the existing error type name is too Shasta-specific after this change, it should be renamed to a generic fork-config error in the same module rather than reusing a misleading name.

### 2. Payload Submission Semantics

There are two classes of payload flows in this repository, and they must be handled differently.

#### Payload-attribute flows

These build `TaikoPayloadAttributes` and ask the engine to construct the block locally. Examples include proposer and preconfirmation attribute builders.

For these flows:

- keep using chain-aware fork timestamps and base-fee helpers
- do not synthesize `header_difficulty` in payload attributes
- allow latest `alethia-reth` builder and engine code to derive or hydrate downstream fields

#### Prebuilt-payload flows

These submit a fully materialized payload or block into `engine_newPayloadV2`. Examples include beacon-sync block injection, locally built execution payload submission, and any helper that round-trips an `ExecutionPayloadV1`.

For these flows:

- populate `TaikoExecutionDataSidecar.header_difficulty` when a block/header source exists
- preserve existing `tx_hash`, `withdrawals_hash`, and `taiko_block` behavior
- do not rely on `ExecutionPayloadV1` alone to preserve hash-relevant Uzen fields

This distinction is necessary because latest upstream explicitly compensates for `ExecutionPayloadV1` omitting fields that matter under Uzen.

### 3. Whitelist Preconfirmation Compatibility

The whitelist preconfirmation path should remain wire-compatible in this pass. The SSZ envelope already carries `parent_beacon_block_root`, but it does not carry `header_difficulty`.

The design choice is:

- do not expand the whitelist P2P envelope format in this change
- instead, adapt local submission points so they derive any required sidecar fields from local block/header context when available
- if a whitelist path cannot recover `header_difficulty` because it only has attribute-level data, it should continue to operate through payload-attribute building rather than pretending it has a fully reconstructed Uzen payload

This limits compatibility work to local engine integration and avoids introducing a network protocol change that is not required by the stated goal.

### 4. Invariant Preservation

This change must preserve the documented preconfirmation and event-sync invariants, especially:

- `WLP-INV-002`: confirmed-sync gate before ingress opens
- `WLP-INV-003`: stale preconfirmation data at or below the confirmed boundary must be dropped
- `WLP-INV-004`: preconfirmation must not reorg event-confirmed blocks
- `WLP-INV-005`: readiness still depends on scanner-live plus confirmed-sync consistency

The fork-config and payload-shape updates must not loosen any stale-boundary or ingress checks. The expected change surface is fork-aware payload construction and submission only.

## File-Level Change Map

### Workspace and dependency pinning

- [Cargo.toml](/Users/davidcai/taiko/taiko-mono/packages/taiko-client-rs/Cargo.toml)
  - bump `alethia-reth-*` git revs to `b3f4ee9`

### Central fork config

- [crates/protocol/src/shasta/constants.rs](/Users/davidcai/taiko/taiko-mono/packages/taiko-client-rs/crates/protocol/src/shasta/constants.rs)
  - add Uzen constants and helper functions
  - extend tests for supported chain IDs and timestamps

### Payload attribute builders and fork-aware callers

- [crates/driver/src/derivation/pipeline/shasta/pipeline/mod.rs](/Users/davidcai/taiko/taiko-mono/packages/taiko-client-rs/crates/driver/src/derivation/pipeline/shasta/pipeline/mod.rs)
- [crates/preconfirmation-driver/src/driver_interface/payload.rs](/Users/davidcai/taiko/taiko-mono/packages/taiko-client-rs/crates/preconfirmation-driver/src/driver_interface/payload.rs)
- [crates/proposer/src/proposer.rs](/Users/davidcai/taiko/taiko-mono/packages/taiko-client-rs/crates/proposer/src/proposer.rs)
- [crates/whitelist-preconfirmation-driver/src/importer/payload.rs](/Users/davidcai/taiko/taiko-mono/packages/taiko-client-rs/crates/whitelist-preconfirmation-driver/src/importer/payload.rs)
- [crates/whitelist-preconfirmation-driver/src/api/service/payload_build.rs](/Users/davidcai/taiko/taiko-mono/packages/taiko-client-rs/crates/whitelist-preconfirmation-driver/src/api/service/payload_build.rs)

These paths need verification that latest upstream trait/API changes compile cleanly and that local assumptions still match Uzen-era behavior.

### Prebuilt payload and engine submission paths

- [crates/driver/src/sync/engine.rs](/Users/davidcai/taiko/taiko-mono/packages/taiko-client-rs/crates/driver/src/sync/engine.rs)
- [crates/driver/src/sync/beacon.rs](/Users/davidcai/taiko/taiko-mono/packages/taiko-client-rs/crates/driver/src/sync/beacon.rs)
- [crates/test-harness/src/shasta/helpers.rs](/Users/davidcai/taiko/taiko-mono/packages/taiko-client-rs/crates/test-harness/src/shasta/helpers.rs)

These paths are the most likely places that must start populating `header_difficulty`.

### Tests likely to need expectation updates

- [crates/preconfirmation-driver/tests/preconf_e2e.rs](/Users/davidcai/taiko/taiko-mono/packages/taiko-client-rs/crates/preconfirmation-driver/tests/preconf_e2e.rs)
- [crates/preconfirmation-driver/src/driver_interface/payload.rs](/Users/davidcai/taiko/taiko-mono/packages/taiko-client-rs/crates/preconfirmation-driver/src/driver_interface/payload.rs)
- [crates/protocol/src/shasta/constants.rs](/Users/davidcai/taiko/taiko-mono/packages/taiko-client-rs/crates/protocol/src/shasta/constants.rs)
- any driver, proposer, whitelist, or harness tests asserting:
  - `difficulty == 0`
  - `parent_beacon_block_root == None`
  - blob gas fields are always absent

## Data Flow

The intended data flow after the change is:

1. Chain ID resolves both Shasta and Uzen activation through protocol constants.
2. Attribute builders continue to construct `TaikoPayloadAttributes` using chain-aware fork config.
3. If the engine builds the block locally, latest upstream handles Uzen-specific execution details.
4. If this repository submits a fully built block/payload, local code includes hash-relevant sidecar data such as `header_difficulty`.
5. Existing event-sync and preconfirmation readiness checks remain unchanged.

## Error Handling

- Unsupported chain IDs must continue to fail closed when fork timestamps are requested.
- Payload submission code must not silently drop `header_difficulty` on prebuilt Uzen payload paths once the source value is available.
- Tests should prefer explicit fork-aware assertions over implicit assumptions that happened to be true before Uzen support.

## Testing Strategy

### Local verification gates

- `just fmt`
- `just clippy`
- targeted Rust tests for updated fork config and payload-sidecar behavior
- `just test` once code changes settle, because end-to-end behavior is relevant to preconfirmation and engine submission

### Required test updates

- Add unit coverage for `uzen_fork_*_for_chain` on all supported Taiko L2 chain IDs.
- Update any tests that assume all generated or injected blocks are pre-Uzen.
- Add focused tests for prebuilt-payload submission helpers that now need `header_difficulty`.
- Preserve or extend tests proving existing Shasta behavior is unchanged on non-Uzen chains or pre-Uzen timestamps.

### Special test assumption

For this repository, tests must assume that Uzen starts from genesis when the selected test chainspec or harness fixture does so. That means existing assertions based on historical pre-Uzen semantics are no longer reliable defaults in those environments and must be made fork-aware.

## Risks

- Compile-only fixes may leave runtime engine submission wrong under Uzen. This design explicitly avoids that by auditing prebuilt payload paths.
- Over-coupling to current upstream internals could introduce churn on the next bump. Keeping the local changes focused on fork config and sidecar population contains that risk.
- Changing whitelist P2P wire format would enlarge the rollout risk. This design avoids that unless later implementation proves it is unavoidable.

## Rollout Notes

- Implement dependency bump and fork-config support first so the compiler exposes all downstream breakpoints.
- Fix payload submission paths next, starting with direct `engine_newPayloadV2` callers.
- Update tests last, but treat Uzen-from-genesis fixtures as intentional behavior rather than test drift.

## Open Decisions Already Resolved

- Scope is full Uzen-readiness, not a minimal compile-only bump.
- Explicit Uzen constants will be added only for the Taiko L2s already modeled in this repository: devnet, masaya, hoodi, mainnet.
- Test expectations must account for Uzen-at-genesis fixtures.
