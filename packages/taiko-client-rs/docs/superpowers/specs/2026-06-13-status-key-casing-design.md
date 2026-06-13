# Status Key Casing Compatibility Design

## Goal

Make the Rust whitelist preconfirmation driver's `GET /status` response use the same JSON key as the Go taiko-client for the highest unsafe L2 payload block ID.

## Scope

This change is limited to the existing `ApiStatus.highest_unsafe_l2_payload_block_id` wire name. It does not add the Go-only `lookahead` or `totalCached` fields, and it does not change status value reconciliation, ingress readiness, or preconfirmation behavior.

## Current Behavior

`ApiStatus` uses `#[serde(rename_all = "camelCase")]`, so `highest_unsafe_l2_payload_block_id` serializes as `highestUnsafeL2PayloadBlockId`. The Go preconfirmation server exposes the same concept as `highestUnsafeL2PayloadBlockID`.

## Proposed Behavior

Keep `ApiStatus` as the single response DTO and add an explicit serde field rename:

```rust
#[serde(rename = "highestUnsafeL2PayloadBlockID")]
pub highest_unsafe_l2_payload_block_id: u64,
```

Other status fields continue to use the existing `camelCase` struct-level rename.

## Error Handling

No new runtime error paths are introduced. This is a serialization-only compatibility change.

## Testing

Update the `ApiStatus` serialization test to assert:

- `highestUnsafeL2PayloadBlockID` is present with the expected value.
- `highestUnsafeL2PayloadBlockId` is absent, preventing accidental regression to serde's default acronym casing.
- Existing `endOfSequencingBlockHash` and `canShutdown` assertions continue to pass.

Targeted verification should run the updated serialization test. Full completion verification remains governed by the repository instructions.

## Invariants

Impacted invariant: `WLP-INV-010`, because the change checks Rust API behavior against Go taiko-client compatibility. The change is response serialization only and does not affect stale-boundary enforcement, confirmed-sync readiness, or preconfirmation ingress.
