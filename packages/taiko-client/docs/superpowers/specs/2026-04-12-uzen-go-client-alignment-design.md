# Uzen Go Client Alignment Design

## Goal

Update the Go `taiko-client` so it remains compatible with:

- `taiko-geth` after the Uzen changes from taiko-geth PR #543
- the current `alethia-reth` node
- the aligned Rust client behavior in `taiko-client-rs`

The design must preserve the existing Go preconfirmation HTTP and P2P wire format.

## Scope

This design covers the Go-side client behavior that interacts with Uzen-specific execution payload semantics:

- Engine API `getPayloadV2 -> newPayloadV2` round-trips
- Checkpoint / beacon-sync block injection
- Local preconfirmation block creation and later gossip of the sealed block
- Preconfirmation payload import from P2P, cache, and replay paths

This design does not change the external preconfirmation envelope shape.

## Context

`taiko-geth` Uzen adds a new hash-relevant execution payload field, `headerDifficulty`, and uses `getPayloadV2.blockValue` to transport that value back to the client. The current Go client mostly treats `engine_getPayloadV2` as returning only `ExecutionPayload`, which drops envelope metadata needed for a hash-stable Uzen `newPayloadV2`.

The current Go preconfirmation flow also does not carry an explicit difficulty field in its external wire format. It uses the existing `ExecutionPayload.PrevRandao` field and currently has inconsistent behavior between local build-time payload construction and later gossip of a sealed header. That is acceptable pre-Uzen, but it is too implicit for Uzen cross-client parity.

## Recommended Approach

Introduce one Go-only normalization layer for execution payload submission and retrieval, centered in `pkg/rpc/engine.go`, and route all Uzen-sensitive payload paths through it.

This is preferred over a minimal patch because it covers all required execution paths, and it is preferred over a broader payload abstraction rewrite because it keeps the change set focused on the current fork delta.

## Architecture

### Internal model

Keep using `engine.ExecutableData` as the base payload representation, but treat the following fields as a Uzen sidecar that must be preserved intentionally:

- `HeaderDifficulty`
- `TxHash`
- `WithdrawalsHash`
- `TaikoBlock`

The normalization layer is responsible for constructing, preserving, and validating those fields when the payload belongs to a Uzen-active chain and timestamp.

### Centralization

Concentrate Uzen payload normalization in `pkg/rpc/engine.go` rather than spreading fork-specific logic across driver, beacon sync, and preconfirmation code. The higher-level components should ask the RPC layer to:

- read a payload envelope without losing `blockValue`
- construct a `newPayloadV2` request with the right Uzen sidecar fields
- submit remote blocks or cached blocks through the same normalization rules

## Data Flow

### Engine round-trip

For `engine_getPayloadV2`:

- stop discarding the full envelope too early
- keep `ExecutionPayloadEnvelope.BlockValue` available to the caller

For `engine_newPayloadV2`:

- when Uzen is active, treat `getPayloadV2.blockValue` as the canonical source of `headerDifficulty`
- serialize `headerDifficulty` back into the `newPayloadV2` request
- keep non-Uzen behavior unchanged

If a Uzen payload cannot reconstruct its effective `headerDifficulty`, submission should fail explicitly instead of silently degrading.

### Beacon sync / checkpoint import

For checkpoint block injection:

- continue deriving the base payload from `engine.BlockToExecutableData(block, nil, nil, nil)`
- preserve the sealed block's effective difficulty when converting the checkpoint block into a `newPayloadV2` request

This guarantees that a block fetched from a checkpoint node is replayed into the local execution engine with the same Uzen hash-relevant header state that sealed it originally.

### Preconfirmation without wire changes

The preconfirmation HTTP and P2P envelope remains unchanged.

Internally, Go defines one compatibility rule:

- before sealing, Go derives the intended block difficulty from the existing payload context
- after sealing, whenever Go re-emits or replays a block, the sealed header becomes the canonical source of the effective Uzen difficulty

That rule is applied consistently to:

- local build -> sealed header -> gossip envelope
- cached envelope -> replay/import path
- received gossip -> import path

This avoids the current mismatch where one path computes difficulty during block construction but another path later republishes the sealed header's mix digest without an explicit Uzen normalization step.

## Component Changes

### `pkg/rpc/engine.go`

- Extend `GetPayload` handling so callers can preserve `ExecutionPayloadEnvelope.BlockValue`
- Add a normalized `newPayloadV2` submission path that includes Uzen sidecar fields when required
- Gate Uzen-specific behavior on chain and timestamp, matching the Rust client and current engine expectations

### `driver/chain_syncer/beaconsync/syncer.go`

- Submit checkpoint blocks through the normalized engine submission path
- Preserve the effective Uzen difficulty from the sealed header

### `driver/preconf_blocks/api.go`

- Keep the request and response wire format unchanged
- Ensure local preconfirmation build paths feed the normalized internal representation needed for later Uzen-safe submission and gossip

### `driver/preconf_blocks/util.go`

- Keep envelope construction wire-compatible
- Make sealed-header replay use the canonical post-seal difficulty source

### Preconfirmation import / replay paths

- Route received and cached payloads through the same normalization rule as local payloads
- Reject ambiguous Uzen payloads rather than submitting a payload that only one execution client accepts

## Error Handling

Uzen-specific failures should be explicit:

- missing `blockValue` / missing effective `headerDifficulty` for a Uzen engine round-trip is an error
- inability to derive a stable Uzen difficulty from a preconfirmation replay context is an error

Non-Uzen paths keep their current behavior.

The principle is simple: fail closed on hash-relevant ambiguity.

## Testing

### Unit tests

Add focused tests for:

- `getPayloadV2.blockValue -> newPayloadV2.headerDifficulty` round-trip behavior
- serialization of Uzen `newPayloadV2` requests
- non-Uzen payloads remaining unchanged

### Beacon sync tests

Add or update tests so remote block submission preserves Uzen difficulty when replaying sealed blocks.

### Preconfirmation tests

Add tests covering:

- local build -> sealed header -> gossip envelope consistency
- cached or gossiped envelope -> import path consistency
- unchanged preconfirmation wire format

### Acceptance criteria

The change is successful when:

- Go `taiko-client` can submit and replay Uzen blocks correctly against current `taiko-geth`
- the same Go flows also work against current `alethia-reth`
- pre-Uzen behavior does not regress

## Risks

The primary risk is hidden payload drift across different execution paths that appear equivalent but reconstruct difficulty differently. Centralizing normalization reduces that risk and keeps future fork-specific payload changes easier to contain.

## Out of Scope

- Changing the external preconfirmation HTTP or P2P envelope schema
- Broad refactoring unrelated to Uzen payload compatibility
- Fork behavior changes that belong entirely inside execution clients rather than the Go `taiko-client`
