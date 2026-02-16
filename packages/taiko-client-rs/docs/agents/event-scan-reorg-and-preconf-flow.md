# Event Scan, Reorg, and Preconf Flow

This document explains the operational flow that must be preserved when changing preconfirmation or event-sync behavior across `taiko-client-rs` crates.

Scope includes `crates/driver`, `crates/preconfirmation-driver`, `crates/whitelist-preconfirmation-driver`, and `crates/rpc`.

Whitelist-specific importer paths are included as concrete examples where those flows are implemented.

## End-to-End Flow

1. Sync pipeline runs beacon stage first, then event stage.
2. Event stage resolves a safe resume source:
   - checkpoint mode: checkpoint head published by beacon stage;
   - no checkpoint mode: local `head_l1_origin`.
3. Event stage computes a finalized-bounded target proposal and starts scanner replay from a safe anchor.
4. Event scanner processes proposal events through canonical derivation.
5. Preconf ingress only opens after both scanner-live and confirmed-sync readiness are true.
6. Every preconf ingress path enforces stale boundary: `block_number <= head_l1_origin` is stale.
7. Reorg handling remains split across event path and preconf path.

## Event-Scanner Startup And Safety Boundaries

Primary Rust behavior anchors:

- `crates/driver/src/sync/mod.rs`
  - Pipeline order is beacon-sync stage first, then event-sync stage.
- `crates/driver/src/sync/event.rs`
  - Resume source is resolved from checkpoint-synced head or local `head_l1_origin`.
  - Resume-source gaps fail closed instead of falling back to unsafe latest state.
  - Event replay start is bounded by finalized-safe proposal context.
- `crates/driver/src/sync/error.rs`
  - Explicit sync errors exist for missing checkpoint resume head and missing `head_l1_origin` resume source.

Rules:

- Resume source is fail-closed, never `Latest` fallback.
- Finalized-safe proposal context bounds event startup.
- Batch-to-last-block mapping plus anchor metadata determines scanner start point.

## Confirmed-Sync Readiness And Ingress Gate

Primary Rust behavior anchors:

- `crates/driver/src/sync/confirmed_sync.rs`
  - Defines strict readiness semantics from target proposal, target block, and `head_l1_origin`.
- `crates/driver/src/sync/event.rs`
  - Continuously evaluates scanner-live plus confirmed-sync readiness.
  - Opens preconf ingress only after readiness is true.
  - Exposes explicit wait path for ingress readiness.
- `crates/preconfirmation-driver/src/runner/preconf_ingress_sync.rs`
  - Runner waits for ingress readiness before preconf operations proceed.
- `crates/whitelist-preconfirmation-driver/src/preconf_ingress_sync.rs`
  - Whitelist importer path also blocks on event-sync ingress readiness.

Rules:

- Scanner-live is required.
- Confirmed-sync readiness is also required:
  - `target_proposal_id = nextProposalId - 1`.
  - `target == 0` is ready.
  - otherwise `last_block_id_by_batch_id(target)` must exist and `head_l1_origin >= target_block`.
- Ingress opens only when both conditions are true.

## Stale Boundary (Must Be Enforced Everywhere)

Stale rule: `block_number <= head_l1_origin`.

Primary Rust behavior anchors:

- `crates/driver/src/sync/event.rs`
  - Stale check is applied before enqueue and again during ingress processing.
- `crates/whitelist-preconfirmation-driver/src/importer/cache_import.rs`
  - Whitelist importer cached payloads at or below confirmed boundary are dropped.
- `crates/whitelist-preconfirmation-driver/src/importer/response.rs`
  - Whitelist importer unsafe-response serving excludes blocks at or below confirmed boundary.
- `crates/preconfirmation-driver/src/subscription/event_handler.rs`
  - Incoming commitments at or below event-sync tip are dropped.

Required interpretation:

- If `block_number <= head_l1_origin`, the preconf item is stale.
- If `block_number <= head_l1_origin`, it must be dropped/ignored.
- If `block_number <= head_l1_origin`, it cannot be used to reorg confirmed history.

## Event Path Reorg Handling (Sequence)

This is the event-side chain reorg handling flow and remains distinct from preconf branch handling.

Primary Rust behavior anchors:

- `crates/driver/src/sync/event.rs`
  - Event scanner loop processes canonical proposal stream and maintains strict ingress gating.
  - Confirmed boundary checks are re-evaluated as new scanner progress arrives.
- `crates/driver/src/sync/confirmed_sync.rs`
  - Readiness logic prevents unsafe preconf ingress when confirmed state is incomplete.

Sequence:

1. Consume scanner data/notifications and process proposal logs through canonical derivation.
2. Re-evaluate confirmed-sync state continuously while scanner progresses.
3. Keep ingress closed until confirmed boundary checks pass, preventing unsafe progression across confirmed state.

## New Preconf Path Branch/Reorg Handling (Sequence)

This is the preconf-side branch/orphan handling flow. It is separate from event path handling.

Primary Rust behavior anchors:

- `crates/whitelist-preconfirmation-driver/src/importer/cache_import.rs`
  - Detects parent mismatches and requests missing parent/ancestor payloads.
  - Imports only contiguous parent-valid payload chains.
- `crates/whitelist-preconfirmation-driver/src/importer/response.rs`
  - Publishes unsafe block requests/responses used for ancestry recovery.
- `crates/driver/src/sync/event.rs`
  - Final preconf submission passes through strict ingress/stale gating.

Sequence:

1. Reject stale payloads using `head_l1_origin` boundary.
2. Detect parent mismatch and request missing parent/ancestor payloads.
3. Import only contiguous parent-valid payload chains.
4. Submit candidate payloads through event-sync ingress after gating checks.
5. Never cross below `head_l1_origin` while resolving parent gaps.

## Confirmed Block Checks Agents Must Preserve

When logic needs to decide whether confirmed sync is complete, preserve this check:

- read target proposal from protocol state (`nextProposalId - 1`);
- read target block from `last_block_id_by_batch_id(target)`;
- read `head_l1_origin`;
- require `head_l1_origin >= target_block` for nonzero target.

Primary Rust behavior anchors:

- `crates/driver/src/sync/confirmed_sync.rs`
  - Encodes strict confirmed-sync readiness requirements.
- `crates/driver/src/sync/event.rs`
  - Builds confirmed-sync snapshots from protocol/core state plus custom table reads.

## Cross-Repo Parity Requirement

Before changing behavior, check:

- Rust behavior in `taiko-client-rs`.
- `altehia-reth` behavior after asking for the local repo path in the current environment.
- Protocol assumptions in `../protocol/contracts/layer1/preconf`.

If parity intentionally changes, update this doc and `docs/agents/reference-map.md` in the same PR.
