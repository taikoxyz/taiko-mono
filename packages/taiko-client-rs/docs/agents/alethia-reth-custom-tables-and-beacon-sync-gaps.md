# Altehia-Reth Custom Tables and Beacon-Sync Gaps

This document records the custom-table model that preconfirmation and event-sync logic across `taiko-client-rs` depends on.

Scope includes `crates/driver`, `crates/preconfirmation-driver`, `crates/whitelist-preconfirmation-driver`, and `crates/rpc`.

Before checking `altehia-reth` code, ask for the local path in the current environment.

## Table Model (Separate Concerns)

Altehia-reth stores Taiko-specific state in separate tables:

- per-block origin table
- confirmed-head origin pointer table
- proposal/batch-to-last-block mapping table

Behavior anchors:

- `altehia-reth/crates/db/src/model.rs`
  - Declares the three Taiko custom tables as separate storage concerns.
- `altehia-reth/crates/rpc/src/eth/eth.rs`
  - Exposes public queries for per-block origin and head origin.
- `altehia-reth/crates/rpc/src/eth/auth.rs`
  - Exposes authenticated writes/reads for head pointer, per-block origin, and batch mapping.

Implication: these tables are related but independent. Do not assume one table implies another is populated.

## Confirmed-Sync Check Dependence

`taiko-client-rs` confirmed-sync readiness depends on:

- target proposal from protocol (`nextProposalId - 1`)
- `last_block_id_by_batch_id(target)` from batch-mapping path
- `head_l1_origin` from head-pointer path

Behavior anchors:

- `crates/driver/src/sync/confirmed_sync.rs`
  - Defines strict readiness based on target block and head origin alignment.
- `crates/driver/src/sync/event.rs`
  - Reads protocol/core state and custom table signals to build readiness snapshot.

## Why Beacon Sync Can Leave Custom-Table Gaps

Driver beacon sync path submits checkpoint payloads and runs forkchoice updates without payload attributes.

Behavior anchors:

- `crates/driver/src/sync/beacon.rs`
  - Beacon sync submits remote payloads and forkchoice updates to catch up block bodies.
- `altehia-reth/crates/rpc/src/engine/api.rs`
  - Custom L1-origin persistence is tied to the payload-attributes path.
  - Without payload attributes, table persistence path is not executed.
- `altehia-reth/crates/primitives/src/payload/attributes.rs`
  - Defines preconf-block classification via L1-origin metadata shape.

## Canonical Gap Statement (Must Preserve)

When beacon sync is triggered by the driver, the node can sync event-confirmed block bodies while still missing custom-table rows for those same blocks.

- Block presence does not imply custom-table presence.
- Event-confirmed block presence does not imply per-block origin row presence.
- Event-confirmed block presence does not imply batch-mapping row presence.

This is expected recoverable state, not automatic corruption.

## Recovery / Reconciliation Signals

`taiko-client-rs` recovery behavior depends on strict confirmed-sync gates plus stale-boundary enforcement, and should not assume custom-table completeness immediately after beacon sync.

Behavior anchors:

- `crates/driver/src/sync/confirmed_sync.rs`
  - Readiness requires table-backed confirmed state, not just block-height progression.
- `crates/driver/src/sync/event.rs`
  - Uses table-backed checks before opening preconf ingress.
- `crates/whitelist-preconfirmation-driver/src/importer/cache_import.rs`
  - Whitelist importer drops outdated cached preconf payloads against confirmed boundary.

## Agent Rules For Table-Gap Safety

- Never infer confirmed-sync readiness from block height alone.
- Always check table-backed signals (`head_l1_origin`, `last_block_id_by_batch_id`) before opening preconf ingress.
- Keep stale boundary strict: `block_number <= head_l1_origin`.
- Do not treat missing custom rows after beacon sync as impossible.
