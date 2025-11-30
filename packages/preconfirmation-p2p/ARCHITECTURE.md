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
- **reth-discv5** (behind feature `reth-discovery`): wraps `discv5` for discovery so we reuse
  upstream maintenance instead of hand-rolling UDP/ENR wiring.
- **Kona presets** (feature `kona-presets`): optionally import gossipsub mesh/score parameter
  presets from `kona-gossip`/`kona-peers` instead of local defaults.
- **reth peers** (feature `reth-peers`): optional adapter that stores reputation keyed by reth
  PeerId and mirrors bans back to libp2p; scoring deltas remain local.
- **Kona gater** (feature `kona-gater`): optional connection gater reuse from `kona-gossip` to
  apply Kona's rate limits and block/allow checks before dialing and when banning peers.

## Feature flags

- `reth-discovery` (default on): enable discovery via `reth-discv5` wrapper.
- `kona-presets`: use Kona gossipsub mesh/score presets.
- `kona-gater`: enable Kona connection gater in the dial/ban path (adds Kona deps).
- `reth-peers`: use reth peer-id keyed reputation backend (API surface unchanged).
- `real-transport-test`: real TCP integration test now runs by default with retries; use this
  feature only to disable it in constrained environments. In-memory transport tests always run.

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
