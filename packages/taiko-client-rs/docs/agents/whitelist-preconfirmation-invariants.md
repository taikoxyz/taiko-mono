# Preconfirmation and Event-Sync Invariants (Canonical)

This is the canonical invariant catalog for AI code agents working on preconfirmation and event-sync behavior in `taiko-client-rs`.

The `WLP` invariant prefix is kept for continuity, but scope is broader than whitelist-only flows.

## Scope

- These invariants apply across `crates/driver`, `crates/preconfirmation-driver`, `crates/whitelist-preconfirmation-driver`, and `crates/rpc`.
- Some anchors reference whitelist-specific importer paths, but boundary, gating, and custom-table assumptions are shared cross-crate.

## Agent Contract

- Read this file, `docs/agents/event-scan-reorg-and-preconf-flow.md`, and `docs/agents/alethia-reth-custom-tables-and-beacon-sync-gaps.md` before changing preconfirmation or event-sync behavior.
- In plans and reviews, cite affected IDs (`WLP-INV-001..010`).
- If you need to inspect `altehia-reth`, ask for its local path first; do not assume where it is checked out.
- Do not merge behavior changes that violate any invariant unless the invariant docs are intentionally updated in the same change.

## Glossary

- `event-confirmed block`: an L2 block at or below the current `head_l1_origin` boundary and treated as canonical from event sync perspective.
- `preconf block`: an unsafe/offchain-propagated block above `head_l1_origin`.
- `scanner-live`: event scanner has emitted its live-transition notification.
- `confirmed-sync readiness`: strict gate where target proposal resolution and `head_l1_origin` consistency indicate the confirmed range is locally present.
- `head_l1_origin`: execution-engine pointer to the latest confirmed L2 block origin.
- `l1_origin` (per block): per-block origin metadata row keyed by L2 block number.
- `batch_to_last_block`: mapping from proposal/batch ID to its last L2 block number.
- `beacon-sync gap`: situation where block bodies exist locally but custom Taiko tables (`l1_origin`, `head_l1_origin`, `batch_to_last_block`) are missing for some blocks.

## Invariants

### WLP-INV-001

Event sync startup must use checkpoint resume head or local `head_l1_origin` recovery context, and the startup target must remain finalized-safe.

- Assumptions:
  - Checkpoint mode trusts the checkpoint head actually reached by local beacon sync.
  - Non-checkpoint mode requires local `head_l1_origin` and must fail closed if missing.
- Failure mode if broken:
  - Starting from `Latest` or another unsafe point can include local-only preconf chain state and skip required historical event replay.

### WLP-INV-002

Preconf ingress must not go live until both conditions hold: scanner-live and confirmed-sync readiness.

- Assumptions:
  - Scanner-live alone is insufficient.
  - Confirmed-sync readiness is strict and fail-closed.
- Failure mode if broken:
  - Unsafe preconf blocks can be admitted before event-confirmed boundary is established.

### WLP-INV-003

Any preconf block where `block_number <= head_l1_origin` is stale and must be ignored/rejected.

- Assumptions:
  - This stale boundary check must be enforced in all ingress paths.
- Failure mode if broken:
  - Preconf data can overwrite or conflict with event-confirmed chain state.

### WLP-INV-004

Preconf processing must never reorg event-confirmed blocks.

- Assumptions:
  - Event-confirmed boundary is represented by `head_l1_origin`.
  - Parent-recovery/orphan handling cannot cross below confirmed boundary.
- Failure mode if broken:
  - Canonical confirmed history can be displaced by unsafe preconf branches.

### WLP-INV-005

Confirmed-sync readiness depends on proposal target resolution and `batch_to_last_block` plus `head_l1_origin` consistency.

- Assumptions:
  - `target_proposal_id = nextProposalId - 1`.
  - For nonzero target, readiness requires both target last block and `head_l1_origin >= target_block`.
- Failure mode if broken:
  - Preconf ingress can open before confirmed range is fully synced.

### WLP-INV-006

`head_l1_origin`, per-block `l1_origin`, and `batch_to_last_block` are separate custom-table concerns in altehia-reth.

- Assumptions:
  - Data can be present in one table and missing in another.
- Failure mode if broken:
  - Agents incorrectly infer global consistency from a single table lookup.

### WLP-INV-007

Beacon sync imports blocks but does not guarantee custom-table population.

- Assumptions:
  - Driver beacon sync submits payload and forkchoice updates without payload attributes.
  - altehia-reth custom-table persistence is tied to payload-attributes flow.
- Failure mode if broken:
  - Agents assume custom-table rows exist whenever block bodies exist.

### WLP-INV-008

Event-confirmed blocks may exist without custom-table rows after beacon sync; this is expected and recoverable.

- Assumptions:
  - Missing custom rows can happen transiently after checkpoint catch-up.
  - Subsequent event-driven paths can repopulate rows.
- Failure mode if broken:
  - Agents treat valid node state as corruption and implement incorrect recovery logic.

### WLP-INV-009

Event-driven reorg handling and preconf-driven branch/reorg handling are distinct flows; both are required.

- Assumptions:
  - Event path handles L1 reorg resets and proposal cursor rollback.
  - Preconf path handles orphan/branch imports, cache ancestry, and unsafe-head updates.
- Failure mode if broken:
  - Reorgs are only partially handled, leaving inconsistent unsafe/canonical heads.

### WLP-INV-010

Rust behavior changes must be checked against Rust implementation, altehia-reth assumptions, and protocol-contract assumptions.

- Assumptions:
  - Rust implementation in `taiko-client-rs` is the source of truth for agent decisions.
  - altehia-reth behavior may affect driver correctness and must be validated when relevant.
  - Protocol contracts define proposer/lookahead assumptions that preconf clients must honor.
- Failure mode if broken:
  - Rust changes drift from protocol or execution-engine assumptions, causing network-level incompatibility.

## Source Of Truth Links

- Detailed flow: `docs/agents/event-scan-reorg-and-preconf-flow.md`
- Custom tables + beacon gaps: `docs/agents/alethia-reth-custom-tables-and-beacon-sync-gaps.md`
- Invariant-to-code mapping: `docs/agents/reference-map.md`
