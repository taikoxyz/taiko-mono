# preconfirmation-p2p architecture & usage

This crate group is a library-only scaffold for the Taiko preconfirmation P2P layer. It mirrors
`taiko-client-rs` style and leans on upstream P2P building blocks instead of reimplementing them.

## Crate roles

- `crates/types`: Spec-driven SSZ message types (gossip + req/resp), topic/protocol helpers,
  and crypto/validation utilities (domain-prefixed SSZ hashing, secp256k1 signing/recovery).
- `crates/net`: libp2p transport + behaviours (ping, identify, gossipsub, request/response),
  discovery scaffold (reth-discv5-backed), basic reputation + rate limiting, and the driver/handle
  API: `NetworkConfig`, `NetworkCommand`, `NetworkEvent`, `NetworkDriver`, `NetworkHandle`.
- `crates/service`: Async façade that owns the driver, spawns it on tokio, and exposes a small
  channel-based API (`publish_*`, `request_*`, `next_event`, `run_with_handler`). Examples live
  under `crates/service/examples/` (no binaries are installed).

## Upstream reuse (how pieces fit)

- **libp2p** (0.56.x): transport, gossipsub, request/response, ping, identify, allow/block list,
  connection limits.
- **reth-discv5** (tag `v1.9.3`, behind feature `reth-discovery`): wraps `discv5` for discovery so
  we reuse upstream maintenance instead of hand-rolling UDP/ENR wiring.
- **Kona presets** (tag `kona-client/v1.2.4`, always on): import gossipsub mesh/score parameter
  presets from `kona-gossip`/`kona-peers` instead of local defaults.
- **reth peers**: always on. Reputation is keyed by reth `PeerId` when conversion succeeds and bans
  are mirrored back to libp2p; scoring deltas remain local and fall back to the local store if
  conversion fails.
- **Kona gater** (tag `kona-client/v1.2.4`, always on): connection gater reuse from `kona-gossip`
  to apply Kona's rate limits and block/allow checks before dialing and when banning peers.

## Feature flags

- `reth-discovery` (default on): enable discovery via `reth-discv5` wrapper.
- `kona-presets`: always on (Kona gossipsub mesh/score presets).
- `kona-gater`: enable Kona connection gater in the dial/ban path (adds Kona deps).
- `real-transport-test`: real TCP integration test now runs by default with retries; use this
  feature only to disable it in constrained environments. In-memory transport tests always run.

Note: Reth peer-id keyed reputation is always enabled; it mirrors bans to libp2p `PeerId` while
still using the local scoring logic. IP colocation protection today relies on libp2p connection
limits (per-peer/incoming caps) plus request limiting; Lighthouse-style gating/scoring remains
blocked until upstream publishes a compatible crate/API for libp2p 0.56.

## Typical usage flow

1. Build a `NetworkConfig` (listen/discovery/reputation knobs, chain_id for topics/protocol IDs).
2. Start `P2pService::start(config)`; keep the returned command sender and event receiver.
3. Publish via `NetworkCommand::Publish*` or helper methods; request via `NetworkCommand::Request*`.
4. Consume `NetworkEvent` stream directly or via a `P2pHandler` using `run_with_handler`.

## Future work

- Deeper upstream reuse for gating/scoring (e.g., Kona connection gater or Lighthouse-style
  reputation) once libp2p/dependency versions align and adapters are practical.
- Stabilize the real TCP integration test so it can run by default instead of behind
  `real-transport-test`.
