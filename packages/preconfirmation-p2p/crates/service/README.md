# preconfirmation-service

Async façade over `preconfirmation-net`. It owns the network driver task (libp2p + discv5) and exposes a small channel-based API for publishing gossip, sending req/resp, and consuming events.

## What to read first
- `src/lib.rs`: public API (`P2pService`, `P2pHandler` trait, re-exports of `NetworkConfig`, `NetworkCommand`, `NetworkEvent`).
- `crates/net/README.md`: lower-level transport/behaviour details and limits.
- `docs/specification.md`: authoritative P2P protocol (topics/IDs, varint req/resp framing, size/rate limits).

## API surface
- `P2pService::start(config) -> Result<Self>`: spawns the driver on tokio, returns a handle.
- `command_sender()`: cloneable `mpsc::Sender<NetworkCommand>`; convenience helpers `publish_*` / `request_*` forward to it.
- `next_event()` / `events()`: pull events manually (single consumer).
- `run_with_handler(handler)`: consume the event stream with a `P2pHandler` implementation (takes the receiver).
- Blocking helpers `request_*_blocking`: temporarily own the event stream until a response/error. Pick one consumption style per service instance to avoid races.
- `shutdown()`: graceful stop; `Drop` aborts if not called.

## Commands & events (re-exported from net)
- Commands: publish commitments/raw txlists; request commitments/raw txlists/head; update head.
- Events: inbound gossip, req/resp responses + inbound requests, peer connect/disconnect, errors, lifecycle (Started/Stopped).
- Config: `NetworkConfig` exposes listen/discovery, reputation thresholds (reth weights), per-peer rate limits, Kona gater knobs, chain_id-derived topics/IDs.

## Upstream reuse (via net crate)
- Kona gossipsub presets + connection gater (subnet/redial limits) are always applied.
- Reth reputation weights (`ReputationChangeWeights`) with bans mirrored to libp2p IDs; local fixed-window req/resp rate limiter.
- SSZ req/resp framed with libp2p unsigned-varint lengths and per-message size caps per `preconfirmation_types`.

## Typical usage
1. Build `NetworkConfig` (set listen/discovery, rate/reputation knobs, chain_id).
2. `let mut svc = P2pService::start(cfg)?;`
3. Send commands via `svc.command_sender()` or helpers; consume events via `next_event()` or `run_with_handler`.
4. Call `shutdown().await` on exit (drops will abort if not already stopped).

## Testing
- `cargo test -p preconfirmation-service` (service-level checks; networking behaviour is covered in `preconfirmation-net`).
