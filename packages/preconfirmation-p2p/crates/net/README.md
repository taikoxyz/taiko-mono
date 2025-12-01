# preconfirmation-net

libp2p + discv5 networking layer for Taiko preconfirmation P2P. It wires gossip and req/resp, adds reputation + per-peer rate limiting, and integrates Kona’s gating presets.

## What to read first
- `src/lib.rs`: crate surface and re-exports.
- `src/config.rs`: `NetworkConfig` knobs (listen/discv5, reputation, rate limits, gater).
- `src/codec.rs`: SSZ codecs for req/resp (varint-framed, per spec IDs).
- `src/behaviour.rs`: combined libp2p behaviour (gossipsub, request-response, ping/identify, gating).
- `src/driver.rs`: `NetworkDriver` command/event loop, handlers for gossip and req/resp.
- `src/reputation.rs`: scoring, bans/greylists, per-peer rate limiter.

## Data flow (high level)
- Commands/events: the driver owns the swarm; callers send `NetworkCommand` and receive `NetworkEvent` (channels are surfaced via the service crate’s `P2pService`).
- Gossip: topics built from `preconfirmation_types::topic_*` for commitments and raw txlists.
- Req/Resp: protocol IDs from `preconfirmation_types::protocol_get_*`; SSZ + libp2p varint framing with per-message size caps; handlers in `driver.rs` with validation + rate/reputation checks.
- Gating/DoS: Kona gater for dial decisions (subnet/redial limits), per-peer req/resp rate limit, reputation decay/ban/greylist (reth weights), txlist size caps.

## Spec & integration
- Protocol spec: `docs/specification.md` (authoritative P2P specification).
- Typical integration: use the service crate (`crates/service`, see `crates/service/examples/p2p-node.rs` or `minimal_flow.rs`) which wraps `NetworkDriver` with `P2pService`.

## Testing
- Unit + integration: `cargo test -p preconfirmation-net` (includes memory-transport and real TCP tests with retries).
- Default real TCP test runs; if needed in constrained environments, see crate docs/feature notes for disabling.
