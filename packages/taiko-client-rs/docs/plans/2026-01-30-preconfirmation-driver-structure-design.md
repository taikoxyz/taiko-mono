# Preconfirmation Driver Structure Refinement Design

**Goal:** Refactor the preconfirmation-driver crate structure to improve modularity and readability
without changing behavior or public APIs.

**Scope:** Apply the recommended re-org (A) plus the moderate module splits (B). No
forward-compatibility shims or compatibility re-exports are required.

## Architecture Summary

We keep the crate's top-level API stable and focus on reorganizing internal modules into
smaller, single-responsibility files. Key changes:

- Move runner-specific sync bootstrap into a `runner` submodule.
- Move node RPC implementation details into the `rpc` namespace.
- Split large modules (`subscription`, `storage`, `sync`) into smaller sub-files.
- Keep module entry points (`mod.rs`) as the public-facing surfaces.

## Proposed Layout

```
src/
├── client.rs                 # PreconfirmationClient + EventLoop (may stay as-is)
├── config.rs
├── driver_interface/
│   ├── embedded.rs
│   ├── payload.rs
│   └── traits.rs
├── error.rs
├── metrics.rs
├── node.rs                   # Orchestrator only
├── preconf_ingress_sync.rs   # Removed (moved under runner)
├── rpc/
│   ├── api.rs
│   ├── mod.rs
│   ├── node_api.rs           # Node RPC implementation details
│   ├── server.rs
│   └── types.rs
├── runner/
│   ├── driver_sync.rs        # DriverSync + wait helpers
│   └── mod.rs                # PreconfirmationDriverRunner
├── storage/
│   ├── awaiting.rs           # CommitmentsAwaitingTxList
│   ├── mod.rs                # Re-exports + CommitmentStore trait
│   └── store.rs              # InMemoryCommitmentStore
├── subscription/
│   ├── event_handler.rs      # Event handler + validation flow
│   ├── mod.rs                # PreconfirmationEvent + re-exports
│   └── submission.rs         # Submission helpers
├── sync/
│   ├── catchup.rs            # TipCatchup + chain building
│   ├── mod.rs                # Re-exports
│   └── txlist_fetch.rs       # Concurrent txlist fetch helpers
└── validation/
    └── mod.rs
```

## Data Flow and Responsibilities

- `node.rs` wires the embedded driver, p2p client, and rpc server.
- `rpc/node_api.rs` holds the `PreconfRpcApi` implementation used by `node.rs`.
- `runner/driver_sync.rs` handles driver event-sync bootstrapping for the runner.
- `subscription/event_handler.rs` processes inbound gossip and validation, and emits
  events to subscribers. Submission helpers live in `subscription/submission.rs`.
- `storage/store.rs` owns the commitment/txlist persistence and pruning logic; the
  pending buffer eviction policy is isolated in `storage/awaiting.rs`.
- `sync/catchup.rs` handles tip catch-up; `sync/txlist_fetch.rs` encapsulates IO
  concurrency and fetch requests.

## Migration Notes

- Update intra-crate `use` paths to new module locations.
- Keep public exports from `lib.rs` and `mod.rs` stable where possible.
- Update README module tree to reflect the new structure.

## Testing

Run:

- `just fmt`
- `just clippy-fix`
- `PROTOCOL_DIR=/Users/davidcai/Workspace/taiko-mono-shasta/packages/protocol just test`

No behavior changes are expected; failures should indicate module wiring issues.
